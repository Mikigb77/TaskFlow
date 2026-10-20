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
import 'package:agenda/widgets/task_actions.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  final _untimed = ScrollController();
  final _timeline = GlobalKey();
  final _landedRow = GlobalKey();
  Timer? _clock;

  /// Tasks just saved from this timeline, for this day: lit until
  /// [_highlightTimer] fires.
  Set<int> _landingIds = {};
  Set<int> _landedIds = {};
  bool _highlight = false;
  Timer? _highlightTimer;

  /// The day is new (just opened, or an arrow): once it has loaded, scroll to
  /// its first timed item, or to now. [_glide] after an arrow, unless
  /// animations are off.
  bool _placing = true;
  bool _glide = false;
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
    _highlightTimer?.cancel();
    _scroll.dispose();
    _untimed.dispose();
    super.dispose();
  }

  void _changeDay(int offset) {
    setState(() {
      _day = DateTime(_day.year, _day.month, _day.day + offset);
      _placing = true;
      _glide = true;
    });
  }

  /// Where the day opens, in the timeline's own pixels: the hour of its first
  /// timed item. On today, once that item is over, the hour before now, so
  /// what just passed and the now line both show. Null: the top of the page.
  double? _opening(DayTimeline data, TimelineLayout layout, DateTime now) {
    const hour = 72.0;
    final first = layout.items.firstOrNull;
    if (first == null) return null;
    final today = Task.dateKey(now) == Task.dateKey(_day);
    if (today && data.window.contains(now) && first.entry.end.isBefore(now)) {
      final current = (data.window.offset(now) * 1.2 / hour).floor();
      return math.max(0, current - 1) * hour;
    }
    return (first.top / hour).floor() * hour;
  }

  void _place(double? y) {
    final box = _timeline.currentContext?.findRenderObject();
    if (box == null || !_scroll.hasClients) return;
    final position = _scroll.position;
    final target = y == null
        ? position.minScrollExtent
        : (RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset +
                y -
                12)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    if (_glide && !MediaQuery.disableAnimationsOf(context)) {
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  /// After a save from this timeline. Tasks for this day light up here;
  /// any other (no date, another day) shows on Calendar, as after saving from
  /// the pending list.
  void _land(CalendarFocus focus) {
    final day = focus.day;
    if (day != null && Task.dateKey(day) == Task.dateKey(_day)) {
      setState(() {
        _landingIds = focus.taskIds;
        _landedIds = {};
        _highlight = false;
        _highlightTimer?.cancel();
      });
      return;
    }
    final calendarFocus = ref.read(calendarFocusProvider.notifier);
    Navigator.of(context).popUntil((route) => route.isFirst);
    // Once this focus has reached every listener.
    scheduleMicrotask(() => calendarFocus.state =
        CalendarFocus(day, focus.taskIds, showCalendar: true));
  }

  /// Brings the first saved row into view, then lets the highlight fade.
  Future<void> _reveal() async {
    final row = _landedRow.currentContext;
    if (row != null) {
      await Scrollable.ensureVisible(row,
          alignment: .15,
          duration: MediaQuery.disableAnimationsOf(row)
              ? Duration.zero
              : const Duration(milliseconds: 250));
    }
    if (!mounted) return;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _highlight = false);
    });
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
    // Capture opened here shows what it saved here (or on Calendar).
    ref.listen<CalendarFocus?>(calendarFocusProvider, (_, focus) {
      if (focus != null && identical(focus.page, this)) _land(focus);
    });
    final l = context.l10n;
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
    final now = ref.watch(calendarClockProvider)();
    if (_placing && !tasks.isLoading && eventRead?.isLoading != true) {
      _placing = false;
      final y = _opening(data, layout, now);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _place(y);
        _glide = false;
      });
    }
    if (_landingIds.isNotEmpty &&
        (data.unblocked.any((task) => _landingIds.contains(task.id)) ||
            layout.items
                .any((item) => _landingIds.contains(item.entry.task?.id)))) {
      _landedIds = _landingIds;
      _landingIds = {};
      _highlight = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
    bool saved(Task? task) => task != null && _landedIds.contains(task.id);
    final landedTask = data.unblocked.where(saved).firstOrNull;
    // A row under «Sin hora» for this day leaves out the day the header
    // already names; one listed for another day's task keeps its date.
    bool otherDay(Task task) =>
        task.displayDate == null ||
        Task.dateKey(task.displayDate!) != Task.dateKey(_day);
    final landedItem = landedTask == null
        ? layout.items.where((item) => saved(item.entry.task)).firstOrNull
        : null;
    return Scaffold(
      appBar: CustomAppBar(title: l.dayTimeline),
      // The body reaches the screen's edge, so «Sin hora»'s third counts all
      // the height under the day header; it pads itself clear of the button.
      extendBody: true,
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              IconButton(
                  tooltip: l.previousDay,
                  onPressed: () => _changeDay(-1),
                  icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                  child: Text(context.fullDate(_day),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium)),
              IconButton(
                  tooltip: l.nextDay,
                  onPressed: () => _changeDay(1),
                  icon: const Icon(Icons.chevron_right_rounded)),
            ])),
        // The notices and the day's untimed items stay above the hours: the
        // day opens on its first timed item without scrolling them away.
        Expanded(
            child: LayoutBuilder(
                builder: (context, space) => Padding(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.paddingOf(context).bottom),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (tasks.isLoading ||
                                        eventRead?.isLoading == true)
                                      const LinearProgressIndicator(),
                                    if (tasks.hasError)
                                      MessageBanner(l.loadTasksError,
                                          isError: true),
                                    if (access.preferences.enabled &&
                                        (access.error ||
                                            eventRead?.hasError == true))
                                      MessageBanner(l.calendarReadError,
                                          isError: true),
                                    if (access.preferences.enabled &&
                                        access.access !=
                                            CalendarAccess.granted &&
                                        access.access !=
                                            CalendarAccess.checking)
                                      TextButton(
                                          onPressed: () => Navigator.pushNamed(
                                              context, '/deviceCalendars'),
                                          child: Text(l.calendarDenied)),
                                    if (eventRead?.valueOrNull?.truncated ==
                                        true)
                                      MessageBanner(l.calendarTruncated),
                                    if (data.entries.length > 200)
                                      MessageBanner(l.timelineLimit),
                                  ])),
                          // Pinned, as a phone calendar pins all-day items: a
                          // third of the space, or as much as its label and
                          // first whole row need, never more than half;
                          // scrolling by itself. The bar shows there's more
                          // when no row shows cut.
                          if (data.allDayEvents.isNotEmpty ||
                              data.unblocked.isNotEmpty)
                            _UntimedCap(
                                space: space.maxHeight,
                                child: Scrollbar(
                                  controller: _untimed,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    key: const ValueKey('timeline-untimed'),
                                    controller: _untimed,
                                    padding:
                                        const EdgeInsets.fromLTRB(16, 4, 16, 0),
                                    child: _untimedItems(context, data,
                                        landedTask, saved, otherDay),
                                  ),
                                )),
                          // An edge under the pinned area, so a row cut there
                          // reads as cut by it, not as a broken card.
                          if (data.allDayEvents.isNotEmpty ||
                              data.unblocked.isNotEmpty)
                            Divider(
                                height: 1,
                                thickness: 1,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant),
                          Expanded(
                              child: _hours(context, data, layout, now,
                                  minimumHeight, scale, landedItem, saved)),
                        ])))),
      ]),
      // The same one button as Calendar, for this day.
      bottomNavigationBar:
          SafeArea(top: false, child: TaskActions(day: _day, page: this)),
    );
  }

  /// «Sin hora»'s label and rows. The label and the first item are its head,
  /// which [_UntimedCap] measures.
  Widget _untimedItems(BuildContext context, DayTimeline data, Task? landedTask,
      bool Function(Task?) saved, bool Function(Task) otherDay) {
    final l = context.l10n;
    final items = [
      for (final event in data.allDayEvents)
        ListTile(
            leading: const Icon(Icons.event_outlined),
            title: Text(
                event.title.isEmpty ? l.calendarUntitled : event.title),
            subtitle: Text('${l.calendarAllDay} · ${l.calendarReadOnly}'),
            onTap: () => showDeviceCalendarEvent(context, _day, event)),
      for (final task in data.unblocked)
        Padding(
            key: identical(task, landedTask) ? _landedRow : null,
            padding: const EdgeInsets.only(bottom: 8),
            child: saved(task)
                ? LandedTaskTile(
                    task: task, showDate: otherDay(task), lit: _highlight)
                : TaskTile(task: task, showDate: otherDay(task))),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _UntimedHead(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            SectionLabel(l.timelineUnblocked),
            ...items.take(1),
          ])),
      ...items.skip(1),
    ]);
  }

  /// The hours, the one part of the page that scrolls as a whole (and
  /// refreshes on a pull).
  Widget _hours(
      BuildContext context,
      DayTimeline data,
      TimelineLayout layout,
      DateTime now,
      double minimumHeight,
      double scale,
      TimelinePlacement? landedItem,
      bool Function(Task?) saved) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
        onRefresh: _refresh,
        // All of it is built, so the day can open on its first timed
        // item however short the view is above the add button.
        child: SingleChildScrollView(
            key: const ValueKey('timeline-scroll'),
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              if (data.entries.isEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(l.timelineNoBlocks)),
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
                final times =
                    data.window.hours.map(context.clockTime).toList();
                return SingleChildScrollView(
                    key: _timeline,
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
                                child: KeyedSubtree(
                                    key: identical(item, landedItem)
                                        ? _landedRow
                                        : null,
                                    child: _TimelineBlock(
                                        key: ValueKey(item.entry.id),
                                        item: item,
                                        day: _day,
                                        lit: _highlight &&
                                            saved(item.entry.task)))),
                        ])));
              }),
            ])));
  }
}

class _TimelineBlock extends StatelessWidget {
  const _TimelineBlock(
      {super.key, required this.item, required this.day, this.lit = false});
  final TimelinePlacement item;
  final DateTime day;

  /// Just saved: drawn as LandedTaskTile draws a saved task.
  final bool lit;
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
    // Title first, as the block reads: «Paseo por el parque, 08:30».
    final label = switch (entry.kind) {
      TimelineKind.planned => '$title, $range',
      TimelineKind.deadline => '${l.deadline}: $title, $range',
      TimelineKind.calendar => '$title, $range, ${l.calendarReadOnly}'
    };
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
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                  end: lit ? colors.primaryContainer : colors.surfaceContainer),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 600),
              builder: (context, background, child) => Material(
                  color: background,
                  borderRadius: BorderRadius.circular(8),
                  child: child),
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

/// Marks «Sin hora»'s head, its label and first item, for [_UntimedCap].
class _UntimedHead extends SingleChildRenderObjectWidget {
  const _UntimedHead({required super.child});
  @override
  RenderProxyBox createRenderObject(BuildContext context) =>
      _RenderUntimedHead();
}

class _RenderUntimedHead extends RenderProxyBox {
  /// Its height, kept here: only a parent may read a box's size.
  double height = 0;
  @override
  void performLayout() {
    super.performLayout();
    height = size.height;
  }
}

/// Caps «Sin hora» at the larger of a third of [space] and what its head
/// needs (the top padding, the label and the first whole item), never more
/// than half of [space]. Shorter content keeps its own height. Measured during
/// layout, so the day opens on the area's final size.
class _UntimedCap extends SingleChildRenderObjectWidget {
  const _UntimedCap({required this.space, required super.child});
  final double space;
  @override
  _RenderUntimedCap createRenderObject(BuildContext context) =>
      _RenderUntimedCap(space);
  @override
  void updateRenderObject(BuildContext context, _RenderUntimedCap cap) =>
      cap.space = space;
}

class _RenderUntimedCap extends RenderProxyBox {
  _RenderUntimedCap(this._space);
  double _space;
  set space(double value) {
    if (value == _space) return;
    _space = value;
    markNeedsLayout();
  }

  /// The cap of the last layout: tried first, so a steady area is laid out
  /// once.
  double? _cap;

  /// The bottom of the head, from this box's top, with nothing scrolled.
  double _headBottom() {
    _RenderUntimedHead? head;
    void find(RenderObject node) {
      if (head != null) return;
      if (node is _RenderUntimedHead) {
        head = node;
      } else {
        node.visitChildren(find);
      }
    }

    visitChildren(find);
    final found = head;
    if (found == null) return 0;
    var bottom = found.height;
    RenderObject? node = found;
    while (node != null && node != this) {
      final data = node.parentData;
      if (data is BoxParentData) bottom += data.offset.dy;
      node = node.parent;
    }
    return bottom;
  }

  BoxConstraints _within(double cap) => BoxConstraints(
      minWidth: constraints.minWidth,
      maxWidth: constraints.maxWidth,
      minHeight: math.min(constraints.minHeight, cap),
      maxHeight: math.min(constraints.maxHeight, cap));

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final half = _space / 2;
    final tried = math.min(_cap ?? half, half);
    child.layout(_within(tried), parentUsesSize: true);
    final cap = math.min(half, math.max(_space / 3, _headBottom()));
    final fits = child.size.height < tried - .01 && child.size.height <= cap;
    if ((cap - tried).abs() > .01 && !fits) {
      child.layout(_within(cap), parentUsesSize: true);
    }
    _cap = cap;
    size = constraints.constrain(child.size);
  }
}
