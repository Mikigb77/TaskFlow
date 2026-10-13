import 'package:agenda/widgets/capture_review_editor.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/capture_messages.dart';
import 'package:agenda/services/capture_problem.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/capture_diagnostics.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';

class ReviewTasksScreen extends ConsumerStatefulWidget {
  const ReviewTasksScreen({
    super.key,
    this.drafts = const [],
    this.transcript = '',
    this.session,
  });
  final List<TaskDraft> drafts;
  final String transcript;
  final CaptureSession? session;
  @override
  ConsumerState<ReviewTasksScreen> createState() => _ReviewTasksScreenState();
}

class _ReviewTasksScreenState extends ConsumerState<ReviewTasksScreen> {
  late CaptureSession? _session = widget.session;
  late List<CaptureDraft> _items = [
    ...?_session?.drafts,
    if (_session == null) ...widget.drafts.map(CaptureDraft.fromAI),
  ];
  late final CaptureStore _store;
  Future<void> _writes = Future.value();
  bool _saving = false;
  String? _expandedId;
  String? _error;
  final _reviewWatch = Stopwatch()..start();
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _store = ref.read(captureStoreProvider);
    unawaited(
      CaptureDiagnostics(_store.database).record(CaptureEvent.reviewOpened),
    );
  }

  @override
  void dispose() {
    if (!_finished && _items.any((d) => d.pending)) {
      unawaited(
        CaptureDiagnostics(
          _store.database,
        ).record(CaptureEvent.leftReviewPending),
      );
      unawaited(
        CaptureDiagnostics(_store.database).record(
          CaptureEvent.reviewTime,
          elapsedMs: _reviewWatch.elapsedMilliseconds,
        ),
      );
    }
    super.dispose();
  }

  Future<void> _change(CaptureDraft draft) async {
    setState(() {
      _items = _items.map((d) => d.id == draft.id ? draft : d).toList();
      _error = null;
    });
    if (_session == null) return;
    final snapshot = _session!.copyWith(drafts: _items, status: 'ready');
    _session = snapshot;
    _writes = _writes
        .catchError((Object _) {})
        .then((_) => _store.update(snapshot));
    try {
      await _writes;
      await CaptureDiagnostics(_store.database).record(CaptureEvent.edited);
      if (mounted) ref.invalidate(pendingCapturesProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _error = CaptureProblem.reviewWriteFailed);
      }
    }
  }

  Future<void> _save() async {
    final ready = _items.where((d) => d.ready).toList();
    if (_saving || ready.isEmpty) return;
    final saveWatch = Stopwatch()..start();
    unawaited(
      CaptureDiagnostics(_store.database).record(
        CaptureEvent.reviewTime,
        elapsedMs: _reviewWatch.elapsedMilliseconds,
      ),
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    final notifier = ref.read(taskProvider.notifier);
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context);
    final strings = context.l10n;
    CaptureSession? undoBefore;
    final undoIds = <String, int>{};
    try {
      await _writes;
      if (_session != null) {
        undoBefore = _session;
        final result = await _store.saveReady(
          _session!.id,
          _session!.ownerKey,
          ready.map((d) => d.id).toSet(),
        );
        _session = result;
        _items = result.drafts;
        for (final draft in result.drafts) {
          if (ready.any((d) => d.id == draft.id) && draft.savedTaskId != null) {
            undoIds[draft.id] = draft.savedTaskId!;
          }
        }
        await CaptureDiagnostics(_store.database).record(
          CaptureEvent.saved,
          elapsedMs: saveWatch.elapsedMilliseconds,
          count: ready.length,
        );
        _reviewWatch.reset();
        _finished = !_items.any((d) => d.pending);
        await notifier.loadTasks();
      } else {
        await notifier.addTasks(ready.map((d) => d.task).toList());
        final ids = ready.map((d) => d.id).toSet();
        _items = _items
            .map((d) => ids.contains(d.id) ? d.copyWith(savedTaskId: -1) : d)
            .toList();
      }
      if (!mounted) return;
      ref.invalidate(pendingCapturesProvider);
      final remaining = _items.where((d) => d.pending).length;
      _finished = remaining == 0;
      final messenger = ScaffoldMessenger.of(context);
      final message = ready.every((item) => item.task.isNote)
          ? context.l10n.noteSaved
          : '${context.l10n.captureTasksSaved(ready.length)}${remaining > 0 ? ' · ${context.l10n.captureKeptForReview(remaining)}' : ''}';
      if (remaining == 0) Navigator.pop(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 8),
          action: undoBefore == null
              ? null
              : SnackBarAction(
                  label: strings.undo,
                  onPressed: () async {
                    if (mounted && _saving) return;
                    if (mounted) setState(() => _saving = true);
                    try {
                      final before = undoBefore!;
                      if (container.read(captureOwnerProvider) !=
                          before.ownerKey) {
                        return;
                      }
                      // Finish edits to other cards before restoring this save.
                      await _writes;
                      final restored = await _store.undoSave(before, undoIds);
                      if (restored == null) {
                        if (messenger.mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(strings.reviewUndoChanged)),
                          );
                        }
                        return;
                      }
                      await container.read(taskProvider.notifier).loadTasks();
                      container.invalidate(pendingCapturesProvider);
                      if (mounted) {
                        setState(() {
                          _session = restored;
                          _items = restored.drafts;
                          _finished = false;
                        });
                      } else if (navigator.mounted &&
                          container.read(captureOwnerProvider) ==
                              before.ownerKey) {
                        unawaited(
                          navigator.push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ReviewTasksScreen(session: restored),
                            ),
                          ),
                        );
                      }
                      if (messenger.mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(strings.reviewUndoSaved)),
                        );
                      }
                    } catch (_) {
                      if (messenger.mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(strings.undoError)),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
                ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = CaptureProblem.saveFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _remove(CaptureDraft item) {
    unawaited(_change(item.copyWith(removed: true)));
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.reviewRemoved),
        action: SnackBarAction(
          label: context.l10n.undo,
          onPressed: () {
            if (mounted && !_saving) {
              unawaited(_change(item.copyWith(removed: false)));
            }
          },
        ),
      ),
    );
  }

  Future<void> _finishEmpty() async {
    if (_session != null) {
      await _writes;
      await _store.discard(_session!.id, _session!.ownerKey);
    }
    _finished = true;
    if (mounted) {
      ref.invalidate(pendingCapturesProvider);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _items.where((d) => d.pending).toList();
    final ready = pending.where((d) => d.ready).length;
    final compact = pending.length > 1;
    final l = context.l10n;
    final note =
        _session?.kind == 'note' ||
        (_items.isNotEmpty && _items.every((d) => d.task.isNote));
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: CustomAppBar(
          title: note
              ? l.reviewNote
              : compact
              ? l.checkTasks
              : l.reviewTask,
          showAppearance: false,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    children: [
                      Icon(
                        ready == pending.length
                            ? Icons.check_rounded
                            : Icons.info_outline_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ready == pending.length
                              ? (compact ? l.readyCount(ready) : l.reviewReady)
                              : l.needsCheckCount(pending.length - ready),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MessageBanner(
                      captureProblemText(l, _error!),
                      isError: true,
                    ),
                  ),
                for (final item in pending)
                  Padding(
                    padding: EdgeInsets.only(bottom: compact ? 14 : 0),
                    child: CaptureReviewEditor(
                      key: ValueKey(item.id),
                      draft: item,
                      compact: compact,
                      expanded: _expandedId == item.id,
                      enabled: !_saving,
                      onExpand: () => setState(
                        () => _expandedId = _expandedId == item.id
                            ? null
                            : item.id,
                      ),
                      onChanged: (draft) => unawaited(_change(draft)),
                      onRemove: () => _remove(item),
                    ),
                  ),
                if (pending.isEmpty) ...[
                  EmptyState(
                    title: l.captureNothingToReview,
                    message: l.captureRemovedDraftsHelp,
                  ),
                  TextButton(
                    onPressed: _finishEmpty,
                    child: Text(l.captureFinish),
                  ),
                ],
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  leading: const Icon(Icons.graphic_eq_rounded, size: 20),
                  title: Text(
                    l.reviewOriginal,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  childrenPadding: const EdgeInsets.only(bottom: 16),
                  expandedAlignment: Alignment.centerLeft,
                  children: [
                    SelectableText(_session?.transcript ?? widget.transcript),
                  ],
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  key: const ValueKey('save-drafts'),
                  onPressed: _saving || ready == 0 ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.done_all_rounded),
                  label: Text(
                    _saving
                        ? l.saving
                        : ready == 0
                        ? l.captureCheckDetails
                        : note
                        ? l.saveNote
                        : compact
                        ? l.captureSaveTasks(ready)
                        : l.reviewSaveOne,
                  ),
                ),
                if (_session != null &&
                    MediaQuery.viewInsetsOf(context).bottom == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l.reviewKeepDraft,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
