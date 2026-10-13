import 'package:agenda/models/task.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:agenda/l10n/region.dart';

String taskScheduleLabel(Task task,
    {bool showDate = true, BuildContext? context}) {
  final date = task.displayDate;
  if (context != null) {
    if (date == null) return '${context.l10n.inbox} · ${context.l10n.noDate}';
    final time = task.hasTime ? context.clockTime(date) : context.l10n.anyTime;
    return showDate ? '${context.dayLabel(date)} · $time' : time;
  }
  if (date == null) return 'Inbox · No date';
  if (!task.hasTime) {
    return showDate
        ? '${DateFormat('d MMM').format(date)} · Any time'
        : 'Any time';
  }
  return DateFormat(showDate ? 'd MMM · HH:mm' : 'HH:mm').format(date);
}
