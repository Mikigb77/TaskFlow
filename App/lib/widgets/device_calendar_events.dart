import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/device_calendar_event.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showDeviceCalendarEvent(
        BuildContext context, DateTime day, DeviceCalendarEvent event) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _CalendarSheet(day: day, eventKey: event.identity));

/// One line under the day's tasks: the phone-calendar event count and the
/// first start times. Tapping it opens every event; access problems take the
/// same line and open calendar choice, read problems retry, and a day without
/// events shows nothing. A tapped retry keeps its line, busy, until the read
/// settles.
class DeviceCalendarEvents extends ConsumerStatefulWidget {
  const DeviceCalendarEvents({super.key, required this.day});
  final DateTime day;
  @override
  ConsumerState<DeviceCalendarEvents> createState() =>
      _DeviceCalendarEventsState();
}

class _DeviceCalendarEventsState extends ConsumerState<DeviceCalendarEvents> {
  bool _retrying = false;

  @override
  void didUpdateWidget(DeviceCalendarEvents oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (Task.dateKey(oldWidget.day) != Task.dateKey(widget.day)) {
      _retrying = false;
    }
  }

  Future<void> _retry(Future<void> Function() read) async {
    setState(() => _retrying = true);
    try {
      await read();
    } catch (_) {
      // A failed retry shows the retry line again.
    }
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final state = ref.watch(deviceCalendarProvider);
    if (!state.preferences.enabled) return const SizedBox.shrink();
    final l = context.l10n;
    final busy = _EventsLine(l.calendarReadRetry, onTap: null, busy: true);
    void choose() => Navigator.pushNamed(context, '/deviceCalendars');
    void showAll() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _CalendarSheet(day: day));
    if (state.error) {
      if (_retrying) return busy;
      return _EventsLine(l.calendarReadRetry,
          onTap: () =>
              _retry(() => ref.read(deviceCalendarProvider.notifier).refresh()));
    }
    if (state.access == CalendarAccess.checking) {
      return _retrying ? busy : const SizedBox.shrink();
    }
    if (state.access != CalendarAccess.granted) {
      return _EventsLine(l.calendarDenied, onTap: choose);
    }
    if (state.preferences.selected.isEmpty) {
      return _EventsLine(l.calendarNoSelection, onTap: choose);
    }
    final key = Task.dateKey(day);
    return ref.watch(deviceEventsProvider(key)).when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => _retrying ? busy : const SizedBox.shrink(),
        error: (_, __) => _retrying
            ? busy
            : _EventsLine(l.calendarReadRetry,
                onTap: () => _retry(() {
                      ref.invalidate(deviceEventsProvider(key));
                      return ref.read(deviceEventsProvider(key).future);
                    })),
        data: (result) {
          if (result.items.isEmpty) return const SizedBox.shrink();
          final times = result.items
              .take(3)
              .map((event) => _startTime(context, event, day));
          return _EventsLine(
              [l.calendarEventCount(result.items.length), ...times]
                  .join(' · '),
              onTap: showAll);
        });
  }
}

String _startTime(
    BuildContext context, DeviceCalendarEvent event, DateTime day) {
  if (event.allDay) return context.l10n.calendarAllDay;
  final start = event.start.toLocal();
  return Task.dateKey(start) == Task.dateKey(day)
      ? context.clockTime(start)
      : context.shortDate(start);
}

class _EventsLine extends StatelessWidget {
  const _EventsLine(this.text, {required this.onTap, this.busy = false});
  final String text;
  final VoidCallback? onTap;

  /// A tapped retry in progress: a spinner takes the icon's place.
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Semantics(
            button: true,
            child: InkWell(
                key: const ValueKey('calendar-events-line'),
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        child: Row(children: [
                          if (busy)
                            SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: color))
                          else
                            Icon(Icons.event_outlined, size: 20, color: color),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(text,
                                  style: TextStyle(color: color))),
                        ]))))));
  }
}

String deviceEventTime(
    BuildContext context, DeviceCalendarEvent event, DateTime day) {
  if (event.allDay) return context.l10n.calendarAllDay;
  String format(DateTime value) {
    final local = value.toLocal();
    return '${Task.dateKey(local) == Task.dateKey(day) ? '' : '${context.shortDate(local)} · '}${context.clockTime(local)}';
  }

  return event.start.isAtSameMomentAs(event.end)
      ? format(event.start)
      : '${format(event.start)} – ${format(event.end)}';
}

class _EventTile extends ConsumerWidget {
  const _EventTile({required this.event, required this.day});
  final DeviceCalendarEvent event;
  final DateTime day;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final title = event.title.isEmpty ? l.calendarUntitled : event.title;
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppSurface(
            padding: EdgeInsets.zero,
            child: ListTile(
                leading: const Icon(Icons.event_outlined),
                title:
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    '${deviceEventTime(context, event, day)}\n${event.sources.map((c) => c.name).join(' · ')} · ${l.calendarReadOnly}'),
                onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (context) =>
                        _CalendarSheet(day: day, eventKey: event.identity)))));
  }
}

/// A sheet observes the same live permission/selection snapshot as the agenda;
/// opening an event never freezes its contents across permission revocation.
class _CalendarSheet extends ConsumerWidget {
  const _CalendarSheet({required this.day, this.eventKey});
  final DateTime day;
  final String? eventKey;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceCalendarProvider);
    final l = context.l10n;
    Widget body;
    if (state.access == CalendarAccess.checking) {
      body = const LinearProgressIndicator();
    } else if (!state.showing) {
      body = Text(l.calendarEventGone);
    } else {
      body = ref.watch(deviceEventsProvider(Task.dateKey(day))).when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => Text(l.calendarReadError),
          data: (result) {
            if (eventKey == null) {
              return Column(children: [
                if (result.truncated) MessageBanner(l.calendarTruncated),
                for (final event in result.items)
                  _EventTile(event: event, day: day)
              ]);
            }
            final event = result.items
                .where((event) => event.identity == eventKey)
                .firstOrNull;
            if (event == null) return Text(l.calendarEventGone);
            return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(l.calendarReadOnly),
                  Text(event.title.isEmpty ? l.calendarUntitled : event.title,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(deviceEventTime(context, event, day)),
                  if (event.allDay)
                    Text(
                        '${context.shortDate(event.start)} – ${context.shortDate(event.end.isAfter(event.start) ? event.end.subtract(const Duration(days: 1)) : event.start)}'),
                  Text(event.sources.map((c) => c.name).join(' · ')),
                  if (event.location.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: SelectableText(event.location)),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(l.calendarOpenEvent),
                      onPressed: () async {
                        try {
                          await ref.read(deviceCalendarsProvider).open(event);
                        } catch (_) {
                          if (context.mounted) {
                            showFeedback(ScaffoldMessenger.of(context),
                                l.calendarOpenError);
                          }
                        }
                      })
                ]);
          });
    }
    if (eventKey == null) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: SectionLabel(l.calendarEvents)),
          IconButton(
              tooltip: l.calendarChoose,
              onPressed: () => Navigator.pushNamed(context, '/deviceCalendars'),
              icon: const Icon(Icons.tune_rounded, size: 20))
        ]),
        body,
      ]);
    }
    return SafeArea(
        child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .75,
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24), child: body)));
  }
}
