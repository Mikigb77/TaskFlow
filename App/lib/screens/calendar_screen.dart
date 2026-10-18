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
  Timer? _midnight;
  CalendarFormat _format = CalendarFormat.week;
  PageController? _calendarPage;
  final _page = GlobalKey();
  final _scroll = ScrollController();
  // Tasks seen open on the selected day. Completing one keeps its place
  // until the day changes or Calendar is covered.
  final _openOnDay = <String>{};
  // Just-saved tasks: waiting to appear, then shown and highlighted. Saved
  // without a date, the no-date row is highlighted instead, or as well.
  Set<int> _landingIds = {};
  Set<int> _landedIds = {};
  bool _landingInbox = false;
  bool _landedInbox = false;
  bool _highlight = false;
  Timer? _highlightTimer;
  final _landedRow = GlobalKey();
  // The gap after the last row. A task saved without a date lands on the
  // last row, so it grows to the save message's height while that landing
  // lasts, letting the row scroll clear of the message.
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    _highlightTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _select(DateTime day, [DateTime? focused]) {
    if (!isSameDay(day, _selectedDay)) {
      _openOnDay.clear();
      _landingIds = {};
      _landedIds = {};
      _landingInbox = false;
      _landedInbox = false;
      _end = 20;
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

  void _land(CalendarFocus focus) => setState(() {
    final day = focus.day;
    if (day != null) {
      // A landing on another day shows the tasks; it doesn't choose that day
      // for the next capture.
      if (!isSameDay(day, _selectedDay)) _picked = false;
      _select(day);
    }
    _landingIds = day == null ? {} : focus.taskIds;
    _landingInbox = day == null || focus.undated;
    _landedIds = {};
    _landedInbox = false;
    _end = 20;
    _highlight = false;
    _highlightTimer?.cancel();
  });

  /// Brings the new task's row (the first, for several) into view, clear of the save message, then
  /// lets its highlight fade.
  Future<void> _reveal() async {
    // The no-date row is the last one: make room under it for the save
    // message, which shows a moment after the landing.
    if (_inboxOnly) {
      for (var i = 0; i < 60 && mounted; i++) {
        final clearance = _messageClearance();
        if (clearance != null) {
          if (clearance > _end) setState(() => _end = clearance);
          break;
        }
        await WidgetsBinding.instance.endOfFrame;
      }
      await WidgetsBinding.instance.endOfFrame;
    }
    for (var i = 0; i < 20 && mounted && _scroll.hasClients; i++) {
      final row = _landedRow.currentContext?.findRenderObject();
      final position = _scroll.position;
      if (row == null) {
        // Rows far below are only built once scrolled near.
        if (position.pixels >= position.maxScrollExtent) break;
        _scroll.jumpTo(
          math.min(
            position.pixels + position.viewportDimension,
            position.maxScrollExtent,
          ),
        );
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }
      final viewport = RenderAbstractViewport.of(row);
      final top = viewport.getOffsetToReveal(row, 0).offset;
      final bottom =
          viewport.getOffsetToReveal(row, 1).offset + math.max(88, _end);
      final target = position.pixels > top
          ? top
          : position.pixels < bottom
          ? math.min(bottom, top)
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
      break;
    }
    if (!mounted) return;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _highlight = false);
    });
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
      setState(_followToday);
      _scheduleMidnight();
      ref.read(taskProvider.notifier).loadTasks();
      ref.read(deviceCalendarProvider.notifier).refresh();
    } else {
      ref.read(deviceCalendarProvider.notifier).suspend();
    }
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

  @override
  Widget build(BuildContext context) {
    ref.listen<CalendarFocus?>(calendarFocusProvider, (_, focus) {
      // A task page that opened capture shows the tasks itself.
      if (focus != null && focus.page == null) _land(focus);
    });
    _followToday();
    // Calendar is covered by another screen: the user has left it.
    final shown = TickerMode.valuesOf(context).enabled;
    if (!shown) {
      _openOnDay.clear();
      // Leaving Calendar ends a landing's room for the save message.
      _end = 20;
    }
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
        .where(
          (task) => !task.isNote && task.dueDate == null && !task.isCompleted,
        )
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
    final landedIndex = events.indexWhere(
      (task) => _landedIds.contains(task.id),
    );
    final instant = MediaQuery.disableAnimationsOf(context);
    final now = _now();
    final today = isSameDay(_selectedDay, now);
    final listed = {for (final task in events) key(task)};
    final overdue = today
        ? (tasks
              .map((task) => task.overdueOn(now))
              .whereType<Task>()
              .where((task) => !listed.contains(key(task)))
              .toList()
            ..sort(
              (a, b) => (a.displayDate ?? a.displayDeadline!).compareTo(
                b.displayDate ?? b.displayDeadline!,
              ),
            ))
        : <Task>[];
    final completed = events.where((task) => task.isCompleted).length;
    final total = events.length + overdue.length;
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
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: AppSurface(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
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
                              tooltip: context.l10n.previousPeriod,
                              onPressed: () => _turnPage(-1, instant: instant),
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            IconButton(
                              tooltip: context.l10n.nextPeriod,
                              onPressed: () => _turnPage(1, instant: instant),
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                      ),
                      TableCalendar<Task>(
                        firstDay: DateTime(2010),
                        lastDay: DateTime(2100, 12, 31),
                        focusedDay: _focusedDay,
                        currentDay: now,
                        calendarFormat: _format,
                        headerVisible: false,
                        locale: context.localeName,
                        startingDayOfWeek:
                            StartingDayOfWeek.values[(MaterialLocalizations.of(
                                      context,
                                    ).firstDayOfWeekIndex +
                                    6) %
                                7],
                        rowHeight: 48,
                        daysOfWeekHeight: 30,
                        pageAnimationEnabled: !instant,
                        onCalendarCreated: (controller) =>
                            _calendarPage = controller,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        onDaySelected: (selected, focused) => setState(() {
                          _picked = true;
                          _select(selected, focused);
                        }),
                        onPageChanged: (focused) =>
                            setState(() => _focusedDay = focused),
                        eventLoader: (day) => tasks
                            .expand((task) => task.calendarOccurrencesOn(day))
                            .where((task) => !task.isCompleted)
                            .toList(),
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: false,
                          cellMargin: const EdgeInsets.all(4),
                          defaultTextStyle: TextStyle(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          weekendTextStyle: TextStyle(
                            color: colors.onSurfaceVariant,
                          ),
                          selectedTextStyle: TextStyle(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                          todayTextStyle: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          todayDecoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          defaultDecoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          weekendDecoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          weekendStyle: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, day, dayTasks) {
                            if (dayTasks.isEmpty) return null;
                            return Positioned(
                              bottom: 1,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: dayTasks
                                    .take(3)
                                    .map(
                                      (task) => Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 1.5,
                                        ),
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppTheme.priorityColor(
                                            context,
                                            task.priority,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            );
                          },
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
                    if (!firstRun) ...[
                      const SizedBox(height: 4),
                      Text(
                        total == 0
                            ? phoneCalendars
                                  ? context.l10n.noScheduledTasks
                                  : context.l10n.breathingRoom
                            : context.l10n.agendaCounts(
                                total - completed,
                                completed,
                              ),
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
                  title: context.l10n.rememberPrompt,
                  icon: firstRun ? null : Icons.event_available_outlined,
                  // An account that has never had a task or note is told what
                  // to try, as Añadir tarea will open it. Once it has had one,
                  // the instruction never comes back.
                  message: hasAny || hadTask.valueOrNull == true
                      ? context.l10n.calendarEmpty
                      : ref.watch(voiceAvailableProvider)
                      ? context.l10n.calendarTrySaying
                      : ref.watch(freeVoiceUsedUpProvider)
                      ? context.l10n.calendarTryTypingWrite
                      : context.l10n.calendarTryTyping,
                ),
              )
            else ...[
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
                            ),
                          ),
                  ),
                ),
              if (overdue.isNotEmpty && events.isNotEmpty)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 10),
                  sliver: SliverToBoxAdapter(child: Divider()),
                ),
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
                    return Padding(
                      key: index == landedIndex ? _landedRow : null,
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _landedIds.contains(task.id)
                          ? LandedTaskTile(
                              task: task,
                              showDate: showDate,
                              lit: _highlight,
                            )
                          : TaskTile(task: task, showDate: showDate),
                    );
                  },
                ),
              ),
            ],
            SliverToBoxAdapter(child: DeviceCalendarEvents(day: _selectedDay)),
            if (inbox > 0)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    key: _inboxOnly ? _landedRow : null,
                    alignment: AlignmentDirectional.centerStart,
                    // A task saved without a date lights this row up.
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        end: _landedInbox && _highlight
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
