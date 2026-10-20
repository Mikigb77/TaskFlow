import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/task.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScheduleChoice {
  const ScheduleChoice(this.date, this.hasTime, {this.scope = 'series'});
  final DateTime? date;
  final bool hasTime;

  /// What a move changes: `series` (also any task that doesn't repeat),
  /// `occurrence`, or `skip` / `reset` for one occurrence.
  final String scope;
}

/// [moving] is the task "Cambiar fecha" moves: Hoy, Mañana and Sin fecha
/// then apply at once, and a repeating task chooses this occurrence or the
/// whole series. [applyDays] makes those chips apply at once without a move,
/// as on the capture result. Otherwise (the edit form) they only select.
/// [dayOnly] is the new-task form's «Elegir día»: only a day, with no time
/// and no «Listo»; a day tapped, in the chips or the calendar, applies at
/// once.
Future<ScheduleChoice?> editSchedule(
  BuildContext context, {
  DateTime? date,
  required bool hasTime,
  String? title,
  Task? moving,
  bool applyDays = false,
  bool dayOnly = false,
}) => showModalBottomSheet<ScheduleChoice>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ScheduleEditor(
    date: date,
    hasTime: hasTime,
    title: title,
    moving: moving,
    applyDays: applyDays,
    dayOnly: dayOnly,
  ),
);

class _ScheduleEditor extends StatefulWidget {
  const _ScheduleEditor({
    this.date,
    required this.hasTime,
    this.title,
    this.moving,
    this.applyDays = false,
    this.dayOnly = false,
  });
  final DateTime? date;
  final bool hasTime;
  final String? title;
  final Task? moving;
  final bool applyDays;
  final bool dayOnly;
  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  late String _scope = widget.moving?.isRecurring ?? false
      ? 'occurrence'
      : 'series';
  DateTime? _day;
  bool _hasTime = false;
  final _hour = TextEditingController();
  final _minute = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _periodRow = GlobalKey();
  final _calendarBox = GlobalKey();
  bool? _clock24;
  // Null until chosen when there was no time, so 5 never becomes 5 a. m.
  bool? _pm;
  bool _missingDate = false;
  bool _missingPeriod = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_clock24 != null) return;
    _clock24 = MediaQuery.alwaysUse24HourFormatOf(context);
    _load(widget.date, widget.hasTime && !widget.dayOnly);
  }

  void _load(DateTime? date, bool hasTime) {
    _day = date == null ? null : Task.day(date);
    _hasTime = hasTime && date != null;
    _pm = _hasTime ? date!.hour >= 12 : null;
    final h = date?.hour ?? 0;
    _hour.text = !_hasTime
        ? ''
        : '${_clock24!
              ? h
              : h % 12 == 0
              ? 12
              : h % 12}';
    _minute.text = _hasTime ? date!.minute.toString().padLeft(2, '0') : '';
  }

  void _setScope(String scope) {
    final task = widget.moving!;
    setState(() {
      _scope = scope;
      _missingDate = false;
      _missingPeriod = false;
      if (scope == 'series') {
        _load(task.dueDate, task.seriesHasTime);
      } else {
        _load(task.displayDate, task.hasTime);
      }
    });
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

  /// Whether the calendar shows its year grid. A year pick is the only change
  /// the calendar reports while that grid is still mounted.
  bool _yearGridShown() {
    var found = false;
    void visit(Element element) {
      if (found) return;
      if (element.widget is YearPicker) {
        found = true;
        return;
      }
      element.visitChildElements(visit);
    }

    (_calendarBox.currentContext as Element?)?.visitChildElements(visit);
    return found;
  }

  void _done() {
    if (_hasTime && _day == null) {
      setState(() => _missingDate = true);
      return;
    }
    // With no time there is nothing in the form to check; the hour field
    // may still be mounted until the next frame after `Sin fecha`.
    final valid = !_hasTime || _form.currentState!.validate();
    final missingPeriod = _hasTime && !_clock24! && _pm == null;
    setState(() => _missingPeriod = missingPeriod);
    if (missingPeriod) {
      // The keyboard hides the a. m./p. m. chips; drop it and show them.
      FocusScope.of(context).unfocus();
      final animate = !MediaQuery.disableAnimationsOf(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final row = _periodRow.currentContext;
        if (!mounted || row == null) return;
        Scrollable.ensureVisible(
          row,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
        );
      });
    }
    if (!valid || missingPeriod) return;
    var date = _day;
    if (_hasTime && date != null) {
      var hour = int.parse(_hour.text);
      if (!_clock24!) hour = hour % 12 + (_pm! ? 12 : 0);
      date = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        // An empty minutes box means on the hour.
        int.tryParse(_minute.text) ?? 0,
      );
    }
    Navigator.pop(
      context,
      ScheduleChoice(date, _hasTime && date != null, scope: _scope),
    );
  }

  void _setPeriod(bool pm) => setState(() {
    _pm = pm;
    _missingPeriod = false;
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final material = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final today = Task.day(now);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final moving = widget.moving;
    final repeating = moving?.isRecurring ?? false;
    // An occurrence can be moved or skipped, not undated.
    final occurrence = repeating && _scope == 'occurrence';
    final error = TextStyle(color: Theme.of(context).colorScheme.error);
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
                          widget.title ??
                              (widget.dayOnly ? l.pickDay : l.reviewSchedule),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (repeating) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final scope in ['occurrence', 'series'])
                                ChoiceChip(
                                  label: Text(
                                    scope == 'occurrence'
                                        ? l.thisOccurrence
                                        : l.wholeSeries,
                                  ),
                                  selected: _scope == scope,
                                  onSelected: (_) => _setScope(scope),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            occurrence
                                ? l.occurrenceRescheduleHelp
                                : l.seriesRescheduleHelp,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final entry in [
                              (l.today, today),
                              (l.tomorrow, tomorrow),
                              if (!occurrence) (l.noDate, null),
                            ])
                              ChoiceChip(
                                label: Text(entry.$1),
                                selected: _day == entry.$2,
                                onSelected: (_) {
                                  _select(entry.$2);
                                  // Moving, or fixing a capture result: every
                                  // day chip applies at once (Hoy and Mañana
                                  // keep the time). In the edit form a time
                                  // often follows, so they only select.
                                  if (moving != null ||
                                      widget.applyDays ||
                                      widget.dayOnly) {
                                    _done();
                                  }
                                },
                              ),
                          ],
                        ),
                        // Next to the days, so it shows without scrolling.
                        if (occurrence) ...[
                          TextButton.icon(
                            key: const ValueKey('schedule-skip'),
                            onPressed: () => Navigator.pop(
                              context,
                              const ScheduleChoice(null, false, scope: 'skip'),
                            ),
                            icon: const Icon(Icons.event_busy_outlined),
                            label: Text(l.skipOccurrence),
                          ),
                          if (moving!.exceptions.any(
                            (change) =>
                                change.originalDate == moving.occurrenceId,
                          ))
                            TextButton(
                              key: const ValueKey('schedule-restore'),
                              onPressed: () => Navigator.pop(
                                context,
                                const ScheduleChoice(
                                  null,
                                  false,
                                  scope: 'reset',
                                ),
                              ),
                              child: Text(l.restoreOriginal),
                            ),
                        ],
                        KeyedSubtree(
                          key: _calendarBox,
                          child: CalendarDatePicker(
                            key: ValueKey('schedule-calendar-$_day'),
                            // The calendar and time validation must share the
                            // same selection, including an explicit "No date".
                            initialDate: _day,
                            firstDate: pickerFirstDate(_day),
                            lastDate: pickerLastDate(_day),
                            onDateChanged: (day) {
                              if (!widget.dayOnly) {
                                _select(day);
                                return;
                              }
                              // A year pick only moves the calendar to that
                              // year; a tapped day applies and closes.
                              if (_yearGridShown()) return;
                              _select(day);
                              _done();
                            },
                          ),
                        ),
                        if (!widget.dayOnly)
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
                          Text(l.reviewChooseDate, style: error),
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
                                    errorMaxLines: 3,
                                  ),
                                  validator: (value) {
                                    final number = int.tryParse(value ?? '');
                                    return number == null ||
                                            number < (_clock24! ? 0 : 1) ||
                                            number > (_clock24! ? 23 : 12)
                                        ? (_clock24!
                                              ? l.scheduleHourRange24
                                              : l.scheduleHourRange12)
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
                                    errorMaxLines: 3,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return null;
                                    }
                                    final number = int.tryParse(value);
                                    return number == null ||
                                            number < 0 ||
                                            number > 59
                                        ? l.scheduleMinuteRange
                                        : null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          Column(
                            key: _periodRow,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                        selected: _pm == false,
                                        onSelected: (_) => _setPeriod(false),
                                      ),
                                      ChoiceChip(
                                        label: Text(
                                          material.postMeridiemAbbreviation,
                                        ),
                                        selected: _pm == true,
                                        onSelected: (_) => _setPeriod(true),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_missingPeriod)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(l.chooseAmPm, style: error),
                                  ),
                                ),
                            ],
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
                    if (!widget.dayOnly)
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
