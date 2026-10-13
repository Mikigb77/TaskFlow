import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/services/text_search.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:agenda/services/capture_store.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key, this.listId, this.isRoot = true});
  final String? listId;
  final bool isRoot;
  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _query = '';
  late String? _listId = widget.listId;

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(taskListsProvider).valueOrNull ?? [];
    final content = ref.watch(taskProvider);
    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.notes, isRoot: widget.isRoot),
      body: RefreshIndicator(
        onRefresh: () => ref.read(taskProvider.notifier).loadTasks(),
        child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Text(context.l10n.notesHelp,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              ref.watch(pendingCapturesProvider).when(
                  data: (captures) {
                    final count = captures
                        .where((capture) => capture.kind == 'note')
                        .length;
                    return count == 0
                        ? const SizedBox.shrink()
                        : TextButton.icon(
                            key: const ValueKey('resume-notes'),
                            icon: const Icon(Icons.restore_rounded),
                            label:
                                Text(context.l10n.pendingCaptureCount(count)),
                            onPressed: () =>
                                Navigator.pushNamed(context, '/captures'));
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/captures'),
                      child: Text(context.l10n.checkCaptures))),
              TextField(
                  key: const ValueKey('note-search'),
                  onChanged: (value) =>
                      setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                      hintText: context.l10n.findNote,
                      prefixIcon: const Icon(Icons.search_rounded))),
              const SizedBox(height: 12),
              if (lists.isNotEmpty)
                DropdownButton<String>(
                    isExpanded: true,
                    value: _listId ?? '',
                    items: [
                      DropdownMenuItem(
                          value: '', child: Text(context.l10n.notes)),
                      if (_listId != null &&
                          !lists.any((list) => list.id == _listId))
                        DropdownMenuItem(
                            value: _listId,
                            child: Text(context.l10n.taskUnavailable)),
                      for (final list in lists)
                        DropdownMenuItem(
                            value: list.id,
                            child: Text(list.name,
                                maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (id) =>
                        setState(() => _listId = id == '' ? null : id)),
              const SizedBox(height: 12),
              ...content.when(
                  data: (all) {
                    final notes = all
                        .where((item) =>
                            item.isNote &&
                            (_listId == null || item.listId == _listId) &&
                            matchesSearch(
                                '${item.title} ${item.notes ?? ''} ${item.labels.join(' ')} ${item.checklist.map((step) => step.title).join(' ')}',
                                _query))
                        .toList();
                    if (notes.isEmpty) {
                      return <Widget>[
                        EmptyState(
                            title: _query.isEmpty
                                ? context.l10n.notesEmpty
                                : context.l10n.noMatches,
                            message: _query.isEmpty
                                ? context.l10n.notesEmptyHelp
                                : context.l10n.differentFilter,
                            icon: Icons.description_outlined)
                      ];
                    }
                    return notes
                        .map<Widget>((note) => _tile(
                            context,
                            note,
                            lists
                                .where((list) => list.id == note.listId)
                                .firstOrNull
                                ?.name))
                        .toList();
                  },
                  loading: () => <Widget>[
                        const Center(child: CircularProgressIndicator())
                      ],
                  error: (_, __) => <Widget>[Text(context.l10n.savedOnDevice)]),
            ]),
      ),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                        icon: const Icon(Icons.edit_note_rounded),
                        label: Text(context.l10n.newNote),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => TaskEditor(
                                    kind: 'note',
                                    initialListId:
                                        ref.read(listCanEditProvider(_listId))
                                            ? _listId
                                            : null)))),
                    OutlinedButton.icon(
                        icon: const Icon(Icons.mic_none_rounded),
                        label: Text(context.l10n.recordNote),
                        onPressed: () =>
                            showCaptureSheet(context, kind: 'note')),
                  ]))),
    );
  }

  Widget _tile(BuildContext context, Task note, String? listName) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurface(
          padding: EdgeInsets.zero,
          child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              leading: const Icon(Icons.description_outlined),
              title: Text(note.title,
                  maxLines: 3, overflow: TextOverflow.ellipsis),
              subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_preview(note).isNotEmpty)
                      Text(_preview(note),
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                    if (note.checklist.isNotEmpty)
                      Text(
                          '${note.checklistDone}/${note.checklist.length} · ${context.l10n.checklist}'),
                    if (listName != null) Text(listName),
                  ]),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => TaskDetailScreen(taskId: note.id!))))));

  String _preview(Task note) {
    final lines = (note.notes ?? '').split('\n');
    return lines.first.trim() == note.title.trim()
        ? lines.skip(1).join('\n')
        : lines.join('\n');
  }
}
