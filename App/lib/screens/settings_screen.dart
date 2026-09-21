import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/app_components.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final colors = Theme.of(context).colorScheme;
    final account = ref.watch(authProvider).account;
    return Scaffold(
      appBar: const CustomAppBar(title: 'Settings', isRoot: true),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
          children: [
            const SectionLabel('Make yourself at home'),
            Text('Settings', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 28),
            const SectionLabel('Appearance'),
            AppSurface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Choose your appearance',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('Choose your look, or follow your device.',
                      style: TextStyle(color: colors.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                      builder: (context, constraints) =>
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final option in [
                              (
                                ThemeMode.light,
                                Icons.light_mode_outlined,
                                'Light'
                              ),
                              (
                                ThemeMode.dark,
                                Icons.dark_mode_outlined,
                                'Dark'
                              ),
                              (
                                ThemeMode.system,
                                Icons.brightness_auto_outlined,
                                'System'
                              )
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
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            onTap: () async {
                                              try {
                                                await ref
                                                    .read(themeModeProvider
                                                        .notifier)
                                                    .setMode(option.$1);
                                              } catch (_) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(const SnackBar(
                                                          content: Text(
                                                              'Could not save your appearance preference.')));
                                                }
                                              }
                                            },
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 18,
                                                        horizontal: 4),
                                                child: Column(children: [
                                                  Icon(option.$2,
                                                      color: mode == option.$1
                                                          ? colors.primary
                                                          : colors
                                                              .onSurfaceVariant),
                                                  const SizedBox(height: 10),
                                                  Text(option.$3,
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: mode ==
                                                                  option.$1
                                                              ? colors
                                                                  .onPrimaryContainer
                                                              : colors
                                                                  .onSurfaceVariant)),
                                                  const SizedBox(height: 8),
                                                  Icon(
                                                      mode == option.$1
                                                          ? Icons
                                                              .check_circle_rounded
                                                          : Icons
                                                              .circle_outlined,
                                                      size: 16,
                                                      color: mode == option.$1
                                                          ? colors.primary
                                                          : colors.outline),
                                                ]))),
                                      ))),
                          ])),
                ])),
            const SizedBox(height: 28),
            const SectionLabel('Your space'),
            AppSurface(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      leading: Icon(Icons.person_outline_rounded,
                          color: colors.primary),
                      title: const Text('Account & backup'),
                      subtitle: Text(
                          account?.email ??
                              'Sign in to keep your tasks with you',
                          overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pushNamed(context, '/account')),
                  const Divider(indent: 20, endIndent: 20),
                  ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      leading:
                          Icon(Icons.task_alt_rounded, color: colors.primary),
                      title: const Text('Completed tasks'),
                      subtitle: const Text('A little record of your progress'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () =>
                          Navigator.pushNamed(context, '/completedTasks')),
                ])),
            const SizedBox(height: 16),
            TextButton(
                onPressed: () => showLicensePage(
                    context: context, applicationName: 'TaskFlow'),
                child: const Text('Open-source licences')),
            const SizedBox(height: 16),
            Text('taskflow',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text('More clarity. More room for life.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
          ]),
    );
  }
}
