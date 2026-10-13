import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/project_scope_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'UX-303: the project picker search ignores accents and picks the match '
      '(es/ca, 2x text, 320 dp, both themes)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final language in ['es', 'ca']) {
      for (final dark in [false, true]) {
        final l10n = lookupAppLocalizations(Locale(language));
        final container = ProviderContainer(overrides: [
          taskListsProvider.overrideWith((ref) async => [
                TaskListInfo(id: 'school', name: 'Col·legi'),
                TaskListInfo(id: 'doctor', name: 'Médico'),
                TaskListInfo(id: 'food', name: 'Compras'),
              ]),
        ]);
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
                locale: Locale(language),
                theme: dark ? AppTheme.dark : AppTheme.light,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!),
                home: const Scaffold(
                    body: SafeArea(child: ProjectScopeControl())))));
        await tester.pumpAndSettle();
        final reason = '$language dark=$dark';
        await tester.tap(find.widgetWithText(ActionChip, l10n.projectsAll));
        await tester.pumpAndSettle();
        final search = find.widgetWithText(TextField, l10n.projectsFind);
        final sheet = find.byType(BottomSheet);
        // At 2x text the sheet's list is short: scroll it to reach a row.
        final results = find
            .descendant(
                of: find.descendant(of: sheet, matching: find.byType(ListView)),
                matching: find.byType(Scrollable))
            .first;
        Future<void> reveal(Finder row) =>
            tester.scrollUntilVisible(row, 60, scrollable: results);
        Future<void> toEnd() async {
          await tester.drag(results, const Offset(0, -3000));
          await tester.pumpAndSettle();
        }

        await tester.enterText(search, 'medico');
        await tester.pumpAndSettle();
        final doctor = find.descendant(
            of: sheet, matching: find.widgetWithText(ListTile, 'Médico'));
        await reveal(doctor);
        expect(doctor, findsOneWidget, reason: reason);
        await toEnd();
        expect(find.descendant(of: sheet, matching: find.text('Compras')),
            findsNothing);
        expect(find.descendant(of: sheet, matching: find.text('Col·legi')),
            findsNothing);
        expect(find.text(l10n.projectsNoneFound), findsNothing);

        await tester.enterText(search, 'dentista');
        await tester.pumpAndSettle();
        expect(find.text(l10n.projectsNoneFound), findsOneWidget,
            reason: reason);

        await tester.enterText(search, 'collegi');
        await tester.pumpAndSettle();
        final match = find.descendant(
            of: sheet, matching: find.widgetWithText(ListTile, 'Col·legi'));
        await reveal(match);
        expect(match, findsOneWidget, reason: reason);
        await toEnd();
        expect(find.descendant(of: sheet, matching: find.text('Médico')),
            findsNothing);
        await reveal(match);
        await tester.tap(match);
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);
        expect(container.read(projectScopeProvider).projectId, 'school');
        expect(find.widgetWithText(ActionChip, 'Col·legi'), findsOneWidget,
            reason: reason);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    }
  });
}
