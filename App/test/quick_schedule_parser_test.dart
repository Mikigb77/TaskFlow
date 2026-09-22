import 'package:agenda/services/quick_schedule_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reference = DateTime(2026, 9, 22, 23, 58);
  test('explicit deadline phrases do not invent a planned start', () {
    final timed = QuickScheduleParser.parse(
        'Submit report by Friday at 5 pm', reference)!;
    expect(timed.isDeadline, isTrue);
    expect(timed.title, 'Submit report');
    expect(timed.date, DateTime(2026, 9, 25, 17));
    expect(timed.hasTime, isTrue);
    final civil = QuickScheduleParser.parse(
        'Entregar factura antes del viernes', reference)!;
    expect(civil.isDeadline, isTrue);
    expect(civil.title, 'Entregar factura');
    expect(civil.date, DateTime(2026, 9, 25));
    expect(civil.hasTime, isFalse);
    expect(
        QuickScheduleParser.parse('Appointment Friday', reference)!.isDeadline,
        isFalse);
    expect(
        QuickScheduleParser.parse('Work at 9:00, deadline Friday', reference),
        isNull);
  });
  test(
      'English and Spanish phrases suggest independent dates and explicit times',
      () {
    final cases = [
      ('Buy coffee tomorrow', 'Buy coffee', DateTime(2026, 9, 23), false),
      (
        'Pay rent on Friday at 5 pm',
        'Pay rent',
        DateTime(2026, 9, 25, 17),
        true
      ),
      (
        'Llamar al médico mañana a las 17:30',
        'Llamar al médico',
        DateTime(2026, 9, 23, 17, 30),
        true
      ),
      (
        'Doctor el miércoles a las 12 pm',
        'Doctor',
        DateTime(2026, 9, 23, 12),
        true
      ),
      ('Backup today at 00:00', 'Backup', DateTime(2026, 9, 22), true),
      (
        'Renew passport 2027-02-03',
        'Renew passport',
        DateTime(2027, 2, 3),
        false
      ),
    ];
    for (final row in cases) {
      final parsed = QuickScheduleParser.parse(row.$1, reference)!;
      expect(parsed.title, row.$2, reason: row.$1);
      expect(parsed.date, row.$3, reason: row.$1);
      expect(parsed.hasTime, row.$4, reason: row.$1);
    }
  });
  test('ambiguous hours never invent AM/PM and remain available for correction',
      () {
    final suggestion =
        QuickScheduleParser.parse('Doctor on Friday at 5', reference)!;
    expect(suggestion.date, DateTime(2026, 9, 25));
    expect(suggestion.hasTime, isFalse);
    expect(suggestion.ambiguousTime, isTrue);
    expect(suggestion.title, 'Doctor at 5');
    final invalid =
        QuickScheduleParser.parse('Doctor tomorrow at 25:00', reference)!;
    expect(invalid.hasTime, isFalse);
    expect(invalid.title, contains('25:00'));
  });
  test('unsupported, quoted, conflicting and regional dates are left untouched',
      () {
    for (final input in [
      'Buy coffee sometime',
      'Read "Tomorrow"',
      "Read today's report",
      'Call tomorrow or Friday',
      'Call tomorrow actually Monday',
      'Tomorrow and tomorrow',
      'Call on 03/04',
      'Call 2026-02-30',
      'Call Friday at 2pm and 4pm',
      'Tomorrow'
    ]) {
      expect(QuickScheduleParser.parse(input, reference), isNull,
          reason: input);
    }
  });
  test('next weekday rolls forward and tomorrow stays tied to capture time',
      () {
    expect(QuickScheduleParser.parse('Meeting next Tuesday', reference)!.date,
        DateTime(2026, 9, 29));
    expect(QuickScheduleParser.parse('Meeting Tuesday', reference)!.date,
        DateTime(2026, 9, 22));
    expect(QuickScheduleParser.parse('Errand tomorrow', reference)!.date,
        DateTime(2026, 9, 23));
  });
}
