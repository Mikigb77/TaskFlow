import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/utils/constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/task_provider.dart';

class EditTaskScreen extends ConsumerWidget {
  final int taskId;

  const EditTaskScreen({
    super.key,
    required this.taskId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskProvider);
    final taskNotifier = ref.read(taskProvider.notifier);

    return taskState.when(
      data: (tasks) {
        final task = tasks.firstWhere((task) => task.id == taskId);

        final formKey = GlobalKey<FormState>();
        late String title = task.title;
        DateTime? dueDate = task.dueDate;
        late int priority = task.priority;
        String? notes = task.notes;

        void submitTask() {
          if (formKey.currentState!.validate()) {
            formKey.currentState!.save();
            final updatedTask = Task(
              id: task.id,
              title: title,
              dueDate: dueDate!,
              priority: priority,
              notes: notes,
              isCompleted: task.isCompleted,
            );
            taskNotifier.updateTask(updatedTask);
            Navigator.of(context).pop();
          }
        }

        void pickDueDateTime() async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: dueDate ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2101),
            builder: (context, child) {
              return Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: accentColor,
                    onPrimary: Colors.black,
                    surface: cardColor,
                    onSurface: textColor,
                  ),
                  dialogBackgroundColor: defaultBackgroundColor,
                ),
                child: child!,
              );
            },
          );

          if (pickedDate != null) {
            TimeOfDay? pickedTime = await showTimePicker(
              // ignore: use_build_context_synchronously
              context: context,
              initialTime: TimeOfDay.fromDateTime(dueDate ?? DateTime.now()),
              builder: (context, child) {
                return Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: accentColor,
                      onPrimary: Colors.black,
                      surface: cardColor,
                      onSurface: textColor,
                    ),
                    dialogBackgroundColor: defaultBackgroundColor,
                  ),
                  child: child!,
                );
              },
            );

            if (pickedTime != null) {
              dueDate = DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime.hour,
                pickedTime.minute,
              );
            }
          }
        }

        return Scaffold(
          appBar: const CustomAppBar(title: "Edit Task"),
          backgroundColor: defaultBackgroundColor,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    initialValue: title,
                    decoration: InputDecoration(
                      labelText: 'Task Title',
                      labelStyle: TextStyle(color: subtitleTextColor),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: textColor),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a task title';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      title = value!;
                    },
                  ),
                  const SizedBox(height: 20.0),
                  GestureDetector(
                    onTap: pickDueDateTime,
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Due Date & Time',
                          labelStyle: TextStyle(color: subtitleTextColor),
                          filled: true,
                          fillColor: cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(color: textColor),
                        controller: TextEditingController(
                          text: dueDate != null
                              ? '${dueDate!.toLocal()}'.split('.')[0]
                              : '',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  DropdownButtonFormField<int>(
                    value: priority,
                    decoration: InputDecoration(
                      labelText: 'Priority',
                      labelStyle: TextStyle(color: subtitleTextColor),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: subtitleTextColor),
                    items: const [
                      DropdownMenuItem(
                          value: 1,
                          child: Text('Low',
                              style: TextStyle(
                                color: Colors.grey,
                              ))),
                      DropdownMenuItem(
                          value: 2,
                          child: Text('Medium',
                              style: TextStyle(
                                color: Colors.grey,
                              ))),
                      DropdownMenuItem(
                          value: 3,
                          child: Text('High',
                              style: TextStyle(
                                color: Colors.grey,
                              ))),
                    ],
                    onChanged: (value) {
                      priority = value!;
                    },
                  ),
                  const SizedBox(height: 20.0),
                  TextFormField(
                    initialValue: notes,
                    decoration: InputDecoration(
                      labelText: 'Additional Notes',
                      labelStyle: TextStyle(color: subtitleTextColor),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: textColor),
                    maxLines: 3, // Allow multiple lines for notes
                    onSaved: (value) {
                      notes = value;
                    },
                  ),
                  const SizedBox(height: 30.0),
                  Center(
                    child: ElevatedButton(
                      onPressed: submitTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30.0, vertical: 15.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      child: const Text(
                        'Update Task',
                        style: TextStyle(fontSize: 16.0, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(
          'Error: $error',
          style: const TextStyle(color: Colors.red, fontSize: 18),
        ),
      ),
    );
  }
}
