import 'dart:convert';
import 'dart:io';
import 'package:agenda/l10n/app_languages.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/task.dart';
import 'package:flutter/material.dart';
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
        ['Nothing will change.', 'No se hará ningún cambio.', 'No es farà cap canvi.'],
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
          'Keep what you said for later?',
          '¿Conservar lo que has dicho para más tarde?',
          'Vols conservar el que has dit per a més tard?',
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

  test(
    'UX-225: no catalog value keeps the Lista → Proyecto rename slips',
    () {
      final slip = RegExp(
        'Proyecto de pasos|Projecte de passos|proyecto compartida',
        caseSensitive: false,
      );
      for (final file in files) {
        final catalog =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        for (final MapEntry(:key, :value) in catalog.entries) {
          if (key.startsWith('@')) continue;
          expect(
            slip.hasMatch(value as String),
            isFalse,
            reason: '${file.path} $key: $value',
          );
        }
      }
    },
  );

  // ---- Round 1 · P22 · UX-225, UX-122, UX-123: Spanish and Catalan slips ----

  test('UX-225: in Spanish, agendaCounts(1, 1) reads 1 pendiente · 1 completada',
      () {
    final es = lookupAppLocalizations(const Locale('es'));
    expect(es.agendaCounts(1, 1), '1 pendiente · 1 completada');
    expect(es.agendaCounts(0, 1), '0 pendientes · 1 completada');
    expect(es.agendaCounts(2, 3), '2 pendientes · 3 completadas');
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(ca.agendaCounts(1, 1), isNot(contains('1 completades')));
  });

  for (final (language, one, two) in [
    ('es', 'Cada semana', 'Cada 2 semanas'),
    ('ca', 'Cada setmana', 'Cada 2 setmanes'),
    ('en', 'Every week', 'Every 2 weeks'),
  ]) {
    testWidgets(
        'UX-225: a weekly repeat with weekdays reads $one · …, never Cada 1 semanas ($language)',
        (tester) async {
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(builder: (c) {
            context = c;
            return const SizedBox();
          })));
      await tester.pumpAndSettle();
      Task weekly(int interval) => Task(
          title: 'Correr',
          priority: 1,
          dueDate: DateTime(2026, 10, 12),
          recurrence: 'weekly',
          repeatInterval: interval,
          repeatWeekdays: const [1, 3]);
      final label = context.repeatLabel(weekly(1));
      expect(label, startsWith('$one · '));
      expect(label, isNot(contains(' 1 ')));
      expect(context.repeatLabel(weekly(2)), startsWith('$two · '));
      if (language == 'es') {
        expect(label, 'Cada semana · lun, mié');
      }
    });
  }

  test('UX-225: Lista de pasos is the one Spanish name for a checklist', () {
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(es.checklist, 'Lista de pasos');
    expect(es.checklistSemantics(1, 3), 'Lista de pasos, 1 de 3 completados');
    expect(ca.checklist, 'Llista de passos');
    expect(ca.checklistSemantics(1, 3), startsWith('Llista de passos'));
    expect(es.notesEmptyHelp, isNot(contains('verificación')));
  });

  test('UX-225: a project is masculine in Spanish and Catalan', () {
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(es.archived, 'Archivado');
    expect(ca.archived, 'Arxivat');
    expect(es.archivedListHelp, startsWith('Archivado'));
    expect(ca.archivedListHelp, startsWith('Arxivat'));
    expect(ca.listConflict, startsWith('Modificat'));
  });

  test('UX-122: the Catalan review buttons are imperatives', () {
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(ca.reviewEditDetail, 'Canvia aquesta dada');
    expect(ca.reviewRepair, 'Corregeix el text');
    expect(ca.reviewRemove, startsWith('Treu'));
    // No review button starts with an infinitive (Desar, Canviar, Treure…).
    final infinitive = RegExp(r'^\S+(ar|er|re|ir)$');
    for (final label in [
      ca.reviewEditDetail,
      ca.reviewRepair,
      ca.reviewRemove,
      ca.reviewOriginal,
      ca.reviewResolve,
      ca.reviewOptions,
    ]) {
      final first = label.split(RegExp(r'[\s’]')).first;
      expect(infinitive.hasMatch(first), isFalse, reason: label);
    }
  });

  test('UX-123: captureKeptForReview has plurals in English and Catalan', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(ca.captureKeptForReview(1), '1 pendent de revisar');
    expect(ca.captureKeptForReview(3), '3 pendents de revisar');
    expect(en.captureKeptForReview(1), '1 kept for review');
    expect(en.captureKeptForReview(3), '3 kept for review');
    expect(es.captureKeptForReview(1), '1 pendiente de revisar');
  });

  // ---- Round 1 (b9) · P43 (U11): no Bandeja, captura or Inbox ----

  // Developer and staging strings keep their technical words.
  const technical = {
    'captureDiagnostics',
    'diagnosticsHelp',
    'diagnosticsEvent',
    'diagnosticsMeasurementHelp',
    'billingTestMode',
  };

  /// Keys of [language]'s catalog whose user-facing text matches [banned].
  List<String> offending(String language, RegExp banned) {
    final catalog = jsonDecode(
      File('${directory.path}/app_$language.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    return [
      for (final entry in catalog.entries)
        if (!entry.key.startsWith('@') &&
            !technical.contains(entry.key) &&
            entry.value is String &&
            banned.hasMatch(entry.value as String))
          '${entry.key}: ${entry.value}',
    ];
  }

  test(
    'U11: the Spanish catalog has no Bandeja, Capturas pendientes, captura or Lista para cuando in user-facing text',
    () {
      expect(
        offending('es', RegExp(r'Bandeja|Capturas pendientes|captura|Lista para cuando', caseSensitive: false)),
        isEmpty,
      );
    },
  );

  test('U11: the English catalog has no Inbox or capture in user-facing text', () {
    expect(offending('en', RegExp(r'inbox|captur', caseSensitive: false)), isEmpty);
  });

  test('U11: the Catalan catalog has no Safata or captura in user-facing text', () {
    expect(offending('ca', RegExp(r'safata|captura', caseSensitive: false)), isEmpty);
  });

  test('U11: Sin fecha, Sin proyecto and Sin guardar read as decided in each language', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    for (final (l, inbox, count, saved, moved, noList, notSaved, notSavedCount, remove) in [
      (en, 'No date', 'No date · 2', 'Added with no date', 'Date removed', 'No project', 'Not saved yet', 'Not saved yet · 1', 'Remove'),
      (es, 'Sin fecha', 'Sin fecha · 2', 'Añadida sin fecha', 'Se ha quitado la fecha', 'Sin proyecto', 'Sin guardar', 'Sin guardar · 1', 'Quitar'),
      (ca, 'Sense data', 'Sense data · 2', 'Afegida sense data', 'S’ha tret la data', 'Sense projecte', 'Sense desar', 'Sense desar · 1', 'Treu'),
    ]) {
      expect(l.inbox, inbox);
      expect(l.inboxCount(2), count);
      expect(l.taskSavedInbox, saved);
      expect(l.movedInbox, moved);
      expect(l.noList, noList);
      expect(l.unfinishedCaptures, notSaved);
      expect(l.pendingCaptureCount(1), notSavedCount);
      expect(l.reviewRemove, remove);
    }
    expect(es.inboxEmpty, startsWith('Las tareas sin fecha esperan aquí hasta que elijas una.'));
    expect(en.inboxEmpty, startsWith('Tasks without a date wait here until you choose one.'));
    expect(ca.inboxEmpty, startsWith('Les tasques sense data esperen aquí fins que en triïs una.'));
    expect(es.checkCaptures, 'Ver lo que falta por guardar');
    expect(ca.checkCaptures, 'Mostra el que falta per desar');
    expect(en.checkCaptures, 'See what’s not saved yet');
    expect(es.sharedCaptureRetained,
        'Lo que has compartido se ha conservado. Vuelve a abrir TaskFlow para intentarlo de nuevo.');
    expect(en.sharedCaptureRetained, 'What you shared is kept. Open TaskFlow again to try again.');
    expect(ca.sharedCaptureRetained,
        'El que has compartit s’ha conservat. Torna a obrir TaskFlow per tornar-ho a provar.');
    expect(es.capturePrivacy,
        endsWith('Lo que aún no has guardado se queda en este teléfono hasta que lo guardes o lo descartes.'));
    expect(en.capturePrivacy,
        endsWith('Anything not saved yet stays on this phone until you save or discard it.'));
    expect(ca.capturePrivacy,
        endsWith('El que encara no has desat es queda en aquest telèfon fins que ho desis o ho descartis.'));
    // retryCaptures is gone; the Sin guardar list retries with tryAgain.
    expect(keys.contains('retryCaptures'), isFalse);
  });

  test('P25–P27: the new Projects, Groups and Activity copy reads as the plan wrote it in EN / ES / CA', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    // The catalogs write apostrophes as ’; the plan's straight ones match.
    String plain(String text) => text.replaceAll('’', "'");
    for (final (l, expected) in [
      (en, [
        'Group activity', 'Unread', 'Pinned', 'Shared · Editor', 'Everyone in Máster will see it.',
        'Create group', 'Next', 'Enter a name.', 'What can Ana do?',
        "Couldn't load. Check your connection.", 'Invited', 'Pending', 'Name for voice assignments',
      ]),
      (es, [
        'Actividad del grupo', 'No leída', 'Fijado', 'Compartido · Editor', 'Todos en Máster lo verán.',
        'Crear grupo', 'Siguiente', 'Escribe un nombre.', '¿Qué puede hacer Ana?',
        'No se ha podido cargar. Revisa la conexión.', 'Invitados', 'Pendiente', 'Nombre para asignarte por voz',
      ]),
      (ca, [
        'Activitat del grup', 'No llegida', 'Fixat', 'Compartit · Editor', 'Tothom a Máster el veurà.',
        'Crea el grup', 'Següent', 'Escriu un nom.', 'Què pot fer Ana?',
        "No s'ha pogut carregar. Revisa la connexió.", 'Convidats', 'Pendent', 'Nom per assignar-te per veu',
      ]),
    ]) {
      final actual = [
        l.groupActivity, l.activityUnread, l.projectPinned, l.projectSharedRole('Editor'),
        l.projectGroupSees('Máster'), l.createGroup, l.nextStep, l.enterName,
        l.groupRoleQuestion('Ana'), l.loadFailed, l.groupInvited, l.invitationPending, l.groupVoiceName,
      ].map(plain).toList();
      expect(actual, expected, reason: l.localeName);
    }
  });

  // ---- Run 2026-10-18-commands, round 1 (P128, P129, P132) ----

  Map<String, dynamic> catalog(String code) =>
      jsonDecode(File('${directory.path}/app_$code.arb').readAsStringSync())
          as Map<String, dynamic>;

  test('UX-905 and UX-1208: commandApply, saveChanges and '
      'deleteAccountThrottledWait are gone from all three catalogs', () {
    for (final code in ['en', 'es', 'ca']) {
      final arb = catalog(code);
      for (final gone in [
        'commandApply',
        'saveChanges',
        'deleteAccountThrottledWait',
      ]) {
        expect(arb.containsKey(gone), isFalse, reason: '$gone in $code');
        expect(arb.containsKey('@$gone'), isFalse, reason: '@$gone in $code');
      }
    }
  });

  test('UX-903, UX-905, UX-902 and UX-1208: every new key is in all three '
      'catalogs, described in English, with the plan’s copy', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    final added = [
      'commandDontDelete',
      'commandDontChange',
      'commandDontCreate',
      'commandWontDelete',
      'commandWontChange',
      'commandWontCreate',
      'captureKeepTextQuestion',
      'commandAddAndChange',
      'commandAddAndDelete',
      'commandChangeAndDelete',
      'commandAddChangeAndDelete',
      'taskAddedDue',
      'tooManyTriesWait',
    ];
    for (final code in ['en', 'es', 'ca']) {
      final arb = catalog(code);
      for (final key in added) {
        expect(arb.containsKey(key), isTrue, reason: '$key in $code');
      }
    }
    final english = catalog('en');
    for (final key in added) {
      final description =
          (english['@$key'] as Map<String, dynamic>?)?['description'];
      expect(description, isA<String>(), reason: '@$key');
      expect((description as String).trim(), isNotEmpty, reason: '@$key');
    }
    String all(String Function(AppLocalizations l) text) =>
        [en, es, ca].map(text).join(' / ');
    expect(
      all((l) => l.commandDontDelete('Dentista')),
      'Don’t delete Dentista / No eliminar Dentista / No suprimeixis Dentista',
    );
    expect(
      all((l) => l.commandDontChange('Informe')),
      'Don’t change Informe / No cambiar Informe / No canviïs Informe',
    );
    expect(
      all((l) => l.commandDontCreate('Física')),
      'Don’t create Física / No crear Física / No creïs Física',
    );
    expect(
      all((l) => l.commandWontDelete),
      'Won’t be deleted / No se eliminará / No es suprimirà',
    );
    expect(
      all((l) => l.commandWontChange),
      'Won’t be changed / No se cambiará / No es canviarà',
    );
    expect(
      all((l) => l.commandWontCreate),
      'Won’t be created / No se creará / No es crearà',
    );
    expect(
      all((l) => l.captureKeepQuestion),
      'Keep what you said for later? / ¿Conservar lo que has dicho para '
      'más tarde? / Vols conservar el que has dit per a més tard?',
    );
    expect(
      all((l) => l.captureKeepTextQuestion),
      'Keep the text for later? / ¿Conservar el texto para más tarde? / '
      'Vols conservar el text per a més tard?',
    );
    expect(
      all((l) => l.captureRemovedDraftsHelp),
      'Nothing will change. / No se hará ningún cambio. / '
      'No es farà cap canvi.',
    );
    expect(
      all((l) => l.commandAddAndChange),
      'Add and change / Añadir y cambiar / Afegeix i canvia',
    );
    expect(
      all((l) => l.commandAddAndDelete),
      'Add and delete / Añadir y eliminar / Afegeix i suprimeix',
    );
    expect(
      all((l) => l.commandChangeAndDelete),
      'Change and delete / Cambiar y eliminar / Canvia i suprimeix',
    );
    expect(
      all((l) => l.commandAddChangeAndDelete),
      'Add, change and delete / Añadir, cambiar y eliminar / '
      'Afegeix, canvia i suprimeix',
    );
    expect(
      all((l) => l.taskAddedDue('jue, 12 nov')),
      'Added · due jue, 12 nov / Añadida · vence el jue, 12 nov / '
      'Afegida · venç el jue, 12 nov',
    );
    expect(
      all((l) => l.tooManyTriesWait(1)),
      'Too many tries. Wait a minute and try again. / Demasiados intentos. '
      'Espera un minuto y vuelve a intentarlo. / Massa intents. Espera un '
      'minut i torna-ho a provar.',
    );
    expect(
      all((l) => l.tooManyTriesWait(15)),
      'Too many tries. Wait 15 minutes and try again. / Demasiados '
      'intentos. Espera 15 minutos y vuelve a intentarlo. / Massa intents. '
      'Espera 15 minuts i torna-ho a provar.',
    );
  });
}
