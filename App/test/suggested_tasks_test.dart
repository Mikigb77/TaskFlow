// «Tareas sugeridas» (the owner, 2026-11-06): which drafted tasks start
// ticked, and the server's `sure` read back.
import 'package:agenda/models/meeting.dart';
import 'package:agenda/widgets/suggested_tasks_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a to-do for nobody named, or for the person, starts ticked', () {
    const task = MeetingTask(title: 'Enviar el presupuesto');
    expect(suggestedTaskTicked(task, ''), isTrue);
    expect(suggestedTaskTicked(task, 'Miki'), isTrue);
    expect(
      suggestedTaskTicked(
        const MeetingTask(title: 'Enviar el presupuesto', who: 'miki'),
        'Miki',
      ),
      isTrue,
    );
    // The speaker as the server writes them: their own.
    for (final me in ['yo', 'I', 'jo']) {
      expect(
        suggestedTaskTicked(MeetingTask(title: 'Llamar', who: me), ''),
        isTrue,
        reason: me,
      );
    }
    // No task the server wrote for the line: ticked, as before.
    expect(suggestedTaskTicked(null, 'Miki'), isTrue);
  });

  test('a maybe, or a task for someone else, starts unticked', () {
    expect(
      suggestedTaskTicked(
        const MeetingTask(title: 'Mirar las fechas', sure: false),
        'Miki',
      ),
      isFalse,
    );
    expect(
      suggestedTaskTicked(
        const MeetingTask(title: 'Revisar el contrato', who: 'Ana'),
        'Miki',
      ),
      isFalse,
    );
    // Without the account's name, someone named is someone else.
    expect(
      suggestedTaskTicked(
        const MeetingTask(title: 'Revisar el contrato', who: 'Ana'),
        '',
      ),
      isFalse,
    );
  });

  test('`sure` round-trips, and a result from before it reads as sure', () {
    final floated = MeetingTask.fromJson({
      'title': 'Mirar las fechas',
      'sure': false,
    })!;
    expect(floated.sure, isFalse);
    expect(MeetingTask.fromJson(floated.toJson())!.sure, isFalse);
    expect(MeetingTask.fromJson({'title': 'Llamar a Ana'})!.sure, isTrue);
  });
}
