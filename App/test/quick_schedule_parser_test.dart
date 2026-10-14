import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/services/local_capture.dart';
import 'package:agenda/services/quick_schedule_parser.dart';
import 'package:flutter/widgets.dart' show Locale;
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
    // The result asks morning or afternoon, so the hour leaves the title.
    expect(suggestion.ambiguousHour, 5);
    expect(suggestion.title, 'Doctor');
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
    ]) {
      expect(QuickScheduleParser.parse(input, reference), isNull,
          reason: input);
    }
    // Words that are only a date still name it, with no title left.
    final alone = QuickScheduleParser.parse('Tomorrow', reference)!;
    expect(alone.title, isEmpty);
    expect(alone.date, DateTime(2026, 9, 23));
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

  test('UX-221: `a las 17` is 17:00 with no ambiguity; `a las 5` stays ambiguous',
      () {
    final evening =
        QuickScheduleParser.parse('Llamar al médico mañana a las 17', reference)!;
    expect(evening.date, DateTime(2026, 9, 23, 17));
    expect(evening.hasTime, isTrue);
    expect(evening.ambiguousTime, isFalse);
    expect(evening.title, 'Llamar al médico');
    for (final hour in [0, 13, 23]) {
      final parsed =
          QuickScheduleParser.parse('Cena mañana a las $hour', reference)!;
      expect(parsed.date, DateTime(2026, 9, 23, hour), reason: '$hour');
      expect(parsed.hasTime, isTrue, reason: '$hour');
      expect(parsed.ambiguousTime, isFalse, reason: '$hour');
    }
    final five =
        QuickScheduleParser.parse('Llamar al médico mañana a las 5', reference)!;
    expect(five.date, DateTime(2026, 9, 23));
    expect(five.hasTime, isFalse);
    expect(five.ambiguousTime, isTrue);
  });

  // ---- P38 (UX-204): Catalan in the parser, and the local result ----

  test('UX-204: `divendres a les 17` parses as Friday 17:00', () {
    final found =
        QuickScheduleParser.parse('Trucar al metge divendres a les 17', reference)!;
    expect(found.date, DateTime(2026, 9, 25, 17));
    expect(found.date.weekday, DateTime.friday);
    expect(found.hasTime, isTrue);
    expect(found.ambiguousTime, isFalse);
    expect(found.title, 'Trucar al metge');
  });

  test('UX-204: the Catalan day words, and vinent / proper for next', () {
    // The reference is Tuesday 22 September 2026.
    final days = {
      'avui': DateTime(2026, 9, 22),
      'demà': DateTime(2026, 9, 23),
      'dimecres': DateTime(2026, 9, 23),
      'dijous': DateTime(2026, 9, 24),
      'divendres': DateTime(2026, 9, 25),
      'dissabte': DateTime(2026, 9, 26),
      'diumenge': DateTime(2026, 9, 27),
      'dilluns': DateTime(2026, 9, 28),
      'dimarts': DateTime(2026, 9, 22),
      'dimarts vinent': DateTime(2026, 9, 29),
      'el proper dimarts': DateTime(2026, 9, 29),
    };
    for (final MapEntry(key: words, value: day) in days.entries) {
      final found = QuickScheduleParser.parse('Reunió $words', reference);
      expect(found, isNotNull, reason: words);
      final date = found!.date;
      expect(DateTime(date.year, date.month, date.day), day, reason: words);
      expect(found.title, 'Reunió', reason: words);
    }
  });

  test(
      'UX-204: `a las 5` is ambiguous, and the local result offers 5:00 and 17:00 (and Sin hora on the card), with the date applied and no time',
      () {
    final found =
        QuickScheduleParser.parse('Llamar al médico el viernes a las 5', reference)!;
    expect(found.ambiguousTime, isTrue);
    expect(found.ambiguousHour, 5);
    expect(found.hasTime, isFalse);
    final draft = localDrafts('llamar al médico el viernes a las 5', reference)
        .single;
    expect(draft.task.title, 'Llamar al médico');
    expect(draft.task.dueDate, DateTime(2026, 9, 25));
    expect(draft.task.hasTime, isFalse);
    expect(draft.confirmed, isFalse);
    final question = draft.clarifications.single;
    expect(question.field, 'schedule');
    expect(question.times, ['05:00', '17:00']);
    // `Dejar como está` has the words as typed, with no date.
    expect(draft.asTyped!.title, 'Llamar al médico el viernes a las 5');
    expect(draft.asTyped!.dueDate, isNull);
  });

  test(
      'UX-204: typed words with no date are the title: the first sentence, at most 160 characters cut at a word, with the rest in the notes',
      () {
    final short = localDrafts('comprar pan. Y leche si hay', reference).single;
    expect(short.task.title, 'Comprar pan');
    expect(short.task.notes, 'Y leche si hay');
    expect(short.task.dueDate, isNull);
    expect(short.asTyped, isNull);
    final long = List.filled(40, 'palabra').join(' ');
    final cut = localDrafts(long, reference).single.task;
    expect(cut.title.length, lessThanOrEqualTo(160));
    expect(long.startsWith(cut.title.toLowerCase()), isTrue);
    expect(cut.title.endsWith(' '), isFalse);
    expect('${cut.title.toLowerCase()} ${cut.notes}', long);
  });

  test(
      'UX-112: a typed task with no date gets a later default day without a time; today adds nothing; a note never gets a day',
      () {
    final thursday = DateTime(2026, 9, 24);
    final later =
        localDrafts('Comprar pan', reference, defaultDay: thursday).single.task;
    expect(later.dueDate, thursday);
    expect(later.hasTime, isFalse);
    final dated = localDrafts('Comprar pan el viernes', reference,
            defaultDay: thursday)
        .single
        .task;
    expect(dated.dueDate, DateTime(2026, 9, 25));
    final note = localDrafts('Ideas', reference,
            defaultDay: thursday, kind: 'note')
        .single
        .task;
    expect(note.dueDate, isNull);
  });

  test(
      'UX-468: the typing hint in each language is read as one task on the coming Friday at 17:00',
      () {
    // reference is a Tuesday: the coming Friday is 25 September.
    final hints = {
      'es': 'Médico el viernes a las 17:00',
      'en': 'Doctor Friday at 5 p.m.',
      // The plan suggested `Metge divendres a les 17 h`; the parser reads
      // its time but leaves `h` in the title (`Metge h`), so the catalog
      // uses the wording it reads cleanly.
      'ca': 'Metge divendres a les 17:00',
    };
    for (final MapEntry(key: language, value: hint) in hints.entries) {
      expect(lookupAppLocalizations(Locale(language)).exampleTask, hint,
          reason: language);
      final draft = localDrafts(hint, reference).single;
      expect(draft.task.title, isNot(contains('17')), reason: hint);
      expect(draft.task.title.split(' ').length, 1, reason: hint);
      expect(draft.task.dueDate, DateTime(2026, 9, 25, 17), reason: hint);
      expect(draft.task.hasTime, isTrue, reason: hint);
      expect(draft.clarifications, isEmpty, reason: hint);
      expect(draft.task.notes, isNull, reason: hint);
    }
  });

  // ---- 2026-10-14-speed · P104 (UX-604): parts of the day and 'pasado mañana' ----

  group('typed dates (P104)', () {
    // Wednesday 14 October 2026, 10:00: Thursday is the 15th, Friday the 16th.
    final wednesday = DateTime(2026, 10, 14, 10);
    DateTime dayOf(DateTime value) =>
        DateTime(value.year, value.month, value.day);

    /// [words] parsed on the phone: a date, an optional time, and the title.
    void expectParsed(
      String words, {
      required DateTime day,
      int? hour,
      int minute = 0,
      required String title,
    }) {
      final found = QuickScheduleParser.parse(words, wednesday);
      expect(found, isNotNull, reason: words);
      expect(dayOf(found!.date), day, reason: words);
      expect(found.title, title, reason: words);
      expect(found.ambiguousTime, isFalse, reason: words);
      if (hour == null) {
        expect(found.hasTime, isFalse, reason: words);
      } else {
        expect(found.hasTime, isTrue, reason: words);
        expect(found.date, DateTime(day.year, day.month, day.day, hour, minute),
            reason: words);
      }
      // The local result the sheet shows: no question to answer.
      final draft = localDrafts(words, wednesday).single;
      expect(draft.clarifications, isEmpty, reason: words);
      expect(draft.task.title.toLowerCase(), title.toLowerCase(),
          reason: words);
    }

    test(
        "UX-604: 'Llamar a mamá mañana por la mañana' is Thursday 15 Oct with no time, titled 'Llamar a mamá por la mañana'",
        () {
      expectParsed('Llamar a mamá mañana por la mañana',
          day: DateTime(2026, 10, 15), title: 'Llamar a mamá por la mañana');
    });

    test(
        "UX-604: 'Médico el viernes por la mañana' is Friday 16 Oct with no time, titled 'Médico por la mañana'",
        () {
      expectParsed('Médico el viernes por la mañana',
          day: DateTime(2026, 10, 16), title: 'Médico por la mañana');
    });

    test(
        "UX-604: 'Llamar a Juan por la mañana' and 'Llamar a Juan esta mañana' get no date and keep every word",
        () {
      for (final words in [
        'Llamar a Juan por la mañana',
        'Llamar a Juan esta mañana',
      ]) {
        final found = QuickScheduleParser.parse(words, wednesday);
        expect(found, isNull, reason: words);
        final task = localDrafts(words, wednesday).single.task;
        expect(task.dueDate, isNull, reason: words);
        expect(task.title, words, reason: words);
      }
    });

    test(
        "UX-604: 'pasado mañana', 'demà passat', 'passat demà' and 'the day after tomorrow' are Friday 16 Oct and leave the title",
        () {
      final cases = {
        'Recoger el coche pasado mañana': 'Recoger el coche',
        'Recollir el cotxe demà passat': 'Recollir el cotxe',
        'Recollir el cotxe passat demà': 'Recollir el cotxe',
        'Pick up the car the day after tomorrow': 'Pick up the car',
      };
      for (final MapEntry(key: words, value: title) in cases.entries) {
        expectParsed(words, day: DateTime(2026, 10, 16), title: title);
      }
    });

    test(
        "UX-604: 'a las 5 de la tarde' and 'por la tarde a las 5' are 17:00 with no question, titled 'Médico'",
        () {
      for (final words in [
        'Médico el viernes a las 5 de la tarde',
        'Médico el viernes por la tarde a las 5',
      ]) {
        expectParsed(words,
            day: DateTime(2026, 10, 16), hour: 17, title: 'Médico');
      }
    });

    test(
        "UX-604: 'tomorrow morning at 9' and 'demà al matí a les 9' are Thursday 09:00",
        () {
      expectParsed('Call Ana tomorrow morning at 9',
          day: DateTime(2026, 10, 15), hour: 9, title: 'Call Ana');
      expectParsed('Trucar a la Marta demà al matí a les 9',
          day: DateTime(2026, 10, 15), hour: 9, title: 'Trucar a la Marta');
    });

    test(
        "UX-604: 'a las 9 de la noche' is 21:00 and 'a les 8 del vespre' is 20:00",
        () {
      expectParsed('Cena el viernes a las 9 de la noche',
          day: DateTime(2026, 10, 16), hour: 21, title: 'Cena');
      expectParsed('Sopar divendres a les 8 del vespre',
          day: DateTime(2026, 10, 16), hour: 20, title: 'Sopar');
    });

    test(
        "UX-604: 'a las 2 de la noche' and 'a las 12 de la mañana' still ask, offering both hours",
        () {
      final night = QuickScheduleParser.parse(
          'Tren el viernes a las 2 de la noche', wednesday)!;
      expect(night.ambiguousTime, isTrue);
      expect(night.hasTime, isFalse);
      expect(dayOf(night.date), DateTime(2026, 10, 16));
      final question = localDrafts('Tren el viernes a las 2 de la noche', wednesday)
          .single
          .clarifications
          .single;
      expect(question.times, ['02:00', '14:00']);

      final noon = QuickScheduleParser.parse(
          'Comida el viernes a las 12 de la mañana', wednesday)!;
      expect(noon.ambiguousTime, isTrue);
      expect(noon.hasTime, isFalse);
      expect(
          localDrafts('Comida el viernes a las 12 de la mañana', wednesday)
              .single
              .clarifications,
          isNotEmpty);
    });

    test("UX-604: 'a las 5:30 de la tarde' is 17:30, titled 'Médico'", () {
      expectParsed('Médico el viernes a las 5:30 de la tarde',
          day: DateTime(2026, 10, 16), hour: 17, minute: 30, title: 'Médico');
    });

    test(
        "UX-604, unchanged: 'a las 5' alone still asks (05:00 / 17:00); 'a las 17' is 17:00",
        () {
      final five =
          QuickScheduleParser.parse('Médico el viernes a las 5', wednesday)!;
      expect(five.ambiguousTime, isTrue);
      expect(five.hasTime, isFalse);
      expect(
          localDrafts('Médico el viernes a las 5', wednesday)
              .single
              .clarifications
              .single
              .times,
          ['05:00', '17:00']);
      expectParsed('Médico el viernes a las 17',
          day: DateTime(2026, 10, 16), hour: 17, title: 'Médico');
    });
  });
  // ---- 2026-10-14-speed round 2 · P107 (UX-618): a passed time with no date
  // word goes on the next day ----

  group('a time that has already passed (P107)', () {
    // Wednesday 14 October 2026.
    DateTime at(int hour, [int minute = 0]) =>
        DateTime(2026, 10, 14, hour, minute);

    void expectTimed(
      String words,
      DateTime reference, {
      required DateTime date,
      required String title,
      DateTime? day,
    }) {
      final found = QuickScheduleParser.parse(words, reference, day: day);
      expect(found, isNotNull, reason: words);
      expect(found!.date, date, reason: words);
      expect(found.hasTime, isTrue, reason: words);
      expect(found.ambiguousTime, isFalse, reason: words);
      expect(found.ambiguousHour, isNull, reason: words);
      expect(found.title, title, reason: words);
      // On the phone: no question to answer, so Guardar tal cual saves it.
      final draft = localDrafts(words, reference, defaultDay: day).single;
      expect(draft.clarifications, isEmpty, reason: words);
      expect(draft.task.dueDate, date, reason: words);
      expect(draft.task.title, title, reason: words);
    }

    test(
        "UX-618: at 10:00, 'Llamar a Juan a las 9 de la mañana' is Thursday 15 Oct 09:00 with no question",
        () {
      expectTimed('Llamar a Juan a las 9 de la mañana', at(10),
          date: DateTime(2026, 10, 15, 9), title: 'Llamar a Juan');
    });

    test(
        "UX-618: at 10:00, 'Llamar a Juan a las 5 de la tarde' stays today, Wednesday 14 Oct 17:00",
        () {
      expectTimed('Llamar a Juan a las 5 de la tarde', at(10),
          date: DateTime(2026, 10, 14, 17), title: 'Llamar a Juan');
    });

    test(
        "UX-618: at 18:00, 'a las 17', 'at 9:30 am' and 'a les 9 del matí' go on Thursday 15 Oct",
        () {
      expectTimed('Llamar al médico a las 17', at(18),
          date: DateTime(2026, 10, 15, 17), title: 'Llamar al médico');
      expectTimed('Call Ana at 9:30 am', at(18),
          date: DateTime(2026, 10, 15, 9, 30), title: 'Call Ana');
      expectTimed('Trucar a la Marta a les 9 del matí', at(18),
          date: DateTime(2026, 10, 15, 9), title: 'Trucar a la Marta');
    });

    test(
        "UX-618: at 10:00, 'a las 10' still asks 10:00 / 22:00 on Wednesday; 'a las 10:00' (the same minute) stays today",
        () {
      final ten =
          QuickScheduleParser.parse('Llamar a Juan a las 10', at(10))!;
      expect(ten.ambiguousHour, 10);
      expect(ten.hasTime, isFalse);
      expect(
          DateTime(ten.date.year, ten.date.month, ten.date.day),
          DateTime(2026, 10, 14));
      final question = localDrafts('Llamar a Juan a las 10', at(10))
          .single
          .clarifications
          .single;
      expect(question.times, ['10:00', '22:00']);

      expectTimed('Llamar a Juan a las 10:00', at(10),
          date: DateTime(2026, 10, 14, 10), title: 'Llamar a Juan');
      // Seconds past the minute don't make the same minute "passed".
      expectTimed('Llamar a Juan a las 10:00', DateTime(2026, 10, 14, 10, 0, 45),
          date: DateTime(2026, 10, 14, 10), title: 'Llamar a Juan');
    });

    test(
        "UX-618: a date word wins ('hoy a las 9 de la mañana' stays Wednesday 09:00), and so does a picked day (Friday 16 Oct)",
        () {
      final today = QuickScheduleParser.parse(
          'Llamar a Juan hoy a las 9 de la mañana', at(10))!;
      expect(today.date, DateTime(2026, 10, 14, 9));
      expect(today.hasTime, isTrue);
      expect(today.title, 'Llamar a Juan');

      expectTimed('Llamar a Juan a las 9 de la mañana', at(10),
          day: DateTime(2026, 10, 16),
          date: DateTime(2026, 10, 16, 9),
          title: 'Llamar a Juan');
    });

    test(
        "UX-618: at 23:30 on Saturday 31 Oct, 'Cena a las 9 de la noche' is Sunday 1 Nov 21:00",
        () {
      expectTimed('Cena a las 9 de la noche', DateTime(2026, 10, 31, 23, 30),
          date: DateTime(2026, 11, 1, 21), title: 'Cena');
    });

    test(
        'UX-618: at the 23:58 reference, a time with no date word goes on 23 Sep',
        () {
      expectTimed('Llamar al médico a las 17', reference,
          date: DateTime(2026, 9, 23, 17), title: 'Llamar al médico');
    });
  });
}
