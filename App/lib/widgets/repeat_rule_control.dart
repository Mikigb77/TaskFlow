import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:agenda/models/task.dart';
import 'package:intl/intl.dart';

class RepeatRuleControl extends StatelessWidget {
  final String recurrence;
  final int interval;
  final List<int> weekdays;
  final void Function(int, List<int>) onChanged;
  const RepeatRuleControl(
      {super.key,
      required this.recurrence,
      required this.interval,
      required this.weekdays,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final unit = switch (recurrence) {
      'daily' => context.l10n.days,
      'weekly' => context.l10n.weeks,
      'monthly' => context.l10n.months,
      _ => context.l10n.years,
    };
    final names = List.generate(
        7,
        (i) =>
            DateFormat.E(context.localeName).format(DateTime(2024, 1, 1 + i)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.repeatEvery(interval, unit)),
          subtitle: Text(context.l10n.repeatInterval),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () async {
            var value = interval.toString();
            final form = GlobalKey<FormState>();
            final result = await showDialog<int>(
                context: context,
                builder: (context) => AlertDialog(
                        scrollable: true,
                        title: Text(context.l10n.repeatEveryPrompt(unit)),
                        content: Form(
                            key: form,
                            child: TextFormField(
                                key: const ValueKey('repeat-interval'),
                                initialValue: value,
                                autofocus: true,
                                keyboardType: TextInputType.number,
                                onChanged: (text) => value = text,
                                validator: (text) {
                                  final number = int.tryParse(text ?? '');
                                  return number == null ||
                                          number < 1 ||
                                          number > 99
                                      ? context.l10n.intervalRange
                                      : null;
                                })),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(context.l10n.cancel)),
                          FilledButton(
                              onPressed: () {
                                if (form.currentState!.validate()) {
                                  Navigator.pop(context, int.parse(value));
                                }
                              },
                              child: Text(context.l10n.keepChanges))
                        ]));
            if (result != null) onChanged(result, weekdays);
          }),
      if (recurrence == 'weekly') ...[
        Text(context.l10n.repeatOn),
        Wrap(spacing: 6, children: [
          for (final day in List.generate(
              7,
              (offset) =>
                  (MaterialLocalizations.of(context).firstDayOfWeekIndex +
                          6 +
                          offset) %
                      7 +
                  1))
            FilterChip(
                label: Text(names[day - 1]),
                selected: weekdays.contains(day),
                onSelected: (selected) => onChanged(
                    interval,
                    [
                      ...weekdays.where((value) => value != day),
                      if (selected) day,
                    ]..sort()))
        ]),
        if (weekdays.isEmpty) Text(context.l10n.repeatUsesStart),
      ],
    ]);
  }
}

Future<Task?> editTaskRepeat(BuildContext context, Task task) =>
    showModalBottomSheet<Task>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _RepeatSheet(task: task));

class _RepeatSheet extends StatefulWidget {
  final Task task;
  const _RepeatSheet({required this.task});
  @override
  State<_RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<_RepeatSheet> {
  late Task _task = widget.task;
  @override
  Widget build(BuildContext context) => SafeArea(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.repeat,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                    initialValue: _task.recurrence,
                    isExpanded: true,
                    items: Task.repeats.entries
                        .map((entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(context.repeatName(entry.key))))
                        .toList(),
                    onChanged: (value) => setState(() => _task = _task.copyWith(
                        recurrence: value,
                        repeatInterval:
                            value == 'none' ? 1 : _task.repeatInterval,
                        repeatWeekdays:
                            value == 'weekly' ? _task.repeatWeekdays : [],
                        repeatUntil:
                            value == 'none' ? null : _task.repeatUntil))),
                if (_task.isRecurring) ...[
                  RepeatRuleControl(
                      recurrence: _task.recurrence,
                      interval: _task.repeatInterval,
                      weekdays: _task.repeatWeekdays,
                      onChanged: (interval, days) => setState(() => _task =
                          _task.copyWith(
                              repeatInterval: interval, repeatWeekdays: days))),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_task.repeatUntil == null
                          ? context.l10n.noEndDate
                          : context.l10n.untilDate(
                              context.shortDate(_task.repeatUntil!))),
                      trailing: _task.repeatUntil == null
                          ? null
                          : IconButton(
                              tooltip: context.l10n.removeEndDate,
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() =>
                                  _task = _task.copyWith(repeatUntil: null))),
                      onTap: () async {
                        final date = await showDatePicker(
                            context: context,
                            initialDate: _task.repeatUntil ?? _task.dueDate!,
                            firstDate: Task.day(_task.dueDate!),
                            lastDate: pickerLastDate(
                                _task.repeatUntil ?? _task.dueDate));
                        if (date != null && mounted) {
                          setState(
                              () => _task = _task.copyWith(repeatUntil: date));
                        }
                      }),
                ],
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: () => Navigator.pop(context, _task),
                    child: Text(context.l10n.done)),
              ])));
}
