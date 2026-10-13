import 'dart:io';
import 'dart:ui' as ui;
import 'package:agenda/l10n/region.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/widgets/task_actions.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets(
    'Undo stays available for the phone timeout, read on each toggle',
    (tester) async {
      const channel = MethodChannel('taskflow/accessibility');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var recommended = 10000;
      messenger.setMockMethodCallHandler(channel, (_) async => recommended);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = designContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      final notifier = container.read(taskProvider.notifier);
      for (final task in container.read(taskProvider).requireValue) {
        await notifier.deleteTask(task.id!);
      }
      await notifier.addTask(
        Task(
          title: 'Check feedback timing',
          priority: 1,
          dueDate: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();
      final checkbox = find.descendant(
        of: find.byType(TaskTile),
        matching: find.byType(Checkbox),
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 10),
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.text(l.undo));
      await tester.pumpAndSettle();
      expect(
        container.read(taskProvider).requireValue.single.isCompleted,
        isFalse,
      );

      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 9));
      expect(find.text(l.taskCompleted), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(
        container.read(taskProvider).requireValue.single.isCompleted,
        isTrue,
      );

      recommended = 6000;
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 6),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(find.text(l.taskReopened), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(
        container.read(taskProvider).requireValue.single.isCompleted,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'es', 'ca']) {
    testWidgets(
      '$language completion feedback keeps controls accessible in both themes',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.reset);
        final preview = GlobalKey();
        final container = designContainer(
          regionalStore: MemoryRegionalStore(
            RegionalPreferences(language: language),
          ),
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(key: preview, child: const MyApp()),
          ),
        );
        await tester.pumpAndSettle();
        final notifier = container.read(taskProvider.notifier);
        for (final task in container.read(taskProvider).requireValue) {
          await notifier.deleteTask(task.id!);
        }
        final now = DateTime.now();
        await notifier.addTask(
          Task(
            title: 'Publicar la aplicación en Google Play',
            priority: 1,
            dueDate: DateTime(now.year, now.month, now.day, 10, 20),
            notes: 'Preparar la ficha y las capturas de la aplicación.',
            checklist: [ChecklistItem(title: 'Revisar las capturas')],
          ),
        );
        for (final theme in [ThemeMode.light, ThemeMode.dark]) {
          await setAppearance(container, theme);
          await tester.pumpAndSettle();
          final l = tester.element(find.byType(CalendarScreen)).l10n;
          expect(find.text(l.checklistCount(0, 1)), findsOneWidget);
          expect(find.textContaining(' steps'), findsNothing);
          final checkbox = find.descendant(
            of: find.byType(TaskTile),
            matching: find.byType(Checkbox),
          );
          await tester.ensureVisible(checkbox);
          await tester.pumpAndSettle();
          await tester.tap(checkbox);
          await tester.pumpAndSettle();
          expect(find.text(l.taskCompleted), findsOneWidget);
          expect(
            tester.getRect(find.byType(SnackBar)).bottom,
            lessThanOrEqualTo(tester.getRect(find.byType(TaskActions)).top),
          );
          expect(find.text(l.undo).hitTestable(), findsOneWidget);
          expect(
            find.byTooltip(l.createTaskTooltip).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byTooltip(l.createVoiceTask).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('WRITE_CALENDAR_PREVIEWS') &&
              language == 'es') {
            final boundary =
                preview.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              await File(
                'build/calendar-feedback-${theme.name}.png',
              ).writeAsBytes(bytes.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pump(const Duration(seconds: 3));
          await tester.tap(find.text(l.undo));
          await tester.pumpAndSettle();
          expect(
            container.read(taskProvider).requireValue.single.isCompleted,
            isFalse,
          );
          await tester.tap(checkbox);
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 3));
          expect(find.text(l.taskCompleted), findsOneWidget);
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          expect(find.byType(SnackBar), findsNothing);
          expect(
            container.read(taskProvider).requireValue.single.isCompleted,
            isTrue,
          );

          await tester.tap(checkbox);
          await tester.pumpAndSettle();
          expect(find.text(l.taskReopened), findsOneWidget);
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
          expect(find.byType(SnackBar), findsNothing);
          expect(
            container.read(taskProvider).requireValue.single.isCompleted,
            isFalse,
          );
        }
      },
    );
  }
}
