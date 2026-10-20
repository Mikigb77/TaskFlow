// UX loop 2026-10-19-app, round 1 · P174 (UX-1317): each row of «Sin
// guardar» (`/captures`) says when it was kept, then only what tells it
// apart.
import 'dart:async';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/screens/captures_screen.dart';
import 'package:agenda/services/capture_problem.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_fixtures.dart';

final es = lookupAppLocalizations(const Locale('es'));

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

  /// Tuesday 20 October 2026, noon, on the app's clock.
  final now = DateTime(2026, 10, 20, 12);

  CaptureSession recording(String id, DateTime kept) => CaptureSession(
    id: id,
    ownerKey: 'owner',
    timezone: 'Europe/Madrid',
    capturedAt: kept.toUtc(),
    status: 'failed',
    source: 'speech',
    audioPath: 'kept/$id.wav',
    error: CaptureProblem.offline,
  );

  CaptureSession note(DateTime kept) => CaptureSession(
    id: 'note',
    ownerKey: 'owner',
    timezone: 'Europe/Madrid',
    capturedAt: kept.toUtc(),
    status: 'editing',
    source: 'typed',
    kind: 'note',
    text: 'Ideas para el regalo de Lucía',
  );

  CaptureSession result(DateTime kept) => CaptureSession(
    id: 'result',
    ownerKey: 'owner',
    timezone: 'Europe/Madrid',
    capturedAt: kept.toUtc(),
    status: 'ready',
    source: 'speech',
    transcript: 'Pedir cita para la ITV y llevar el coche al taller el jueves',
    drafts: [
      CaptureDraft(
        id: 'itv',
        task: Task(title: 'Pedir cita para la ITV', priority: 1),
      ),
      CaptureDraft(
        id: 'garage',
        task: Task(
          title: 'Llevar el coche al taller',
          priority: 1,
          dueDate: DateTime(2026, 10, 22),
        ),
      ),
    ],
  );

  /// «Sin guardar» in Spanish with [sessions] kept, on a 24-hour clock.
  Future<void> openKept(
    WidgetTester tester,
    List<CaptureSession> sessions, {
    Size size = const Size(360, 800),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (textScale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    final container = designContainer(
      regionalStore: MemoryRegionalStore(
        const RegionalPreferences(
          language: 'es',
          clock: ClockFormat.twentyFour,
          weekStart: 1,
        ),
      ),
      pendingCaptures: sessions,
      overrides: [calendarClockProvider.overrideWithValue(() => now)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    unawaited(
      Navigator.of(
        tester.element(find.byType(Scaffold).first),
      ).pushNamed('/captures'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CapturesScreen), findsOneWidget);
  }

  /// Each row's subtitle, in order, as shown.
  List<Text> subtitles(WidgetTester tester) => [
    for (final tile in tester.widgetList<ListTile>(
      find.descendant(
        of: find.byType(CapturesScreen),
        matching: find.byType(ListTile),
      ),
    ))
      tile.subtitle! as Text,
  ];

  testWidgets(
    'UX-1317: two recordings kept at 9:41 today and 18:05 yesterday show «Hoy, 9:41» and «Ayer, 18:05»',
    (tester) async {
      await openKept(tester, [
        recording('today', DateTime(2026, 10, 20, 9, 41)),
        recording('yesterday', DateTime(2026, 10, 19, 18, 5)),
      ]);
      expect(es.today, 'Hoy');
      expect(es.yesterday, 'Ayer');
      final lines = subtitles(tester).map((t) => t.data!).toList();
      expect(lines, hasLength(2));
      // The time as the app writes times on this phone's clock (24-hour
      // Spanish: 09:41).
      final context = tester.element(find.byType(CapturesScreen));
      final morning = context.clockTime(DateTime(2026, 10, 20, 9, 41));
      expect(morning, anyOf('9:41', '09:41'));
      expect(lines[0], startsWith('Hoy, $morning'));
      expect(lines[1], startsWith('Ayer, 18:05'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1317: no subtitle says «Guardado en este teléfono» or «Toca para continuar» or «Tareas ·»; a note says «Nota»; a result with 2 tasks left says «2 sin añadir»',
    (tester) async {
      await openKept(tester, [
        recording('kept', DateTime(2026, 10, 20, 11)),
        note(DateTime(2026, 10, 20, 9)),
        result(DateTime(2026, 10, 19, 12)),
      ]);
      final lines = subtitles(tester).map((t) => t.data!).toList();
      expect(lines, hasLength(3));
      for (final line in lines) {
        expect(line, isNot(contains('Guardado en este teléfono')));
        expect(line, isNot(contains('Toca para continuar')));
        expect(line, isNot(startsWith('${es.tasks} ·')));
      }
      expect(es.note, 'Nota');
      expect(lines[1].split(' · '), contains(es.note));
      expect(es.captureDraftSummary(2), '2 sin añadir');
      expect(lines[2].split(' · '), contains(es.captureDraftSummary(2)));
      // A recording, typed words or a note: nothing more to say.
      expect(lines[0], 'Hoy, 11:00');
      expect(lines[1], startsWith('Hoy, '));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1317: ES 2× on 360×800, three kept captures: each row’s subtitle takes at most 3 lines and starts with the time it was kept',
    (tester) async {
      await openKept(tester, [
        recording('kept', DateTime(2026, 10, 20, 11)),
        note(DateTime(2026, 10, 20, 9)),
        result(DateTime(2026, 10, 16, 12)),
      ], textScale: 2);
      final at = tester
          .element(find.byType(CapturesScreen))
          .clockTime(DateTime(2026, 10, 20, 9));
      final starts = ['Hoy, 11:00', 'Hoy, $at', null];
      final texts = subtitles(tester);
      expect(texts, hasLength(3));
      for (var i = 0; i < texts.length; i++) {
        final line = texts[i].data!;
        final shown = find.text(line);
        await tester.ensureVisible(shown);
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(shown);
        final painter = TextPainter(
          text: paragraph.text,
          textDirection: paragraph.textDirection,
          textScaler: paragraph.textScaler,
          locale: paragraph.locale,
          strutStyle: paragraph.strutStyle,
          textHeightBehavior: paragraph.textHeightBehavior,
        )..layout(maxWidth: paragraph.size.width);
        final lines = painter.computeLineMetrics().length;
        painter.dispose();
        expect(lines, lessThanOrEqualTo(3), reason: '«$line»: $lines lines');
        if (starts[i] case final start?) {
          expect(line, startsWith(start));
        } else {
          // Last Friday: the day alone, as the app writes a day («vie, 16
          // oct»).
          final context = tester.element(find.byType(CapturesScreen));
          expect(line, startsWith(context.weekdayDate(DateTime(2026, 10, 16))));
        }
      }
      expect(tester.takeException(), isNull);
    },
  );
}
