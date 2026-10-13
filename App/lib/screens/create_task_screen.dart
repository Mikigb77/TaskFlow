import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/widgets/task_editor.dart';

class CreateTaskScreen extends ConsumerWidget {
  const CreateTaskScreen({super.key, this.initialDraft, this.calendarDate});
  final DateTime? calendarDate;
  final TaskDraft? initialDraft;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(projectScopeProvider).projectId;
    final editable =
        selected == null || ref.watch(listCanEditProvider(selected));
    return TaskEditor(
      draft: initialDraft,
      initialListId: editable ? selected : null,
      calendarDate:
          calendarDate ??
          ModalRoute.of(context)?.settings.arguments as DateTime?,
    );
  }
}
