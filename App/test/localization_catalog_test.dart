import 'dart:convert';
import 'dart:io';
import 'package:agenda/l10n/app_languages.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/services/api_client.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final directory = Directory('lib/l10n');
  final template =
      jsonDecode(File('${directory.path}/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;
  final keys = template.keys.where((key) => !key.startsWith('@')).toSet();
  final files = directory.listSync().whereType<File>().where(
        (file) => file.path.endsWith('.arb'),
      );

  test('generated locales match the translation catalogs', () {
    final codes = files
        .map((file) => (jsonDecode(file.readAsStringSync()) as Map)['@@locale'])
        .toSet();
    expect(
      AppLanguages.supported.map((locale) => locale.languageCode).toSet(),
      codes,
    );
  });

  for (final file in files) {
    test('complete messages and placeholders in ${file.path}', () {
      final catalog =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(
        catalog.keys.where((key) => !key.startsWith('@')).toSet(),
        keys,
        reason: 'Every new UI message must be translated before shipping.',
      );
      for (final key in keys) {
        final message = catalog[key] as String;
        expect(message.trim(), isNotEmpty, reason: key);
        final placeholders =
            (template['@$key'] as Map?)?['placeholders'] as Map? ?? {};
        for (final name in placeholders.keys) {
          expect(
            RegExp(
              '\\{\\s*${RegExp.escape(name as String)}\\s*[,}]',
            ).hasMatch(message),
            isTrue,
            reason: '$key must retain placeholder $name',
          );
        }
      }
    });
  }

  test('Catalan plurals, diagnostics and billing are translated', () {
    final strings = lookupAppLocalizations(const Locale('ca'));
    expect(strings.captureSaveTasks(1), 'Desa 1 tasca');
    expect(strings.captureSaveTasks(3), 'Desa 3 tasques');
    expect(strings.notificationSnooze, 'Ajorna 10 min');
    expect(strings.billingStatus('active'), 'Pro està actiu');
    expect(
      strings.archiveInvalidInteger(strings.archiveField('priority'), 1, 3),
      'prioritat: valor no vàlid (1–3).',
    );
  });

  test('server errors keep their meaning without leaking raw English', () {
    expect(
        requestProblemText(lookupAppLocalizations(const Locale('ca')),
            'A list changed on another device. Choose which version to keep in Lists.'),
        contains('Tria quina versió'));
    expect(
        requestProblemText(lookupAppLocalizations(const Locale('ca')),
            ApiException(400, 'Ask the list owner for the current invitation code.')),
        contains('codi d’invitació actual'));
    final errors = <(Object, String)>[
      (
        ApiException(401, 'No active account found with the given credentials'),
        'credentials',
      ),
      (
        ApiException(401, 'Token is invalid', {'code': 'token_not_valid'}),
        'session',
      ),
      (
        ApiException(400, 'email: An account with this email already exists.', {
          'email': ['An account with this email already exists.'],
        }),
        'emailUsed',
      ),
      (
        ApiException(400, 'This password is too common.', {
          'password': ['This password is too common.'],
        }),
        'password',
      ),
      (ApiException(0, 'Cannot reach the server.'), 'network'),
      (
        ApiException(500, 'Internal database implementation details'),
        'unavailable',
      ),
      (StateError('Private internal error'), 'other'),
    ];
    for (final (error, expected) in errors) {
      expect(requestProblem(error), expected);
      for (final code in ['es', 'ca']) {
        final localized = requestProblemText(
          lookupAppLocalizations(Locale(code)),
          error,
        );
        expect(localized, isNot(error.toString()));
        expect(
          localized,
          isNot(
            lookupAppLocalizations(const Locale('en')).requestError(expected),
          ),
        );
      }
    }
  });
}
