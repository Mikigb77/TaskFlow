import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/widgets/task_schedule_label.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'support/design_fixtures.dart';

// UX-111 / P7: dates lead with Hoy, Mañana or the weekday, so a date can be
// checked without knowing today's date.
void main() {
  Future<BuildContext> localized(WidgetTester tester, String language) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );
    return captured;
  }

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-111: taskScheduleLabel reads Hoy · 17:00, Mañana · 17:00 and a weekday date for other days ($language)',
      (tester) async {
        final context = await localized(tester, language);
        final l = lookupAppLocalizations(Locale(language));
        final now = DateTime.now();
        DateTime on(int days, [int hour = 17]) =>
            DateTime(now.year, now.month, now.day + days, hour);
        String label(DateTime date, {bool hasTime = true}) => taskScheduleLabel(
          Task(title: 'Médico', priority: 1, dueDate: date, hasTime: hasTime),
          context: context,
        );

        expect(label(on(0)), '${l.today} · 17:00');
        expect(label(on(1)), '${l.tomorrow} · 17:00');
        final later = on(3);
        final weekday = DateFormat.MMMEd(language).format(later);
        expect(label(later), '$weekday · 17:00');
        // It leads with the weekday name.
        expect(weekday, contains(DateFormat.E(language).format(later)));
        expect(context.weekdayDate(later), weekday);
        // A past day keeps its weekday too.
        expect(
          label(on(-2)),
          '${DateFormat.MMMEd(language).format(on(-2))} · 17:00',
        );
        // A date without a time.
        expect(label(on(1), hasTime: false), '${l.tomorrow} · ${l.anyTime}');
        // An undated task just reads `Sin fecha` (D6a).
        expect(
          taskScheduleLabel(
            Task(title: 'Algún día', priority: 1),
            context: context,
          ),
          l.noDate,
        );
      },
    );
  }

  testWidgets('UX-111: in Spanish a Friday reads vie, 16 oct', (tester) async {
    final context = await localized(tester, 'es');
    expect(context.weekdayDate(DateTime(2026, 10, 16)), 'vie, 16 oct');
  });

  testWidgets(
    'UX-445: a tile’s past deadline reads Vence <weekday date> · Fecha límite vencida, in the same format as its date, never Vence 12 oct',
    (tester) async {
      final container = designContainer();
      addTearDown(container.dispose);
      final task = Task(
        id: 1,
        title: 'Entregar el informe',
        priority: 1,
        dueDate: DateTime(2026, 10, 16, 17),
        deadline: DateTime(2026, 10, 12),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('es'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: ListView(children: [TaskTile(task: task)]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(TaskTile));
      final l = context.l10n;
      final deadline = DateTime(2026, 10, 12);
      final expected =
          '${l.deadlineLabel(context.weekdayDate(deadline))} · ${l.deadlineOverdue}';
      final tile = find.byType(TaskTile);
      expect(
        find.descendant(of: tile, matching: find.text(expected)),
        findsOneWidget,
      );
      // The weekday leads, as on the date line: never the bare `12 oct`.
      expect(
        context.weekdayDate(deadline),
        contains(DateFormat.E('es').format(deadline)),
      );
      expect(
        find.descendant(
          of: tile,
          matching: find.textContaining(
            l.deadlineLabel(context.shortDate(deadline)),
          ),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: tile,
          matching: find.textContaining('Vence 12 oct'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
