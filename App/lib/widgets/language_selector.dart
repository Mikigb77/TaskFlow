import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/l10n/app_languages.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/regional_provider.dart';
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
      await TaskReminders.refreshLanguage();
      if (mounted) Navigator.pop(context);
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
    final colors = Theme.of(context).colorScheme;
    final automatic = AppLanguages.nativeName(
      AppLanguages.resolve(
        AppLanguages.system,
        WidgetsBinding.instance.platformDispatcher.locales,
      ).languageCode,
    );
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.language,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.languageHelp,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            for (final code in [
              AppLanguages.system,
              ...AppLanguages.displayCodes,
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  selected: preferences.language == code,
                  child: Material(
                    color: preferences.language == code
                        ? colors.primaryContainer
                        : colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      key: ValueKey('language-$code'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                      title: Text(
                        code == AppLanguages.system
                            ? strings.languageAutomatic
                            : AppLanguages.nativeName(code),
                      ),
                      subtitle: code == AppLanguages.system
                          ? Text(automatic)
                          : null,
                      trailing: preferences.language == code
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: colors.primary,
                            )
                          : null,
                      enabled: !_saving,
                      onTap: () => _choose(code),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
