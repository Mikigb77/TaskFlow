import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/device_calendar_event.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:flutter/material.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showDeviceCalendarEvent(
        BuildContext context, DateTime day, DeviceCalendarEvent event) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _CalendarSheet(day: day, eventKey: event.identity));

/// Every phone-calendar event of [day], in a sheet.
Future<void> _showDeviceCalendarEvents(BuildContext context, DateTime day) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _CalendarSheet(day: day));

/// Under the day's tasks, its phone-calendar events by name, up to three
/// rows: «Cita con el dentista · 17:00». Each row opens its event; with more,
/// a fourth row opens every event. Access problems take one line and open
/// calendar choice, read problems retry, and a day without events shows
/// nothing. A tapped retry keeps its line, busy, until the read settles.
class DeviceCalendarEvents extends ConsumerStatefulWidget {
  const DeviceCalendarEvents({super.key, required this.day});
  final DateTime day;
  @override
  ConsumerState<DeviceCalendarEvents> createState() =>
      _DeviceCalendarEventsState();
}

class _DeviceCalendarEventsState extends ConsumerState<DeviceCalendarEvents>
    with CalendarReadRetry {
  @override
  void didUpdateWidget(DeviceCalendarEvents oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (Task.dateKey(oldWidget.day) != Task.dateKey(widget.day)) {
      retrying = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown(context);
    // 8 dp keep whatever shows apart from «Sin fecha · N» under it.
    return shown == null
        ? const SizedBox.shrink()
        : Padding(padding: const EdgeInsets.only(bottom: 8), child: shown);
  }

  Widget? _shown(BuildContext context) {
    final day = widget.day;
    final state = ref.watch(deviceCalendarProvider);
    if (!state.preferences.enabled) return null;
    final l = context.l10n;
    const busy = CalendarReadRetryLine(busy: true);
    void choose() => Navigator.pushNamed(context, '/deviceCalendars');
    if (state.error) {
      if (retrying) return busy;
      return CalendarReadRetryLine(
          onRetry: () =>
              retry(() => ref.read(deviceCalendarProvider.notifier).refresh()));
    }
    if (state.access == CalendarAccess.checking) {
      return retrying ? busy : null;
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
        loading: () => retrying ? busy : null,
        error: (_, _) => retrying
            ? busy
            : CalendarReadRetryLine(
                onRetry: () => retry(() => readDayEventsAgain(ref, key))),
        data: (result) {
          final events = result.items;
          if (events.isEmpty) return null;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            for (final event in events.take(3))
              _EventRow(event: event, day: day),
            if (events.length > 3)
              _EventRow(
                  key: const ValueKey('calendar-events-all'),
                  text: l.calendarSeeAllEvents(events.length),
                  day: day),
          ]);
        });
  }
}

/// Reads a day's phone events again, for a retry.
Future<void> readDayEventsAgain(WidgetRef ref, String dateKey) {
  ref.invalidate(deviceEventsProvider(dateKey));
  return ref.read(deviceEventsProvider(dateKey).future);
}

/// A tapped retry keeps its line on screen, busy, until its read settles,
/// while the read itself shows as loading.
mixin CalendarReadRetry<T extends StatefulWidget> on State<T> {
  bool retrying = false;

  Future<void> retry(Future<void> Function() read) async {
    setState(() => retrying = true);
    try {
      await read();
    } catch (_) {
      // A failed retry shows the retry line again.
    }
    if (mounted) setState(() => retrying = false);
  }
}

/// «No se pudieron leer los eventos. Toca para reintentar.»: a failed
/// phone-calendar read, which a tap reads again. While [busy], a spinner takes
/// the icon's place and the line takes no tap. [inset] is its side margin.
class CalendarReadRetryLine extends StatelessWidget {
  const CalendarReadRetryLine(
      {super.key, this.onRetry, this.busy = false, this.inset = 20});
  final VoidCallback? onRetry;
  final bool busy;
  final double inset;
  @override
  Widget build(BuildContext context) => _EventsLine(
      context.l10n.calendarReadRetry,
      onTap: busy ? null : onRetry,
      busy: busy,
      inset: inset);
}

String _startTime(
    BuildContext context, DeviceCalendarEvent event, DateTime day) {
  if (event.allDay) return context.l10n.calendarAllDay;
  final start = event.start.toLocal();
  return Task.dateKey(start) == Task.dateKey(day)
      ? context.clockTime(start)
      : context.shortDate(start);
}

/// One of the day's events on Calendar, title first: «Cita con el dentista ·
/// 17:00»; a tap opens it. Without [event], [text] opens every event. Events,
/// not tasks: no circle and no swipe.
class _EventRow extends StatelessWidget {
  const _EventRow({super.key, this.event, this.text, required this.day});
  final DeviceCalendarEvent? event;
  final String? text;
  final DateTime day;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final event = this.event;
    final l = context.l10n;
    final Widget label;
    final VoidCallback onTap;
    if (event == null) {
      label = Text(text!,
          style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600));
      onTap = () => _showDeviceCalendarEvents(context, day);
    } else {
      label = Text.rich(
          TextSpan(children: [
            TextSpan(
                text: event.title.isEmpty ? l.calendarUntitled : event.title),
            TextSpan(
                text: ' · ${_startTime(context, event, day)}',
                style: TextStyle(color: colors.onSurfaceVariant)),
          ]),
          maxLines: 2,
          overflow: TextOverflow.ellipsis);
      onTap = () => showDeviceCalendarEvent(context, day, event);
    }
    final row = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(children: [
          if (event == null)
            const SizedBox(width: 20)
          else
            Icon(Icons.event_outlined, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: label),
        ]));
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Semantics(
            button: true,
            // An event is an aqua card with a teal edge, set apart from the
            // white task cards; the line that opens them all stays plain.
            child: event == null
                ? InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: row))
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Material(
                        color: dark
                            ? Lagoon.tint.withValues(alpha: 0.12)
                            : Lagoon.tintBg,
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                            key: ValueKey('calendar-event-${event.identity}'),
                            onTap: onTap,
                            child: IntrinsicHeight(
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  Container(
                                      width: 4,
                                      color: dark
                                          ? Lagoon.tint
                                          : Lagoon.accent2),
                                  Expanded(
                                      child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              minHeight: 48),
                                          child: Padding(
                                              padding:
                                                  const EdgeInsetsDirectional
                                                      .only(start: 8),
                                              child: row))),
                                ])))))));
  }
}

class _EventsLine extends StatelessWidget {
  const _EventsLine(this.text,
      {required this.onTap, this.busy = false, this.inset = 20});
  final String text;
  final VoidCallback? onTap;

  /// A tapped retry in progress: a spinner takes the icon's place.
  final bool busy;
  final double inset;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: Semantics(
            button: true,
            enabled: onTap != null,
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
                    '${deviceEventTime(context, event, day)}\n${event.sources.map((c) => c.name).join(' · ')}'),
                onTap: () => showDeviceCalendarEvent(context, day, event))));
  }
}

/// A sheet observes the same live permission/selection snapshot as the agenda;
/// opening an event never freezes its contents across permission revocation.
/// It is as tall as its content, up to three quarters of the screen, and ends
/// with «Cerrar».
class _CalendarSheet extends ConsumerStatefulWidget {
  const _CalendarSheet({required this.day, this.eventKey});
  final DateTime day;
  final String? eventKey;
  @override
  ConsumerState<_CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends ConsumerState<_CalendarSheet>
    with CalendarReadRetry {
  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final eventKey = widget.eventKey;
    final state = ref.watch(deviceCalendarProvider);
    final l = context.l10n;
    final key = Task.dateKey(day);
    const busy = CalendarReadRetryLine(busy: true, inset: 0);
    Widget body;
    if (state.access == CalendarAccess.checking) {
      body = const LinearProgressIndicator();
    } else if (!state.showing) {
      body = Text(l.calendarEventGone);
    } else {
      body = ref.watch(deviceEventsProvider(key)).when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => retrying ? busy : const LinearProgressIndicator(),
          error: (_, _) => retrying
              ? busy
              : CalendarReadRetryLine(
                  inset: 0,
                  onRetry: () => retry(() => readDayEventsAgain(ref, key))),
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
        child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .75),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                          child: body)),
                  // A way out that shows, as Back, the scrim or a drag do.
                  Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: TextButton(
                          key: const ValueKey('calendar-sheet-close'),
                          onPressed: () => Navigator.pop(context),
                          child: Text(l.close))),
                ])));
  }
}
