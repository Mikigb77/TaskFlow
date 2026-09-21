import 'package:agenda/models/task.dart';
import 'package:intl/intl.dart';

String taskScheduleLabel(Task task, {bool showDate = true}) {
  final date = task.displayDate;
  if (date == null) return 'Inbox · No date';
  if (!task.hasTime) {
    return showDate
        ? '${DateFormat('d MMM').format(date)} · Any time'
        : 'Any time';
  }
  return DateFormat(showDate ? 'd MMM · HH:mm' : 'HH:mm').format(date);
}
