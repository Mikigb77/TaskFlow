import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/utils/constants.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late final ValueNotifier<DateTime> _selectedDay;
  late final ValueNotifier<List<Task>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = ValueNotifier(DateTime.now());
    _selectedEvents = ValueNotifier([]);
    _loadSelectedDayEvents();
  }

  void _loadSelectedDayEvents() {
    final tasksAsyncValue = ref.read(taskProvider);
    tasksAsyncValue.when(
      data: (tasks) {
        _selectedEvents.value = tasks
            .where((task) => isSameDay(task.dueDate, _selectedDay.value))
            .toList();
      },
      loading: () {},
      error: (error, stackTrace) {},
    );
  }

  List<Task> _getTasksForDay(DateTime day) {
    final tasksAsyncValue = ref.watch(taskProvider);
    return tasksAsyncValue.when(
      data: (tasks) =>
          tasks.where((task) => isSameDay(task.dueDate, day)).toList(),
      loading: () => [],
      error: (error, stackTrace) => [],
    );
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay.value = selectedDay;
      _selectedEvents.value = _getTasksForDay(selectedDay);
    });
  }

  void _toggleTaskCompletion(Task task) {
    final taskNotifier = ref.read(taskProvider.notifier);
    final updatedTask = task.copyWith(isCompleted: !task.isCompleted);
    taskNotifier.updateTask(updatedTask);
    setState(() {
      _selectedEvents.value = _selectedEvents.value.map((t) {
        if (t.id == task.id) {
          return updatedTask;
        }
        return t;
      }).toList();
    });
  }

  Color _getMarkerColorForTask(Task task) {
    if (task.isCompleted) {
      return Colors.green[700]!; // Green for completed tasks
    } else {
      switch (task.priority) {
        case 1:
          return Colors.blueGrey[700]!;
        case 2:
          return Colors.amber[700]!;
        case 3:
          return Colors.deepOrange[900]!;
        default:
          return Colors.grey[700]!; // Fallback for any unexpected cases
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(taskProvider, (previous, next) {
      _loadSelectedDayEvents(); // Reload events when the taskProvider changes
    });

    return Scaffold(
      appBar: const CustomAppBar(title: "Calendar"),
      backgroundColor: defaultBackgroundColor,
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2010, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: _selectedDay.value,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay.value, day),
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            eventLoader: _getTasksForDay,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: const TextStyle(color: Colors.white),
              weekendTextStyle: const TextStyle(color: Colors.redAccent),
              todayDecoration: BoxDecoration(
                color: Colors.deepPurple[400],
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blueGrey[600],
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              markersAlignment: Alignment.bottomCenter,
              markersMaxCount: 3,
              markerSizeScale: 0.2,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, tasks) {
                final taskList = tasks.cast<Task>();
                if (taskList.isNotEmpty) {
                  return Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4.0,
                    children: taskList.map((task) {
                      return Container(
                        width: 5.0,
                        height: 5.0,
                        decoration: BoxDecoration(
                          color: _getMarkerColorForTask(task),
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  );
                }
                return null;
              },
            ),
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              titleTextStyle:
                  const TextStyle(color: Colors.white, fontSize: 16),
              leftChevronIcon:
                  const Icon(Icons.chevron_left, color: Colors.white),
              rightChevronIcon:
                  const Icon(Icons.chevron_right, color: Colors.white),
              decoration: BoxDecoration(color: Colors.grey[800]),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: Colors.white70),
              weekendStyle: TextStyle(color: Colors.redAccent),
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: ValueListenableBuilder<List<Task>>(
              valueListenable: _selectedEvents,
              builder: (context, events, _) {
                if (events.isEmpty) {
                  return const Center(
                    child: Text(
                      'No tasks for the selected day.',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final task = events[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border(
                          left: BorderSide(
                            color: _getMarkerColorForTask(task),
                            width: 4.0,
                          ),
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(
                          _getMarkerColorForTask(task) == Colors.green[700]!
                              ? Icons.check
                              : _getPriorityIcon(task.priority),
                          color: _getMarkerColorForTask(task),
                        ),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            color: task.isCompleted ? Colors.grey : textColor,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        subtitle: Text(
                          task.notes ?? '',
                          style: TextStyle(color: subtitleTextColor),
                        ),
                        trailing: Checkbox(
                          value: task.isCompleted,
                          onChanged: (bool? value) {
                            _toggleTaskCompletion(task);
                          },
                          activeColor: Colors.green[700],
                          checkColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/taskDetails',
                            arguments: task.id,
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/createTask',
            arguments: _selectedDay.value,
          );
        },
        backgroundColor: Colors.deepPurple[400],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _selectedDay.dispose();
    _selectedEvents.dispose();
    super.dispose();
  }

  IconData _getPriorityIcon(int priority) {
    switch (priority) {
      case 1:
        return Icons.low_priority;
      case 2:
        return Icons.flag;
      case 3:
        return Icons.priority_high;
      default:
        return Icons.label;
    }
  }
}
