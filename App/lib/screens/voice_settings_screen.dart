import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/app_languages.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';

/// The name of the speech language chosen in Voz, e.g. `Como la aplicación`
/// or `Català`.
String speechLanguageName(BuildContext context, String preference) =>
    preference == RegionalPreferences.sameAsApp
    ? context.l10n.sameAsApp
    : AppLanguages.nativeName(preference);

/// Ajustes › Otros ajustes › Voz: the language capture listens in, how speech
/// becomes text, and the privacy note. Kept on this device.
class VoiceSettingsScreen extends ConsumerStatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  ConsumerState<VoiceSettingsScreen> createState() =>
      _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends ConsumerState<VoiceSettingsScreen> {
  // Whether on-device speech works for the language; null while checking.
  SpeechCapability? _capability;
  // The language last checked.
  String? _checked;
  int _checks = 0;
  // The answer to `Configurar la transcripción local`.
  String? _setup;

  String _language(RegionalPreferences preferences) => speechLanguageTag(
    preferences.speechLanguage,
    app: Localizations.localeOf(context),
    devices: WidgetsBinding.instance.platformDispatcher.locales,
  );

  Future<void> _check(String language) async {
    final check = ++_checks;
    setState(() => _capability = null);
    final capability = await ref
        .read(nativeSpeechProvider)
        .capability(language: language);
    if (mounted && check == _checks) {
      setState(() => _capability = capability);
    }
  }

  Future<void> _save(RegionalPreferences value) async {
    try {
      await ref.read(regionalProvider.notifier).set(value);
    } catch (_) {
      if (mounted) {
        showFeedback(
          ScaffoldMessenger.of(context),
          context.l10n.preferenceError,
        );
      }
    }
  }

  Future<void> _setUp(String language) async {
    final l10n = context.l10n;
    bool opened;
    try {
      opened = await ref.read(nativeSpeechProvider).prepareLanguage(language);
    } catch (_) {
      opened = false;
    }
    if (mounted) {
      setState(
        () => _setup = opened
            ? l10n.voiceSetupRequested
            : l10n.voiceSetupUnavailable,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final preferences = ref.watch(regionalProvider);
    final language = _language(preferences);
    // A new language: check it once this frame is built.
    if (language != _checked) {
      _checked = language;
      _capability = null;
      _setup = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _check(language);
      });
    }
    final capability = _capability;
    final usable = capability?.usable;
    final online = preferences.speechOnline || usable == false;
    return Scaffold(
      appBar: CustomAppBar(title: l10n.voiceSettings),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(l10n.speechLanguage, style: theme.textTheme.titleSmall),
          ),
          RadioGroup<String>(
            groupValue: preferences.speechLanguage,
            onChanged: (value) {
              if (value != null) {
                _save(ref.read(regionalProvider).withSpeechLanguage(value));
              }
            },
            child: Column(
              children: [
                for (final option in [
                  RegionalPreferences.sameAsApp,
                  ...AppLanguages.displayCodes,
                ])
                  RadioListTile<String>(
                    key: ValueKey('speech-language-$option'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    value: option,
                    title: Text(speechLanguageName(context, option)),
                  ),
              ],
            ),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(l10n.speechMethod, style: theme.textTheme.titleSmall),
          ),
          RadioGroup<bool>(
            groupValue: online,
            onChanged: (value) {
              if (value != null) {
                _save(ref.read(regionalProvider).withSpeechOnline(value));
              }
            },
            child: Column(
              children: [
                RadioListTile<bool>(
                  key: const ValueKey('speech-on-device'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  value: false,
                  enabled: usable != false,
                  title: Text(l10n.onDeviceTranscript),
                ),
                RadioListTile<bool>(
                  key: const ValueKey('speech-online'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  value: true,
                  title: Text(l10n.onlineAudio),
                ),
              ],
            ),
          ),
          if (usable == false)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                l10n.onDeviceUnavailable,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          // The recognizer exists but lacks this language: it can be set up.
          if (capability != null && capability.onDevice && !capability.usable)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => _setUp(language),
                    child: Text(l10n.setUpSpeech),
                  ),
                  TextButton(
                    onPressed: () => _check(language),
                    child: Text(l10n.checkAgain),
                  ),
                ],
              ),
            ),
          if (_setup != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: MessageBanner(_setup!),
            ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              l10n.capturePrivacy,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
