import 'dart:async';
import 'dart:math' as math;
import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/day_timeline.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/device_calendar_events.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DayTimelineScreen extends ConsumerStatefulWidget {
  const DayTimelineScreen({super.key, required this.day});
  final DateTime day;
  @override
  ConsumerState<DayTimelineScreen> createState() => _DayTimelineScreenState();
}

class _DayTimelineScreenState extends ConsumerState<DayTimelineScreen>
    with WidgetsBindingObserver {
  late DateTime _day = Task.day(widget.day);
  final _scroll = ScrollController();
  final _firstItem = GlobalKey();
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _changeDay(int offset) {
    setState(() => _day = DateTime(_day.year, _day.month, _day.day + offset));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final calendars = ref.read(deviceCalendarProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      calendars.refresh();
      ref.read(taskProvider.notifier).loadTasks();
    } else {
      calendars.suspend();
    }
  }

  Future<void> _refresh() async => Future.wait([
        ref.read(taskProvider.notifier).loadTasks(),
        ref.read(deviceCalendarProvider.notifier).refresh(),
      ]);
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final tasks = ref.watch(taskProvider);
    final access = ref.watch(deviceCalendarProvider);
    final eventRead = access.showing
        ? ref.watch(deviceEventsProvider(Task.dateKey(_day)))
        : null;
    final events =
        eventRead != null && !eventRead.isLoading && !eventRead.hasError
            ? eventRead.valueOrNull?.items ?? []
            : [];
    final data =
        DayTimeline.build(_day, tasks.valueOrNull ?? [], events.cast());
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final minimumHeight = math.max(52.0, 46 * scale);
    final layout = TimelineLayout.place(
        data.entries.take(200).toList(), data.window,
        minimumHeight: minimumHeight);
    final first = layout.items.firstOrNull;
    return Scaffold(
      appBar: CustomAppBar(title: l.dayTimeline),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              IconButton(
                  tooltip: l.previousPeriod,
                  onPressed: () => _changeDay(-1),
                  icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                  child: Text(context.fullDate(_day),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium)),
              IconButton(
                  tooltip: l.nextPeriod,
                  onPressed: () => _changeDay(1),
                  icon: const Icon(Icons.chevron_right_rounded)),
            ])),
        Expanded(
            child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                    key: const ValueKey('timeline-scroll'),
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Text(l.timelineHelp),
                      if (tasks.isLoading || eventRead?.isLoading == true)
                        const LinearProgressIndicator(),
                      if (tasks.hasError)
                        MessageBanner(l.loadTasksError, isError: true),
                      if (access.preferences.enabled &&
                          (access.error || eventRead?.hasError == true))
                        MessageBanner(l.calendarReadError, isError: true),
                      if (access.preferences.enabled &&
                          access.access != CalendarAccess.granted &&
                          access.access != CalendarAccess.checking)
                        TextButton(
                            onPressed: () => Navigator.pushNamed(
                                context, '/deviceCalendars'),
                            child: Text(l.calendarDenied)),
                      if (eventRead?.valueOrNull?.truncated == true)
                        MessageBanner(l.calendarTruncated),
                      if (data.allDayEvents.isNotEmpty ||
                          data.unblocked.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        SectionLabel(l.timelineUnblocked),
                        for (final event in data.allDayEvents)
                          ListTile(
                              leading: const Icon(Icons.event_outlined),
                              title: Text(event.title.isEmpty
                                  ? l.calendarUntitled
                                  : event.title),
                              subtitle: Text(
                                  '${l.calendarAllDay} · ${l.calendarReadOnly}'),
                              onTap: () => showDeviceCalendarEvent(
                                  context, _day, event)),
                        for (final task in data.unblocked)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TaskTile(task: task, showDate: true)),
                      ],
                      if (data.entries.isEmpty)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(l.timelineNoBlocks)),
                      if (data.entries.length > 200)
                        MessageBanner(l.timelineLimit),
                      if (first != null)
                        TextButton.icon(
                            onPressed: () {
                              final item = _firstItem.currentContext;
                              if (item != null) {
                                Scrollable.ensureVisible(item,
                                    alignment: .15,
                                    duration:
                                        const Duration(milliseconds: 250));
                              }
                            },
                            icon: const Icon(Icons.schedule_outlined),
                            label: Text(l.timelineFirstPlan)),
                      Text(l.timelineShortBlocks,
                          style: Theme.of(context).textTheme.bodySmall),
                      if (data.window.minutes != 1440)
                        Text(l.timelineHours(data.window.minutes ~/ 60)),
                      const SizedBox(height: 16),
                      LayoutBuilder(builder: (context, constraints) {
                        final ruler = math.max(64.0, 54 * scale);
                        final laneWidth = math.max(150.0 * math.min(scale, 2),
                            (constraints.maxWidth - ruler) / layout.lanes);
                        final width = ruler + laneWidth * layout.lanes;
                        final height =
                            data.window.minutes * 1.2 + minimumHeight + 12;
                        final now = DateTime.now();
                        final times =
                            data.window.hours.map(context.clockTime).toList();
                        return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                                width: width,
                                height: height,
                                child: Stack(children: [
                                  for (var index = 0;
                                      index < data.window.hours.length;
                                      index++)
                                    Positioned(
                                        top: index * 72.0,
                                        left: 0,
                                        right: 0,
                                        child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(
                                                  width: ruler,
                                                  child: Text(
                                                      '${times[index]}${times.take(times.length - 1).where((time) => time == times[index]).length > 1 ? '\n${data.window.hours[index].timeZoneName}' : ''}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall)),
                                              Expanded(
                                                  child: Divider(
                                                      color:
                                                          colors.outlineVariant,
                                                      height: 1)),
                                            ])),
                                  if (data.window.contains(now))
                                    Positioned(
                                        top: data.window.offset(now) * 1.2,
                                        left: ruler,
                                        right: 0,
                                        child: ExcludeSemantics(
                                            child: Divider(
                                                color: colors.error,
                                                thickness: 2,
                                                height: 2))),
                                  for (final item in layout.items)
                                    Positioned(
                                        top: item.top,
                                        left: ruler + item.lane * laneWidth + 4,
                                        width: laneWidth - 8,
                                        height: item.height,
                                        child: _TimelineBlock(
                                            key: identical(item, first)
                                                ? _firstItem
                                                : ValueKey(item.entry.id),
                                            item: item,
                                            day: _day)),
                                ])));
                      }),
                    ]))),
      ]),
      floatingActionButton: FloatingActionButton(
          tooltip: l.newTask,
          onPressed: () {
            // Never pre-fill a day that has already gone.
            final today = Task.day(ref.read(calendarClockProvider)());
            Navigator.pushNamed(context, '/createTask',
                arguments: _day.isBefore(today) ? today : _day);
          },
          child: const Icon(Icons.add_rounded)),
    );
  }
}

class _TimelineBlock extends StatelessWidget {
  const _TimelineBlock({super.key, required this.item, required this.day});
  final TimelinePlacement item;
  final DateTime day;
  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final color = entry.kind == TimelineKind.deadline
        ? colors.error
        : entry.kind == TimelineKind.calendar
            ? colors.secondary
            : colors.primary;
    final title = entry.title.isEmpty ? l.calendarUntitled : entry.title;
    String time(DateTime value) {
      final local = value.toLocal();
      return '${Task.dateKey(local) == Task.dateKey(day) ? '' : '${context.shortDate(local)} · '}${context.clockTime(local)}';
    }

    final range = entry.point
        ? time(entry.start)
        : '${time(entry.start)} – ${time(entry.end)}';
    final kind = switch (entry.kind) {
      TimelineKind.deadline => l.deadline,
      TimelineKind.calendar => l.calendarReadOnly,
      TimelineKind.planned => l.plannedFor
    };
    final label =
        '$kind · $title · $range${entry.kind == TimelineKind.planned && entry.point ? ' · ${l.timelinePoint}' : ''}';
    void open() {
      if (entry.event != null) {
        showDeviceCalendarEvent(context, day, entry.event!);
        return;
      }
      if (entry.task?.id == null) return;
      Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => TaskDetailScreen(
                  taskId: entry.task!.id!,
                  occurrenceDate: entry.task!.occurrenceDate,
                  occurrenceKey: entry.task!.occurrenceId)));
    }

    return Semantics(
        label: label,
        button: true,
        excludeSemantics: true,
        child: Tooltip(
            message: label,
            child: Material(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                  onTap: open,
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(children: [
                    Positioned(
                        left: 0,
                        top: 0,
                        width: 5,
                        height: item.durationHeight,
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3)))),
                    Positioned.fill(
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(11, 5, 5, 5),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${entry.kind == TimelineKind.deadline ? '${l.deadline}: ' : ''}$title',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          decoration:
                                              entry.task?.isCompleted == true
                                                  ? TextDecoration.lineThrough
                                                  : null)),
                                  Text(range,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12, color: color)),
                                ]))),
                  ])),
            )));
  }
}
