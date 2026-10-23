import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/reminder_plan_words.dart';
import 'package:agenda/models/reminder_plan.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/reminder_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/subscription_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_problem.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/reminder_plans.dart';
import 'package:agenda/services/reminder_preferences.dart';

/// What the reminder sheet chose: one of the single reminder's values, as
/// the list has always given them, or a plan.
class ReminderSheetChoice {
  const ReminderSheetChoice.single(int this.value) : plan = null;
  const ReminderSheetChoice.plan(ReminderPlan this.plan) : value = null;
  final int? value;
  final ReminderPlan? plan;
}

/// One row of the single reminder: its value, and how it reads.
typedef ReminderRow = ({int value, String label, String? subtitle});

/// The reminder sheet of a task with a deadline or a day: the single
/// reminder's rows, each applied with one tap as before, then the plans.
/// «Hasta la fecha límite» opens Suave · Normal · Intenso; «A tu manera»,
/// for Pro, a field to type or say a rhythm. A plan shows what it gives
/// (its words, a strip of dots from today to the day, the count and the
/// next one) and applies with «Listo». [current] is the single row in use,
/// null while [plan] is set. [task] is the task as it would be saved. On a
/// [shared] task one line under the title, which stays in view while the
/// choices scroll, says that every choice here is only for this person:
/// none, once or a plan, each is each account's own.
Future<ReminderSheetChoice?> showReminderPlanSheet(
  BuildContext context, {
  required String title,
  required List<ReminderRow> rows,
  required int? current,
  required Task task,
  required ReminderPlan? plan,
  bool shared = false,
}) => showModalBottomSheet<ReminderSheetChoice>(
  context: context,
  isScrollControlled: true,
  builder: (context) => _ReminderPlanSheet(
    title: title,
    rows: rows,
    current: current,
    task: task,
    plan: plan,
    shared: shared,
  ),
);

/// The words typed or said in «A tu manera» when the sheet closed without a
/// choice, and the plan read from them if it was, by account and task: so
/// opening it again shows them, and asks the assistant nothing.
final _unsentProvider = Provider<Map<String, _Kept>>((ref) => {});

typedef _Kept = ({String words, ReminderPlan? plan});

enum _Open { none, rhythm, custom }

class _ReminderPlanSheet extends ConsumerStatefulWidget {
  const _ReminderPlanSheet({
    required this.title,
    required this.rows,
    required this.current,
    required this.task,
    required this.plan,
    required this.shared,
  });
  final String title;
  final List<ReminderRow> rows;
  final int? current;
  final Task task;
  final ReminderPlan? plan;
  final bool shared;

  @override
  ConsumerState<_ReminderPlanSheet> createState() => _ReminderPlanSheetState();
}

class _ReminderPlanSheetState extends ConsumerState<_ReminderPlanSheet> {
  late final Map<String, _Kept> _unsent = ref.read(_unsentProvider);
  late final String _unsentKey =
      '${ref.read(taskRepositoryProvider).ownerKey}/${widget.task.id}';

  /// Words left in «A tu manera» last time, with Pro: they win over the
  /// plan's own. A capture's task, with no id yet, keeps none.
  late final _Kept? _kept = widget.task.id != null && ref.read(hasProProvider)
      ? _unsent[_unsentKey]
      : null;
  late _Open _open = _kept != null
      ? _Open.custom
      : widget.plan == null
      ? _Open.none
      : widget.plan!.isRhythm
      ? _Open.rhythm
      : _Open.custom;
  late String _strength = widget.plan?.strength ?? ReminderPlan.normal;
  late final _words = TextEditingController(
    text: _kept?.words ?? widget.plan?.said ?? '',
  );
  final _wordsFocus = FocusNode();

  /// The field's own scroll: while listening, it follows the newest words.
  final _wordsScroll = ScrollController();
  final _section = GlobalKey();
  final _untilDayRow = GlobalKey();
  final _yourWayRow = GlobalKey();

  /// The plan read from the words in the field, while they are these.
  late ReminderPlan? _custom = _kept != null
      ? _kept.plan
      : widget.plan?.isRhythm == false
      ? widget.plan
      : null;
  late String? _readWords = _custom == null ? null : _words.text.trim();
  bool _reading = false;
  String? _problem;

  /// The words the last read found no reminders in: while the field holds
  /// them, saying it again starts from an empty field rather than adding to
  /// them. Words typed over them are kept.
  String? _unclear;

  /// A choice was applied: nothing left in the field is kept.
  bool _chosen = false;

  // Listening, with the phone's own recognizer. Its runs are numbered apart
  // from capture's, which may be open underneath.
  late final NativeSpeech _speech = ref.read(nativeSpeechProvider);
  static var _runs = 1 << 20;
  int _run = 0;
  bool _listening = false;
  String _prefix = '';
  StreamSubscription<SpeechEvent>? _speechEvents;
  Timer? _limit;
  Timer? _ending;

  DateTime get _anchor => ReminderPlans.anchor(widget.task)!;

  bool _closed = false;

  @override
  void initState() {
    super.initState();
    // Read now: the sheet's providers aren't read while it closes.
    _speech;
    _unsent;
    _unsentKey;
    _kept;
    _wordsFocus.addListener(() {
      // Leaving the field reads what was typed.
      if (!_closed && !_wordsFocus.hasFocus && !_listening) {
        unawaited(_read());
      }
    });
    _words.addListener(_wordsChanged);
    // Opened on a plan: its row at the top, its section below it, rather
    // than under the single rows.
    if (_open != _Open.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final row =
            (_open == _Open.rhythm ? _untilDayRow : _yourWayRow).currentContext;
        if (row == null || !row.mounted) return;
        unawaited(
          Scrollable.ensureVisible(
            row,
            duration: MediaQuery.disableAnimationsOf(row)
                ? Duration.zero
                : const Duration(milliseconds: 200),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _closed = true;
    final words = _words.text.trim();
    // Closed without a choice: the words, read or not, wait for the next
    // time, unless they are the plan's own. Only a saved task is known
    // again by its id; a capture's isn't.
    if (!_chosen &&
        words.isNotEmpty &&
        words != widget.plan?.said &&
        widget.task.id != null) {
      _unsent[_unsentKey] = (
        words: words,
        plan: words == _readWords ? _custom : null,
      );
    } else {
      _unsent.remove(_unsentKey);
    }
    _limit?.cancel();
    _ending?.cancel();
    unawaited(_speechEvents?.cancel());
    if (_listening) {
      unawaited(_speech.cancel(_run).catchError((Object _) {}));
    }
    _words.dispose();
    _wordsFocus.dispose();
    _wordsScroll.dispose();
    super.dispose();
  }

  void _wordsChanged() {
    // Other words than those read: their plan isn't known yet.
    if (_custom != null && _words.text.trim() != _readWords) {
      setState(() => _custom = null);
    }
  }

  /// Applies [choice] and closes: what was left in the field isn't kept.
  void _choose(ReminderSheetChoice choice) {
    _chosen = true;
    Navigator.pop(context, choice);
  }

  /// Brings the end of the open section into view after this frame: the
  /// words heard with «Dejar de escuchar», or what was read with «Listo».
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final section = _section.currentContext;
      if (_closed || section == null || !section.mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          section,
          duration: MediaQuery.disableAnimationsOf(section)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ),
      );
    });
  }

  void _toggle(_Open open) {
    setState(() {
      _open = _open == open ? _Open.none : open;
      _problem = null;
    });
    if (_open == _Open.none) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final section = _section.currentContext;
      if (section != null && section.mounted) {
        unawaited(
          Scrollable.ensureVisible(
            section,
            duration: const Duration(milliseconds: 200),
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          ),
        );
      }
    });
  }

  void _openPro() => Navigator.of(
    context,
  ).pushNamed('/subscription', arguments: ProReason.reminderPlans);

  String _zone() {
    final chosen = ref.read(regionalProvider).captureTimezone;
    if (CaptureTimezone.valid(chosen)) return chosen!;
    final account = ref.read(authProvider).account?.timezone;
    return CaptureTimezone.valid(account) ? account! : 'UTC';
  }

  /// Sends the words to the assistant, which reads them as a plan.
  Future<void> _read() async {
    if (_closed || !mounted) return;
    final words = _words.text.trim();
    if (words.isEmpty || _reading) return;
    if (_custom != null && words == _readWords) return;
    final account = ref.read(authProvider).account;
    if (account == null) return _openPro();
    final l = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    setState(() {
      _reading = true;
      _problem = null;
    });
    try {
      final answer = await ref
          .read(apiClientProvider)
          .request(
            'POST',
            'ai/reminder-plan/',
            accountId: account.id,
            data: {
              'text': words,
              'timezone': _zone(),
              'reference_time': ref
                  .read(calendarClockProvider)()
                  .toUtc()
                  .toIso8601String(),
              'anchor_date': Task.dateKey(_anchor),
              'language': language,
            },
          );
      if (!mounted) return;
      final plan = answer is Map
          ? ReminderPlan.tryParse(answer['reminder_plan'])
          : null;
      setState(() {
        if (plan == null || plan.isRhythm) {
          // Words that don't describe reminders: asked for again.
          _custom = null;
          _unclear = words;
          _problem = l.reminderPlanUnclear;
        } else {
          _custom = plan.said == null
              ? ReminderPlan.custom(plan.phases, time: plan.time, said: words)
              : plan;
          _readWords = words;
        }
      });
      _announce(_problem);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.status == 402) {
        _openPro();
        return;
      }
      setState(
        () => _problem = CaptureProblem.from(error) == CaptureProblem.offline
            ? l.reminderPlanOffline
            : l.reminderPlanFailed,
      );
      _announce(_problem);
    } catch (_) {
      if (!mounted) return;
      setState(() => _problem = l.reminderPlanFailed);
      _announce(_problem);
    } finally {
      if (mounted) {
        setState(() => _reading = false);
        // Its plan and «Listo», or its problem, in view.
        _reveal();
      }
    }
  }

  void _announce(String? message) {
    if (message == null || !mounted) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (_listening) return _stopListening();
    final l = context.l10n;
    final speech = _speech;
    final language = captureSpeechLanguage(context, ref.read(regionalProvider));
    setState(() => _problem = null);
    try {
      if (await speech.permission() != SpeechPermission.granted) {
        if (mounted) setState(() => _problem = l.reminderPlanMicOff);
        return;
      }
      if (!(await speech.knownCapability(language)).usable) {
        if (mounted) setState(() => _problem = l.reminderPlanCantListen);
        return;
      }
      if (!mounted) return;
      _run = ++_runs;
      // After words that weren't understood, start again from nothing.
      if (_unclear != null && _words.text.trim() == _unclear) _words.clear();
      _unclear = null;
      _prefix = _words.text.trim();
      _wordsFocus.unfocus();
      _speechEvents ??= speech.events.listen(
        _hear,
        onError: (Object _) => _hear(SpeechEvent(_run, 'error')),
      );
      setState(() => _listening = true);
      _reveal();
      await speech.start(_run, language);
      // Nobody needs longer for a rhythm: it stops by itself, as Listo does.
      _limit = Timer(const Duration(seconds: 30), _stopListening);
    } catch (_) {
      _endListening(read: false);
      if (mounted) setState(() => _problem = l.reminderPlanCantListen);
    }
  }

  void _hear(SpeechEvent event) {
    if (!_listening || event.run != _run) return;
    final text = event.text?.trim() ?? '';
    if (text.isNotEmpty) {
      // Words said go after those already in the field.
      final words = [_prefix, text].where((s) => s.isNotEmpty).join(' ');
      final bounded = words.length > ReminderPlan.saidLimit
          ? words.substring(0, ReminderPlan.saidLimit)
          : words;
      if (event.kind == 'segment') _prefix = bounded;
      _words.value = TextEditingValue(
        text: bounded,
        selection: TextSelection.collapsed(offset: bounded.length),
      );
      // The field grows as words come: «Dejar de escuchar» stays in view.
      _reveal();
      // Past its four lines, the newest words on its last one (UX-105).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_closed || !_wordsScroll.hasClients) return;
        _wordsScroll.jumpTo(_wordsScroll.position.maxScrollExtent);
      });
    }
    if (event.kind == 'error') {
      final heard = _words.text.trim().isNotEmpty;
      _endListening(read: heard);
      if (!heard && mounted) {
        setState(() => _problem = context.l10n.reminderPlanCantListen);
      }
    } else if (event.terminal) {
      _endListening(read: true);
    }
  }

  Future<void> _stopListening() async {
    if (!_listening) return;
    _limit?.cancel();
    // The recognizer still has the last words: give it time to send them.
    _ending = Timer(
      const Duration(seconds: 4),
      () => _endListening(read: true),
    );
    try {
      await _speech.stop(_run);
    } catch (_) {
      _endListening(read: true);
    }
  }

  void _endListening({required bool read}) {
    if (!_listening) return;
    _listening = false;
    _limit?.cancel();
    _ending?.cancel();
    unawaited(_speech.cancel(_run).catchError((Object _) {}));
    if (!mounted) return;
    setState(() {});
    if (read) unawaited(_read());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final pro = ref.watch(hasProProvider);
    final settings = ref.watch(reminderPreferencesProvider).valueOrNull;
    final now = ref.watch(calendarClockProvider)();
    final minute = settings?.dateOnlyTime;
    // On a timed day, the day's own reminder of a plan without a time of its
    // own rings at the task's usual one (D1); one with its own keeps it (D8).
    // Each plan shown is asked for its own.
    int? dayLead(ReminderPlan plan) => ReminderPlans.dayLead(
      widget.task,
      (settings ?? const ReminderPreferences()).leadMinutes,
      plan: plan,
    );
    final current = widget.plan;
    // A rhythm said while dictating is the person's, with or without Pro.
    final dictated = current?.isRhythm == false ? current : null;
    final yourWay = pro || dictated != null;
    // Plans where they help: a day still 2 or more days away, or a plan
    // already set, so it can be changed or removed.
    final plans = current != null || ReminderPlans.daysUntil(_anchor, now) >= 2;
    final strings = MaterialLocalizations.of(context);
    // Announced as ExpansionTile's header is: expanded or collapsed.
    Widget expandable({
      required GlobalKey key,
      required bool open,
      required Widget child,
    }) => Semantics(
      key: key,
      expanded: open,
      hint: open ? strings.collapsedHint : strings.expandedHint,
      onTapHint: open
          ? strings.expansionTileExpandedTapHint
          : strings.expansionTileCollapsedTapHint,
      child: child,
    );
    Widget check(bool on) =>
        on ? const Icon(Icons.check_rounded) : const SizedBox.shrink();
    Widget expander(bool open) =>
        Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded);
    final rhythm = ReminderPlan.rhythm(_strength);
    final title = Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Text(widget.title, style: theme.textTheme.titleMedium),
    );
    Widget choices({required bool withTitle}) => SingleChildScrollView(
      padding: EdgeInsets.only(top: withTitle ? 16 : 0, bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (withTitle) title,
          // The single reminder, as the list has always been: a tap
          // applies it and closes.
          for (final row in widget.rows)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(row.label),
              subtitle: row.subtitle == null ? null : Text(row.subtitle!),
              selected: current == null && row.value == widget.current,
              trailing: check(current == null && row.value == widget.current),
              onTap: () => _choose(ReminderSheetChoice.single(row.value)),
            ),
          if (plans) ...[
            const Divider(height: 17),
            expandable(
              key: _untilDayRow,
              open: _open == _Open.rhythm,
              child: ListTile(
                key: const ValueKey('reminder-plan-until-day'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(l.reminderPlanUntilDay),
                subtitle: _open == _Open.rhythm
                    ? null
                    : Text(
                        l.reminderPlanGrowing(
                          planWhen(_anchor, now),
                          planDay(_anchor, now, context.localeName),
                        ),
                      ),
                selected: current?.isRhythm == true,
                trailing: current?.isRhythm == true && _open != _Open.rhythm
                    ? check(true)
                    : expander(_open == _Open.rhythm),
                onTap: () => _toggle(_Open.rhythm),
              ),
            ),
            if (_open == _Open.rhythm)
              _Section(
                key: _section,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final strength in ReminderPlan.strengths)
                        ChoiceChip(
                          key: ValueKey('reminder-plan-$strength'),
                          label: Text(switch (strength) {
                            ReminderPlan.gentle => l.reminderPlanGentle,
                            ReminderPlan.intense => l.reminderPlanIntense,
                            _ => l.reminderPlanNormal,
                          }),
                          selected: _strength == strength,
                          onSelected: (_) =>
                              setState(() => _strength = strength),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PlanPreview(
                    plan: rhythm,
                    anchor: _anchor,
                    now: now,
                    minute: ReminderPlans.minute(rhythm, minute),
                    dayLead: dayLead(rhythm),
                  ),
                  const SizedBox(height: 16),
                  _Apply(plan: rhythm, onApply: _choose),
                ],
              ),
            if (!yourWay)
              ListTile(
                key: const ValueKey('reminder-plan-your-way'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.record_voice_over_outlined),
                title: Text(l.reminderPlanYourWay),
                trailing: const ProBadge(),
                // Without Pro, the Pro screen says what it gives here.
                onTap: _openPro,
              )
            else
              expandable(
                key: _yourWayRow,
                open: _open == _Open.custom,
                child: ListTile(
                  key: const ValueKey('reminder-plan-your-way'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: const Icon(Icons.record_voice_over_outlined),
                  title: Text(l.reminderPlanYourWay),
                  subtitle: dictated == null || _open == _Open.custom
                      ? null
                      : Text(
                          planRhythm(
                            l,
                            dictated,
                            anchor: _anchor,
                            now: now,
                            minute: ReminderPlans.minute(dictated, minute),
                            dayLead: dayLead(dictated),
                          ),
                        ),
                  selected: dictated != null,
                  trailing: dictated != null && _open != _Open.custom
                      ? check(true)
                      : expander(_open == _Open.custom),
                  onTap: () => _toggle(_Open.custom),
                ),
              ),
            // Without Pro, the rhythm said while dictating, kept with
            // «Listo»: no field and no «Dictarlo», which ask the assistant.
            if (!pro && dictated != null && _open == _Open.custom)
              _Section(
                key: _section,
                children: [
                  PlanPreview(
                    plan: dictated,
                    anchor: _anchor,
                    now: now,
                    minute: ReminderPlans.minute(dictated, minute),
                    dayLead: dayLead(dictated),
                  ),
                  const SizedBox(height: 16),
                  _Apply(plan: dictated, onApply: _choose),
                ],
              ),
            if (pro && _open == _Open.custom)
              _Section(
                key: _section,
                children: [
                  // Named as capture's words field is.
                  Semantics(
                    label: l.captureYourWords,
                    child: TextField(
                      key: const ValueKey('reminder-plan-words'),
                      controller: _words,
                      focusNode: _wordsFocus,
                      scrollController: _wordsScroll,
                      enabled: !_reading,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: ReminderPlan.saidLimit,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => unawaited(_read()),
                      // What to put in it stays in view while typing,
                      // until the plan read from the words says it.
                      decoration: InputDecoration(
                        helperText: _custom == null
                            ? l.reminderPlanYourWayHint
                            : null,
                        helperMaxLines: 4,
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      TextButton.icon(
                        key: const ValueKey('reminder-plan-speak'),
                        onPressed: _reading
                            ? null
                            : () => unawaited(_toggleListening()),
                        icon: Icon(
                          _listening
                              ? Icons.stop_rounded
                              : Icons.mic_none_rounded,
                        ),
                        label: Text(
                          _listening
                              ? l.reminderPlanStopListening
                              : l.reminderPlanSpeak,
                        ),
                      ),
                      if (_listening)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            l.captureListening,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_reading) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(l.reminderPlanReading),
                  ],
                  if (_problem case final problem?) ...[
                    const SizedBox(height: 8),
                    Text(
                      problem,
                      key: const ValueKey('reminder-plan-problem'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (_custom case final plan? when !_reading) ...[
                    const SizedBox(height: 16),
                    PlanPreview(
                      plan: plan,
                      anchor: _anchor,
                      now: now,
                      minute: ReminderPlans.minute(plan, minute),
                      dayLead: dayLead(plan),
                    ),
                    const SizedBox(height: 16),
                    _Apply(plan: plan, onApply: _choose),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        // On a shared task the title and the line that every choice is only
        // this person's stay above the choices as they scroll (UX-2026). A
        // thin line marks where the choices scroll under the title and the
        // note (UX-2035).
        child: widget.shared
            ? Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const _JustYou(),
                    const Divider(
                      height: 1,
                      key: ValueKey('reminder-sheet-header-edge'),
                    ),
                    Flexible(child: choices(withTitle: false)),
                  ],
                ),
              )
            : choices(withTitle: true),
      ),
    );
  }
}

/// A plan's choices, under its row.
class _Section extends StatelessWidget {
  const _Section({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// On a shared task, under the sheet's title: every choice rings only for
/// this person.
class _JustYou extends StatelessWidget {
  const _JustYou();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Text(
        context.l10n.reminderPlanJustYou,
        key: const ValueKey('reminder-plan-just-you'),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Applies the plan shown and closes: the sheet's one primary action, as
/// wide as the other sheets' are.
class _Apply extends StatelessWidget {
  const _Apply({required this.plan, required this.onApply});
  final ReminderPlan plan;
  final ValueChanged<ReminderSheetChoice> onApply;
  @override
  Widget build(BuildContext context) => FilledButton(
    key: const ValueKey('reminder-plan-apply'),
    onPressed: () => onApply(ReminderSheetChoice.plan(plan)),
    child: Text(context.l10n.done),
  );
}

/// What a plan gives: its words, a strip of dots from today to the day, and
/// how many reminders are still to come, with the next one.
class PlanPreview extends StatelessWidget {
  const PlanPreview({
    super.key,
    required this.plan,
    required this.anchor,
    required this.now,
    required this.minute,
    this.dayLead,
  });
  final ReminderPlan plan;
  final DateTime anchor;
  final DateTime now;
  final int minute;

  /// How long before the anchor's time its day's reminder rings
  /// ([ReminderPlans.dayLead]); null at [minute], as the others.
  final int? dayLead;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final locale = context.localeName;
    final days = [
      for (final alert in ReminderPlans.alerts(
        plan,
        anchor,
        minute,
        now,
        late: false,
        dayLead: dayLead,
      ))
        alert.daysBefore,
    ];
    return Column(
      key: const ValueKey('reminder-plan-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          planRhythm(
            l,
            plan,
            anchor: anchor,
            now: now,
            minute: minute,
            dayLead: dayLead,
          ),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        // The count below says it in words: the strip and its ends.
        ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PlanStrip(
                days: days,
                span: math.max(0, ReminderPlans.daysUntil(anchor, now)),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.today,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // The task's day under the strip's end, in the rest of
                  // the row: a long one stays on one line (UX-2031).
                  Expanded(
                    child: Text(
                      planDay(anchor, now, locale),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            planCount(
              l,
              plan,
              anchor: anchor,
              now: now,
              minute: minute,
              locale: locale,
              clock: context.clockTime,
              dayLead: dayLead,
            ),
            key: const ValueKey('reminder-plan-count'),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// A strip from today, on the left, to the task's day, on the right, with a
/// dot on each day a reminder is still to come: closer together as the day
/// approaches. [days] are days before the task's day; [span] is how many
/// days away it is.
class PlanStrip extends StatelessWidget {
  const PlanStrip({super.key, required this.days, required this.span});
  final List<int> days;
  final int span;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 20,
      width: double.infinity,
      child: CustomPaint(
        painter: _StripPainter(
          days: days,
          span: span,
          line: colors.outline,
          dot: colors.primary,
          today: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter({
    required this.days,
    required this.span,
    required this.line,
    required this.dot,
    required this.today,
  });
  final List<int> days;
  final int span;
  final Color line;
  final Color dot;
  final Color today;

  @override
  void paint(Canvas canvas, Size size) {
    const end = 7.0;
    final middle = size.height / 2;
    final width = size.width - 2 * end;
    double x(int daysBefore) =>
        end + (span == 0 ? width : width * (span - daysBefore) / span);
    canvas.drawLine(
      Offset(end, middle),
      Offset(size.width - end, middle),
      Paint()
        ..color = line
        ..strokeWidth = 1.5,
    );
    // Today: an open ring at the start.
    canvas.drawCircle(
      Offset(end, middle),
      5,
      Paint()
        ..color = today
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final fill = Paint()..color = dot;
    for (final day in days) {
      if (day < 0 || day > span) continue;
      canvas.drawCircle(Offset(x(day), middle), day == 0 ? 6 : 3.5, fill);
    }
    // The day itself, always marked.
    if (!days.contains(0)) {
      canvas.drawCircle(
        Offset(x(0), middle),
        6,
        Paint()
          ..color = dot
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.span != span ||
      old.line != line ||
      old.dot != dot ||
      old.today != today ||
      old.days.length != days.length ||
      !old.days.every(days.contains);
}

/// A small «Pro» beside a choice that comes with TaskFlow Pro.
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        context.l10n.proBadge,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
