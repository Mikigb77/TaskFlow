import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/text_search.dart';

final _timezoneProvider = FutureProvider.autoDispose<CaptureTimezone>((ref) {
  final zone = ref.watch(regionalProvider.select((p) => p.captureTimezone));
  final accountZone = ref.watch(
    authProvider.select((a) => a.account?.timezone),
  );
  return CaptureTimezone.resolve(
    RegionalPreferences(captureTimezone: zone),
    accountTimezone: accountZone,
  );
});

class RegionalSettingsScreen extends ConsumerWidget {
  const RegionalSettingsScreen({super.key});
  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    RegionalPreferences value,
  ) async {
    try {
      await ref.read(regionalProvider.notifier).set(value);
      await TaskReminders.refreshLanguage();
    } catch (_) {
      if (context.mounted) {
        showFeedback(
          ScaffoldMessenger.of(context),
          context.l10n.preferenceError,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(regionalProvider);
    final s = context.l10n;
    final zone = ref.watch(_timezoneProvider).valueOrNull;
    return Scaffold(
      appBar: CustomAppBar(title: s.regionalFormats),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(s.regionHelp),
          const SizedBox(height: 24),
          _choice<ClockFormat>(
            key: const ValueKey('regional-clock'),
            label: s.clockFormat,
            value: p.clock,
            values: {
              ClockFormat.system: s.deviceDefault,
              ClockFormat.twelve: s.clock12,
              ClockFormat.twentyFour: s.clock24,
            },
            changed: (v) => _save(context, ref, p.withClock(v)),
          ),
          _choice<int>(
            key: const ValueKey('regional-week'),
            label: s.weekStart,
            value: p.weekStart ?? -1,
            values: {
              -1: s.deviceDefault,
              1: s.monday,
              0: s.sunday,
              6: s.saturday,
            },
            changed: (v) =>
                _save(context, ref, p.withWeekStart(v == -1 ? null : v)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.timeZone),
            subtitle: Text(
              p.captureTimezone == null
                  ? s.deviceDefault
                  : timeZoneName(p.captureTimezone!),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final zone = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => const _TimezonePicker()),
              );
              if (zone != null && context.mounted) {
                await _save(
                  context,
                  ref,
                  ref
                      .read(regionalProvider)
                      .withTimezone(zone.isEmpty ? null : zone),
                );
              }
            },
          ),
          Text(s.timezoneHelp),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: zone == null
                ? const SizedBox.shrink()
                : zone.fallback
                ? MessageBanner(
                    s.timezoneFallback(timeZoneName(zone.identifier)),
                  )
                : Text(timeZoneName(zone.identifier)),
          ),
        ],
      ),
    );
  }

  Widget _choice<T>({
    required Key key,
    required String label,
    required T value,
    required Map<T, String> values,
    required ValueChanged<T> changed,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        DropdownButton<T>(
          key: key,
          isExpanded: true,
          value: value,
          items: values.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            if (v != null) changed(v);
          },
        ),
      ],
    ),
  );
}

class _TimezonePicker extends StatefulWidget {
  const _TimezonePicker();
  @override
  State<_TimezonePicker> createState() => _TimezonePickerState();
}

/// Old names kept in the tz database for compatibility, such as `US/Pacific`
/// for `America/Los_Angeles`. The list hides them so `Pacific` isn't listed
/// twice; a zone already stored under one still shows as the current one.
const _legacyAreas = {'US', 'Canada', 'Brazil', 'Chile', 'Mexico', 'Etc'};

bool _listedZone(String id) => id.contains('/')
    ? !_legacyAreas.contains(id.split('/').first)
    : id == 'UTC';

/// Spanish and Catalan names of commonly searched cities, so `Londres` or
/// `Nova York` find their zone. Some are another city in the same zone, such
/// as `Pekín` for Shanghai; a row found by one shows it under the tz city.
const _cityAliases = <String, List<String>>{
  // Europe
  'Europe/London': ['Londres'],
  'Europe/Paris': ['París'],
  'Europe/Berlin': ['Berlín'],
  'Europe/Rome': ['Roma'],
  'Europe/Lisbon': ['Lisboa'],
  'Europe/Brussels': ['Bruselas', 'Brussel·les'],
  'Europe/Amsterdam': ['Ámsterdam'],
  'Europe/Vienna': ['Viena'],
  'Europe/Athens': ['Atenas', 'Atenes'],
  'Europe/Warsaw': ['Varsovia', 'Varsòvia'],
  'Europe/Prague': ['Praga'],
  'Europe/Stockholm': ['Estocolmo', 'Estocolm'],
  'Europe/Copenhagen': ['Copenhague', 'Copenhaguen'],
  'Europe/Moscow': ['Moscú', 'Moscou'],
  'Europe/Dublin': ['Dublín'],
  'Europe/Zurich': ['Zúrich', 'Zuric'],
  'Europe/Bucharest': ['Bucarest'],
  'Europe/Kyiv': ['Kiev', 'Kíiv'],
  'Europe/Istanbul': ['Estambul'],
  'Europe/Belgrade': ['Belgrado'],
  'Europe/Luxembourg': ['Luxemburgo', 'Luxemburg'],
  'Europe/Monaco': ['Mónaco', 'Mònaco'],
  'Atlantic/Canary': ['Canarias', 'Canàries', 'Las Palmas', 'Tenerife'],
  'Atlantic/Azores': ['Azores', 'Açores'],
  // The Americas
  'America/New_York': ['Nueva York', 'Nova York'],
  'America/Los_Angeles': ['Los Ángeles'],
  'America/Phoenix': ['Fénix'],
  'America/Mexico_City': ['Ciudad de México', 'Ciutat de Mèxic'],
  'America/Havana': ['La Habana', 'l’Havana'],
  'America/Panama': ['Panamá'],
  'America/Puerto_Rico': ['San Juan'],
  'America/Costa_Rica': ['San José'],
  'America/Guatemala': ['Ciudad de Guatemala', 'Ciutat de Guatemala'],
  'America/Guayaquil': ['Quito'],
  'America/Santiago': ['Santiago de Chile', 'Santiago de Xile'],
  'America/Asuncion': ['Asunción'],
  'America/Sao_Paulo': ['São Paulo'],
  'Pacific/Honolulu': ['Honolulú', 'Hawái'],
  // Asia
  'Asia/Tokyo': ['Tokio', 'Tòquio'],
  'Asia/Shanghai': ['Shanghái', 'Xangai', 'Pekín', 'Pequín', 'Beijing'],
  'Asia/Seoul': ['Seúl', 'Seül'],
  'Asia/Singapore': ['Singapur'],
  'Asia/Kolkata': ['Calcuta', 'Nueva Delhi', 'Nova Delhi', 'Bombay'],
  'Asia/Dubai': ['Dubái'],
  'Asia/Jerusalem': ['Jerusalén', 'Tel Aviv'],
  'Asia/Tehran': ['Teherán'],
  'Asia/Riyadh': ['Riad'],
  'Asia/Jakarta': ['Yakarta'],
  'Asia/Taipei': ['Taipéi'],
  // Africa
  'Africa/Cairo': ['El Cairo', 'el Caire'],
  'Africa/Johannesburg': ['Johannesburgo', 'Ciudad del Cabo', 'Ciutat del Cap'],
  'Africa/Algiers': ['Argel', 'Alger'],
  'Africa/Tunis': ['Túnez'],
  // Oceania
  'Australia/Sydney': ['Sídney'],
  'Pacific/Auckland': ['Nueva Zelanda', 'Nova Zelanda'],
};

class _TimezonePickerState extends State<_TimezonePicker> {
  String _query = '';
  final _zones = CaptureTimezone.identifiers.where(_listedZone).toList();
  @override
  Widget build(BuildContext context) {
    // The city, the id or one of its Spanish and Catalan names, so `Bogotá`
    // finds Bogota, `Londres` finds London and `America` still lists the
    // continent. A zone found only by a name shows that name under its city.
    final matches = <({String zone, String? alias})>[];
    for (final z in _zones) {
      if (matchesSearch('${timeZoneName(z)} $z', _query)) {
        matches.add((zone: z, alias: null));
        continue;
      }
      final alias = _cityAliases[z]
          ?.where((a) => matchesSearch(a, _query))
          .firstOrNull;
      if (alias != null) matches.add((zone: z, alias: alias));
    }
    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.timeZone),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.l10n.searchTimezone,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          ListTile(
            title: Text(context.l10n.deviceDefault),
            onTap: () => Navigator.pop(context, ''),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: matches.length,
              itemBuilder: (context, i) {
                final (:zone, :alias) = matches[i];
                return ListTile(
                  title: Text(timeZoneName(zone)),
                  subtitle: alias == null ? null : Text(alias),
                  onTap: () => Navigator.pop(context, zone),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
