import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceCalendarsScreen extends ConsumerStatefulWidget {
  const DeviceCalendarsScreen({super.key});
  @override
  ConsumerState<DeviceCalendarsScreen> createState() =>
      _DeviceCalendarsScreenState();
}

class _DeviceCalendarsScreenState extends ConsumerState<DeviceCalendarsScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (mounted) {
        ref.read(deviceCalendarProvider.notifier).refresh(browse: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(deviceCalendarProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      controller.refresh(browse: true);
    } else {
      controller.suspend();
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        showFeedback(ScaffoldMessenger.of(context),
            context.l10n.calendarPreferenceError);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceCalendarProvider);
    final controller = ref.read(deviceCalendarProvider.notifier);
    final l = context.l10n;
    return Scaffold(
        appBar: CustomAppBar(title: l.deviceCalendars),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          Text(l.deviceCalendarHelp,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text(l.deviceCalendarPrivacy),
          const SizedBox(height: 20),
          if (_busy || state.access == CalendarAccess.checking)
            const LinearProgressIndicator(),
          if (state.error) MessageBanner(l.calendarReadError, isError: true),
          if (state.access == CalendarAccess.unavailable)
            Text(l.calendarUnsupported)
          else ...[
            if (state.access == CalendarAccess.denied) Text(l.calendarDenied),
            if (state.access == CalendarAccess.blocked) Text(l.calendarBlocked),
            if (state.access == CalendarAccess.blocked)
              OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(ref.read(deviceCalendarsProvider).settings),
                  child: Text(l.calendarSettings))
            else if (!state.preferences.enabled ||
                state.access == CalendarAccess.denied)
              FilledButton.icon(
                  key: const ValueKey('calendar-connect'),
                  onPressed: _busy || state.access == CalendarAccess.checking
                      ? null
                      : () => _run(controller.enable),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(l.calendarEnable)),
            if (state.preferences.enabled)
              TextButton(
                  onPressed: _busy ? null : () => _run(controller.disable),
                  child: Text(l.calendarDisable)),
            if (state.access == CalendarAccess.granted &&
                state.preferences.enabled) ...[
              const SizedBox(height: 20),
              SectionLabel(l.calendarChoose),
              Text(l.calendarChooseHelp),
              if (state.truncated) MessageBanner(l.calendarTruncated),
              if (state.calendars.isEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(l.calendarEmptySources)),
              for (final calendar in state.calendars)
                CheckboxListTile(
                    key: ValueKey('device-calendar-${calendar.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(calendar.name.isEmpty
                        ? l.calendarUntitled
                        : calendar.name),
                    subtitle: calendar.account.isEmpty
                        ? null
                        : Text(calendar.account),
                    value: state.preferences.selected
                        .contains(calendar.selectionKey),
                    onChanged: _busy
                        ? null
                        : (selected) => _run(() => controller.select(
                            calendar.selectionKey, selected == true))),
              if (state.preferences.selected.isNotEmpty)
                TextButton(
                    onPressed:
                        _busy ? null : () => _run(controller.clearSelection),
                    child: Text(l.calendarClear)),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(() => controller.refresh(browse: true)),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.calendarRefresh)),
          ],
        ]));
  }
}
