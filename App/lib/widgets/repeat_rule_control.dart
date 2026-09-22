import 'package:flutter/material.dart';
import 'package:agenda/models/task.dart';

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
      'daily' => 'days',
      'weekly' => 'weeks',
      'monthly' => 'months',
      _ => 'years',
    };
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Every $interval $unit'),
          subtitle: const Text('Repeat interval'),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () async {
            var value = interval.toString();
            final form = GlobalKey<FormState>();
            final result = await showDialog<int>(
                context: context,
                builder: (context) => AlertDialog(
                        scrollable: true,
                        title: Text('Repeat every… $unit'),
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
                                      ? 'Choose a number from 1 to 99.'
                                      : null;
                                })),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () {
                                if (form.currentState!.validate()) {
                                  Navigator.pop(context, int.parse(value));
                                }
                              },
                              child: const Text('Keep changes'))
                        ]));
            if (result != null) onChanged(result, weekdays);
          }),
      if (recurrence == 'weekly') ...[
        const Text('Repeat on'),
        Wrap(spacing: 6, children: [
          for (var day = 1; day <= 7; day++)
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
        if (weekdays.isEmpty) const Text('Uses the weekday of the start date.'),
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
                Text('Repeat', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                    initialValue: _task.recurrence,
                    isExpanded: true,
                    items: Task.repeats.entries
                        .map((entry) => DropdownMenuItem(
                            value: entry.key, child: Text(entry.value)))
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
                          ? 'No end date'
                          : 'Until ${Task.dateKey(_task.repeatUntil!)}'),
                      trailing: _task.repeatUntil == null
                          ? null
                          : IconButton(
                              tooltip: 'Remove end date',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() =>
                                  _task = _task.copyWith(repeatUntil: null))),
                      onTap: () async {
                        final date = await showDatePicker(
                            context: context,
                            initialDate: _task.repeatUntil ?? _task.dueDate!,
                            firstDate: Task.day(_task.dueDate!),
                            lastDate: DateTime(2101));
                        if (date != null && mounted) {
                          setState(
                              () => _task = _task.copyWith(repeatUntil: date));
                        }
                      }),
                ],
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: () => Navigator.pop(context, _task),
                    child: const Text('Keep repeat')),
              ])));
}
