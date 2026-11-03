import 'package:collection/collection.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/occurrence_exception.dart';

class OccurrenceChange {
  final Task series;
  final String key;
  final OccurrenceException? before;
  final OccurrenceException? after;
  const OccurrenceChange(this.series, this.key, this.before, this.after);
  bool canUndo(Task current) {
    final value = current.exceptions
        .where((change) => change.originalDate == key)
        .firstOrNull;
    return current.id == series.id &&
        current.dueDate == series.dueDate &&
        current.hasTime == series.hasTime &&
        current.recurrence == series.recurrence &&
        current.repeatInterval == series.repeatInterval &&
        current.repeatUntil == series.repeatUntil &&
        const ListEquality<int>()
            .equals(current.repeatWeekdays, series.repeatWeekdays) &&
        (after == null ? value == null : after!.sameAs(value));
  }

  Task restore(Task current) => current.copyWith(exceptions: [
        ...current.exceptions.where((change) => change.originalDate != key),
        ?before,
      ]);
}
