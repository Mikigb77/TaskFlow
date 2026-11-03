import 'package:agenda/l10n/region.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/screens/voice_settings_screen.dart';
import 'package:agenda/services/capture_entries.dart';
import 'package:agenda/services/site_links.dart';
import 'package:agenda/widgets/custom_app_bar.dart';

/// Version and build, e.g. `1.0.5 (4007)`.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// Settings people rarely change, kept out of the main list.
class OtherSettingsScreen extends ConsumerWidget {
  const OtherSettingsScreen({
    super.key,
    this.debug = kDebugMode,
    this.staging = const String.fromEnvironment('APP_ENV') == 'staging',
  });

  /// Debug builds list Capture diagnostics; staging builds keep it, with
  /// the server address, behind a long-press on the version line.
  final bool debug;
  final bool staging;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final version = ref.watch(appVersionProvider).value;
    final speechLanguage = ref.watch(
      regionalProvider.select((p) => p.speechLanguage),
    );
    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.otherSettings),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          ListTile(
            leading: Icon(Icons.schedule_rounded, color: colors.primary),
            title: Text(context.l10n.regionalFormats),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.pushNamed(context, '/region'),
          ),
          ListTile(
            leading: Icon(Icons.mic_none_rounded, color: colors.primary),
            title: Text(context.l10n.voiceSettings),
            subtitle: Text(speechLanguageName(context, speechLanguage)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.pushNamed(context, '/voiceSettings'),
          ),
          ListTile(
            leading: Icon(Icons.calendar_month_outlined, color: colors.primary),
            title: Text(context.l10n.deviceCalendars),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.pushNamed(context, '/deviceCalendars'),
          ),
          ListTile(
            leading: Icon(Icons.widgets_outlined, color: colors.primary),
            title: Text(context.l10n.homeCapture),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              try {
                final opened = await ref
                    .read(captureEntriesProvider)
                    .pinWidget();
                if (!opened && context.mounted) {
                  _showWidgetHelp(
                    context,
                    context.l10n.homeCaptureInstructions,
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  _showWidgetHelp(context, context.l10n.widgetPickerHelp);
                }
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.import_export_rounded, color: colors.primary),
            title: Text(context.l10n.exportImport),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.pushNamed(context, '/dataTransfer'),
          ),
          ListTile(
            leading: Icon(Icons.description_outlined, color: colors.primary),
            title: Text(context.l10n.licenses),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'TaskFlow',
              applicationVersion: version,
            ),
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: colors.primary),
            title: Text(context.l10n.privacyPolicy),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => openSitePage(context, ref, SitePage.privacy),
          ),
          ListTile(
            leading: Icon(Icons.gavel_outlined, color: colors.primary),
            title: Text(context.l10n.termsAndConditions),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => openSitePage(context, ref, SitePage.terms),
          ),
          if (debug)
            ListTile(
              leading: const Icon(Icons.speed_rounded),
              title: Text(context.l10n.captureDiagnostics),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pushNamed(context, '/captureDiagnostics'),
            ),
          if (version != null)
            GestureDetector(
              key: const ValueKey('app-version'),
              onLongPress: staging ? () => _showDeveloperTools(context) : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Text(
                  context.l10n.appVersion(version),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void _showDeveloperTools(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => Consumer(
    builder: (context, ref, _) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.speed_rounded),
              title: Text(context.l10n.captureDiagnostics),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context)
                ..pop()
                ..pushNamed('/captureDiagnostics'),
            ),
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: Text(context.l10n.connectionDetails),
              subtitle: SelectableText(ref.read(apiClientProvider).baseUrl),
            ),
          ],
        ),
      ),
    ),
  ),
);

/// Instructions are too long to read before a snackbar times out, so they
/// stay until the user closes them.
void _showWidgetHelp(BuildContext context, String text) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(text, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.done),
              ),
            ],
          ),
        ),
      ),
    );
