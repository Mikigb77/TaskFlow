import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/utils/constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:agenda/providers/task_provider.dart';

class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _CreateTaskScreenState createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  DateTime? _dueDate; // Keep this nullable to detect when it is unset
  int _priority = 1;
  String? _notes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final DateTime? selectedDate =
        ModalRoute.of(context)?.settings.arguments as DateTime?;
    // Set due date only if a selectedDate is passed
    if (selectedDate != null) {
      _dueDate = selectedDate;
    }
  }

  void _submitTask() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final newTask = Task(
        title: _title,
        dueDate: _dueDate!,
        priority: _priority,
        notes: _notes,
      );
      ref.read(taskProvider.notifier).addTask(newTask);
      Navigator.of(context).pop();
    }
  }

  void _pickDueDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
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
        initialTime: TimeOfDay.fromDateTime(DateTime.now()),
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
        setState(() {
          _dueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: "Create Task"),
      backgroundColor: defaultBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
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
                  _title = value!;
                },
              ),
              const SizedBox(height: 20.0),
              GestureDetector(
                onTap: _pickDueDateTime,
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: _dueDate == null
                          ? 'Select Due Date & Time'
                          : 'Due Date & Time',
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
                      if (_dueDate == null) {
                        return 'Please pick a due date and time';
                      }
                      return null;
                    },
                    controller: TextEditingController(
                      text: _dueDate != null
                          ? DateFormat('dd/MM/yyyy HH:mm').format(_dueDate!)
                          : '', // Empty if not set
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              DropdownButtonFormField<int>(
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
                value: _priority,
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
                  setState(() {
                    _priority = value!;
                  });
                },
              ),
              const SizedBox(height: 20.0),
              TextFormField(
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
                  _notes = value;
                },
              ),
              const SizedBox(height: 30.0),
              Center(
                child: ElevatedButton(
                  onPressed: _submitTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30.0, vertical: 15.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  child: const Text(
                    'Create Task',
                    style: TextStyle(fontSize: 16.0, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
