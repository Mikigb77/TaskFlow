import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/reminder_provider.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/reminder_engine.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/app_components.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  ReminderPreferences? _settings;
  ReminderCapability _capability =
      const ReminderCapability(allowed: false, exact: false);
  List<Map<String, Object?>> _alerts = [];
  String? _error;
  String? _schedulerError;
  int _deferred = 0;
  bool _busy = false;
  late final String _owner;
  @override
  void initState() {
    super.initState();
    _owner = ref.read(taskRepositoryProvider).ownerKey;
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final store = ref.read(reminderPreferenceStoreProvider);
      final settings = await store.read(_owner);
      var capability = _capability;
      if (TaskReminders.supported) {
        await TaskReminders.initialize();
        await TaskReminders.engine.reconcile(_owner);
        capability = await TaskReminders.engine.driver.capability();
      }
      final alerts = await store.upcomingAlerts(_owner);
      final meta = await store.schedulingInfo();
      int deferred = 0;
      String? schedulerError;
      for (final row in meta) {
        if (row['key'] == 'window') {
          final window = jsonDecode(row['value'] as String);
          if (window['owner'] == _owner) deferred = window['deferred'] as int;
        }
        if (row['key'] == 'error') schedulerError = row['value'] as String;
      }
      if (mounted) {
        setState(() {
          _settings = settings;
          _alerts = alerts;
          _deferred = deferred;
          _capability = capability;
          _schedulerError = schedulerError;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Could not load notification settings. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(ReminderPreferences settings) async {
    if (_busy) return;
    setState(() => _busy = true);
    var saved = false;
    try {
      final store = ref.read(reminderPreferenceStoreProvider);
      if (settings.enabled && _settings?.enabled != true) {
        await TaskReminders.requestPermission();
      }
      await store.write(_owner, settings);
      saved = true;
      if (mounted) ref.invalidate(reminderPreferencesProvider);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not save reminder settings. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && saved) await _load();
  }

  ReminderPreferences _changed(
          {bool? enabled,
          int? lead,
          Object? dateOnly = _same,
          Object? morning = _same,
          Object? evening = _same}) =>
      ReminderPreferences(
          enabled: enabled ?? _settings!.enabled,
          leadMinutes: lead ?? _settings!.leadMinutes,
          dateOnlyTime: identical(dateOnly, _same)
              ? _settings!.dateOnlyTime
              : dateOnly as int?,
          morning:
              identical(morning, _same) ? _settings!.morning : morning as int?,
          evening:
              identical(evening, _same) ? _settings!.evening : evening as int?);
  static const _same = Object();
  String _time(int? minute) => minute == null
      ? 'Off'
      : TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);
  Future<void> _pick(int? current, ValueChanged<int?> save) async {
    final value = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
            hour: (current ?? 540) ~/ 60, minute: (current ?? 540) % 60));
    if (value != null && mounted) save(value.hour * 60 + value.minute);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
        appBar: const CustomAppBar(title: 'Notifications'),
        body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              if (_error != null) MessageBanner(_error!, isError: true),
              if (_schedulerError != null) MessageBanner(_schedulerError!),
              if (_busy) const LinearProgressIndicator(),
              if (settings != null) ...[
                SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable reminders'),
                    subtitle: const Text(
                        'For this account on this device. Task choices sync; device preferences stay here.'),
                    value: settings.enabled,
                    onChanged: _busy || !TaskReminders.supported
                        ? null
                        : (value) => _save(_changed(enabled: value))),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_capability.allowed
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined),
                    title: Text(!TaskReminders.supported
                        ? 'Mobile notifications only'
                        : _capability.allowed
                            ? 'System permission is on'
                            : 'System permission is off'),
                    subtitle: Text(_capability.exact
                        ? 'Precise alarm access available'
                        : 'Alerts are approximate until precise alarm access is enabled')),
                Wrap(spacing: 8, children: [
                  OutlinedButton(
                      onPressed:
                          TaskReminders.supported ? openAppSettings : null,
                      child: const Text('Open system settings')),
                  if (Platform.isAndroid && !_capability.exact)
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                await TaskReminders.requestExactAccess();
                                if (mounted) _load();
                              },
                        child: const Text('Allow precise alarms')),
                ]),
                const SizedBox(height: 24),
                const SectionLabel('Task defaults'),
                DropdownButtonFormField<int>(
                    key: ValueKey(settings.leadMinutes),
                    initialValue: settings.leadMinutes,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Timed tasks'),
                    items: <int>{-1, 0, 10, 30, 60, 1440, settings.leadMinutes}
                        .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(reminderLeadLabel(value))))
                        .toList(),
                    onChanged:
                        _busy ? null : (value) => _save(_changed(lead: value))),
                _timeRow('Date-only tasks', settings.dateOnlyTime,
                    (value) => _save(_changed(dateOnly: value))),
                const SizedBox(height: 24),
                const SectionLabel('Daily check-ins'),
                const Text('A gentle prompt to review your current tasks.'),
                _timeRow('Morning', settings.morning,
                    (value) => _save(_changed(morning: value))),
                _timeRow('Evening', settings.evening,
                    (value) => _save(_changed(evening: value))),
                const SizedBox(height: 24),
                const SectionLabel('Upcoming alerts'),
                const Text(
                    'Scheduled means your phone accepted the alert. Battery restrictions, system settings and force-stop can delay or prevent delivery.'),
                if (_deferred > 0)
                  MessageBanner(
                      '$_deferred later alerts are outside the current window. The next refresh adds the earliest ones that fit.'),
                const SizedBox(height: 8),
                Text(Platform.isAndroid
                    ? 'The window refreshes on app use and through an hourly background job when Android permits.'
                    : 'The window refreshes on app use and when the system allows background refresh.'),
                if (_alerts.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                          'No upcoming alerts. Choose a reminder on a scheduled task.')),
                for (final alert in _alerts)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(alert['title'] as String),
                      subtitle: Text(
                          '${_alertDate(alert)} · ${alert['status']}${alert['daily'] == 1 ? ' · repeats daily' : ''}${alert['error'] == null ? '' : '\n${alert['error']}'}'),
                      isThreeLine: alert['error'] != null),
              ],
              OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          try {
                            await TaskReminders.retrySetup();
                          } catch (_) {
                            await TaskReminders.recordError(
                                'Notification setup could not finish. Retry again or check system settings.');
                          }
                          if (mounted) _load();
                        },
                  child: const Text('Refresh and retry scheduling')),
            ])));
  }

  String _alertDate(Map<String, Object?> alert) {
    final date = DateTime.parse(alert['fire_at'] as String).toLocal();
    return '${MaterialLocalizations.of(context).formatMediumDate(date)} ${TimeOfDay.fromDateTime(date).format(context)}';
  }

  Widget _timeRow(String title, int? value, ValueChanged<int?> save) =>
      ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(_time(value)),
          onTap: _busy ? null : () => _pick(value, save),
          trailing: value == null
              ? const Icon(Icons.add_rounded)
              : IconButton(
                  tooltip: 'Turn off $title',
                  onPressed: _busy ? null : () => save(null),
                  icon: const Icon(Icons.close_rounded)));
}
