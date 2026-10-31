import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/services/text_search.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/task_list_picker.dart';
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
  final _scroll = ScrollController();
  // Kept while the search is hidden, so its words and the filter agree.
  final _search = TextEditingController();

  // While a note is being added: the newest note id before it. A newer note
  // is the one just saved; it is brought into view and highlighted.
  int? _newerThan;
  bool _settling = false;
  int? _landedId;
  bool _highlight = false;
  Timer? _highlightTimer;
  // A new key for each landing: the row it marks changes.
  var _landedRow = GlobalKey();

  /// Where a new note goes: the project shown, when the user can add to it.
  String? get _saveTo =>
      ref.read(listCanEditProvider(_listId)) ? _listId : null;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  static int _newestNoteId(List<Task>? all) => (all ?? [])
      .where((item) => item.isNote)
      .fold(0, (newest, note) => math.max(newest, note.id ?? 0));

  Future<void> _add(Future<void> Function() open) async {
    _newerThan = _newestNoteId(ref.read(taskProvider).valueOrNull);
    _settling = false;
    await open();
    if (!mounted || _newerThan == null) return;
    // The list may still be reloading; its next load decides.
    if (!_land(ref.read(taskProvider).valueOrNull)) _settling = true;
  }

  bool _land(List<Task>? all) {
    final newerThan = _newerThan;
    final newest = _newestNoteId(all);
    if (newerThan == null || newest <= newerThan) return false;
    _newerThan = null;
    // Saved where the list doesn't show it: the list stays where it is.
    final note = all!.firstWhere((item) => item.isNote && item.id == newest);
    if (!_shown(note)) return true;
    _highlightTimer?.cancel();
    setState(() {
      _landedId = newest;
      _landedRow = GlobalKey();
      _highlight = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    return true;
  }

  /// Whether the list shows [item]: a note in the project and search shown.
  bool _shown(Task item) =>
      item.isNote &&
      (_listId == null || item.listId == _listId) &&
      matchesSearch(
          '${item.title} ${item.notes ?? ''} ${item.labels.join(' ')} ${item.checklist.map((step) => step.title).join(' ')}',
          _query);

  /// Brings the new note, first in the list, into view, then lets its
  /// highlight fade.
  Future<void> _reveal() async {
    if (!mounted || !_scroll.hasClients) return;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    if (_scroll.offset > 0) {
      if (duration == Duration.zero) {
        _scroll.jumpTo(0);
        await WidgetsBinding.instance.endOfFrame;
      } else {
        await _scroll.animateTo(0, duration: duration, curve: Curves.easeOut);
      }
    }
    final row = _landedRow.currentContext?.findRenderObject();
    if (mounted && row != null && row.attached && _scroll.hasClients) {
      // All of the row when it fits, and always its top.
      final viewport = RenderAbstractViewport.of(row);
      final position = _scroll.position;
      final offset = math
          .min(viewport.getOffsetToReveal(row, 1).offset,
              viewport.getOffsetToReveal(row, 0).offset)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if (offset > position.pixels) {
        if (duration == Duration.zero) {
          _scroll.jumpTo(offset);
        } else {
          await _scroll.animateTo(offset,
              duration: duration, curve: Curves.easeOut);
        }
      }
    }
    if (!mounted) return;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _highlight = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Task>>>(taskProvider, (_, next) {
      if (_newerThan == null || !next.hasValue) return;
      if (!_land(next.value) && _settling) _newerThan = null;
    });
    final lists = ref.watch(taskListsProvider).valueOrNull ?? [];
    final content = ref.watch(taskProvider);
    // The search waits for a first note.
    final hasNotes =
        content.valueOrNull?.any((item) => item.isNote) ?? false;
    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.notes, isRoot: widget.isRoot),
      body: RefreshIndicator(
        onRefresh: () => ref.read(taskProvider.notifier).loadTasks(),
        child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
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
              if (hasNotes) ...[
                TextField(
                    key: const ValueKey('note-search'),
                    controller: _search,
                    onChanged: (value) =>
                        setState(() => _query = value.trim()),
                    decoration: InputDecoration(
                        hintText: context.l10n.findNote,
                        prefixIcon: const Icon(Icons.search_rounded))),
                const SizedBox(height: 12),
              ],
              if (lists.isNotEmpty)
                DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _listId ?? '',
                    decoration: InputDecoration(labelText: context.l10n.list),
                    items: [
                      DropdownMenuItem(
                          value: '', child: Text(context.l10n.allNotes)),
                      if (_listId != null &&
                          !lists.any((list) => list.id == _listId))
                        DropdownMenuItem(
                            value: _listId,
                            child: Text(context.l10n.listUnavailable)),
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
                    final notes = all.where(_shown).toList()
                      // Newest first: the note just saved is on top.
                      ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
                    if (notes.isEmpty) {
                      return <Widget>[
                        EmptyState(
                            title: _query.isEmpty || !hasNotes
                                ? context.l10n.notesEmpty
                                : context.l10n.noteNoMatches,
                            message: _query.isEmpty || !hasNotes
                                ? context.l10n.notesEmptyHelp
                                : context.l10n.differentFilter,
                            icon: Icons.description_outlined)
                      ];
                    }
                    final colors = Theme.of(context).colorScheme;
                    final instant = MediaQuery.disableAnimationsOf(context);
                    TaskListInfo? project(Task note) => lists
                        .where((list) => list.id == note.listId)
                        .firstOrNull;
                    return notes
                        .map<Widget>((note) => note.id == _landedId
                            ? TweenAnimationBuilder<Color?>(
                                key: _landedRow,
                                tween: ColorTween(
                                    end: _highlight
                                        ? colors.primaryContainer
                                        : colors.surface),
                                duration: instant
                                    ? Duration.zero
                                    : const Duration(milliseconds: 600),
                                builder: (context, color, _) => _tile(
                                    context, note, project(note),
                                    color: color))
                            : _tile(context, note, project(note)))
                        .toList();
                  },
                  loading: () => <Widget>[
                        const Center(child: CircularProgressIndicator())
                      ],
                  error: (_, __) =>
                      <Widget>[Text(context.l10n.notesSavedOnDevice)]),
            ]),
      ),
      // One button, as on Calendar and Tareas: the mic while it is
      // available (Pro, or free dictations left), typing without it.
      bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: FilledButton.icon(
                  icon: Icon(ref.watch(voiceAvailableProvider)
                      ? Icons.mic_none_rounded
                      : Icons.add_rounded),
                  label: Text(context.l10n.addNote),
                  onPressed: () => _add(() => showCaptureSheet(context,
                      kind: 'note',
                      projectId: _saveTo))))),
    );
  }

  Widget _tile(BuildContext context, Task note, TaskListInfo? project,
          {Color? color}) {
    final preview = _preview(note);
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppSurface(
            padding: EdgeInsets.zero,
            color: color,
            child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                leading: const Icon(Icons.description_outlined),
                title: Text(note.title,
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (preview.isNotEmpty)
                        Text(preview,
                            maxLines: 3, overflow: TextOverflow.ellipsis),
                      if (note.checklist.isNotEmpty)
                        Text(context.l10n.checklistCount(
                            note.checklistDone, note.checklist.length)),
                      // The project after its folder, as on task rows.
                      if (project != null)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.folder_outlined,
                              size: 16, color: taskListColor(project.color)),
                          const SizedBox(width: 4),
                          Flexible(
                              child: Text(project.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis)),
                        ]),
                    ]),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            TaskDetailScreen(taskId: note.id!))))));
  }

  /// The note's words after its title. A note made in the capture sheet is
  /// titled by the start of its words, so they aren't shown twice; with
  /// nothing after the title, there is no preview.
  String _preview(Task note) {
    final body = (note.notes ?? '').trim();
    final title = note.title.trim();
    if (title.isEmpty ||
        body.length < title.length ||
        body.substring(0, title.length).toLowerCase() != title.toLowerCase()) {
      return body;
    }
    final rest = body.substring(title.length);
    // The title ends inside a word: the words don't start with it.
    if (rest.startsWith(RegExp(r'[\p{L}\p{N}]', unicode: true))) return body;
    return rest.replaceFirst(RegExp(r'^[\s.,;:!?…\-–—]+'), '');
  }
}
