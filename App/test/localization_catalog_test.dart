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
    expect(strings.captureAddTasks(1), 'Afegeix 1 tasca');
    expect(strings.captureAddTasks(3), 'Afegeix 3 tasques');
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

  // ---- 2026-10-14-speed ----

  AppLocalizations strings(String code) => lookupAppLocalizations(Locale(code));

  test(
    "UX-610: diagnosticsEvent('recognizerFinish') reads 'Last words after Done' / 'Últimas palabras tras Listo' / 'Últimes paraules després de Fet'",
    () {
      expect(
        strings('en').diagnosticsEvent('recognizerFinish'),
        'Last words after Done',
      );
      expect(
        strings('es').diagnosticsEvent('recognizerFinish'),
        'Últimas palabras tras Listo',
      );
      expect(
        strings('ca').diagnosticsEvent('recognizerFinish'),
        'Últimes paraules després de Fet',
      );
    },
  );

  test(
    "U5: captureAlsoOn('X') and captureAlsoOnDays(2) read the same in EN / ES / CA as the plan's copy",
    () {
      expect(strings('en').captureAlsoOn('X'), 'also on X');
      expect(strings('es').captureAlsoOn('X'), 'también el X');
      expect(strings('ca').captureAlsoOn('X'), 'també el X');
      expect(strings('en').captureAlsoOnDays(2), 'also on 2 other days');
      expect(strings('es').captureAlsoOnDays(2), 'también en otros 2 días');
      expect(strings('ca').captureAlsoOnDays(2), 'també en 2 dies més');
      expect(strings('en').captureAlsoOnDays(1), 'also on 1 other day');
      expect(strings('es').captureAlsoOnDays(1), 'también en otro día');
      expect(strings('ca').captureAlsoOnDays(1), 'també en un altre dia');
    },
  );

  test(
    "UX-612: outside the debug-only diagnostics strings, no catalog value says 'draft', 'borrador' or 'esborrany'; captureKeepHelp and captureReviewRetainedHelp are gone",
    () {
      const debugOnly = {'diagnosticsEvent', 'diagnosticsMeasurementHelp'};
      final word = RegExp('draft|borrador|esborrany', caseSensitive: false);
      for (final code in ['en', 'es', 'ca']) {
        final catalog =
            jsonDecode(
                  File('${directory.path}/app_$code.arb').readAsStringSync(),
                )
                as Map<String, dynamic>;
        for (final MapEntry(:key, :value) in catalog.entries) {
          if (key.startsWith('@') || debugOnly.contains(key)) continue;
          expect(
            word.hasMatch(value as String),
            isFalse,
            reason: 'app_$code.arb $key: $value',
          );
        }
        expect(catalog.containsKey('captureKeepHelp'), isFalse, reason: code);
        expect(
          catalog.containsKey('captureReviewRetainedHelp'),
          isFalse,
          reason: code,
        );
      }
    },
  );

  test(
    'UX-612 / UX-605: the renamed capture copy reads as the plan wrote it, in EN / ES / CA',
    () {
      final en = strings('en');
      final es = strings('es');
      final ca = strings('ca');
      expect([en.reviewRemoved, es.reviewRemoved, ca.reviewRemoved], [
        'Removed',
        'Quitada',
        'Treta',
      ]);
      expect([en.reviewRemove, es.reviewRemove, ca.reviewRemove], [
        'Remove',
        'Quitar',
        'Treu',
      ]);
      expect([en.reviewUndoSaved, es.reviewUndoSaved, ca.reviewUndoSaved], [
        'They’re back here, not saved yet.',
        'Han vuelto aquí, sin guardar.',
        'Tornen a ser aquí, sense desar.',
      ]);
      expect(
        [
          en.captureRemovedDraftsHelp,
          es.captureRemovedDraftsHelp,
          ca.captureRemovedDraftsHelp,
        ],
        ['Nothing will be added.', 'No se añadirá nada.', 'No s’afegirà res.'],
      );
      expect(
        [en.capturesEmptyHelp, es.capturesEmptyHelp, ca.capturesEmptyHelp],
        [
          'Recordings and tasks you leave unfinished are kept here.',
          'Aquí se guardan las grabaciones y las tareas que dejes a medias.',
          'Aquí es guarden les gravacions i les tasques que deixis a mig fer.',
        ],
      );
      expect(
        [en.captureWriteFailed, es.captureWriteFailed, ca.captureWriteFailed],
        [
          'Couldn’t keep this on your phone. Try again before leaving.',
          'No se ha podido guardar en el teléfono. Inténtalo de nuevo antes de salir.',
          'No s’ha pogut conservar al telèfon. Torna-ho a provar abans de sortir.',
        ],
      );
      expect(
        [
          en.captureDraftSummary(3),
          es.captureDraftSummary(3),
          ca.captureDraftSummary(3),
        ],
        ['3 not added yet', '3 sin añadir', '3 sense afegir'],
      );
      expect(
        [
          en.captureDraftSummary(1),
          es.captureDraftSummary(1),
          ca.captureDraftSummary(1),
        ],
        ['1 not added yet', '1 sin añadir', '1 sense afegir'],
      );
      expect(
        [
          en.captureKeepQuestion,
          es.captureKeepQuestion,
          ca.captureKeepQuestion,
        ],
        [
          'Keep it for later?',
          '¿Quieres conservarlo para más tarde?',
          'Ho vols conservar per a més tard?',
        ],
      );
      expect([en.discard, es.discard, ca.discard], [
        'Discard',
        'Descartar',
        'Descarta',
      ]);
      expect([en.keep, es.keep, ca.keep], ['Keep', 'Conservar', 'Conserva']);
    },
  );
}
