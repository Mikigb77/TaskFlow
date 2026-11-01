import 'dart:async';
import 'dart:math' as math;
import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/first_task_provider.dart';
import 'package:agenda/providers/invitations_provider.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/widgets/project_scope_control.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:agenda/widgets/task_actions.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/widgets/device_calendar_events.dart';
import 'package:agenda/widgets/invitation_cards.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with WidgetsBindingObserver {
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  // The person chose the selected day, rather than a landing moving to it.
  // Only a chosen day is passed on to capture.
  bool _picked = false;
  // The day that was today when Calendar last checked the date.
  late DateTime _today;
  // When the app last went to the background, while it's away.
  DateTime? _leftAt;
  Timer? _midnight;
  CalendarFormat _format = CalendarFormat.week;
  PageController? _calendarPage;
  final _page = GlobalKey();
  final _scroll = ScrollController();
  // Tasks seen open on the selected day. Completing one keeps its place
  // until the day changes or Calendar is left (covered, or another tab).
  final _openOnDay = <String>{};
  // Today's overdue tasks seen open while today was shown. One ticked keeps
  // its place under «Atrasadas», struck through, by the same rule.
  final _overdueSeen = <String>{};
  // Just-saved tasks: waiting to appear, then shown and highlighted. Saved
  // without a date, the no-date row is highlighted instead, or as well.
  Set<int> _landingIds = {};
  Set<int> _landedIds = {};
  bool _landingInbox = false;
  bool _landedInbox = false;
  bool _highlight = false;
  // The lit rows, by task occurrence, in the order they show; the no-date
  // row is 'inbox'. Each fades 1.5 s after it is first seen whole.
  final _litRows = <String, GlobalKey>{};
  final _inboxRow = GlobalKey();
  // The day's heading, kept in view by a landing when it fits.
  final _dayHeading = GlobalKey();
  List<String> _litOrder = const [];
  final _seen = <String>{};
  final _faded = <String>{};
  final _fades = <Timer>[];
  Timer? _recheck;
  bool _revealing = false;
  bool _watchQueued = false;
  // The gap after the last row. It grows to the save message's height while
  // a landing lasts, so the last rows can scroll clear of the message.
  double _end = 20;

  DateTime _now() => ref.read(calendarClockProvider)();

  @override
  void initState() {
    super.initState();
    _selectedDay = _now();
    _focusedDay = _selectedDay;
    _today = Task.day(_selectedDay);
    _scheduleMidnight();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_scrolled);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    _stopFading();
    _scroll.dispose();
    super.dispose();
  }

  void _select(DateTime day, [DateTime? focused]) {
    if (!isSameDay(day, _selectedDay)) {
      _openOnDay.clear();
      _overdueSeen.clear();
      _landingIds = {};
      _landedIds = {};
      _landingInbox = false;
      _landedInbox = false;
      _end = 20;
      _stopFading();
    }
    _selectedDay = day;
    _focusedDay = focused ?? day;
  }

  /// A calendar left on today moves to the new today after midnight.
  void _followToday() {
    final today = Task.day(_now());
    if (today == _today) return;
    if (isSameDay(_selectedDay, _today)) _select(today);
    _today = today;
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = _now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now) + const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(_followToday);
      _scheduleMidnight();
    });
  }

  /// Shows [focus]'s just-saved tasks on their day, lit.
  void _land(CalendarFocus focus) {
    // A filter that hides a saved task, as `Para mí` does a task for
    // someone else, widens to show it.
    final scope = ref.read(projectScopeProvider);
    final wider = scopeShowing(
      (ref.read(taskProvider).valueOrNull ?? const <Task>[]).where(
        (task) => focus.taskIds.contains(task.id),
      ),
      scope,
      ref.read(authProvider).account?.id,
      ref.read(taskListsProvider).valueOrNull ?? const [],
    );
    if (!identical(wider, scope)) {
      ref.read(projectScopeProvider.notifier).state = wider;
      ref.read(scopeWideningProvider.notifier).state = ScopeWidening(
        focus,
        scope,
        wider,
      );
    }
    setState(() {
      final day = focus.day;
      if (day != null) {
        // A landing on another day shows the tasks; it doesn't choose that
        // day for the next capture.
        if (!isSameDay(day, _selectedDay)) _picked = false;
        _select(day);
      }
      _landingIds = day == null ? {} : focus.taskIds;
      _landingInbox = day == null || focus.undated;
      _landedIds = {};
      _landedInbox = false;
      _end = 20;
      _highlight = false;
      _stopFading();
      _litRows.clear();
    });
  }

  /// Brings the new tasks' rows into view, clear of the save message: all
  /// of them when they fit, or else the first, under the day's heading when
  /// that fits too. Then each fades once seen.
  Future<void> _reveal() async {
    _revealing = true;
    try {
      await _scrollToLit();
    } finally {
      _revealing = false;
    }
    _watchLit();
  }

  Future<void> _scrollToLit() async {
    // The save message shows a moment after the landing: wait for it, and
    // make room under the last row for it, as a new row may be that one.
    double? clearance;
    for (var i = 0; i < 60 && mounted; i++) {
      clearance = _messageClearance();
      if (clearance != null) break;
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    final room = clearance ?? 88;
    if (room > _end) setState(() => _end = room);
    await WidgetsBinding.instance.endOfFrame;
    var looked = false;
    for (var i = 0; i < 20 && mounted && _scroll.hasClients; i++) {
      GlobalKey? find(String? row) => _inboxOnly
          ? _inboxRow
          : row == null
          ? null
          : _litRows[row];
      final first = find(
        _litOrder.firstOrNull,
      )?.currentContext?.findRenderObject();
      final last = find(
        _litOrder.lastOrNull,
      )?.currentContext?.findRenderObject();
      final position = _scroll.position;
      if (first == null) {
        // Rows out of view are only built once scrolled near: start from the
        // top, then move down a screen at a time.
        if (i > 0 && position.pixels >= position.maxScrollExtent) break;
        _scroll.jumpTo(
          i == 0
              ? position.minScrollExtent
              : math.min(
                  position.pixels + position.viewportDimension,
                  position.maxScrollExtent,
                ),
        );
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }
      final viewport = RenderAbstractViewport.of(first);
      final top = viewport.getOffsetToReveal(first, 0).offset;
      final firstEnd = viewport.getOffsetToReveal(first, 1).offset + room;
      final lastEnd = last == null
          ? null
          : viewport.getOffsetToReveal(last, 1).offset + room;
      final end = lastEnd != null && lastEnd <= top ? lastEnd : firstEnd;
      // The day's heading stays in view when it fits with those rows above
      // the message, so a line on screen names their day.
      final heading = _dayHeading.currentContext?.findRenderObject();
      final headingTop = heading == null
          ? null
          : viewport.getOffsetToReveal(heading, 0).offset;
      final upTo = headingTop != null && end <= headingTop ? headingTop : top;
      final target = position.pixels > upTo
          ? upTo
          : position.pixels < end
          ? math.min(end, upTo)
          : position.pixels;
      final offset = target.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (offset != position.pixels) {
        if (MediaQuery.disableAnimationsOf(context)) {
          _scroll.jumpTo(offset);
        } else {
          await _scroll.animateTo(
            offset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
      // The last new row wasn't built yet: look again from here, once.
      if (last == null && !_inboxOnly && _litOrder.length > 1 && !looked) {
        looked = true;
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }
      break;
    }
  }

  bool _lit(String row) => _highlight && !_faded.contains(row);

  void _stopFading() {
    for (final fade in _fades) {
      fade.cancel();
    }
    _fades.clear();
    _recheck?.cancel();
    _seen.clear();
    _faded.clear();
  }

  /// A scroll can bring a lit row into view: look once it's laid out.
  void _scrolled() {
    if (!_highlight || _revealing || _watchQueued) return;
    _watchQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _watchQueued = false;
      _watchLit();
    });
  }

  /// Starts the 1.5 s fade of each lit row now seen whole: on screen and
  /// above the save message. A row out of view stays lit until it shows.
  void _watchLit() {
    if (!mounted || !_highlight || _revealing) return;
    _recheck?.cancel();
    final rows = [
      for (final row in _litOrder) (row, _litRows[row]),
      if (_landedInbox) ('inbox', _inboxRow),
    ];
    final message = _messageClearance() ?? 0;
    final seen = <String>[];
    var covered = false;
    for (final (row, key) in rows) {
      if (_seen.contains(row)) continue;
      final box = key?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final RenderObject? viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport is! RenderBox || !viewport.hasSize) continue;
      final area = viewport.localToGlobal(Offset.zero) & viewport.size;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.top < area.top - 0.5 || rect.top >= area.bottom) continue;
      if (rect.bottom <= area.bottom - message + 0.5) {
        seen.add(row);
      } else if (rect.bottom <= area.bottom + 0.5) {
        // On screen, under the message: seen once the message goes.
        covered = true;
      }
    }
    if (seen.isNotEmpty) {
      _seen.addAll(seen);
      _fades.add(
        Timer(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _faded.addAll(seen));
        }),
      );
    }
    if (covered && message > 0) {
      _recheck = Timer(const Duration(milliseconds: 500), _watchLit);
    }
  }

  /// The week or month arrows; with animations off the page just changes.
  void _turnPage(int by, {required bool instant}) {
    final pages = _calendarPage;
    if (pages == null || !pages.hasClients) return;
    if (instant) {
      pages.jumpToPage((pages.page ?? pages.initialPage).round() + by);
    } else if (by < 0) {
      pages.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      pages.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  /// Only the no-date row landed: no saved task has a date.
  bool get _inboxOnly => _landedInbox && _landedIds.isEmpty;

  /// How much of the page's foot the save message shown over it takes, with
  /// a gap. Read inside its entrance, where its height is already final.
  double? _messageClearance() {
    RenderBox? message;
    var inMessage = false;
    void visit(Element element) {
      // The list can't hold the message, so skip its rows.
      if (message != null || element.widget is CustomScrollView) return;
      if (element.widget is SnackBar) inMessage = true;
      if (inMessage && element.widget is Dismissible) {
        final box = element.findRenderObject();
        if (box is RenderBox && box.hasSize) message = box;
        return;
      }
      element.visitChildren(visit);
    }

    _page.currentContext?.visitChildElements(visit);
    final box = message;
    if (box == null || box.size.height == 0) return null;
    return box.size.height + 8;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      setState(() {
        if (left != null) _comeBack(left);
        _followToday();
      });
      _scheduleMidnight();
      ref.read(taskProvider.notifier).loadTasks();
      ref.read(deviceCalendarProvider.notifier).refresh();
    } else {
      _leftAt ??= _now();
      ref.read(deviceCalendarProvider.notifier).suspend();
    }
  }

  /// Back after a while away, or on another day, Calendar opens on today,
  /// whichever day a landing or the person had chosen. A short return keeps
  /// the day, and a chosen day still goes to the next capture. Today opens
  /// at the top, with the week strip and its header in view.
  void _comeBack(DateTime left) {
    final now = _now();
    if (now.difference(left) < const Duration(minutes: 30) &&
        Task.day(now) == Task.day(left)) {
      return;
    }
    _picked = false;
    _select(Task.day(now));
    // Jump, never animate: the person wasn't looking.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.minScrollExtent);
      }
    });
  }

  Future<void> _refresh() => Future.wait([
    ref.read(taskProvider.notifier).loadTasks(),
    ref.read(deviceCalendarProvider.notifier).refresh(),
    // Offline, the invitation card just stays as it was.
    ref
        .refresh(pendingInvitationsProvider.future)
        .then<void>((_) {}, onError: (Object _) {}),
  ]);

  void _showView(String view) {
    if (view == 'day') {
      Navigator.pushNamed(context, '/timeline', arguments: _selectedDay);
      return;
    }
    setState(
      () => _format = view == 'month'
          ? CalendarFormat.month
          : CalendarFormat.week,
    );
  }

  /// A day tapped or long-pressed. From Mes, the strip goes back to Semana on
  /// that day, so its first tasks show under the week.
  void _pickDay(DateTime day) => setState(() {
    _picked = true;
    _select(day);
    _format = CalendarFormat.week;
  });

  /// The open tasks overdue on [now]'s day that aren't among its own
  /// occurrences, oldest first: what today's agenda lists under its tasks.
  List<Task> _overdueOn(List<Task> tasks, DateTime now) {
    String key(Task task) => '${task.id}:${task.occurrenceId}';
    final listed = {
      for (final task in tasks.expand(
        (task) => task.calendarOccurrencesOn(now),
      ))
        key(task),
    };
    return tasks
        .map((task) => task.overdueOn(now))
        .whereType<Task>()
        .where((task) => !listed.contains(key(task)))
        .toList()
      ..sort(
        (a, b) => (a.displayDate ?? a.displayDeadline!).compareTo(
          b.displayDate ?? b.displayDeadline!,
        ),
      );
  }

  /// Today's [open] overdue tasks, with those ticked since they were seen
  /// open, struck through where they were. [listed] are today's own rows.
  List<Task> _withTicked(
    List<Task> tasks,
    List<Task> open,
    Set<String> listed,
    DateTime now,
  ) {
    String key(Task task) => '${task.id}:${task.occurrenceId}';
    DateTime when(Task task) => task.displayDate ?? task.displayDeadline!;
    final first = Task.day(now);
    final ticked = [
      for (final task in tasks)
        ...(task.isRecurring
                ? task.completedDates
                      .map(task.completedOccurrence)
                      .whereType<Task>()
                : [if (task.isCompleted) task])
            .where(
              (done) =>
                  _overdueSeen.contains(key(done)) &&
                  !listed.contains(key(done)) &&
                  (done.displayDate ?? done.displayDeadline) != null &&
                  Task.day(when(done)).isBefore(first),
            ),
    ];
    // Oldest first; rows of the same day keep the tasks' order, so a ticked
    // row stays where it was.
    final at = {for (final (i, task) in tasks.indexed) task.id: i};
    final rows = [...open, ...ticked].indexed.toList()
      ..sort((a, b) {
        final date = when(a.$2).compareTo(when(b.$2));
        if (date != 0) return date;
        final order = at[a.$2.id]!.compareTo(at[b.$2.id]!);
        return order != 0 ? order : a.$1.compareTo(b.$1);
      });
    return [for (final (_, task) in rows) task];
  }

  /// The week or the month. At any text size each day is at least 48 dp
  /// tall, its number whole inside its pill and the weekday names whole; a
  /// screen reader hears which day is chosen, today, and how many tasks.
  Widget _weekStrip(
    BuildContext context, {
    required List<Task> tasks,
    required DateTime now,
    required int overdueToday,
    required bool instant,
    required double cellWidth,
  }) {
    final colors = Theme.of(context).colorScheme;
    final locale = context.localeName;
    final scaler = MediaQuery.textScalerOf(context);
    final base = Theme.of(context).textTheme.bodyMedium!.copyWith(height: 1.2);
    final plainStyle = base.copyWith(
      color: colors.onSurface,
      fontWeight: FontWeight.w600,
    );
    final weekendStyle = base.copyWith(color: colors.onSurfaceVariant);
    final selectedStyle = base.copyWith(
      color: colors.onPrimary,
      fontWeight: FontWeight.w800,
    );
    final todayStyle = base.copyWith(
      color: colors.primary,
      fontWeight: FontWeight.w800,
    );
    final weekdayStyle = base.copyWith(
      color: colors.onSurfaceVariant,
      fontSize: 11,
    );
    Size measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      final size = painter.size;
      painter.dispose();
      return size;
    }

    const margin = 4.0;
    // The short weekday names, or the narrow ones when a short one doesn't
    // fit its day.
    final week = [for (var i = 0; i < 7; i++) DateTime(2024, 1, 1 + i)];
    final weekday =
        week.any(
          (day) =>
              measure(DateFormat.E(locale).format(day), weekdayStyle).width >
              cellWidth - margin,
        )
        ? DateFormat.EEEEE(locale)
        : DateFormat.E(locale);
    final rowHeight = math.max(
      48.0,
      measure('30', selectedStyle).height + 4 * margin,
    );
    final weekdayHeight = math.max(
      30.0,
      measure('Mg', weekdayStyle).height + 2 * margin,
    );
    Widget cell(DateTime day, TextStyle style, [Color? fill]) =>
        AnimatedContainer(
          duration: instant ? Duration.zero : const Duration(milliseconds: 250),
          margin: const EdgeInsets.all(margin),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(12),
          ),
          // Shrunk only as far as the pill needs, never cut.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${day.day}', style: style),
          ),
        );
    // Another month's days look like any other: they can be chosen too.
    Widget plain(DateTime day) =>
        cell(day, day.weekday >= DateTime.saturday ? weekendStyle : plainStyle);
    return TableCalendar<Task>(
      firstDay: DateTime(2010),
      lastDay: DateTime(2100, 12, 31),
      focusedDay: _focusedDay,
      currentDay: now,
      calendarFormat: _format,
      headerVisible: false,
      locale: locale,
      startingDayOfWeek:
          StartingDayOfWeek.values[(MaterialLocalizations.of(
                    context,
                  ).firstDayOfWeekIndex +
                  6) %
              7],
      rowHeight: rowHeight,
      daysOfWeekHeight: weekdayHeight,
      pageAnimationEnabled: !instant,
      onCalendarCreated: (controller) => _calendarPage = controller,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selected, _) => _pickDay(selected),
      onDayLongPressed: (selected, _) => _pickDay(selected),
      onPageChanged: (focused) => setState(() => _focusedDay = focused),
      eventLoader: (day) => tasks
          .expand((task) => task.calendarOccurrencesOn(day))
          .where((task) => !task.isCompleted)
          .toList(),
      daysOfWeekStyle: DaysOfWeekStyle(
        dowTextFormatter: (day, _) => weekday.format(day),
        weekdayStyle: weekdayStyle,
        weekendStyle: weekdayStyle,
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, _) => plain(day),
        outsideBuilder: (context, day, _) => plain(day),
        selectedBuilder: (context, day, _) =>
            cell(day, selectedStyle, colors.primary),
        todayBuilder: (context, day, _) =>
            cell(day, todayStyle, colors.primaryContainer),
        // The cell names only its date. Beside it, every day says whether
        // it's the chosen one, and whether it's today and has open tasks.
        // Today counts its overdue tasks too, as its agenda does.
        markerBuilder: (context, day, dayTasks) {
          final isToday = isSameDay(day, now);
          final count = dayTasks.length + (isToday ? overdueToday : 0);
          final value = [
            if (isToday) context.l10n.today.toLowerCase(),
            if (count > 0) context.l10n.dayTaskCount(count),
          ].join(' · ');
          return Positioned(
            bottom: 1,
            child: Semantics(
              selected: isSameDay(_selectedDay, day),
              value: value.isEmpty ? null : value,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: dayTasks
                    .take(3)
                    .map(
                      (task) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.priorityColor(context, task.priority),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CalendarFocus?>(calendarFocusProvider, (_, focus) {
      // A task page that opened capture shows the tasks itself.
      if (focus != null && focus.page == null) _land(focus);
    });
    _followToday();
    // Calendar is covered by another screen: the user has left it.
    final shown = TickerMode.valuesOf(context).enabled;
    // Another tab is shown: the shell keeps Calendar's tickers running, so
    // only its visibility says the user has left it too.
    if (!shown || !Visibility.of(context)) {
      _openOnDay.clear();
      _overdueSeen.clear();
    }
    // Leaving Calendar ends a landing's room for the save message.
    if (!shown) _end = 20;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tasksState = ref.watch(taskProvider);
    final hadTask = ref.watch(hadTaskProvider);
    final scope = ref.watch(projectScopeProvider);
    final projects = ref.watch(taskListsProvider).valueOrNull ?? [];
    final accountId = ref.watch(authProvider).account?.id;
    final tasks = (tasksState.valueOrNull ?? <Task>[])
        .where((task) => taskInProjectScope(task, scope, accountId, projects))
        .toList();
    String key(Task task) => '${task.id}:${task.occurrenceId}';
    final events = tasks
        .expand((task) => task.calendarOccurrencesOn(_selectedDay))
        .toList();
    _openOnDay.addAll(events.where((task) => !task.isCompleted).map(key));
    // Done tasks go last, except those completed while the day was shown.
    bool settled(Task task) =>
        task.isCompleted && !_openOnDay.contains(key(task));
    events.sort((a, b) {
      if (settled(a) != settled(b)) return settled(a) ? 1 : -1;
      return Task.compareBySchedule(a, b);
    });
    final inbox = tasks
        .where((task) => !task.isNote && task.undated && !task.isCompleted)
        .length;
    if (_landingIds.isNotEmpty &&
        shown &&
        events.any((task) => _landingIds.contains(task.id))) {
      _landedIds = _landingIds;
      _landingIds = {};
      // Saved with a task without a date: the no-date row lights up with
      // these rows, and the reveal goes to these.
      _landedInbox = _landingInbox && inbox > 0;
      _landingInbox = false;
      _highlight = true;
      _stopFading();
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
    _litOrder = [
      for (final task in events)
        if (_landedIds.contains(task.id)) key(task),
    ];
    final instant = MediaQuery.disableAnimationsOf(context);
    final now = _now();
    final today = isSameDay(_selectedDay, now);
    final overdueToday = _overdueOn(tasks, now);
    if (today) _overdueSeen.addAll(overdueToday.map(key));
    final overdue = today
        ? _withTicked(tasks, overdueToday, events.map(key).toSet(), now)
        : <Task>[];
    final completed = [
      ...events,
      ...overdue,
    ].where((task) => task.isCompleted).length;
    final total = events.length + overdue.length;
    // The day's last open row says so when it's ticked (WD34).
    final lastOpen = total - completed == 1;
    final hasAny = (tasksState.valueOrNull ?? const []).isNotEmpty;
    // The state in which the empty state shows the instruction, or is still
    // deciding whether to. Its header and empty state drop their decorations
    // so the instruction sits above Añadir tarea at the largest text.
    final firstRun = total == 0 && !hasAny && hadTask.valueOrNull != true;
    const loading = SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    final syncError = ref.read(taskRepositoryProvider).syncError;
    if (_landingInbox && _landingIds.isEmpty && shown && inbox > 0) {
      _landingInbox = false;
      _landedInbox = true;
      _highlight = true;
      _stopFading();
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
    final phoneCalendars = ref
        .watch(deviceCalendarProvider)
        .preferences
        .enabled;
    final invitations =
        ref.watch(pendingInvitationsProvider).valueOrNull ?? const [];
    return Scaffold(
      key: _page,
      appBar: CustomAppBar(title: context.l10n.calendar, isRoot: true),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          key: const PageStorageKey('calendar-scroll'),
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: ProjectScopeControl(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              ),
            ),
            if (syncError != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                sliver: SliverToBoxAdapter(
                  // Offline is a normal state: say the tasks are safe, calmly.
                  child: requestProblem(syncError) == 'network'
                      ? Row(
                          key: const ValueKey('calendar-offline'),
                          children: [
                            Icon(
                              Icons.cloud_off_outlined,
                              size: 20,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.l10n.calendarOffline,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        )
                      : MessageBanner(
                          requestProblemText(context.l10n, syncError),
                          isError: true,
                        ),
                ),
              ),
            // 12 dp a side in all, so each day is 48 dp wide at 360 dp.
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverToBoxAdapter(
                child: AppSurface(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 14),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    // The current year goes without saying.
                                    (_focusedDay.year == _now().year
                                            ? DateFormat.LLLL(
                                                context.localeName,
                                              )
                                            : DateFormat.yMMMM(
                                                context.localeName,
                                              ))
                                        .format(_focusedDay),
                                    style: text.titleMedium,
                                  ),
                                  PopupMenuButton<String>(
                                    key: const ValueKey('calendar-format'),
                                    tooltip: context.l10n.changeView,
                                    initialValue:
                                        _format == CalendarFormat.month
                                        ? 'month'
                                        : 'week',
                                    onSelected: _showView,
                                    itemBuilder: (context) => [
                                      for (final (view, label) in [
                                        ('week', context.l10n.week),
                                        ('month', context.l10n.month),
                                        ('day', context.l10n.day),
                                      ])
                                        PopupMenuItem(
                                          value: view,
                                          child: Text(label),
                                        ),
                                    ],
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 48,
                                      ),
                                      child: Padding(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                              start: 8,
                                            ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                _format == CalendarFormat.month
                                                    ? context.l10n.month
                                                    : context.l10n.week,
                                                style: text.labelLarge
                                                    ?.copyWith(
                                                      color: colors.primary,
                                                    ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_drop_down_rounded,
                                              color: colors.primary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!today)
                                    TextButton(
                                      onPressed: () => setState(() {
                                        _picked = true;
                                        _select(Task.day(_now()));
                                      }),
                                      child: Text(context.l10n.today),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: _format == CalendarFormat.month
                                  ? context.l10n.previousMonth
                                  : context.l10n.previousWeek,
                              onPressed: () => _turnPage(-1, instant: instant),
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            IconButton(
                              tooltip: _format == CalendarFormat.month
                                  ? context.l10n.nextMonth
                                  : context.l10n.nextWeek,
                              onPressed: () => _turnPage(1, instant: instant),
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) => _weekStrip(
                          context,
                          tasks: tasks,
                          now: now,
                          overdueToday: overdueToday.length,
                          instant: instant,
                          cellWidth: constraints.maxWidth / 7,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Someone shared a project or a group: the first invitation,
            // with how many more wait.
            if (invitations.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: InvitationCard(
                    invitation: invitations.first,
                    more: invitations.length - 1,
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  key: _dayHeading,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      today
                          ? context.l10n.todayAgenda
                          : DateFormat.MMMMEEEEd(
                              context.localeName,
                            ).format(_selectedDay),
                      style: text.titleLarge,
                    ),
                    // An empty day says so once, in the agenda below.
                    if (total > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.agendaCounts(total - completed, completed),
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (tasksState.isLoading)
              loading
            else if (tasksState.hasError)
              SliverToBoxAdapter(
                child: EmptyState(
                  title: context.l10n.loadTasksError,
                  message: context.l10n.refreshCalendar,
                  action: TextButton(
                    onPressed: _refresh,
                    child: Text(context.l10n.tryAgain),
                  ),
                ),
              )
            else if (total == 0 && !hasAny && hadTask.isLoading)
              loading
            else if (total == 0)
              SliverToBoxAdapter(
                child: EmptyState(
                  // An account that has never had a task or note is told what
                  // to try, as Añadir tarea will open it. Once it has had one,
                  // the instruction never comes back, and an empty day is one
                  // line: about tasks only when the phone's events follow.
                  title: firstRun ? context.l10n.rememberPrompt : null,
                  icon: null,
                  message: !firstRun
                      ? phoneCalendars
                            ? context.l10n.noScheduledTasks
                            : context.l10n.calendarEmpty
                      : ref.watch(voiceAvailableProvider)
                      ? context.l10n.calendarTrySaying
                      // Nueva tarea opens the form, which reads no dates
                      // from words.
                      : ref.watch(opensFormProvider)
                      ? context.l10n.calendarTryForm
                      : context.l10n.calendarTryTyping,
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final task = events[index];
                    final showDate =
                        task.displayDate != null &&
                        Task.dateKey(task.displayDate!) !=
                            Task.dateKey(_selectedDay);
                    final landed = _landedIds.contains(task.id);
                    return Padding(
                      key: landed
                          ? _litRows.putIfAbsent(key(task), GlobalKey.new)
                          : null,
                      padding: const EdgeInsets.only(bottom: 10),
                      child: landed
                          ? LandedTaskTile(
                              task: task,
                              showDate: showDate,
                              lit: _lit(key(task)),
                              lastOpen: lastOpen && !task.isCompleted,
                            )
                          : TaskTile(
                              task: task,
                              showDate: showDate,
                              lastOpen: lastOpen && !task.isCompleted,
                            ),
                    );
                  },
                ),
              ),
              if (overdue.isNotEmpty && events.isNotEmpty)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 10),
                  sliver: SliverToBoxAdapter(child: Divider()),
                ),
              if (overdue.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: overdue.length + 1,
                    itemBuilder: (context, index) => index == 0
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                            child: Semantics(
                              header: true,
                              child: Text(
                                context.l10n.overdueCount(overdue.length),
                                style: text.titleSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TaskTile(
                              task: overdue[index - 1],
                              showDate: true,
                              lastOpen:
                                  lastOpen && !overdue[index - 1].isCompleted,
                            ),
                          ),
                  ),
                ),
            ],
            SliverToBoxAdapter(child: DeviceCalendarEvents(day: _selectedDay)),
            if (inbox > 0)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    key: _inboxRow,
                    alignment: AlignmentDirectional.centerStart,
                    // A task saved without a date lights this row up.
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        end: _landedInbox && _lit('inbox')
                            ? colors.primaryContainer
                            : colors.primaryContainer.withValues(alpha: 0),
                      ),
                      duration: instant
                          ? Duration.zero
                          : const Duration(milliseconds: 600),
                      builder: (context, color, child) => DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: child,
                      ),
                      child: TextButton.icon(
                        key: const ValueKey('calendar-inbox'),
                        onPressed: () => Navigator.pushNamed(context, '/inbox'),
                        icon: const Icon(Icons.inbox_outlined, size: 18),
                        label: Text(context.l10n.inboxCount(inbox)),
                      ),
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: _end)),
          ],
        ),
      ),
      // A task added without a date goes to a later day the person chose,
      // not to one a landing moved to.
      bottomNavigationBar: TaskActions(day: _picked ? _selectedDay : null),
    );
  }
}
