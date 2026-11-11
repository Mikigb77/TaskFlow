import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/device_calendar_event.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/device_calendar_events.dart';
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
  bool _refused = false;
  bool? _more;
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

  /// Asks for access; a refusal is said on the screen.
  Future<void> _connect() async {
    await ref.read(deviceCalendarProvider.notifier).enable();
    if (mounted) {
      setState(() => _refused =
          ref.read(deviceCalendarProvider).access != CalendarAccess.granted);
    }
  }

  Future<void> _export(bool on) async {
    final allowed =
        await ref.read(deviceCalendarProvider.notifier).setExport(on);
    if (!allowed && mounted) {
      showFeedback(
          ScaffoldMessenger.of(context), context.l10n.calendarExportRefused);
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

  /// One tick per account, the switch that adds tasks to the calendar, and
  /// behind «More options» the extra calendars (holidays, birthdays…, off by
  /// default) and, with two or more, where tasks go.
  List<Widget> _choices(
      DeviceCalendarState state, DeviceCalendarController controller) {
    final l = context.l10n;
    final preferences = state.preferences;
    final accounts = <String, List<DeviceCalendar>>{};
    for (final calendar in state.calendars) {
      if (calendar.isOwn) {
        (accounts[calendar.accountKey] ??= []).add(calendar);
      }
    }
    // Accounts by address; the phone's own calendars last.
    final ordered = accounts.values.toList()
      ..sort((a, b) {
        if (a.first.onPhone != b.first.onPhone) return a.first.onPhone ? 1 : -1;
        return a.first.account
            .toLowerCase()
            .compareTo(b.first.account.toLowerCase());
      });
    final extras = [for (final c in state.calendars) if (!c.isOwn) c];
    final target = state.exportCalendar;
    final more = _more ??
        extras.any((c) => preferences.extras.contains(c.selectionKey));
    Widget address(String text) =>
        Text(breakableAddress(text), semanticsLabel: text);
    return [
      const SizedBox(height: 20),
      SectionLabel(l.calendarChoose),
      if (state.truncated) MessageBanner(l.calendarTruncated),
      if (state.calendars.isEmpty) ...[
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(l.calendarEmptySources)),
        OutlinedButton.icon(
            onPressed:
                _busy ? null : () => _run(() => controller.refresh(browse: true)),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l.calendarRefresh)),
      ],
      for (final calendars in ordered)
        CheckboxListTile(
            key: ValueKey('device-account-${calendars.first.accountKey}'),
            contentPadding: EdgeInsets.zero,
            // An address wraps after «@» or «.», never mid-word.
            title: address(calendarAccount(l, calendars.first)),
            subtitle: calendars.length < 2
                ? null
                : Text(l.calendarAccountCalendars(calendars.length)),
            value: preferences.accounts.contains(calendars.first.accountKey),
            onChanged: _busy
                ? null
                : (selected) => _run(() => controller.selectAccount(
                    calendars.first.accountKey, selected == true))),
      if (target != null)
        SwitchListTile(
            key: const ValueKey('calendar-export'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.calendarExport),
            subtitle: preferences.export
                ? Text(l.calendarExportTo(
                    breakableAddress(calendarName(l, target))))
                : null,
            value: preferences.export,
            onChanged: _busy ? null : (on) => _run(() => _export(on))),
      if (state.calendars.isNotEmpty) ...[
        const SizedBox(height: 4),
        Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
                key: const ValueKey('calendar-more'),
                onPressed: () => setState(() => _more = !more),
                icon: Icon(more
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded),
                label: Text(
                    more ? l.calendarFewerOptions : l.calendarMoreOptions))),
      ],
      if (more && state.calendars.isNotEmpty) ...[
        if (extras.isNotEmpty) ...[
          const SizedBox(height: 8),
          SectionLabel(l.calendarExtras),
          for (final calendar in extras)
            CheckboxListTile(
                key: ValueKey('device-calendar-${calendar.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(calendarName(l, calendar)),
                subtitle: calendar.onPhone ||
                        const {'subscribed', 'birthdays'}
                            .contains(calendar.accountType)
                    ? null
                    : Text(
                        l.calendarFromAccount(
                            breakableAddress(calendar.account)),
                        semanticsLabel:
                            l.calendarFromAccount(calendar.account)),
                value: preferences.extras.contains(calendar.selectionKey),
                onChanged: _busy
                    ? null
                    : (selected) => _run(() => controller.selectExtra(
                        calendar.selectionKey, selected == true))),
        ],
        if (preferences.export && state.writable.length > 1) ...[
          const SizedBox(height: 8),
          SectionLabel(l.calendarExportTarget),
          RadioGroup<String>(
              groupValue: target?.selectionKey,
              onChanged: (id) {
                if (id != null && !_busy) {
                  _run(() => controller.setExportTarget(id));
                }
              },
              child: Column(children: [
                for (final calendar in state.writable)
                  RadioListTile<String>(
                      key: ValueKey('calendar-target-${calendar.id}'),
                      contentPadding: EdgeInsets.zero,
                      value: calendar.selectionKey,
                      title: address(calendarName(l, calendar)),
                      subtitle: calendar.readableName.isEmpty
                          ? null
                          : address(calendarAccount(l, calendar))),
              ])),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed:
                _busy ? null : () => _run(() => controller.refresh(browse: true)),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l.calendarRefresh)),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceCalendarProvider);
    final controller = ref.read(deviceCalendarProvider.notifier);
    final l = context.l10n;
    final enabled = state.preferences.enabled;
    // One line says where things stand: before access, after a refusal, or
    // connected. None while an earlier connection is being checked.
    final String? lead = switch (state.access) {
      CalendarAccess.unavailable => l.calendarUnsupported,
      CalendarAccess.blocked => l.calendarBlocked,
      CalendarAccess.denied when enabled || _refused => l.calendarRefused,
      CalendarAccess.granted when state.showing => l.calendarConnected,
      CalendarAccess.granted || CalendarAccess.checking when enabled => null,
      _ => l.deviceCalendarIntro,
    };
    return Scaffold(
        appBar: CustomAppBar(title: l.deviceCalendars),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          if (lead != null) ...[Text(lead), const SizedBox(height: 16)],
          if (_busy || state.access == CalendarAccess.checking)
            const LinearProgressIndicator(),
          if (state.error)
            CalendarReadRetryLine(
                inset: 0,
                busy: _busy,
                onRetry: () => _run(() => controller.refresh(browse: true))),
          if (state.access != CalendarAccess.unavailable) ...[
            if (state.access == CalendarAccess.blocked)
              OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(ref.read(deviceCalendarsProvider).settings),
                  child: Text(l.calendarSettings))
            else if (!enabled || state.access == CalendarAccess.denied)
              FilledButton.icon(
                  key: const ValueKey('calendar-connect'),
                  onPressed: _busy || state.access == CalendarAccess.checking
                      ? null
                      : () => _run(_connect),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(l.calendarEnable,
                      textAlign: TextAlign.center,
                      textWidthBasis: TextWidthBasis.longestLine)),
            if (state.access == CalendarAccess.granted && enabled)
              ..._choices(state, controller),
            // The off switch sits below the list, never where «Conectar» was.
            if (enabled) ...[
              const SizedBox(height: 8),
              TextButton(
                  key: const ValueKey('calendar-disable'),
                  onPressed: _busy ? null : () => _run(controller.disable),
                  child: Text(l.calendarDisable)),
            ],
          ],
        ]));
  }
}
