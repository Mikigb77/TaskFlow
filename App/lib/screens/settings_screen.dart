import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/reminder_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/language_selector.dart';

/// Six rows, in the order people need them; the rare ones wait in
/// Other settings.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  /// Whether the phone lets reminders through; null until it answers.
  bool? _allowed;

  /// Whether they can come on time («Alarms & reminders»); null until known.
  bool? _exact;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _readAccess();
  }

  Future<void> _readAccess() async {
    try {
      final capability = await ref.read(reminderAccessProvider).capability();
      if (mounted) {
        setState(() {
          _allowed = capability.allowed;
          _exact = capability.exact;
        });
      }
    } catch (_) {
      // Keep the last answer; the Reminders screen explains any problem.
    }
  }

  Future<void> _openReminders() async {
    await Navigator.pushNamed(context, '/notifications');
    if (mounted) _readAccess();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final email = ref.watch(authProvider).account?.email;
    final reminders = ref.watch(reminderPreferencesProvider).valueOrNull;
    // The plan, as the other rows show their value: Pro, or the free
    // dictations left; nothing until billing and the account answer.
    final freeLeft = ref.watch(freeVoiceLeftProvider);
    final plan = ref.watch(hasProProvider)
        ? context.l10n.billingStatus('active')
        : ref.watch(billingLoadingProvider) || freeLeft == null
        ? null
        : context.l10n.freeVoiceLeft(freeLeft);
    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.settings, isRoot: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          ListTile(
            leading: Icon(Icons.notifications_outlined, color: colors.primary),
            title: Text(context.l10n.reminders),
            subtitle: reminders == null
                ? null
                : reminders.enabled && _allowed == false
                ? Row(
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 18,
                        color: colors.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          context.l10n.remindersBlocked,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ],
                  )
                : Text(
                    !reminders.enabled
                        ? context.l10n.remindersOff
                        : _exact == false
                        ? context.l10n.remindersOnLate
                        : context.l10n.remindersOnLead(
                            context.reminderLead(reminders.leadMinutes),
                          ),
                  ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _openReminders,
          ),
          const LanguageSelector(key: ValueKey('settings-language')),
          ListTile(
            leading: Icon(Icons.contrast_rounded, color: colors.primary),
            title: Text(context.l10n.appearance),
            subtitle: Text(
              _appearanceName(context, ref.watch(themeModeProvider)),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _chooseAppearance(context),
          ),
          ListTile(
            leading: Icon(Icons.person_outline_rounded, color: colors.primary),
            title: Text(context.l10n.account),
            subtitle: email == null
                ? null
                : Text(email, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.pushNamed(context, '/account'),
          ),
          ListTile(
            leading: Icon(Icons.auto_awesome_outlined, color: colors.primary),
            title: Text(context.l10n.taskflowPro),
            subtitle: plan == null ? null : Text(plan),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.pushNamed(context, '/subscription'),
          ),
          ListTile(
            leading: Icon(Icons.tune_rounded, color: colors.primary),
            title: Text(context.l10n.otherSettings),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.pushNamed(context, '/otherSettings'),
          ),
        ],
      ),
    );
  }
}

String _appearanceName(BuildContext context, ThemeMode mode) => switch (mode) {
  ThemeMode.light => context.l10n.light,
  ThemeMode.dark => context.l10n.dark,
  ThemeMode.system => context.l10n.deviceDefault,
};

/// The one place to choose light or dark: full-width rows, so each name
/// keeps its line at large text on a small phone.
Future<void> _chooseAppearance(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _AppearanceSheet(),
    );

class _AppearanceSheet extends ConsumerWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                context.l10n.appearance,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: (value) async {
                if (value == null) {
                  Navigator.pop(context);
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                final strings = context.l10n;
                Navigator.pop(context);
                try {
                  await ref.read(themeModeProvider.notifier).setMode(value);
                } catch (_) {
                  showFeedback(messenger, strings.appearanceError);
                }
              },
              child: Column(
                children: [
                  for (final option in const [
                    ThemeMode.light,
                    ThemeMode.dark,
                    ThemeMode.system,
                  ])
                    RadioListTile<ThemeMode>(
                      key: ValueKey('appearance-${option.name}'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      value: option,
                      toggleable: true,
                      title: Text(_appearanceName(context, option)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
