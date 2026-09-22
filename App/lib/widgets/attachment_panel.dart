import 'dart:io';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_attachment.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;

class AttachmentEntry {
  const AttachmentEntry(this.name, this.path, this.exists, {this.item});
  final String name;
  final String? path;
  final bool exists;
  final TaskAttachment? item;
}

final attachmentEntriesProvider = FutureProvider.autoDispose
    .family<List<AttachmentEntry>, int>((ref, taskId) async {
  final repository = ref.watch(taskRepositoryProvider);
  final tasks =
      ref.watch(taskProvider).valueOrNull ?? await repository.getAllTasks();
  final task = tasks.where((task) => task.id == taskId).firstOrNull;
  if (task == null) return [];
  final items = await repository.attachments.forTask(taskId);
  final entries = <AttachmentEntry>[];
  Future<bool> exists(String? path) async {
    if (path == null) return false;
    try {
      return await File(path).exists();
    } on FileSystemException {
      return false;
    }
  }

  for (final item in items) {
    entries.add(AttachmentEntry(
        item.name, item.localPath, await exists(item.localPath),
        item: item));
  }
  final known = items.map((item) => item.sourcePath).toSet();
  for (final path
      in {...task.filePaths, ...task.imagePaths}.difference(known)) {
    entries.add(AttachmentEntry(p.basename(path), path, await exists(path)));
  }
  return entries;
});

class AttachmentPanel extends ConsumerStatefulWidget {
  const AttachmentPanel({super.key, required this.task, this.openFile});
  final Task task;
  final Future<void> Function(String)? openFile;
  @override
  ConsumerState<AttachmentPanel> createState() => _AttachmentPanelState();
}

class _AttachmentPanelState extends ConsumerState<AttachmentPanel> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.fileActionError);
    } finally {
      if (mounted) {
        ref.invalidate(attachmentEntriesProvider(widget.task.id!));
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _open(String path) => _run(() async {
        if (widget.openFile != null) {
          await widget.openFile!(path);
          return;
        }
        final result = await OpenFile.open(path);
        if (result.type.name != 'done') {
          throw StateError('No file viewer available.');
        }
      });

  Future<void> _remove(AttachmentEntry entry) async {
    final repository = ref.read(taskRepositoryProvider);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(context.l10n.fileRemoveQuestion),
                content:
                    Text('${entry.name}\n\n${context.l10n.fileRemoveHelp}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.l10n.cancel)),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.l10n.fileRemove))
                ]));
    if (confirmed != true ||
        !mounted ||
        ref.read(taskRepositoryProvider).ownerKey != repository.ownerKey) {
      return;
    }
    await _run(() async {
      if (entry.item != null) {
        await repository.attachments.remove(entry.item!.id);
      } else {
        await repository.attachments.removeLocal(widget.task.id!, entry.path!);
      }
      if (!mounted) return;
      ref.invalidate(attachmentEntriesProvider(widget.task.id!));
      await ref.read(taskProvider.notifier).loadTasks();
    });
  }

  String _status(AttachmentEntry entry) {
    final l = context.l10n;
    final item = entry.item;
    if (item?.deletePending == true) return l.fileRemovalPending;
    if (item?.uploadPending == true) return l.fileQueued;
    if (item?.remote == true) {
      return entry.exists ? l.fileBackedUp : l.fileDownloadAvailable;
    }
    return entry.exists ? l.fileLocal : l.fileMissing;
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(taskRepositoryProvider);
    final local = repository.ownerKey == 'local';
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 28),
      SectionLabel(context.l10n.attachments),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) MessageBanner(_error!, isError: true),
      ref.watch(attachmentEntriesProvider(widget.task.id!)).when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.l10n.fileLoadError),
                TextButton(
                    onPressed: () => ref
                        .invalidate(attachmentEntriesProvider(widget.task.id!)),
                    child: Text(context.l10n.fileRetry))
              ]),
          data: (entries) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (entries.isEmpty)
                  Text(context.l10n.fileEmpty,
                      style: TextStyle(color: colors.onSurfaceVariant)),
                for (final entry in entries)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppSurface(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              Icon(
                                  entry.item?.remote == true
                                      ? Icons.cloud_done_outlined
                                      : Icons.attach_file_rounded,
                                  color: colors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(entry.name,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium))
                            ]),
                            const SizedBox(height: 8),
                            Text(_status(entry)),
                            if (entry.item?.error != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(entry.item!.error!,
                                      style: TextStyle(color: colors.error))),
                            Wrap(spacing: 8, runSpacing: 4, children: [
                              if (entry.exists && entry.item?.deleted != true)
                                TextButton.icon(
                                    onPressed:
                                        _busy ? null : () => _open(entry.path!),
                                    icon: const Icon(Icons.open_in_new_rounded,
                                        size: 18),
                                    label: Text(context.l10n.fileOpen)),
                              if (entry.item == null && entry.exists && !local)
                                TextButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _run(() async {
                                              await repository.attachments
                                                  .enqueue(widget.task.id!,
                                                      entry.path!);
                                              if (mounted) {
                                                ref.invalidate(
                                                    attachmentEntriesProvider(
                                                        widget.task.id!));
                                                await ref
                                                    .read(taskProvider.notifier)
                                                    .loadTasks();
                                              }
                                            }),
                                    icon: const Icon(
                                        Icons.cloud_upload_outlined,
                                        size: 18),
                                    label: Text(context.l10n.fileUpload)),
                              if (entry.item?.remote == true &&
                                  !entry.exists &&
                                  entry.item?.deleted != true)
                                TextButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _run(() async {
                                              final api =
                                                  ref.read(apiClientProvider);
                                              final account = ref
                                                  .read(authProvider)
                                                  .account;
                                              if (account == null) {
                                                throw StateError(
                                                    'Sign in first.');
                                              }
                                              await repository.attachments
                                                  .download(entry.item!.id, api,
                                                      account.id);
                                            }),
                                    icon: const Icon(Icons.download_outlined,
                                        size: 18),
                                    label: Text(context.l10n.fileDownload)),
                              if (entry.item?.uploadPending == true ||
                                  entry.item?.deletePending == true)
                                TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _run(() => ref
                                            .read(taskProvider.notifier)
                                            .loadTasks()),
                                    child: Text(context.l10n.fileRetry)),
                              if (entry.item?.deleted != true)
                                TextButton(
                                    onPressed:
                                        _busy ? null : () => _remove(entry),
                                    child: Text(context.l10n.fileRemove)),
                            ])
                          ]))),
                if (local && entries.isNotEmpty)
                  Text(context.l10n.fileSignInHelp,
                      style: TextStyle(color: colors.onSurfaceVariant)),
              ]))
    ]);
  }
}
