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
      requestProblemText(
        lookupAppLocalizations(const Locale('ca')),
        'A list changed on another device. Choose which version to keep in Lists.',
      ),
      contains('Tria quina versió'),
    );
    expect(
      requestProblemText(
        lookupAppLocalizations(const Locale('ca')),
        ApiException(
          400,
          'Ask the list owner for the current invitation code.',
        ),
      ),
      contains('codi d’invitació actual'),
    );
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
      expect(
        [en.reviewRemoved, es.reviewRemoved, ca.reviewRemoved],
        ['Removed', 'Quitada', 'Treta'],
      );
      expect(
        [en.reviewUndoSaved(2), es.reviewUndoSaved(2), ca.reviewUndoSaved(2)],
        [
          'They’re back here, not saved yet.',
          'Han vuelto aquí, sin guardar.',
          'Tornen a ser aquí, sense desar.',
        ],
      );
      expect(
        [
          en.captureRemovedDraftsHelp,
          es.captureRemovedDraftsHelp,
          ca.captureRemovedDraftsHelp,
        ],
        [
          'Nothing will change.',
          'No se hará ningún cambio.',
          'No es farà cap canvi.',
        ],
      );
      expect(
        [en.capturesEmptyHelp, es.capturesEmptyHelp, ca.capturesEmptyHelp],
        [
          'Recordings and tasks you leave unfinished are kept here.',
          'Aquí se conservan las grabaciones y las tareas que dejes a medias.',
          'Aquí es conserven les gravacions i les tasques que deixis a mig fer.',
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
      expect(
        [en.discard, es.discard, ca.discard],
        ['Discard', 'Descartar', 'Descarta'],
      );
      expect([en.keep, es.keep, ca.keep], ['Keep', 'Conservar', 'Conserva']);
    },
  );

  test('UX-225: no catalog value keeps the Lista → Proyecto rename slips', () {
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
  });

  // ---- Round 1 · P22 · UX-225, UX-122, UX-123: Spanish and Catalan slips ----

  test(
    'UX-225: in Spanish, agendaCounts(1, 1) reads 1 pendiente · 1 completada',
    () {
      final es = lookupAppLocalizations(const Locale('es'));
      expect(es.agendaCounts(1, 1), '1 pendiente · 1 completada');
      expect(es.agendaCounts(0, 1), '0 pendientes · 1 completada');
      expect(es.agendaCounts(2, 3), '2 pendientes · 3 completadas');
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(ca.agendaCounts(1, 1), isNot(contains('1 completades')));
    },
  );

  for (final (language, one, two) in [
    ('es', 'Cada semana', 'Cada 2 semanas'),
    ('ca', 'Cada setmana', 'Cada 2 setmanes'),
    ('en', 'Every week', 'Every 2 weeks'),
  ]) {
    testWidgets(
      'UX-225: a weekly repeat with weekdays reads $one · …, never Cada 1 semanas ($language)',
      (tester) async {
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        Task weekly(int interval) => Task(
          title: 'Correr',
          priority: 1,
          dueDate: DateTime(2026, 10, 12),
          recurrence: 'weekly',
          repeatInterval: interval,
          repeatWeekdays: const [1, 3],
        );
        final label = context.repeatLabel(weekly(1));
        expect(label, startsWith('$one · '));
        expect(label, isNot(contains(' 1 ')));
        expect(context.repeatLabel(weekly(2)), startsWith('$two · '));
        if (language == 'es') {
          expect(label, 'Cada semana · lun, mié');
        }
      },
    );
  }

  test('UX-225: Lista de pasos is the one Spanish name for a checklist', () {
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(es.checklistSemantics(1, 3), 'Lista de pasos, 1 de 3 completados');
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
    // No review button starts with an infinitive (Desar, Canviar, Treure…).
    final infinitive = RegExp(r'^\S+(ar|er|re|ir)$');
    for (final label in [
      ca.reviewEditDetail,
      ca.reviewRepair,
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
    final catalog =
        jsonDecode(
              File('${directory.path}/app_$language.arb').readAsStringSync(),
            )
            as Map<String, dynamic>;
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
        offending(
          'es',
          RegExp(
            r'Bandeja|Capturas pendientes|captura|Lista para cuando',
            caseSensitive: false,
          ),
        ),
        isEmpty,
      );
    },
  );

  test(
    'U11: the English catalog has no Inbox or capture in user-facing text',
    () {
      expect(
        offending('en', RegExp(r'inbox|captur', caseSensitive: false)),
        isEmpty,
      );
    },
  );

  test(
    'U11: the Catalan catalog has no Safata or captura in user-facing text',
    () {
      expect(
        offending('ca', RegExp(r'safata|captura', caseSensitive: false)),
        isEmpty,
      );
    },
  );

  test(
    'U11: Sin fecha, Sin proyecto and Sin guardar read as decided in each language',
    () {
      final en = lookupAppLocalizations(const Locale('en'));
      final es = lookupAppLocalizations(const Locale('es'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      for (final (
            l,
            inbox,
            count,
            saved,
            moved,
            noList,
            notSaved,
            notSavedCount,
          )
          in [
            (
              en,
              'No date',
              'No date · 2',
              'Added with no date',
              'Date removed',
              'No project',
              'Not saved yet',
              'Not saved yet · 1',
            ),
            (
              es,
              'Sin fecha',
              'Sin fecha · 2',
              'Añadida sin fecha',
              'Se ha quitado la fecha',
              'Sin proyecto',
              'Sin guardar',
              'Sin guardar · 1',
            ),
            (
              ca,
              'Sense data',
              'Sense data · 2',
              'Afegida sense data',
              'S’ha tret la data',
              'Sense projecte',
              'Sense desar',
              'Sense desar · 1',
            ),
          ]) {
        expect(l.inbox, inbox);
        expect(l.inboxCount(2), count);
        expect(l.taskSavedInbox, saved);
        expect(l.movedInbox, moved);
        expect(l.noList, noList);
        expect(l.unfinishedCaptures, notSaved);
        expect(l.pendingCaptureCount(1), notSavedCount);
      }
      expect(
        es.inboxEmpty,
        startsWith('Las tareas sin fecha esperan aquí hasta que elijas una.'),
      );
      expect(
        en.inboxEmpty,
        startsWith('Tasks without a date wait here until you choose one.'),
      );
      expect(
        ca.inboxEmpty,
        startsWith(
          'Les tasques sense data esperen aquí fins que en triïs una.',
        ),
      );
      expect(es.checkCaptures, 'Ver lo que falta por guardar');
      expect(ca.checkCaptures, 'Mostra el que falta per desar');
      expect(en.checkCaptures, 'See what’s not saved yet');
      expect(
        es.sharedCaptureRetained,
        'Lo que has compartido se ha conservado. Vuelve a abrir TaskFlow para intentarlo de nuevo.',
      );
      expect(
        en.sharedCaptureRetained,
        'What you shared is kept. Open TaskFlow again to try again.',
      );
      expect(
        ca.sharedCaptureRetained,
        'El que has compartit s’ha conservat. Torna a obrir TaskFlow per tornar-ho a provar.',
      );
      expect(
        es.capturePrivacy,
        endsWith(
          'Lo que aún no has guardado se queda en este teléfono hasta que lo guardes o lo descartes.',
        ),
      );
      expect(
        en.capturePrivacy,
        endsWith(
          'Anything not saved yet stays on this phone until you save or discard it.',
        ),
      );
      expect(
        ca.capturePrivacy,
        endsWith(
          'El que encara no has desat es queda en aquest telèfon fins que ho desis o ho descartis.',
        ),
      );
      // retryCaptures is gone; the Sin guardar list retries with tryAgain.
      expect(keys.contains('retryCaptures'), isFalse);
    },
  );

  test(
    'P25–P27: the new Projects, Groups and Activity copy reads as the plan wrote it in EN / ES / CA',
    () {
      final en = lookupAppLocalizations(const Locale('en'));
      final es = lookupAppLocalizations(const Locale('es'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      // The catalogs write apostrophes as ’; the plan's straight ones match.
      String plain(String text) => text.replaceAll('’', "'");
      for (final (l, expected) in [
        (
          en,
          [
            'Updates',
            'Unread',
            'Pinned',
            'Shared · Editor',
            'Everyone in Máster will see it.',
            'Create group',
            'Enter a name.',
            'What can Ana do?',
            "Couldn't load. Check your connection.",
            'Invited',
            'Pending',
            'Name for voice assignments',
          ],
        ),
        (
          es,
          [
            'Novedades',
            'No leída',
            'Fijado',
            'Compartido · Editor',
            'Todos en Máster lo verán.',
            'Crear grupo',
            'Escribe un nombre.',
            '¿Qué puede hacer Ana?',
            'No se ha podido cargar. Revisa la conexión.',
            'Invitados',
            'Pendiente',
            'Nombre para asignarte por voz',
          ],
        ),
        (
          ca,
          [
            'Novetats',
            'No llegida',
            'Fixat',
            'Compartit · Editor',
            'Tothom a Máster el veurà.',
            'Crea el grup',
            'Escriu un nom.',
            'Què pot fer Ana?',
            "No s'ha pogut carregar. Revisa la connexió.",
            'Convidats',
            'Pendent',
            'Nom per assignar-te per veu',
          ],
        ),
      ]) {
        final actual = [
          l.groupActivity,
          l.activityUnread,
          l.projectPinned,
          l.projectSharedRole('Editor'),
          l.projectGroupSees('Máster'),
          l.createGroup,
          l.enterName,
          l.groupRoleQuestion('Ana'),
          l.loadFailed,
          l.groupInvited,
          l.invitationPending,
          l.groupVoiceName,
        ].map(plain).toList();
        expect(actual, expected, reason: l.localeName);
      }
    },
  );

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
      all((l) => l.commandWontDelete(1)),
      'Won’t be deleted / No se eliminará / No se suprimirà',
    );
    expect(
      all((l) => l.commandWontChange(1)),
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

  // ---- Run 2026-10-18-commands, round 2 (P133–P138) ----

  test('UX-1204 and UX-911: verifyEmailCodeExpired and captureFillByHand are '
      'gone from all three catalogs', () {
    for (final code in ['en', 'es', 'ca']) {
      final arb = catalog(code);
      for (final gone in ['verifyEmailCodeExpired', 'captureFillByHand']) {
        expect(arb.containsKey(gone), isFalse, reason: '$gone in $code');
        expect(arb.containsKey('@$gone'), isFalse, reason: '@$gone in $code');
      }
    }
  });

  test('UX-1201–UX-1204, UX-1202, UX-908, UX-914, UX-907: every new key is in '
      'all three catalogs, described in English, with the plan’s copy', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    final added = [
      'verifyEmailCodeSpentNew',
      'verifyEmailCodeSpentWait',
      'verifyEmailWrongPassword',
      'commandWhichProject',
      'commandOtherProject',
      'commandShowMore',
      'commandViewOnly',
      'commandFindPeriod',
      'commandFindOpen',
      'commandFindDone',
      'commandFindProjectPerson',
      'commandFindProjectMine',
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
      all((l) => l.verifyEmailCodeInvalid),
      'That code isn’t right. Check the newest email we sent. / Ese código '
      'no es correcto. Mira el último correo que te hemos enviado. / Aquest '
      'codi no és correcte. Mira l’últim correu que t’hem enviat.',
    );
    expect(
      all((l) => l.verifyEmailCodeSpentNew),
      'That code no longer works. We’ve sent you a new one. / Ese código ya '
      'no sirve. Te hemos enviado uno nuevo. / Aquest codi ja no serveix. '
      'T’hem enviat un codi nou.',
    );
    expect(
      all((l) => l.verifyEmailCodeSpentWait),
      'That code no longer works. Tap “Resend code” when the countdown ends. '
      '/ Ese código ya no sirve. Toca «Reenviar código» cuando acabe la '
      'cuenta atrás. / Aquest codi ja no serveix. Toca «Torna a enviar el '
      'codi» quan acabi el compte enrere.',
    );
    // The wait line names the button as it reads.
    for (final l in [en, es, ca]) {
      expect(l.verifyEmailCodeSpentWait, contains(l.verifyEmailResend));
    }
    expect(
      all((l) => l.verifyEmailWrongPassword),
      'That isn’t this account’s password. Don’t remember it? Tap “Use '
      'another email” and create the account again. / Esa contraseña no es '
      'la de esta cuenta. ¿No la recuerdas? Toca «Usar otro correo» y crea '
      'la cuenta de nuevo. / Aquesta contrasenya no és la d’aquest compte. '
      'No la recordes? Toca «Utilitza un altre correu» i torna a crear el '
      'compte.',
    );
    expect(
      all((l) => l.commandWhichProject),
      'Which project should it go in? / ¿En qué proyecto la pongo? / A quin '
      'projecte la poso?',
    );
    expect(
      all((l) => l.commandOtherProject),
      'Another project… / Otro proyecto… / Un altre projecte…',
    );
    expect(
      all((l) => l.commandShowMore(1)),
      'Show 1 more / Ver 1 más / Mostra’n 1 més',
    );
    expect(
      all((l) => l.commandShowMore(3)),
      'Show 3 more / Ver 3 más / Mostra’n 3 més',
    );
    expect(
      all((l) => l.commandViewOnly('Informe')),
      '“Informe” is in a project you can only view. / «Informe» es de un '
      'proyecto que solo puedes ver. / «Informe» és d’un projecte que només '
      'pots veure.',
    );
    expect(
      all((l) => l.commandWhichDay(17, '17:00')),
      'Which day, at 17:00? / ¿Qué día, a las 17:00? / Quin dia, a les 17:00?',
    );
    expect(
      all((l) => l.commandWhichDay(1, '1:00')),
      'Which day, at 1:00? / ¿Qué día, a la 1:00? / Quin dia, a la 1:00?',
    );
    expect(
      all((l) => l.commandFindPeriod('lun, 19 oct', 'dom, 25 oct')),
      'lun, 19 oct to dom, 25 oct / Del lun, 19 oct al dom, 25 oct / Del '
      'lun, 19 oct al dom, 25 oct',
    );
    expect(all((l) => l.commandFindOpen), 'To do / Pendientes / Per fer');
    expect(
      all((l) => l.commandFindDone),
      'Completed / Completadas / Completades',
    );
    expect(
      all((l) => l.commandFindProjectPerson('Matemáticas', 'Paul')),
      'Tasks in “Matemáticas” for Paul / Tareas de «Matemáticas» para Paul / '
      'Tasques de «Matemáticas» assignades a Paul',
    );
    expect(
      all((l) => l.commandFindProjectMine('Matemáticas')),
      'Your tasks in “Matemáticas” / Tus tareas de «Matemáticas» / Les teves '
      'tasques de «Matemáticas»',
    );
  });

  test('UX-916: the copy slips read as the plan wrote them', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(es.commandFindPerson('Ana'), 'Tareas para Ana');
    expect(en.commandFindPerson('Ana'), 'Tasks for Ana');
    expect(ca.commandFindPerson('Ana'), 'Tasques assignades a Ana');
    expect(es.commandExistingProjectTasks(1), 'La tarea va ahí.');
    expect(es.commandExistingProjectTasks(2), 'Las tareas van ahí.');
    expect(en.commandExistingProjectTasks(1), 'The task goes there.');
    expect(en.commandExistingProjectTasks(2), 'The tasks go there.');
    expect(ca.commandExistingProjectTasks(1), 'La tasca hi va.');
    expect(ca.commandExistingProjectTasks(2), 'Les tasques hi van.');
    expect(en.commandWhichToChange, 'Which one do you want to change?');
    expect(en.commandWhichToDelete, 'Which one do you want to delete?');
  });

  test('UX-911: the free account’s keyboard button reads Type instead / '
      'Escribir / Escriu', () {
    expect(
      lookupAppLocalizations(const Locale('en')).captureTypeInstead,
      'Type instead',
    );
    expect(
      lookupAppLocalizations(const Locale('es')).captureTypeInstead,
      'Escribir',
    );
    expect(
      lookupAppLocalizations(const Locale('ca')).captureTypeInstead,
      'Escriu',
    );
  });

  test('UX-1221: billingError’s unsupportedPlatform says the Android app, in '
      'EN, ES and CA, and no catalog value names iOS, iPhone or Apple', () {
    expect(
      lookupAppLocalizations(
        const Locale('en'),
      ).billingError('unsupportedPlatform'),
      'Subscriptions are available in the Android app.',
    );
    expect(
      lookupAppLocalizations(
        const Locale('es'),
      ).billingError('unsupportedPlatform'),
      'Las suscripciones están disponibles en la app para Android.',
    );
    expect(
      lookupAppLocalizations(
        const Locale('ca'),
      ).billingError('unsupportedPlatform'),
      'Les subscripcions estan disponibles a l’aplicació d’Android.',
    );
    final apple = RegExp(r'iOS|iPhone|Apple');
    for (final language in ['en', 'es', 'ca']) {
      final catalog =
          jsonDecode(
                File('${directory.path}/app_$language.arb').readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(
        [
          for (final entry in catalog.entries)
            if (!entry.key.startsWith('@') &&
                entry.value is String &&
                apple.hasMatch(entry.value as String))
              '${entry.key}: ${entry.value}',
        ],
        isEmpty,
        reason: language,
      );
    }
  });

  test('UX-1222: the two page names and the open-page error read as the site '
      'titles them, in EN, ES and CA', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(
      [en.privacyPolicy, en.termsAndConditions, en.webPageOpenError],
      ['Privacy Policy', 'Terms and Conditions', 'Couldn’t open the page.'],
    );
    expect(
      [es.privacyPolicy, es.termsAndConditions, es.webPageOpenError],
      [
        'Política de privacidad',
        'Términos y condiciones',
        'No se ha podido abrir la página.',
      ],
    );
    expect(
      [ca.privacyPolicy, ca.termsAndConditions, ca.webPageOpenError],
      [
        'Política de privacitat',
        'Termes i condicions',
        'No s’ha pogut obrir la pàgina.',
      ],
    );
    // The old key went from every catalog.
    for (final language in ['en', 'es', 'ca']) {
      final catalog =
          jsonDecode(
                File('${directory.path}/app_$language.arb').readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(catalog.containsKey('deleteAccountLinkError'), isFalse);
    }
  });

  // ---- UX loop 2026-10-19-app, round 1: P166, P167, P169, P170 ----

  Map<String, dynamic> catalogOf(String language) =>
      jsonDecode(File('${directory.path}/app_$language.arb').readAsStringSync())
          as Map<String, dynamic>;

  /// Every message value of a catalog, without its @ descriptions.
  Iterable<String> valuesOf(String language) => catalogOf(language).entries
      .where((entry) => !entry.key.startsWith('@'))
      .map((entry) => '${entry.value}');

  test('UX-1303 / UX-1305 / UX-1306: the microphone and listening lines read '
      'as the plan wrote them, in EN, ES and CA', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(
      [
        en.captureMicrophoneBlocked,
        es.captureMicrophoneBlocked,
        ca.captureMicrophoneBlocked,
      ],
      [
        'To dictate again, open Settings and tap Permissions › Microphone › Allow.',
        'Para volver a dictar, abre Ajustes y toca Permisos › Micrófono › Permitir.',
        'Per tornar a dictar, obre Configuració i toca Permisos › Micròfon › Permet.',
      ],
    );
    expect(
      [
        en.captureMicrophoneWhy,
        es.captureMicrophoneWhy,
        ca.captureMicrophoneWhy,
      ],
      [
        'Allow the microphone to dictate your tasks. It only listens while you dictate.',
        'Permite el micrófono para dictar tus tareas. Solo escucha mientras dictas.',
        'Permet el micròfon per dictar les tasques. Només escolta mentre dictes.',
      ],
    );
    expect(
      [en.captureMicrophone, es.captureMicrophone, ca.captureMicrophone],
      [
        'Without the microphone I can’t hear you. Tap Start talking to allow it, or Type instead.',
        'Sin micrófono no puedo escucharte. Toca Empezar a hablar para permitirlo, o Escribir.',
        'Sense micròfon no et puc escoltar. Toca Comença a parlar per permetre-ho, o Escriu.',
      ],
    );
    expect(
      [en.captureCantListen, es.captureCantListen, ca.captureCantListen],
      [
        'I can’t listen on this phone right now. Tap Type instead.',
        'Ahora no puedo escucharte en este teléfono. Toca Escribir.',
        'Ara no et puc escoltar en aquest telèfon. Toca Escriu.',
      ],
    );
    // The buttons the lines name are the ones on the sheet.
    expect(es.captureStartTalking, 'Empezar a hablar');
    expect(es.captureTypeInstead, 'Escribir');
    expect(ca.captureStartTalking, 'Comença a parlar');
    expect(ca.captureTypeInstead, 'Escriu');
    expect(ca.captureOpenSettings, 'Obre Configuració');
    for (final language in ['en', 'es', 'ca']) {
      final catalog = catalogOf(language);
      // UX-1306: one line replaces both.
      expect(
        catalog.containsKey('captureSpeechLanguage'),
        isFalse,
        reason: language,
      );
      expect(
        catalog.containsKey('captureSpeechUnavailable'),
        isFalse,
        reason: language,
      );
      // UX-1305: there is no field below to type in.
      for (final value in valuesOf(language)) {
        final lower = value.toLowerCase();
        for (final gone in ['escribe abajo', 'type below', 'escriu a sota']) {
          expect(
            lower.contains(gone),
            isFalse,
            reason: '$language: «$value» contains «$gone»',
          );
        }
      }
    }
  });

  test('UX-1301 / UX-1304: nothing found, nothing heard, listening online and '
      'the countdown read as the plan wrote them, in EN, ES and CA', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(
      [en.captureNoTasks, es.captureNoTasks, ca.captureNoTasks],
      [
        'I didn’t find a task. Say what and when, for example: “Tomorrow, call the dentist.”',
        'No he encontrado ninguna tarea. Di qué y cuándo, por ejemplo: «Mañana, llamar al dentista».',
        'No he trobat cap tasca. Digues què i quan, per exemple: «Demà, trucar al dentista».',
      ],
    );
    expect(
      [
        en.captureNothingHeardYet,
        es.captureNothingHeardYet,
        ca.captureNothingHeardYet,
      ],
      [
        'Nothing heard yet. Speak when you’re ready, or tap Type instead.',
        'Aún no he oído nada. Habla cuando quieras o toca Escribir.',
        'Encara no he sentit res. Parla quan vulguis o toca Escriu.',
      ],
    );
    expect(
      [
        en.captureListeningOnline,
        es.captureListeningOnline,
        ca.captureListeningOnline,
      ],
      [
        'I’m listening. Tap Done to see what I understood.',
        'Te escucho. Al tocar Listo verás lo que he entendido.',
        'T’escolto. En tocar Fet veuràs el que he entès.',
      ],
    );
    expect(
      [en.captureTimeLeft(3), en.captureTimeLeft(1), en.captureTimeLeft(10)],
      ['3 seconds left', '1 second left', '10 seconds left'],
    );
    expect(
      [es.captureTimeLeft(3), es.captureTimeLeft(1), es.captureTimeLeft(10)],
      ['Quedan 3 segundos', 'Queda 1 segundo', 'Quedan 10 segundos'],
    );
    expect(
      [ca.captureTimeLeft(3), ca.captureTimeLeft(1), ca.captureTimeLeft(10)],
      ['Queden 3 segons', 'Queda 1 segon', 'Queden 10 segons'],
    );
    // Unchanged: once words are heard, and a silent 60 s.
    expect(
      es.captureStillListening,
      'Sigo escuchando. Toca Listo cuando termines.',
    );
    expect(
      es.captureNoSpeech,
      'No te he entendido. Vuelve a intentarlo o escríbelo.',
    );
  });

  test('UX-1404: an empty day’s line with the phone’s calendars reads No tasks '
      'for this day., without the brand; Un momento de calma. is gone', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(
      [en.noScheduledTasks, es.noScheduledTasks, ca.noScheduledTasks],
      [
        'No tasks for this day.',
        'No hay tareas para este día.',
        'No hi ha tasques per a aquest dia.',
      ],
    );
    for (final language in ['en', 'es', 'ca']) {
      expect(
        catalogOf(language).containsKey('breathingRoom'),
        isFalse,
        reason: language,
      );
      for (final value in valuesOf(language)) {
        expect(
          value.contains('tareas de TaskFlow programadas'),
          isFalse,
          reason: '$language: «$value»',
        );
      }
    }
  });

  test('UX-1602 / UX-1617 / UX-1507: the sign-in lines read as the plan wrote '
      'them, in EN, ES and CA', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    const address = 'maria.lopez@example.com';
    expect(
      [
        en.recoveryEmailRequested(address),
        es.recoveryEmailRequested(address),
        ca.recoveryEmailRequested(address),
      ],
      [
        'If maria.lopez@example.com has an account, an email with a code is on its way. Type it here.',
        'Si maria.lopez@example.com tiene cuenta, te llegará un correo con un código. Escríbelo aquí.',
        'Si maria.lopez@example.com té compte, t’arribarà un correu amb un codi. Escriu-lo aquí.',
      ],
    );
    final placeholders =
        (template['@recoveryEmailRequested']
                as Map<String, dynamic>)['placeholders']
            as Map<String, dynamic>;
    expect((placeholders['email'] as Map)['type'], 'String');
    expect([en.email, es.email, ca.email], ['Email', 'Correo', 'Correu']);
    expect(
      [
        en.requestError('emailUsed'),
        es.requestError('emailUsed'),
        ca.requestError('emailUsed'),
      ],
      [
        'This email already has an account.',
        'Este correo ya tiene una cuenta.',
        'Aquest correu ja té un compte.',
      ],
    );
    expect(
      [
        en.invitationWaitingSignIn,
        es.invitationWaitingSignIn,
        ca.invitationWaitingSignIn,
      ],
      [
        'You have an invitation. Sign in with the email address it was sent to.',
        'Tienes una invitación. Entra con el correo en el que la recibiste.',
        'Tens una invitació. Entra amb el correu on l’has rebuda.',
      ],
    );
  });
  test('UX-1318: no capture* message names the server, a service or a request, '
      'and captureUnsupportedKind and captureSpeechBusy are gone', () {
    const words = {
      'en': ['server', 'service', 'request'],
      'es': ['servidor', 'servicio', 'solicitud'],
      'ca': ['servidor', 'servei', 'sol·licitud'],
    };
    for (final MapEntry(key: language, value: banned) in words.entries) {
      final catalog =
          jsonDecode(
                File('${directory.path}/app_$language.arb').readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final gone in ['captureUnsupportedKind', 'captureSpeechBusy']) {
        expect(catalog.containsKey(gone), isFalse, reason: '$language: $gone');
        expect(
          catalog.containsKey('@$gone'),
          isFalse,
          reason: '$language: @$gone',
        );
      }
      for (final MapEntry(:key, :value) in catalog.entries) {
        if (!key.startsWith('capture') || value is! String) continue;
        final text = value.toLowerCase();
        // The word itself (or its plural), not a verb built on it: “was
        // requested” is not “a request”.
        for (final word in banned) {
          expect(
            RegExp(
              r'(^|[^\p{L}])' + RegExp.escape(word) + r's?($|[^\p{L}])',
              unicode: true,
            ).hasMatch(text),
            isFalse,
            reason: '$language: $key: $value',
          );
        }
      }
    }
  });

  test('UX-1630: captureAllowanceRecording is in the three catalogs, described '
      'in English, with the reviewer’s copy and none of the banned words', () {
    const copy = {
      'en':
          'You’ve reached today’s dictation limit. Your recording is kept; try again tomorrow.',
      'es':
          'Has llegado al límite de dictados de hoy. Tu grabación se conserva; inténtalo mañana.',
      'ca':
          'Has arribat al límit de dictats d’avui. La gravació es conserva; torna-ho a provar demà.',
    };
    const banned = {
      'en': ['server', 'service', 'request'],
      'es': ['servidor', 'servicio', 'solicitud'],
      'ca': ['servidor', 'servei', 'sol·licitud'],
    };
    for (final MapEntry(key: language, value: text) in copy.entries) {
      final catalog =
          jsonDecode(
                File('${directory.path}/app_$language.arb').readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(catalog['captureAllowanceRecording'], text, reason: language);
      for (final word in banned[language]!) {
        expect(text.toLowerCase(), isNot(contains(word)), reason: language);
      }
    }
    final english =
        jsonDecode(File('${directory.path}/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final description =
        (english['@captureAllowanceRecording'] as Map?)?['description'];
    expect(description, isA<String>());
    expect((description as String).trim(), isNotEmpty);
  });

  // ---- Run 2026-10-19-app, round 1 · P179 (UX-1414, UX-1421), P180 ----

  Map<String, String> values(String language) {
    final catalog =
        jsonDecode(
              File('${directory.path}/app_$language.arb').readAsStringSync(),
            )
            as Map<String, dynamic>;
    return {
      for (final entry in catalog.entries)
        if (!entry.key.startsWith('@')) entry.key: entry.value as String,
    };
  }

  /// The keys of [language]'s catalog, other than [except], whose value holds
  /// any of [words], in any case.
  List<String> holding(
    String language,
    List<String> words, {
    Set<String> except = const {},
  }) => [
    for (final MapEntry(:key, :value) in values(language).entries)
      if (!except.contains(key) &&
          words.any(
        (word) => value.toLowerCase().contains(word.toLowerCase()),
      ))
        '$key: $value',
  ];

  // Handing a project or its owner's copies over is a transfer of ownership,
  // the right word there; only the file-upload jargon goes.
  for (final (language, words, except) in [
    ('es', ['transferencia'], <String>{}),
    ('en', ['transfer'], {'groupTransfer', 'archiveCsvPersonalCopies'}),
    ('ca', ['transferència'], <String>{}),
  ]) {
    test(
      'UX-1414: no $language catalog value says ${words.join(', ')} (a file upload isn’t a bank transfer)',
      () {
        expect(holding(language, words, except: except), isEmpty);
      },
    );
  }

  // P187 (UX-1606 c) replaces retryScheduling with tryAgain.
  for (final (language, words, except) in [
    (
      'es',
      ['instancia', 'programación', 'Revisa este valor', 'permisos de edición'],
      <String>{},
    ),
    (
      'en',
      ['instance', 'scheduling', 'Check this value', 'edit permissions'],
      {'retryScheduling'},
    ),
    ('ca', ['instància', 'programació', 'permisos d’edició'], <String>{}),
  ]) {
    test(
      'UX-1421: no $language catalog value says ${words.join(', ')}',
      () {
        expect(holding(language, words, except: except), isEmpty);
      },
    );
  }

  test('UX-1421: the plain-words copy reads as the plan wrote it', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(en.deadlineRecurringHelp, 'Each repeat has its own deadline.');
    expect(
      es.deadlineRecurringHelp,
      'Cada repetición tiene su propia fecha límite.',
    );
    expect(ca.deadlineRecurringHelp, 'Cada repetició té el seu propi termini.');
    expect(en.reminderAnchor, 'Remind before');
    expect(es.reminderAnchor, 'Recordar antes de');
    expect(ca.reminderAnchor, 'Recorda-m’ho abans de');
    expect(en.scheduleError, 'Couldn’t change the date. Try again.');
    expect(
      es.scheduleError,
      'No se pudo cambiar la fecha. Inténtalo de nuevo.',
    );
    expect(
      ca.scheduleError,
      'No s’ha pogut canviar la data. Torna-ho a provar.',
    );
    expect(
      en.scheduleChangedAgain,
      'The date changed again. Open the task to check it.',
    );
    expect(
      es.scheduleChangedAgain,
      'La fecha ha vuelto a cambiar. Abre la tarea para revisarla.',
    );
    expect(
      ca.scheduleChangedAgain,
      'La data ha tornat a canviar. Obre la tasca per revisar-la.',
    );
    expect(en.viewOnlyTask, 'You can only view this task.');
    expect(es.viewOnlyTask, 'Solo puedes ver esta tarea.');
    expect(ca.viewOnlyTask, 'Només pots veure aquesta tasca.');
  });

  test(
    'UX-1415 / UX-1417 / UX-1421 / UX-1402 / UX-1407 / UX-1413: the dropped keys are in no catalog',
    () {
      for (final language in ['en', 'es', 'ca']) {
        final keys = values(language).keys.toSet();
        for (final gone in [
          'reminderAnchorHelp',
          'reviewInvalidTime',
          'checklistCompletionHelp',
          'taskDetails',
          'timelineFirstPlan',
          'timelinePoint',
          'progressHeading',
          'useDefault',
        ]) {
          expect(keys, isNot(contains(gone)), reason: '$language: $gone');
        }
      }
    },
  );

  test('UX-1402: the Día view’s words read as the plan wrote them', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(en.timelineUnblocked, 'No time');
    expect(es.timelineUnblocked, 'Sin hora');
    expect(ca.timelineUnblocked, 'Sense hora');
    expect(en.timelineNoBlocks, 'Nothing with a time on this day.');
    expect(es.timelineNoBlocks, 'No hay nada con hora este día.');
    expect(ca.timelineNoBlocks, 'No hi ha res amb hora aquest dia.');
  });

  // ---- Run 2026-10-19-app, round 2 · P205 (UX-1414, UX-1421, UX-1638) ----

  test(
    'UX-1414: the only EN values saying “transfer” are groupTransfer and archiveCsvPersonalCopies (ownership, not files)',
    () {
      final keys = {
        for (final MapEntry(:key, :value) in values('en').entries)
          if (value.toLowerCase().contains('transfer')) key,
      };
      expect(keys, {'groupTransfer', 'archiveCsvPersonalCopies'});
    },
  );

  test(
    'UX-1638: storageFull keeps «(100 MB).» together with a non-breaking space, in EN, ES and CA',
    () {
      for (final language in ['en', 'es', 'ca']) {
        expect(
          values(language)['storageFull'],
          contains('{limit} MB'),
          reason: language,
        );
        expect(
          values(language)['storageFull'],
          isNot(contains('{limit} MB')),
          reason: language,
        );
      }
      expect(
        lookupAppLocalizations(const Locale('en')).storageFull(100),
        'Your file space is full (100 MB).',
      );
      expect(
        lookupAppLocalizations(const Locale('es')).storageFull(100),
        'Tu espacio para archivos está lleno (100 MB).',
      );
      expect(
        lookupAppLocalizations(const Locale('ca')).storageFull(100),
        'El teu espai per a fitxers és ple (100 MB).',
      );
    },
  );

  test(
    'UX-1638: at every width «100» and «MB» land on the same line (ES, EN, CA; 1× and 2×)',
    () {
      for (final language in ['en', 'es', 'ca']) {
        final text = lookupAppLocalizations(Locale(language)).storageFull(100);
        final number = text.indexOf('100');
        final unit = text.indexOf('MB');
        for (final scale in [1.0, 2.0]) {
          // From the narrowest width that holds «(100 MB).» whole: narrower,
          // any word breaks inside itself.
          final group = TextPainter(
            text: const TextSpan(
              text: '(100 MB).',
              style: TextStyle(fontSize: 14),
            ),
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.linear(scale),
          )..layout();
          final narrowest = group.width.ceilToDouble();
          group.dispose();
          for (var width = narrowest; width <= 600; width += 1) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: const TextStyle(fontSize: 14)),
              textDirection: TextDirection.ltr,
              textScaler: TextScaler.linear(scale),
            )..layout(maxWidth: width);
            final line = painter.getLineBoundary(TextPosition(offset: number));
            expect(
              unit >= line.start && unit + 2 <= line.end,
              isTrue,
              reason: '$language at ${scale}x, $width wide: ${text.substring(line.start, line.end)}',
            );
            painter.dispose();
          }
        }
      }
    },
  );

  test(
    'UX-1421: the repeat, view-only and alert-refresh words read as the plan wrote them, in EN, ES and CA',
    () {
      final en = lookupAppLocalizations(const Locale('en'));
      final es = lookupAppLocalizations(const Locale('es'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(en.changeSeriesQuestion, 'Change how it repeats?');
      expect(es.changeSeriesQuestion, '¿Cambiar cómo se repite?');
      expect(ca.changeSeriesQuestion, 'Vols canviar com es repeteix?');
      expect(
        en.changeSeriesHelp,
        'Dates you moved or skipped will follow the new repeat. Completed dates stay in the history.',
      );
      expect(
        es.changeSeriesHelp,
        'Las fechas que cambiaste u omitiste seguirán la nueva repetición. Las fechas completadas se quedan en el historial.',
      );
      expect(
        ca.changeSeriesHelp,
        'Les dates que vas moure o ometre seguiran la repetició nova. Les dates completades es queden a l’historial.',
      );
      expect(
        en.listEditingAccessHelp,
        'To make changes, ask the project’s owner.',
      );
      expect(
        es.listEditingAccessHelp,
        'Si quieres hacer cambios, pídeselo al propietario del proyecto.',
      );
      expect(
        ca.listEditingAccessHelp,
        'Si vols fer canvis, demana-ho al propietari del projecte.',
      );
      expect(
        en.viewOnlyNote,
        'View-only note. To make changes, ask the project’s owner.',
      );
      expect(
        es.viewOnlyNote,
        'Nota de solo lectura. Si quieres hacer cambios, pídeselo al propietario del proyecto.',
      );
      expect(
        ca.viewOnlyNote,
        'Nota de només lectura. Si vols fer canvis, demana-ho al propietari del projecte.',
      );
      expect(
        en.androidAlertRefreshHelp,
        'Upcoming alerts update when you open the app and, when Android allows it, every hour.',
      );
      expect(
        es.androidAlertRefreshHelp,
        'Los próximos avisos se actualizan al abrir la app y, cuando Android lo permite, cada hora.',
      );
      expect(
        ca.androidAlertRefreshHelp,
        'Els avisos propers s’actualitzen quan obres l’aplicació i, quan Android ho permet, cada hora.',
      );
      expect(
        en.backgroundAlertRefreshHelp,
        'Upcoming alerts update when you open the app and when your phone allows it.',
      );
      expect(
        es.backgroundAlertRefreshHelp,
        'Los próximos avisos se actualizan al abrir la app y cuando el teléfono lo permite.',
      );
      expect(
        ca.backgroundAlertRefreshHelp,
        'Els avisos propers s’actualitzen quan obres l’aplicació i quan el telèfon ho permet.',
      );
      expect(
        en.deferredAlerts(1),
        '1 later alert isn’t set yet. The next update sets the nearest ones.',
      );
      expect(
        en.deferredAlerts(3),
        '3 later alerts aren’t set yet. The next update sets the nearest ones.',
      );
      expect(
        es.deferredAlerts(1),
        '1 aviso posterior aún no está activado. La próxima actualización activará los más cercanos.',
      );
      expect(
        es.deferredAlerts(3),
        '3 avisos posteriores aún no están activados. La próxima actualización activará los más cercanos.',
      );
      expect(
        ca.deferredAlerts(1),
        '1 avís posterior encara no està activat. La pròxima actualització activarà els més propers.',
      );
      expect(
        ca.deferredAlerts(3),
        '3 avisos posteriors encara no estan activats. La pròxima actualització activarà els més propers.',
      );
    },
  );

  test('UX-1421: the unused «schedule» key is in no catalog', () {
    for (final language in ['en', 'es', 'ca']) {
      final catalog =
          jsonDecode(
                File(
                  '${directory.path}/app_$language.arb',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(catalog.keys, isNot(contains('schedule')), reason: language);
      expect(catalog.keys, isNot(contains('@schedule')), reason: language);
    }
  });

  // ---- Run 2026-10-19-app, round 1 (P181–P185) ----

  test('UX-1513, UX-1503, UX-1506, UX-1504, UX-1520: the retired strings are '
      'gone from all three catalogs: no Revocar invitación, no Siguiente step, '
      'no formal email labels, no Tu rol or sharing help, no lone «Proyecto '
      'archivado» line, no second notes help', () {
    const retired = [
      'revokeInvitation',
      'nextStep',
      'invitationEmailSent',
      'invitationEmailPending',
      'invitationCodeHelp',
      'theirEmail',
      'inviteeEmail',
      'yourRole',
      'sharingHelp',
      'archivedList',
      'notesHelp',
    ];
    for (final language in ['en', 'es', 'ca']) {
      final catalog = catalogOf(language);
      for (final key in retired) {
        expect(catalog.keys, isNot(contains(key)), reason: '$language $key');
        expect(catalog.keys, isNot(contains('@$key')),
            reason: '$language @$key');
      }
      final values = [
        for (final entry in catalog.entries)
          if (!entry.key.startsWith('@') && entry.value is String)
            entry.value as String,
      ];
      for (final gone in [
        'Revocar invitación',
        'Revoca la invitació',
        'Revoke invitation',
        'Su correo',
        'El seu correu',
        'Correo de su cuenta',
        'Correu del seu compte',
        'Reemplazar una invitación invalida',
      ]) {
        expect(values.where((value) => value.contains(gone)), isEmpty,
            reason: '$language: $gone');
      }
    }
  });

  test('UX-1524: Grupos’ help ends the tú/vosotros mix, Activity is Novedades, '
      'and the Catalan sharing names read plainly', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(en.groupHelp,
        'Invite people once and share several projects with them.');
    expect(es.groupHelp,
        'Invita a las personas una vez y comparte con ellas varios proyectos.');
    expect(ca.groupHelp,
        'Convida les persones una vegada i comparteix amb elles diversos projectes.');
    expect(es.groupHelp, isNot(contains('colaborad')));
    expect(ca.groupHelp, isNot(contains('col·laboreu')));
    expect(en.groupActivity, 'Updates');
    expect(es.groupActivity, 'Novedades');
    expect(ca.groupActivity, 'Novetats');
    expect(ca.listSharing, 'Comparteix el projecte');
    expect(ca.howSharingWorks, 'Com funciona compartir');
    // EN and ES keep theirs.
    expect(es.listSharing, 'Compartir proyecto');
    expect(en.listSharing, 'Project sharing');
  });

  test('UX-1503: the invite reads as a question with a plain label, in EN, ES '
      'and CA', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(en.inviteWho('Casa'), 'Who are you inviting to Casa?');
    expect(es.inviteWho('Casa'), '¿A quién invitas a Casa?');
    expect(ca.inviteWho('Casa'), 'A qui convides a Casa?');
    expect([en.email, es.email, ca.email], ['Email', 'Correo', 'Correu']);
    expect(en.inviteOwnEmail, 'That’s your own email. Type the other person’s.');
    expect(es.inviteOwnEmail,
        'Ese es tu correo. Escribe el de la persona que invitas.');
    expect(ca.inviteOwnEmail,
        'Aquest és el teu correu. Escriu el de la persona que convides.');
    expect(es.shareProjectHelp('Casa'),
        'Esa persona verá todo lo que hay en Casa.');
    expect(ca.shareProjectHelp('Casa'),
        'Aquesta persona veurà tot el que hi ha a Casa.');
    expect(en.sendInvitation, 'Send invitation');
    expect(es.sendInvitation, 'Enviar invitación');
    expect(ca.sendInvitation, 'Envia la invitació');
  });

  // ---- 2026-10-21-changes · P236 (UX-1720): why your words go to Google ----

  test('UX-1720: capturePrivacy says in plain words why the words go to '
      'Google’s AI; its other three sentences are unchanged, in EN, ES and CA', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    for (final (language, privacy, sentences) in [
      (
        'en',
        en.capturePrivacy,
        [
          'Live transcription uses on-device speech where available; no audio '
              'is retained in that mode.',
          'To add, find or change tasks, your words go over the internet to '
              'Google’s AI.',
          'Saved audio is transcribed online.',
          'Anything not saved yet stays on this phone until you save or '
              'discard it.',
        ],
      ),
      (
        'es',
        es.capturePrivacy,
        [
          'La transcripción en directo usa el reconocimiento local cuando está '
              'disponible; ese modo no conserva audio.',
          'Para añadir, buscar o cambiar tareas, tus palabras van por internet '
              'a la IA de Google.',
          'El audio guardado se transcribe en línea.',
          'Lo que aún no has guardado se queda en este teléfono hasta que lo '
              'guardes o lo descartes.',
        ],
      ),
      (
        'ca',
        ca.capturePrivacy,
        [
          'La transcripció en directe utilitza el reconeixement local quan '
              'està disponible; en aquest mode no es conserva l’àudio.',
          'Per afegir, cercar o canviar tasques, les teves paraules van per '
              'internet a la IA de Google.',
          'L’àudio desat es transcriu en línia.',
          'El que encara no has desat es queda en aquest telèfon fins que ho '
              'desis o ho descartis.',
        ],
      ),
    ]) {
      // Exactly four sentences: the first, third and fourth word for word as
      // before, the second the new plain one.
      expect(privacy, sentences.join(' '), reason: language);
      final lower = privacy.toLowerCase();
      for (final jargon in ['extracción', 'extracció', 'extraction']) {
        expect(lower, isNot(contains(jargon)), reason: '$language $jargon');
      }
    }
  });

  test('UX-1720: app_en.arb describes capturePrivacy', () {
    final entry = template['@capturePrivacy'];
    expect(entry, isA<Map<String, dynamic>>());
    final description = (entry as Map<String, dynamic>)['description'];
    expect(description, isA<String>());
    expect((description as String).trim(), isNotEmpty);
    // The organizer's description, so translators know where it shows.
    expect(
      description,
      'The full voice privacy note at the end of the Voice screen in '
      'Settings: on-device or online transcription, why the words go to '
      'Google’s AI, saved audio, and what stays on the phone. '
      'capturePrivacyLine is its short form in the capture sheet.',
    );
  });

  // ---- UX loop 2026-10-28-app, round 1 · P273 (UX-2104, UX-2105) ----

  group('P273 · understanding and failing', () {
    Map<String, dynamic> catalog(String language) =>
        jsonDecode(
              File('${directory.path}/app_$language.arb').readAsStringSync(),
            )
            as Map<String, dynamic>;

    test(
      'UX-2104: no capture string names an assistant («asistente», “assistant”, «assistent»)',
      () {
        const assistant = {
          'es': 'asistente',
          'en': 'assistant',
          'ca': 'assistent',
        };
        for (final MapEntry(key: language, value: word) in assistant.entries) {
          final messages = catalog(language);
          final capture = [
            for (final key in keys)
              if (key.startsWith('capture') || key == 'recordingKept') key,
          ];
          expect(capture, isNotEmpty);
          for (final key in capture) {
            expect(
              (messages[key] as String).toLowerCase(),
              isNot(contains(word)),
              reason: '$language: $key',
            );
          }
        }
      },
    );

    test(
      'UX-2105: words and recordings waiting in «Sin guardar» are kept, never saved, in recordingKept, capturesEmptyHelp, captureFailed and captureOffline',
      () {
        const banned = [
          'guardad',
          'se guardan',
          'es guarden',
          'desad',
          'saved',
        ];
        for (final language in ['en', 'es', 'ca']) {
          final messages = catalog(language);
          for (final key in [
            'recordingKept',
            'capturesEmptyHelp',
            'captureFailed',
            'captureOffline',
          ]) {
            final value = (messages[key] as String).toLowerCase();
            for (final word in banned) {
              expect(
                value,
                isNot(contains(word)),
                reason: '$language: $key: $value',
              );
            }
          }
        }
      },
    );

    test('UX-2105: the reviewer’s copy for the kept words', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final es = lookupAppLocalizations(const Locale('es'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(
        en.captureFailed,
        'That didn’t work. Your words are still here — try again.',
      );
      expect(es.recordingKept, 'Grabación conservada en este teléfono');
      expect(
        es.capturesEmptyHelp,
        'Aquí se conservan las grabaciones y las tareas que dejes a medias.',
      );
      expect(
        ca.capturesEmptyHelp,
        'Aquí es conserven les gravacions i les tasques que deixis a mig fer.',
      );
    });
  });
}
