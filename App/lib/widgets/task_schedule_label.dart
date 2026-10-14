import 'package:agenda/models/task.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:agenda/l10n/region.dart';

/// A capture result's main line: `Hoy · 17:00`, `Mañana`,
/// `vie, 17 oct · 17:00` or `Sin fecha`.
String taskDayLine(BuildContext context, Task task) {
  final date = task.displayDate;
  if (date == null) return context.l10n.noDate;
  final day = context.dayLabel(date);
  return task.hasTime ? '$day · ${context.clockTime(date)}' : day;
}

String taskScheduleLabel(Task task,
    {bool showDate = true, BuildContext? context}) {
  final date = task.displayDate;
  if (context != null) {
    if (date == null) return context.l10n.noDate;
    final time = task.hasTime ? context.clockTime(date) : context.l10n.anyTime;
    return showDate ? '${context.dayLabel(date)} · $time' : time;
  }
  if (date == null) return 'No date';
  if (!task.hasTime) {
    return showDate
        ? '${DateFormat('d MMM').format(date)} · Any time'
        : 'Any time';
  }
  return DateFormat(showDate ? 'd MMM · HH:mm' : 'HH:mm').format(date);
}
