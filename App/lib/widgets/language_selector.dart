import 'dart:async';

import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/l10n/app_languages.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/services/app_language.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showLanguageSelector(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _LanguageSheet(),
    );

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(regionalProvider);
    final language = preferences
        .localeFor(WidgetsBinding.instance.platformDispatcher.locales)
        .languageCode;
    final name = AppLanguages.nativeName(language);
    return ListTile(
      leading: Icon(
        Icons.translate_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(context.l10n.language),
      subtitle: Text(
        preferences.language == AppLanguages.system
            ? context.l10n.languageFollowing(name)
            : name,
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showLanguageSelector(context),
    );
  }
}

class _LanguageSheet extends ConsumerStatefulWidget {
  const _LanguageSheet();
  @override
  ConsumerState<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends ConsumerState<_LanguageSheet> {
  bool _saving = false;

  Future<void> _choose(String language) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(regionalProvider.notifier)
          .set(ref.read(regionalProvider).withLanguage(language));
      // The sheet closes once the language is saved. The widget, the
      // shortcuts and the share messages (Android 13+) and the reminders
      // follow afterwards; each records its own errors.
      if (mounted) Navigator.pop(context);
      unawaited(AppLanguageBridge.apply(language));
      unawaited(TaskReminders.refreshLanguage());
    } catch (_) {
      if (mounted) {
        showFeedback(
          ScaffoldMessenger.of(context),
          context.l10n.preferenceError,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(regionalProvider);
    final strings = context.l10n;
    // Under a per-app language, Flutter's locales are the app's, not the phone's.
    final automatic = AppLanguages.nativeName(
      AppLanguages.resolve(
        AppLanguages.system,
        AppLanguageBridge.phoneOr(
          WidgetsBinding.instance.platformDispatcher.locales,
        ),
      ).languageCode,
    );
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
                strings.language,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            RadioGroup<String>(
              groupValue: preferences.language,
              onChanged: (value) {
                if (value != null) {
                  _choose(value);
                } else if (!_saving) {
                  Navigator.pop(context);
                }
              },
              child: Column(
                children: [
                  for (final code in [
                    AppLanguages.system,
                    ...AppLanguages.displayCodes,
                  ])
                    RadioListTile<String>(
                      key: ValueKey('language-$code'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      value: code,
                      toggleable: true,
                      enabled: !_saving,
                      title: Text(
                        code == AppLanguages.system
                            ? strings.languageAutomatic
                            : AppLanguages.nativeName(code),
                      ),
                      subtitle: code == AppLanguages.system
                          ? Text(automatic)
                          : null,
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
