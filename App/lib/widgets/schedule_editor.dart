import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/task.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScheduleChoice {
  const ScheduleChoice(this.date, this.hasTime);
  final DateTime? date;
  final bool hasTime;
}

Future<ScheduleChoice?> editSchedule(
  BuildContext context, {
  DateTime? date,
  required bool hasTime,
  String? title,
}) => showModalBottomSheet<ScheduleChoice>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ScheduleEditor(date: date, hasTime: hasTime, title: title),
);

class _ScheduleEditor extends StatefulWidget {
  const _ScheduleEditor({this.date, required this.hasTime, this.title});
  final DateTime? date;
  final bool hasTime;
  final String? title;
  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  late DateTime? _day = widget.date == null ? null : Task.day(widget.date!);
  late bool _hasTime = widget.hasTime && _day != null;
  final _hour = TextEditingController();
  final _minute = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool? _clock24;
  late bool _pm = (widget.date?.hour ?? 0) >= 12;
  bool _missingDate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final clock = MediaQuery.alwaysUse24HourFormatOf(context);
    if (_clock24 == null && _hasTime) {
      final h = widget.date!.hour;
      _hour.text =
          '${clock
              ? h
              : h % 12 == 0
              ? 12
              : h % 12}';
      _minute.text = widget.date!.minute.toString().padLeft(2, '0');
    }
    _clock24 ??= clock;
  }

  @override
  void dispose() {
    _hour.dispose();
    _minute.dispose();
    super.dispose();
  }

  void _select(DateTime? day) => setState(() {
    _day = day;
    _missingDate = false;
    if (day == null) _hasTime = false;
  });

  void _done() {
    if (_hasTime && _day == null) {
      setState(() => _missingDate = true);
      return;
    }
    if (!_form.currentState!.validate()) return;
    var date = _day;
    if (_hasTime && date != null) {
      var hour = int.parse(_hour.text);
      if (!_clock24!) hour = hour % 12 + (_pm ? 12 : 0);
      date = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        int.parse(_minute.text),
      );
    }
    Navigator.pop(context, ScheduleChoice(date, _hasTime && date != null));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final material = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final today = Task.day(now);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title ?? l.reviewSchedule,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final entry in [
                              (l.today, today),
                              (l.tomorrow, tomorrow),
                              (l.noDate, null),
                            ])
                              ChoiceChip(
                                label: Text(entry.$1),
                                selected: _day == entry.$2,
                                onSelected: (_) => _select(entry.$2),
                              ),
                          ],
                        ),
                        CalendarDatePicker(
                          key: ValueKey('schedule-calendar-$_day'),
                          // The calendar and time validation must share the
                          // same selection, including an explicit "No date".
                          initialDate: _day,
                          firstDate: pickerFirstDate(_day),
                          lastDate: pickerLastDate(_day),
                          onDateChanged: _select,
                        ),
                        SwitchListTile.adaptive(
                          key: const ValueKey('schedule-has-time'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.addTime),
                          value: _hasTime,
                          subtitle: _hasTime ? null : Text(l.anyTime),
                          onChanged: (value) =>
                              setState(() => _hasTime = value),
                        ),
                        if (_missingDate)
                          Text(
                            l.reviewChooseDate,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        if (_hasTime) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  key: const ValueKey('schedule-hour'),
                                  controller: _hour,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(2),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: material.timePickerHourLabel,
                                  ),
                                  validator: (value) {
                                    final number = int.tryParse(value ?? '');
                                    return number == null ||
                                            number < (_clock24! ? 0 : 1) ||
                                            number > (_clock24! ? 23 : 12)
                                        ? l.reviewInvalidTime
                                        : null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  key: const ValueKey('schedule-minute'),
                                  controller: _minute,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(2),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: material.timePickerMinuteLabel,
                                  ),
                                  validator: (value) {
                                    final number = int.tryParse(value ?? '');
                                    return number == null ||
                                            number < 0 ||
                                            number > 59
                                        ? l.reviewInvalidTime
                                        : null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (!_clock24!)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Wrap(
                                spacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: Text(
                                      material.anteMeridiemAbbreviation,
                                    ),
                                    selected: !_pm,
                                    onSelected: (_) =>
                                        setState(() => _pm = false),
                                  ),
                                  ChoiceChip(
                                    label: Text(
                                      material.postMeridiemAbbreviation,
                                    ),
                                    selected: _pm,
                                    onSelected: (_) =>
                                        setState(() => _pm = true),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.cancel),
                    ),
                    FilledButton(
                      key: const ValueKey('schedule-done'),
                      onPressed: _done,
                      child: Text(l.done),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
