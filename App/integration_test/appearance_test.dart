import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:agenda/main.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import '../test/support/design_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('inspect the main mobile flows in light and dark',
      (tester) async {
    final container = designContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await setAppearance(container, mode);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('calendar-${mode.name}');
      await tester.tap(find.byKey(const ValueKey('calendar-format')));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('agenda-${mode.name}');
      await tester.tap(find.byTooltip('Create task'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('task-title')), 'Plan something good');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('editor-${mode.name}');
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('tasks-${mode.name}');
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('settings-${mode.name}');
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('account-${mode.name}');
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).push(
          MaterialPageRoute<void>(builder: (_) => const VoiceTaskScreen()));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('voice-${mode.name}');
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('calendar-format')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
