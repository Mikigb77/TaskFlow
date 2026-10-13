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

class DeviceCalendarEvents extends ConsumerWidget {
  const DeviceCalendarEvents({super.key, required this.day});
  final DateTime day;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceCalendarProvider);
    if (!state.preferences.enabled) return const SizedBox.shrink();
    final l = context.l10n;
    return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: SectionLabel(l.calendarEvents)),
            IconButton(
                tooltip: l.calendarChoose,
                onPressed: () =>
                    Navigator.pushNamed(context, '/deviceCalendars'),
                icon: const Icon(Icons.tune_rounded, size: 20))
          ]),
          if (state.error)
            MessageBanner(l.calendarReadError, isError: true)
          else if (state.access == CalendarAccess.checking)
            const LinearProgressIndicator()
          else if (state.access != CalendarAccess.granted)
            TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/deviceCalendars'),
                child: Text(l.calendarDenied))
          else if (state.preferences.selected.isEmpty)
            TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/deviceCalendars'),
                child: Text(l.calendarNoSelection))
          else
            ref.watch(deviceEventsProvider(Task.dateKey(day))).when(
                skipLoadingOnRefresh: false,
                skipLoadingOnReload: false,
                loading: () => const LinearProgressIndicator(),
                error: (_, __) =>
                    MessageBanner(l.calendarReadError, isError: true),
                data: (result) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (result.truncated)
                            MessageBanner(l.calendarTruncated),
                          if (result.items.isEmpty) Text(l.calendarNoEvents),
                          for (final event in result.items.take(3))
                            _EventTile(event: event, day: day),
                          if (result.items.length > 3)
                            TextButton(
                                onPressed: () => showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    showDragHandle: true,
                                    builder: (context) =>
                                        _CalendarSheet(day: day)),
                                child: Text(
                                    '${l.calendarShowAll} (${result.items.length})')),
                        ])),
        ]));
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
    return SafeArea(
        child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .75,
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24), child: body)));
  }
}
