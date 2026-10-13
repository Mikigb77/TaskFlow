import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/reminder_locale.dart';
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
import 'package:agenda/widgets/reminder_control.dart';

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
      final access = ref.read(reminderAccessProvider);
      final settings = await store.read(_owner);
      await access.reconcile(_owner);
      final capability = await access.capability();
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
        setState(() => _error = 'load');
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
      await store.write(_owner, settings);
      saved = true;
      if (mounted) ref.invalidate(reminderPreferencesProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'save');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && saved) await _load();
  }

  Future<void> _turnOn() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await turnOnReminders(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) await _load();
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
              identical(evening, _same) ? _settings!.evening : evening as int?,
          asked: _settings!.asked);
  static const _same = Object();
  String _time(int? minute) => minute == null
      ? context.l10n.off
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
    final access = ref.read(reminderAccessProvider);
    final supported = access.supported;
    // The status and its fixes show only when something stops reminders.
    final problem = !supported ||
        !_capability.allowed ||
        !_capability.exact ||
        _schedulerError != null ||
        _deferred > 0;
    final retry = OutlinedButton(
        onPressed: _busy
            ? null
            : () async {
                try {
                  await TaskReminders.retrySetup();
                } catch (_) {
                  await TaskReminders.recordError('setup_failed');
                }
                if (mounted) _load();
              },
        child: Text(context.l10n.retryScheduling));
    return Scaffold(
        appBar: CustomAppBar(title: context.l10n.notifications),
        body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              if (_error != null)
                MessageBanner(
                    _error == 'load'
                        ? context.l10n.notificationLoadError
                        : context.l10n.notificationSaveError,
                    isError: true),
              if (_schedulerError != null)
                MessageBanner(context.reminderDiagnostic(_schedulerError!)),
              if (_busy) const LinearProgressIndicator(),
              if (settings != null) ...[
                SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.enableReminders),
                    value: settings.enabled,
                    onChanged: _busy || !supported
                        ? null
                        : (value) => value
                            ? _turnOn()
                            : _save(_changed(enabled: false))),
                if (problem) ...[
                  if (!supported || !_capability.allowed || !_capability.exact)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.notifications_off_outlined),
                        title: Text(!supported
                            ? context.l10n.mobileNotificationsOnly
                            : !_capability.allowed
                                ? context.l10n.notificationPermissionOff
                                : context.l10n.exactAlarmsNeeded)),
                  if (_deferred > 0)
                    MessageBanner(context.l10n.deferredAlerts(_deferred)),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton(
                        onPressed: supported ? openAppSettings : null,
                        child: Text(context.l10n.openSystemSettings)),
                    if (supported && !_capability.exact)
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  await access.requestExactAccess();
                                  if (mounted) _load();
                                },
                          child: Text(context.l10n.allowPreciseAlarms)),
                    retry,
                  ]),
                ],
                const SizedBox(height: 24),
                SectionLabel(context.l10n.taskDefaults),
                DropdownButtonFormField<int>(
                    key: ValueKey(settings.leadMinutes),
                    initialValue: settings.leadMinutes,
                    isExpanded: true,
                    decoration:
                        InputDecoration(labelText: context.l10n.timedTasks),
                    items: <int>{-1, 0, 10, 30, 60, 1440, settings.leadMinutes}
                        .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(context.reminderLead(value))))
                        .toList(),
                    onChanged:
                        _busy ? null : (value) => _save(_changed(lead: value))),
                _timeRow(context.l10n.dateOnlyTasks, settings.dateOnlyTime,
                    (value) => _save(_changed(dateOnly: value))),
                const SizedBox(height: 8),
                ExpansionTile(
                    key: const ValueKey('reminder-details'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(context.l10n.details),
                    children: [
                      SectionLabel(context.l10n.dailyCheckIns),
                      Text(context.l10n.dailyCheckInsHelp),
                      _timeRow(context.l10n.morningCheckIn, settings.morning,
                          (value) => _save(_changed(morning: value))),
                      _timeRow(context.l10n.eveningCheckIn, settings.evening,
                          (value) => _save(_changed(evening: value))),
                      const SizedBox(height: 24),
                      SectionLabel(context.l10n.upcomingAlerts),
                      Text(context.l10n.scheduledAlertHelp),
                      const SizedBox(height: 8),
                      Text(_capability.exact
                          ? context.l10n.preciseAlarmsAvailable
                          : context.l10n.approximateAlarmsHelp),
                      const SizedBox(height: 8),
                      Text(Platform.isAndroid
                          ? context.l10n.androidAlertRefreshHelp
                          : context.l10n.backgroundAlertRefreshHelp),
                      if (_alerts.isEmpty)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(context.l10n.noUpcomingAlerts)),
                      for (final alert in _alerts)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(alert['daily'] == 1
                                ? ((alert['identity'] as String)
                                        .endsWith('/morning')
                                    ? context.l10n.morningCheckIn
                                    : context.l10n.eveningCheckIn)
                                : alert['title'] as String),
                            subtitle: Text(
                                '${_alertDate(alert)} · ${context.reminderStatus(alert['status'] as String)}${alert['daily'] == 1 ? ' · ${context.l10n.repeatsDaily}' : ''}${alert['error'] == null ? '' : '\n${context.reminderDiagnostic(alert['error'] as String)}'}'),
                            isThreeLine: alert['error'] != null),
                    ]),
              ],
              if (settings == null && _error != null) retry,
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
                  tooltip: context.l10n.turnOffReminder(title),
                  onPressed: _busy ? null : () => save(null),
                  icon: const Icon(Icons.close_rounded)));
}
