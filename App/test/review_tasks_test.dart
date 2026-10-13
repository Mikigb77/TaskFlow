import 'package:agenda/main.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/screens/review_tasks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

TaskDraft draft(String title, {bool ambiguous = false}) => TaskDraft.fromJson({
  'title': title,
  'due_date': null,
  'scheduled_date': title == 'Pay invoice' ? '2026-09-25' : null,
  'priority': 1,
  'notes': '',
  'transcript': 'Buy coffee. Pay invoice Friday.',
  'questions': ambiguous ? ['Morning or afternoon?'] : [],
});

Future<ProviderContainer> openReview(
  WidgetTester tester,
  List<TaskDraft> drafts, {
  GlobalKey? preview,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = designContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(key: preview, child: const MyApp()),
    ),
  );
  await tester.pumpAndSettle();
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .push(
        MaterialPageRoute<void>(
          builder: (_) => ReviewTasksScreen(
            drafts: drafts,
            transcript: 'Buy coffee. Pay invoice Friday.',
          ),
        ),
      );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets(
    'single and batch review keep the save action visible in both appearances',
    (tester) async {
      for (final batch in [false, true]) {
        final preview = GlobalKey();
        final container = await openReview(tester, [
          TaskDraft.fromJson({
            'title': 'Comprobar el funcionamiento de la app',
            'scheduled_date': '2026-10-13',
            'notes':
                'Verificar que funciona con las funcionalidades actuales, sin añadir funciones nuevas.',
            'priority': 1,
            'questions': [],
            'transcript': 'Necesito comprobar que la app funcione.',
          }),
          if (batch) draft('Enviar los resultados a José'),
        ], preview: preview);
        await container
            .read(regionalProvider.notifier)
            .set(const RegionalPreferences(language: 'es'));
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          await setAppearance(container, mode);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('save-drafts')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('WRITE_REVIEW_PREVIEWS')) {
            final boundary =
                preview.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              await File(
                'build/review-${batch ? 'batch' : 'direct'}-${mode.name}.png',
              ).writeAsBytes(bytes.buffer.asUint8List());
              image.dispose();
            });
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
  testWidgets(
    'one task has editable title and notes with optional controls folded away',
    (tester) async {
      final container = await openReview(tester, [
        draft('Revisar la aplicación'),
      ]);
      expect(find.byKey(const ValueKey('task-title')), findsOneWidget);
      expect(find.byKey(const ValueKey('draft-notes')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Comprobar la aplicación',
      );
      await tester.enterText(
        find.byKey(const ValueKey('draft-notes')),
        'Probar con José · demà 🗓️',
      );
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      final saved = container.read(taskProvider).requireValue.last;
      expect(saved.title, 'Comprobar la aplicación');
      expect(saved.notes, 'Probar con José · demà 🗓️');
      expect(saved.dueDate, isNull);
    },
  );

  testWidgets(
    'batch cards expand one editor and save title edits without extra dialogs',
    (tester) async {
      final container = await openReview(tester, [
        draft('Buy coffee'),
        draft('Pay invoice'),
      ]);
      expect(find.byKey(const ValueKey('task-title')), findsNothing);
      await tester.tap(find.byTooltip('Edit Buy coffee'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Buy decaf',
      );
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      final tasks = container.read(taskProvider).requireValue;
      expect(tasks.length, 6);
      expect(tasks.singleWhere((t) => t.title == 'Buy decaf').dueDate, isNull);
      expect(
        tasks.singleWhere((t) => t.title == 'Pay invoice').hasTime,
        isFalse,
      );
    },
  );

  testWidgets('identical questions resolve only the chosen field', (
    tester,
  ) async {
    final container = await openReview(tester, [
      TaskDraft.fromJson({
        'title': 'Doctor',
        'scheduled_date': '2026-10-13',
        'priority': 3,
        'notes': 'Bring test results',
        'transcript': 'Doctor tomorrow at five',
        'questions': ['Please check this detail'],
        'clarifications': [
          {
            'field': 'schedule',
            'question': 'Please check this detail',
            'times': ['05:00', '17:00'],
          },
          {
            'field': 'duration',
            'question': 'Please check this detail',
            'times': [],
          },
        ],
      }),
    ]);
    await tester.ensureVisible(find.text('17:00'));
    await tester.tap(find.text('17:00'));
    await tester.pumpAndSettle();
    expect(find.text('Please check this detail'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('save-drafts')))
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Keep this detail as shown'));
    await tester.tap(find.text('Keep this detail as shown'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await tester.pumpAndSettle();
    final saved = container.read(taskProvider).requireValue.last;
    expect(saved.dueDate, DateTime(2026, 10, 13, 17));
    expect(saved.hasTime, true);
    expect(saved.notes, 'Bring test results');
  });

  testWidgets(
    'ready tasks save while uncertain drafts stay without duplicating saved tasks',
    (tester) async {
      final container = await openReview(tester, [
        draft('Call', ambiguous: true),
        draft('Coffee'),
      ]);
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      expect(container.read(taskProvider).requireValue.length, 5);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save-drafts')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Call Mum',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save-drafts')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Keep this detail as shown'));
      await tester.tap(find.text('Keep this detail as shown'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      expect(container.read(taskProvider).requireValue.length, 6);
      expect(
        container
            .read(taskProvider)
            .requireValue
            .where((t) => t.title == 'Coffee'),
        hasLength(1),
      );
    },
  );

  testWidgets('empty titles cannot save and removing a card offers Undo', (
    tester,
  ) async {
    final container = await openReview(tester, [
      draft('First'),
      draft('Second'),
    ]);
    await tester.tap(find.byTooltip('Edit Second'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Remove Second'));
    await tester.tap(find.byTooltip('Remove Second'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit Second'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Edit First'));
    await tester.tap(find.byTooltip('Edit First'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('task-title')), '   ');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await tester.pumpAndSettle();
    expect(container.read(taskProvider).requireValue.last.title, 'Second');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('save-drafts')))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'Spanish and Catalan retain inline edits, large text and theme changes',
    (tester) async {
      final container = await openReview(tester, [
        draft('Coffee'),
        draft('Call', ambiguous: true),
      ]);
      await tester.tap(find.byTooltip('Edit Coffee'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Café de José',
      );
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final language in ['es', 'ca', 'en']) {
        await container
            .read(regionalProvider.notifier)
            .set(RegionalPreferences(language: language));
        for (final theme in [ThemeMode.light, ThemeMode.dark]) {
          await setAppearance(container, theme);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const ValueKey('draft-notes')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester
                .widget<TextFormField>(find.byKey(const ValueKey('task-title')))
                .controller!
                .text,
            'Café de José',
          );
        }
      }
    },
  );

  testWidgets(
    'existing checklists stay visible in direct review and preserve identity',
    (tester) async {
      final container = await openReview(tester, [
        TaskDraft.fromJson({
          'title': 'Pack',
          'priority': 1,
          'notes': '',
          'transcript': 'Passport and charger',
          'questions': [],
          'checklist': [
            {'id': 'passport', 'title': 'Passport'},
            {'id': 'charger', 'title': 'Charger'},
          ],
        }),
      ]);
      await tester.ensureVisible(find.byTooltip('Edit Passport'));
      await tester.tap(find.byTooltip('Edit Passport'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit step'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('checklist-title')),
        'Renewed passport',
      );
      await tester.tap(find.text('Keep step'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      final saved = container.read(taskProvider).requireValue.last;
      expect(saved.checklist.first.id, 'passport');
      expect(saved.checklist.first.title, 'Renewed passport');
    },
  );
}
