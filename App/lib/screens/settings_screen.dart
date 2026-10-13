import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/services/capture_entries.dart';
import 'package:agenda/widgets/language_selector.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final colors = Theme.of(context).colorScheme;
    final account = ref.watch(authProvider).account;
    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.settings, isRoot: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
        children: [
          SectionLabel(context.l10n.welcomeSettings),
          Text(
            context.l10n.settings,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 28),
          ListTile(
            leading: Icon(Icons.auto_awesome_outlined, color: colors.primary),
            title: Text(context.l10n.taskflowPro),
            subtitle: Text(context.l10n.billingSettingsHelp),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.pushNamed(context, '/subscription'),
          ),
          const SizedBox(height: 16),
          SectionLabel(context.l10n.appearance),
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.chooseAppearance,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.appearanceHelp,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in [
                        (
                          ThemeMode.light,
                          Icons.light_mode_outlined,
                          context.l10n.light,
                        ),
                        (
                          ThemeMode.dark,
                          Icons.dark_mode_outlined,
                          context.l10n.dark,
                        ),
                        (
                          ThemeMode.system,
                          Icons.brightness_auto_outlined,
                          context.l10n.system,
                        ),
                      ])
                        SizedBox(
                          width: (constraints.maxWidth - 16) / 3,
                          child: Semantics(
                            selected: mode == option.$1,
                            child: Material(
                              color: mode == option.$1
                                  ? colors.primaryContainer
                                  : colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  try {
                                    await ref
                                        .read(themeModeProvider.notifier)
                                        .setMode(option.$1);
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context.l10n.appearanceError,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                    horizontal: 4,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        option.$2,
                                        color: mode == option.$1
                                            ? colors.primary
                                            : colors.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        option.$3,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: mode == option.$1
                                              ? colors.onPrimaryContainer
                                              : colors.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Icon(
                                        mode == option.$1
                                            ? Icons.check_circle_rounded
                                            : Icons.circle_outlined,
                                        size: 16,
                                        color: mode == option.$1
                                            ? colors.primary
                                            : colors.outline,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const AppSurface(
            padding: EdgeInsets.zero,
            child: LanguageSelector(key: ValueKey('settings-language')),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.language, color: colors.primary),
            title: Text(context.l10n.regionalFormats),
            subtitle: Text(context.l10n.regionalFormatsHelp),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.pushNamed(context, '/region'),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.calendar_month_outlined, color: colors.primary),
            title: Text(context.l10n.deviceCalendars),
            subtitle: Text(context.l10n.deviceCalendarHelp),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.pushNamed(context, '/deviceCalendars'),
          ),
          SectionLabel(context.l10n.yourSpace),
          AppSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.widgets_outlined, color: colors.primary),
                  title: Text(context.l10n.homeCapture),
                  subtitle: Text(context.l10n.homeCaptureHelp),
                  onTap: () async {
                    try {
                      final opened =
                          await ref.read(captureEntriesProvider).pinWidget();
                      if (!opened && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.homeCaptureInstructions),
                          ),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.widgetPickerHelp),
                          ),
                        );
                      }
                    }
                  },
                ),
                const Divider(indent: 20, endIndent: 20),
                ListTile(
                  leading: Icon(
                    Icons.import_export_rounded,
                    color: colors.primary,
                  ),
                  title: Text(context.l10n.exportImport),
                  subtitle: Text(context.l10n.exportImportHelp),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pushNamed(context, '/dataTransfer'),
                ),
                const Divider(indent: 20, endIndent: 20),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Icon(
                    Icons.notifications_outlined,
                    color: colors.primary,
                  ),
                  title: Text(context.l10n.notifications),
                  subtitle: Text(context.l10n.notificationsHelp),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pushNamed(context, '/notifications'),
                ),
                const Divider(indent: 20, endIndent: 20),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Icon(
                    Icons.person_outline_rounded,
                    color: colors.primary,
                  ),
                  title: Text(context.l10n.accountBackup),
                  subtitle: Text(
                    account?.email ?? context.l10n.signInHelp,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pushNamed(context, '/account'),
                ),
                const Divider(indent: 20, endIndent: 20),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Icon(Icons.task_alt_rounded, color: colors.primary),
                  title: Text(context.l10n.completedTasks),
                  subtitle: Text(context.l10n.progressHelp),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pushNamed(context, '/completedTasks'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.speed_rounded),
            title: Text(context.l10n.captureDiagnostics),
            subtitle: Text(context.l10n.diagnosticsHelp),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.pushNamed(context, '/captureDiagnostics'),
          ),
          TextButton(
            onPressed: () =>
                showLicensePage(context: context, applicationName: 'TaskFlow'),
            child: Text(context.l10n.licenses),
          ),
          const SizedBox(height: 16),
          Text(
            'taskflow',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium!.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.moreClarity,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
