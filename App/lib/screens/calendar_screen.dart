import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/widgets/project_scope_control.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:flutter/material.dart';
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

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with WidgetsBindingObserver {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _format = CalendarFormat.week;
  PageController? _calendarPage;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(taskProvider.notifier).loadTasks();
      ref.read(deviceCalendarProvider.notifier).refresh();
    } else {
      ref.read(deviceCalendarProvider.notifier).suspend();
    }
  }

  Future<void> _refresh() async {
    setState(() => _syncing = true);
    try {
      await Future.wait([
        ref.read(taskProvider.notifier).loadTasks(),
        ref.read(deviceCalendarProvider.notifier).refresh(),
      ]);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _create() =>
      Navigator.pushNamed(context, '/createTask', arguments: _selectedDay);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tasksState = ref.watch(taskProvider);
    final scope = ref.watch(projectScopeProvider);
    final projects = ref.watch(taskListsProvider).valueOrNull ?? [];
    final accountId = ref.watch(authProvider).account?.id;
    final tasks = (tasksState.valueOrNull ?? <Task>[])
        .where((task) => taskInProjectScope(task, scope, accountId, projects))
        .toList();
    final events =
        tasks
            .expand((task) => task.calendarOccurrencesOn(_selectedDay))
            .toList()
          ..sort((a, b) {
            if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
            return Task.compareBySchedule(a, b);
          });
    final completed = events.where((task) => task.isCompleted).length;
    final signedIn = ref.watch(authProvider).account != null;
    final syncError = ref.read(taskRepositoryProvider).syncError;
    final today = isSameDay(_selectedDay, DateTime.now());
    final phoneCalendars = ref
        .watch(deviceCalendarProvider)
        .preferences
        .enabled;
    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.calendar, isRoot: true),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          key: const PageStorageKey('calendar-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: ProjectScopeControl(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.yourCalendar,
                            style: text.titleLarge,
                          ),
                        ),
                        if (signedIn)
                          IconButton(
                            tooltip: context.l10n.syncTasks,
                            onPressed: _syncing ? null : _refresh,
                            icon: _syncing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    syncError == null
                                        ? Icons.cloud_done_outlined
                                        : Icons.cloud_off_outlined,
                                    size: 21,
                                    color: colors.onSurfaceVariant,
                                  ),
                          ),
                      ],
                    ),
                    if (syncError != null) ...[
                      const SizedBox(height: 12),
                      MessageBanner(
                        requestProblemText(context.l10n, syncError),
                        isError: true,
                      ),
                    ],
                    TextButton.icon(
                      key: const ValueKey('calendar-inbox'),
                      onPressed: () => Navigator.pushNamed(context, '/inbox'),
                      icon: const Icon(Icons.inbox_outlined, size: 18),
                      label: Text(
                        context.l10n.inboxCount(
                          tasks
                              .where(
                                (task) =>
                                    !task.isNote &&
                                    task.dueDate == null &&
                                    !task.isCompleted,
                              )
                              .length,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
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
                              child: Text(
                                DateFormat.yMMMM(
                                  context.localeName,
                                ).format(_focusedDay),
                                style: text.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: context.l10n.previousPeriod,
                              onPressed: () => _calendarPage?.previousPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              ),
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            IconButton(
                              tooltip: context.l10n.nextPeriod,
                              onPressed: () => _calendarPage?.nextPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              ),
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                      ),
                      TableCalendar<Task>(
                        firstDay: DateTime(2010),
                        lastDay: DateTime(2100, 12, 31),
                        focusedDay: _focusedDay,
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
                        onCalendarCreated: (controller) =>
                            _calendarPage = controller,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        onDaySelected: (selected, focused) => setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                        }),
                        onPageChanged: (focused) =>
                            setState(() => _focusedDay = focused),
                        eventLoader: (day) => tasks
                            .expand((task) => task.calendarOccurrencesOn(day))
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
                                          color: task.isCompleted
                                              ? colors.primary
                                              : AppTheme.priorityColor(
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
                      const SizedBox(height: 6),
                      const Divider(),
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => setState(() {
                                _selectedDay = DateTime.now();
                                _focusedDay = _selectedDay;
                              }),
                              child: Text(context.l10n.today),
                            ),
                            TextButton.icon(
                              key: const ValueKey('calendar-format'),
                              onPressed: () => setState(
                                () => _format = _format == CalendarFormat.month
                                    ? CalendarFormat.week
                                    : CalendarFormat.month,
                              ),
                              icon: Icon(
                                _format == CalendarFormat.month
                                    ? Icons.view_week_outlined
                                    : Icons.calendar_month_outlined,
                                size: 17,
                              ),
                              label: Text(
                                _format == CalendarFormat.month
                                    ? context.l10n.weekView
                                    : context.l10n.monthView,
                              ),
                            ),
                            TextButton.icon(
                              key: const ValueKey('calendar-timeline'),
                              onPressed: () => Navigator.pushNamed(
                                context,
                                '/timeline',
                                arguments: _selectedDay,
                              ),
                              icon: const Icon(
                                Icons.view_timeline_outlined,
                                size: 17,
                              ),
                              label: Text(context.l10n.dayTimeline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
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
                          const SizedBox(height: 4),
                          Text(
                            events.isEmpty
                                ? phoneCalendars
                                      ? context.l10n.noScheduledTasks
                                      : context.l10n.breathingRoom
                                : context.l10n.agendaCounts(
                                    events.length - completed,
                                    completed,
                                  ),
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (events.isNotEmpty)
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          value: completed / events.length,
                          strokeWidth: 3,
                          backgroundColor: colors.outlineVariant,
                          semanticsLabel: context.l10n.completionCount(
                            completed,
                            events.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: DeviceCalendarEvents(day: _selectedDay)),
            if (tasksState.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
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
            else if (events.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  title: context.l10n.rememberPrompt,
                  message: context.l10n.calendarEmpty,
                  action: TextButton(
                    onPressed: _create,
                    child: Text(context.l10n.typeTask),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TaskTile(
                      task: events[index],
                      showDate:
                          events[index].displayDate != null &&
                          Task.dateKey(events[index].displayDate!) !=
                              Task.dateKey(_selectedDay),
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
      bottomNavigationBar: TaskActions(onCreate: _create),
    );
  }
}
