// Round 1 of 2026-10-13-app, P21 (UX-215, UX-216, UX-222, UX-227) and the
// form parts of P22 (UX-225): the edit form starts with the title, keeps
// Más detalles short and ordered by use, and adds steps in place.
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(
    () => platform.setMockMethodCallHandler(timeoutChannel, (_) async => null),
  );
  tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));

  final es = lookupAppLocalizations(const Locale('es'));
  final now = DateTime.now();
  final dated = DateTime(now.year, now.month, now.day);

  /// The edit form for [task], in [language], with [projects].
  Future<void> openEditor(
    WidgetTester tester,
    Task task, {
    String language = 'es',
    List<TaskListInfo> projects = const [],
    Size size = const Size(390, 3000),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = designContainer(
      regionalStore: MemoryRegionalStore(
        RegionalPreferences(
          language: language,
          clock: ClockFormat.twentyFour,
          weekStart: 1,
        ),
      ),
      projects: projects,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: TaskEditor(task: task),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inEditor(Finder finder) =>
      find.descendant(of: find.byType(TaskEditor), matching: finder);

  Future<void> showDetails(WidgetTester tester) async {
    final more = find.byKey(const ValueKey('task-more-details'));
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
  }

  // ---- UX-215: the title first ----

  testWidgets(
    'UX-215: editing a task shows no headline, no help line and, with no projects, no project row; the title field comes first',
    (tester) async {
      await openEditor(
        tester,
        Task(id: 1, title: 'Comprar pan', priority: 1, dueDate: dated),
      );
      // The removed headline and help line (their keys are gone).
      for (final gone in [
        'Ajusta tu plan.',
        'Ponle un nombre. Añade una fecha cuando quieras.',
        'Revisa los detalles antes de añadirla al calendario.',
        es.notesHelp,
        es.seriesEdits,
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      expect(find.byType(TaskAssignmentPicker), findsNothing);
      // Nothing sits above the title field in the form.
      final title = find.byKey(const ValueKey('task-title'));
      final titleTop = tester.getRect(title).top;
      final texts = inEditor(find.byType(Text)).evaluate().where((element) {
        final inAppBar = find
            .ancestor(
              of: find.byWidget(element.widget),
              matching: find.byType(AppBar),
            )
            .evaluate()
            .isNotEmpty;
        return !inAppBar;
      });
      for (final element in texts) {
        final box = element.renderObject! as RenderBox;
        final top = box.localToGlobal(Offset.zero).dy;
        expect(
          top,
          greaterThanOrEqualTo(titleTop - 0.5),
          reason: '`${(element.widget as Text).data}` sits above the title',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-215: editing a note shows no headline or Guarda información help line; Título de la nota is only the field label',
    (tester) async {
      await openEditor(
        tester,
        Task(id: 2, title: 'Ideas', priority: 1, kind: 'note'),
      );
      expect(find.text(es.notesHelp), findsNothing);
      expect(find.text('Ajusta tu plan.'), findsNothing);
      for (final element in find.text(es.noteTitle).evaluate()) {
        expect(
          find.ancestor(
            of: find.byWidget(element.widget),
            matching: find.byType(TextField),
          ),
          findsOneWidget,
          reason: 'Título de la nota labels the field, not a headline',
        );
      }
      expect(find.byType(TaskAssignmentPicker), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-215: with one project the project row shows; a repeating task still warns that edits change the whole series',
    (tester) async {
      await openEditor(
        tester,
        Task(
          id: 3,
          title: 'Regar las plantas',
          priority: 1,
          dueDate: dated,
          recurrence: 'weekly',
        ),
        projects: [TaskListInfo(id: 'p1', name: 'Casa')],
      );
      expect(find.byType(TaskAssignmentPicker), findsOneWidget);
      expect(find.text(es.seriesEdits), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- UX-216: Más detalles by use, fewer words ----

  testWidgets(
    'UX-216: Más detalles lists Recordatorio, Repetir and Pasos first, then duration, deadline, priority, labels and files',
    (tester) async {
      await openEditor(
        tester,
        Task(
          id: 4,
          title: 'Médico',
          priority: 1,
          dueDate: dated,
          filePaths: const ['/local/resultados.pdf'],
        ),
      );
      await showDetails(tester);
      final order = <(String, Finder)>[
        ('Recordatorio', find.byType(ReminderControl)),
        ('Repetir', find.byKey(const ValueKey('task-repeat'))),
        ('Pasos', find.byKey(const ValueKey('add-checklist-item'))),
        ('Duración', find.byKey(const ValueKey('task-duration'))),
        ('Fecha límite', find.byKey(const ValueKey('task-deadline'))),
        ('Prioridad', inEditor(find.byType(ChoiceChip)).first),
        ('Etiquetas', find.byKey(const ValueKey('task-labels'))),
        ('Archivos', inEditor(find.text(es.addAttachment))),
      ];
      var previous = double.negativeInfinity;
      var previousName = '';
      for (final (name, finder) in order) {
        expect(finder, findsOneWidget, reason: name);
        final top = tester.getRect(finder).top;
        expect(
          top,
          greaterThan(previous),
          reason: '$name comes after $previousName',
        );
        previous = top;
        previousName = name;
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-216: Más detalles shows none of the four help paragraphs and no MiB, here or in the attach sheet',
    (tester) async {
      await openEditor(
        tester,
        Task(
          id: 5,
          title: 'Médico',
          priority: 1,
          dueDate: dated,
          durationMinutes: 30,
        ),
      );
      await showDetails(tester);
      for (final gone in [
        // durationEstimateHelp, deadlineHelp and fileManageHelp (keys gone).
        'Una estimación hasta que elijas una hora de inicio.',
        'Debe estar terminada para esta fecha. Cambiar el inicio previsto mantiene esta fecha límite.',
        'Abre los detalles de la tarea para descargar, subir o eliminar archivos de tu cuenta.',
        es.fileUploadHelp,
        es.fileLocalHelp,
      ]) {
        expect(find.textContaining(gone), findsNothing, reason: gone);
      }
      expect(find.textContaining('MiB'), findsNothing);

      final attach = inEditor(find.text(es.addAttachment));
      await tester.ensureVisible(attach);
      await tester.pumpAndSettle();
      await tester.tap(attach);
      await tester.pumpAndSettle();
      expect(find.textContaining('MiB'), findsNothing);
      expect(find.textContaining('6 MB'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  test('UX-216: no catalog writes MiB in the file help or limit', () {
    for (final language in ['en', 'es', 'ca']) {
      final l = lookupAppLocalizations(Locale(language));
      for (final text in [l.fileUploadHelp, l.fileLocalHelp, l.fileLimit]) {
        expect(text, isNot(contains('MiB')), reason: '$language: $text');
        expect(text, contains('MB'), reason: '$language: $text');
      }
    }
  });

  for (final (language, textScale, size) in [
    ('es', 1.0, const Size(390, 3000)),
    ('es', 2.0, const Size(320, 3000)),
    ('ca', 2.0, const Size(320, 3000)),
    ('en', 1.0, const Size(390, 3000)),
  ]) {
    testWidgets(
      'UX-216: without a date, Repetir is shown disabled with Añade una fecha para repetir ($language, ${textScale}x text at ${size.width.toInt()} dp)',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        await openEditor(
          tester,
          Task(id: 6, title: 'Algún día', priority: 1),
          language: language,
          size: size,
          textScale: textScale,
        );
        await showDetails(tester);
        final repeat = find.byKey(const ValueKey('task-repeat'));
        expect(repeat, findsOneWidget);
        expect(tester.widget<ListTile>(repeat).enabled, isFalse);
        expect(
          find.descendant(of: repeat, matching: find.text(l.repeatNeedsDate)),
          findsOneWidget,
        );
        final rect = tester.getRect(repeat);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width + 0.5));
        // Tapping it opens nothing.
        await tester.ensureVisible(repeat);
        await tester.pumpAndSettle();
        await tester.tap(repeat, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('UX-216: the no-date repeat hint reads as the plan wrote it', () {
    expect(
      lookupAppLocalizations(const Locale('en')).repeatNeedsDate,
      'Add a date to repeat',
    );
    expect(es.repeatNeedsDate, 'Añade una fecha para repetir');
    expect(
      lookupAppLocalizations(const Locale('ca')).repeatNeedsDate,
      'Afegeix una data per repetir',
    );
  });

  testWidgets('UX-216: with a date, Repetir is enabled and shows no date hint', (
    tester,
  ) async {
    await openEditor(
      tester,
      Task(id: 7, title: 'Correr', priority: 1, dueDate: dated),
    );
    await showDetails(tester);
    final repeat = find.byKey(const ValueKey('task-repeat'));
    expect(tester.widget<ListTile>(repeat).enabled, isTrue);
    expect(
      find.descendant(of: repeat, matching: find.text(es.repeatNeedsDate)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  // ---- UX-222: steps are typed in place ----

  testWidgets(
    'UX-222: typing a step and pressing Enter adds it and keeps the field focused; no dialog opens',
    (tester) async {
      await openEditor(
        tester,
        Task(id: 8, title: 'Viaje', priority: 1, dueDate: dated),
      );
      await showDetails(tester);
      final add = find.byKey(const ValueKey('add-checklist-item'));
      expect(
        find.descendant(of: add, matching: find.text(es.addStep)),
        findsOneWidget,
        reason: 'the field reuses the add-step label',
      );
      bool focused() => tester
          .widget<EditableText>(
            find.descendant(of: add, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus;

      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.enterText(add, 'Pasaporte');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(inEditor(find.text('Pasaporte')), findsOneWidget);
      expect(focused(), isTrue, reason: 'the field stays focused');
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: add, matching: find.byType(EditableText)),
            )
            .controller
            .text,
        isEmpty,
      );

      // The next one goes straight in.
      await tester.enterText(add, 'Cargador');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(inEditor(find.text('Pasaporte')), findsOneWidget);
      expect(inEditor(find.text('Cargador')), findsOneWidget);
      expect(focused(), isTrue);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 2 (b8) · P110 (UX-622): Más detalles keeps a half-typed step ----

  testWidgets(
    'UX-622: a step typed without Enter survives Más detalles and Menos detalles, and is never added twice',
    (tester) async {
      await openEditor(
        tester,
        Task(
          id: 11,
          title: 'Viaje',
          priority: 1,
          dueDate: dated,
          checklist: [ChecklistItem(title: 'Pasaporte')],
        ),
      );
      final add = find.byKey(const ValueKey('add-checklist-item'));
      expect(add, findsOneWidget, reason: 'one step shows the steps folded');
      String fieldText() => tester
          .widget<EditableText>(
            find.descendant(of: add, matching: find.byType(EditableText)),
          )
          .controller
          .text;
      // Steps titled Coat in the list, not counting the add field.
      int coatSteps() =>
          inEditor(find.text('Coat')).evaluate().length -
          find.descendant(of: add, matching: find.text('Coat')).evaluate().length;
      void expectKept(String when) {
        final inField = fieldText() == 'Coat';
        final steps = coatSteps();
        expect(
          inField || steps == 1,
          isTrue,
          reason: '$when: Coat is in the field or in the list',
        );
        expect(steps, lessThanOrEqualTo(1), reason: '$when: no duplicate');
        if (steps == 1) {
          expect(inField, isFalse, reason: '$when: not both a step and text');
        }
        expect(inEditor(find.text('Pasaporte')), findsOneWidget);
      }

      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.enterText(add, 'Coat');
      await tester.pump();

      final more = find.byKey(const ValueKey('task-more-details'));
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      expect(find.descendant(of: more, matching: find.text(es.moreDetails)),
          findsOneWidget);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(add, findsOneWidget);
      expectKept('after Más detalles');

      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      expect(find.descendant(of: more, matching: find.text(es.fewerDetails)),
          findsOneWidget);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(add, findsOneWidget);
      expectKept('after Menos detalles');

      // Leaving the field now keeps it once, not twice.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(coatSteps(), 1);
      expect(fieldText(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 3 (b8) · P112 (UX-622): a first step typed without Enter ----

  /// A task with no steps, edited in Spanish at 1× on 360×740, with Más
  /// detalles open and `Coat` typed in Añadir paso without Enter.
  Future<void> typeFirstStepInDetails(WidgetTester tester) async {
    await openEditor(
      tester,
      Task(id: 12, title: 'Salir', priority: 1, dueDate: dated),
      size: const Size(360, 740),
    );
    final add = find.byKey(const ValueKey('add-checklist-item'));
    expect(add, findsNothing, reason: 'no steps: the short form has no Añadir paso');
    await showDetails(tester);
    expect(add, findsOneWidget);
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pump();
    await tester.enterText(add, 'Coat');
    await tester.pump();
  }

  Finder addField() => find.byKey(const ValueKey('add-checklist-item'));

  String addFieldText(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(of: addField(), matching: find.byType(EditableText)),
      )
      .controller
      .text;

  /// Steps titled Coat in the list, not counting the Añadir paso field.
  int coatSteps() =>
      inEditor(find.text('Coat')).evaluate().length -
      find.descendant(of: addField(), matching: find.text('Coat')).evaluate().length;

  Finder moreButton() => find.byKey(const ValueKey('task-more-details'));

  Future<void> tapMore(WidgetTester tester) async {
    await tester.ensureVisible(moreButton());
    await tester.pumpAndSettle();
    await tester.tap(moreButton());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'UX-622: on a task with no steps, a first step typed without Enter shows in the short form after Menos detalles',
    (tester) async {
      await typeFirstStepInDetails(tester);
      expect(
        find.descendant(of: moreButton(), matching: find.text(es.fewerDetails)),
        findsOneWidget,
      );
      await tapMore(tester);

      expect(
        find.descendant(of: moreButton(), matching: find.text(es.moreDetails)),
        findsOneWidget,
        reason: 'the form is collapsed',
      );
      expect(coatSteps(), 1, reason: 'exactly one step Coat in the short form');
      expect(addField(), findsOneWidget);
      expect(addFieldText(tester), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-622: opening Más detalles again keeps the first step Coat once, with no duplicate',
    (tester) async {
      await typeFirstStepInDetails(tester);
      await tapMore(tester); // Menos detalles
      await tapMore(tester); // Más detalles
      expect(
        find.descendant(of: moreButton(), matching: find.text(es.fewerDetails)),
        findsOneWidget,
        reason: 'the form is expanded again',
      );
      expect(coatSteps(), 1);
      expect(addFieldText(tester), isEmpty);
      // Leaving the field later adds nothing more.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(coatSteps(), 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-622: two quick taps on Menos detalles keep the first step Coat once and leave the form collapsed',
    (tester) async {
      await typeFirstStepInDetails(tester);
      await tester.ensureVisible(moreButton());
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: moreButton(), matching: find.text(es.fewerDetails)),
        findsOneWidget,
      );
      // Both taps land on Menos detalles before the first one's collapse has
      // finished (it waits a microtask for the step to be kept), the way two
      // fast taps on a phone reach the button before the form rebuilds.
      final at = tester.getCenter(moreButton());
      void tapOnce(int pointer) {
        tester.binding.handlePointerEvent(
          PointerDownEvent(pointer: pointer, position: at),
        );
        tester.binding.handlePointerEvent(
          PointerUpEvent(pointer: pointer, position: at),
        );
      }

      tapOnce(91);
      tapOnce(92);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(coatSteps(), 1, reason: 'exactly one step Coat');
      expect(
        find.descendant(of: moreButton(), matching: find.text(es.moreDetails)),
        findsOneWidget,
        reason: 'the form is collapsed',
      );
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 1 (b9) · P113 (UX-624): a typed step is never lost ----

  testWidgets(
    'UX-624: removing the last step through ⋮ in the short form keeps the text typed in Añadir paso',
    (tester) async {
      await openEditor(
        tester,
        Task(
          id: 13,
          title: 'Salir',
          priority: 1,
          dueDate: dated,
          checklist: [ChecklistItem(title: 'Pasaporte')],
        ),
        size: const Size(360, 740),
      );
      expect(
        find.descendant(of: moreButton(), matching: find.text(es.moreDetails)),
        findsOneWidget,
        reason: 'the short form',
      );
      expect(addField(), findsOneWidget, reason: 'one step: Añadir paso shows');
      await tester.ensureVisible(addField());
      await tester.pumpAndSettle();
      await tester.enterText(addField(), 'Coat');
      await tester.pump();

      final menu = find.byTooltip(es.editCaptureItem('Pasaporte'));
      await tester.ensureVisible(menu);
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(es.removeStep));
      await tester.pumpAndSettle();

      expect(inEditor(find.text('Pasaporte')), findsNothing);
      final inField =
          addField().evaluate().isNotEmpty && addFieldText(tester) == 'Coat';
      expect(
        inField || coatSteps() == 1,
        isTrue,
        reason: 'Coat is kept, as a step or in the field',
      );
      expect(coatSteps(), lessThanOrEqualTo(1), reason: 'never twice');
      if (coatSteps() == 1 && addField().evaluate().isNotEmpty) {
        expect(addFieldText(tester), isEmpty, reason: 'not both');
      }

      // Opening Más detalles still shows it once.
      await tapMore(tester);
      final kept =
          coatSteps() +
          (addField().evaluate().isNotEmpty && addFieldText(tester) == 'Coat'
              ? 1
              : 0);
      expect(kept, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-624: on a task with 50 steps, Más detalles opens and closes without an Añadir paso field that could drop text, and all 50 steps stay',
    (tester) async {
      await openEditor(
        tester,
        Task(
          id: 14,
          title: 'Mudanza',
          priority: 1,
          dueDate: dated,
          checklist: [
            for (var i = 1; i <= 50; i++) ChecklistItem(title: 'Caja $i'),
          ],
        ),
        size: const Size(390, 12000),
      );
      // Nothing can be typed at the limit, so nothing typed can vanish.
      expect(addField(), findsNothing);
      await showDetails(tester);
      expect(addField(), findsNothing);
      await tapMore(tester);
      expect(
        find.descendant(of: moreButton(), matching: find.text(es.moreDetails)),
        findsOneWidget,
      );
      expect(inEditor(find.text('Caja 50')), findsOneWidget);
      expect(inEditor(find.text('Caja 1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- UX-227: polish ----

  testWidgets(
    'UX-227: the summary under Más detalles is plain text, not chips; the form has no Quitar fecha',
    (tester) async {
      await openEditor(
        tester,
        Task(
          id: 9,
          title: 'Revisión',
          priority: 3,
          dueDate: dated,
          recurrence: 'weekly',
          durationMinutes: 45,
        ),
      );
      expect(inEditor(find.byType(Chip)), findsNothing);
      expect(inEditor(find.byType(ActionChip)), findsNothing);
      expect(inEditor(find.textContaining(es.durationMinutes(45))), findsOne);
      expect(find.text('Quitar fecha'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('UX-227: English labelLimit says up to 32 characters; Catalan too, and Canvia la data', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(en.labelLimit, contains('up to 32 characters'));
    expect(en.labelLimit, isNot(contains('33')));
    expect(ca.labelLimit, contains('de fins a 32 caràcters'));
    expect(ca.labelLimit, isNot(contains('33')));
    expect(ca.reschedule, 'Canvia la data');
    expect(ca.rescheduleTask, 'Canvia la data de la tasca');
    expect(ca.rescheduleRepeating, 'Canvia la data de la tasca periòdica');
  });

  // ---- UX-225 (P22): the remove-file tooltip is translated ----

  for (final (language, remove) in [
    ('es', 'Quitar resultados.pdf'),
    ('en', 'Remove resultados.pdf'),
    ('ca', 'Treu resultados.pdf'),
  ]) {
    testWidgets('UX-225: the attachment remove button is labelled $remove', (
      tester,
    ) async {
      final l = lookupAppLocalizations(Locale(language));
      await openEditor(
        tester,
        Task(
          id: 10,
          title: 'Médico',
          priority: 1,
          dueDate: dated,
          filePaths: const ['/local/resultados.pdf'],
        ),
        language: language,
      );
      await showDetails(tester);
      expect(l.removeFileNamed('resultados.pdf'), remove);
      expect(find.byTooltip(remove), findsOneWidget);
      if (language != 'en') {
        expect(find.byTooltip('Remove resultados.pdf'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
