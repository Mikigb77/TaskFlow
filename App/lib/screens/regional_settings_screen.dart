import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/app_components.dart';

final _timezoneProvider = FutureProvider.autoDispose<CaptureTimezone>((ref) {
  final zone = ref.watch(regionalProvider.select((p) => p.captureTimezone));
  final accountZone =
      ref.watch(authProvider.select((a) => a.account?.timezone));
  return CaptureTimezone.resolve(RegionalPreferences(captureTimezone: zone),
      accountTimezone: accountZone);
});

class RegionalSettingsScreen extends ConsumerWidget {
  const RegionalSettingsScreen({super.key});
  Future<void> _save(
      BuildContext context, WidgetRef ref, RegionalPreferences value) async {
    try {
      await ref.read(regionalProvider.notifier).set(value);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.preferenceError)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(regionalProvider);
    final s = context.l10n;
    final zone = ref.watch(_timezoneProvider).valueOrNull;
    return Scaffold(
        appBar: CustomAppBar(title: s.regionalSettings),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          Text(s.regionHelp),
          const SizedBox(height: 24),
          _choice<String>(
              key: const ValueKey('regional-language'),
              label: s.language,
              value: p.language,
              values: {
                'system': s.deviceDefault,
                'en': 'English',
                'es': 'Español'
              },
              changed: (v) => _save(context, ref, p.withLanguage(v))),
          _choice<ClockFormat>(
              key: const ValueKey('regional-clock'),
              label: s.clockFormat,
              value: p.clock,
              values: {
                ClockFormat.system: s.deviceDefault,
                ClockFormat.twelve: s.clock12,
                ClockFormat.twentyFour: s.clock24
              },
              changed: (v) => _save(context, ref, p.withClock(v))),
          _choice<int>(
              key: const ValueKey('regional-week'),
              label: s.weekStart,
              value: p.weekStart ?? -1,
              values: {
                -1: s.deviceDefault,
                1: s.monday,
                0: s.sunday,
                6: s.saturday
              },
              changed: (v) =>
                  _save(context, ref, p.withWeekStart(v == -1 ? null : v))),
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.captureTimezone),
              subtitle: Text(p.captureTimezone ?? s.deviceDefault),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final zone = await Navigator.push<String>(context,
                    MaterialPageRoute(builder: (_) => const _TimezonePicker()));
                if (zone != null && context.mounted) {
                  await _save(
                      context,
                      ref,
                      ref
                          .read(regionalProvider)
                          .withTimezone(zone.isEmpty ? null : zone));
                }
              }),
          Text(s.timezoneHelp),
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: zone == null
                  ? const SizedBox.shrink()
                  : zone.fallback
                      ? MessageBanner(s.timezoneFallback(zone.identifier))
                      : Text(zone.identifier)),
        ]));
  }

  Widget _choice<T>(
          {required Key key,
          required String label,
          required T value,
          required Map<T, String> values,
          required ValueChanged<T> changed}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label),
            DropdownButton<T>(
                key: key,
                isExpanded: true,
                value: value,
                items: values.entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) changed(v);
                }),
          ]));
}

class _TimezonePicker extends StatefulWidget {
  const _TimezonePicker();
  @override
  State<_TimezonePicker> createState() => _TimezonePickerState();
}

class _TimezonePickerState extends State<_TimezonePicker> {
  String _query = '';
  final _zones = CaptureTimezone.identifiers;
  @override
  Widget build(BuildContext context) {
    final matches =
        _zones.where((z) => z.toLowerCase().contains(_query)).toList();
    return Scaffold(
        appBar: CustomAppBar(title: context.l10n.captureTimezone),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                      labelText: context.l10n.searchTimezone,
                      prefixIcon: const Icon(Icons.search)),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()))),
          ListTile(
              title: Text(context.l10n.deviceDefault),
              onTap: () => Navigator.pop(context, '')),
          Expanded(
              child: ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, i) => ListTile(
                      title: Text(matches[i]),
                      onTap: () => Navigator.pop(context, matches[i])))),
        ]));
  }
}
