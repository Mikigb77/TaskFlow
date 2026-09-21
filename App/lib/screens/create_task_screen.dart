import 'package:flutter/material.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/widgets/task_editor.dart';

class CreateTaskScreen extends StatelessWidget {
  const CreateTaskScreen({super.key, this.initialDraft});
  final TaskDraft? initialDraft;
  @override
  Widget build(BuildContext context) => TaskEditor(
        draft: initialDraft,
        calendarDate: ModalRoute.of(context)?.settings.arguments as DateTime?,
      );
}
