import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/widgets/task_list.dart';
import 'package:agenda/screens/create_task_screen.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/utils/constants.dart';
import 'package:agenda/widgets/custom_app_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsyncValue = ref.watch(taskProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: "Tasks"),
      backgroundColor: defaultBackgroundColor,
      body: taskAsyncValue.when(
        data: (tasks) {
          final incompleteTasks =
              tasks.where((task) => !task.isCompleted).toList();
          if (incompleteTasks.isEmpty) {
            return const Center(
              child: Text(
                'No tasks available.',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            );
          } else {
            return TaskList(tasks: incompleteTasks);
          }
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(
            'An error occurred: $error',
            style: const TextStyle(color: Colors.red, fontSize: 18),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accentColor,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateTaskScreen(),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
