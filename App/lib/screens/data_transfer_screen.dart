import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task_archive.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/archive_files.dart';
import 'package:agenda/services/archive_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/todoist_import.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/task_schedule_label.dart';

final archiveFilesProvider = Provider<ArchiveFiles>((ref) => ArchiveFiles());
final archiveStoreProvider = Provider<ArchiveStore>((ref) =>
    ArchiveStore(TaskDatabase(), ref.watch(taskRepositoryProvider).ownerKey));

class DataTransferScreen extends ConsumerStatefulWidget {
  const DataTransferScreen({super.key});
  @override
  ConsumerState<DataTransferScreen> createState() => _DataTransferScreenState();
}

class _DataTransferScreenState extends ConsumerState<DataTransferScreen> {
  TaskArchive? _archive;
  Set<String> _selected = {};
  Set<String> _imported = {};
  bool _busy = false;
  String? _message;
  bool _error = false;

  Future<void> _run(Future<String?> Function(ArchiveStore) operation) async {
    if (_busy) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final store = ref.read(archiveStoreProvider);
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      final message = await operation(store);
      if (mounted && identical(store, ref.read(archiveStoreProvider))) {
        setState(() => _message = message);
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text(message, maxLines: 3, overflow: TextOverflow.ellipsis)));
        }
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
          _error = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message =
              'Could not finish. Your existing tasks are unchanged. Please retry.';
          _error = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() => _run((store) async {
        final contents = await store.export();
        if (!mounted || !identical(store, ref.read(archiveStoreProvider))) {
          return null;
        }
        return await ref.read(archiveFilesProvider).save(contents)
            ? 'Export saved. Keep the file somewhere private.'
            : null;
      });

  Future<void> _preview() => _run((store) async {
        final file = await ref.read(archiveFilesProvider).choose();
        if (file == null ||
            !mounted ||
            !identical(store, ref.read(archiveStoreProvider))) {
          return null;
        }
        final archive = file.name.toLowerCase().endsWith('.csv')
            ? TodoistImport.parse(file.contents)
            : TaskArchive.parse(file.contents);
        final imported = await store.imported(archive.id);
        if (!mounted || !identical(store, ref.read(archiveStoreProvider))) {
          return null;
        }
        setState(() {
          _archive = archive;
          _imported = imported;
          _selected = archive.tasks
              .where((row) =>
                  row.task != null &&
                  row.error == null &&
                  !imported.contains(row.sourceId))
              .map((row) => row.sourceId)
              .toSet();
        });
        return null;
      });

  Future<void> _import() => _run((store) async {
        final result = await store.import(_archive!, _selected);
        final imported = await store.imported(_archive!.id);
        if (!mounted || !identical(store, ref.read(archiveStoreProvider))) {
          return null;
        }
        setState(() {
          _selected = {};
          _imported = imported;
        });
        unawaited(ref.read(taskProvider.notifier).loadTasks());
        return 'Added ${result.added} ${result.added == 1 ? 'task' : 'tasks'} and ${result.listsAdded} ${result.listsAdded == 1 ? 'list' : 'lists'}.${result.alreadyImported > 0 ? ' Skipped ${result.alreadyImported} already imported.' : ''}';
      });

  @override
  Widget build(BuildContext context) {
    final archive = _archive;
    final colors = Theme.of(context).colorScheme;
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: const CustomAppBar(title: 'Export & import'),
          body: ListView(padding: const EdgeInsets.all(24), children: [
            Text('Keep your tasks with you.',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            const Text(
                'TaskFlow exports include tasks, notes, schedules, recurring date changes, completion, checklists, labels and personal lists. Attachment names are listed; file contents, account credentials, device preferences and unfinished captures are excluded.'),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Export TaskFlow file')),
              OutlinedButton.icon(
                  onPressed: _busy ? null : _preview,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Choose import file')),
            ]),
            const SizedBox(height: 8),
            const Text(
                'Choose a TaskFlow JSON export or Todoist project CSV (up to 32 MB / 5,000 tasks). You will review it before importing.'),
            if (_busy)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator()),
            if (_message != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: MessageBanner(_message!, isError: _error)),
            if (archive != null) ...[
              const SizedBox(height: 24),
              Text('Import preview',
                  style: Theme.of(context).textTheme.titleLarge),
              Text(
                  '${archive.source} · ${archive.tasks.length} tasks · ${archive.lists.length} lists'),
              const SizedBox(height: 12),
              for (final warning in archive.warnings)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(warning,
                        style: TextStyle(color: colors.onSurfaceVariant))),
              const Text(
                  'Selected tasks and the file’s lists are added as copies. Existing tasks are kept. Re-importing this same file skips records already imported on this phone; a changed or newly exported file counts as a different import.'),
              if (archive.lists.isNotEmpty)
                ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Lists included'),
                    children: [
                      for (final list in archive.lists)
                        ListTile(
                            title: Text(list.name),
                            subtitle: Text(list.archived
                                ? 'Archived personal copy'
                                : 'Personal copy'))
                    ]),
              const SizedBox(height: 12),
              for (final row in archive.tasks)
                AppSurface(
                    padding: EdgeInsets.zero,
                    child: CheckboxListTile(
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _selected.contains(row.sourceId),
                        onChanged: _busy ||
                                row.error != null ||
                                _imported.contains(row.sourceId)
                            ? null
                            : (value) => setState(() {
                                  if (value == true) {
                                    _selected.add(row.sourceId);
                                  } else {
                                    _selected.remove(row.sourceId);
                                  }
                                }),
                        title: Text(row.title),
                        subtitle: Text([
                          if (row.error != null) 'Cannot import: ${row.error}',
                          if (_imported.contains(row.sourceId))
                            'Already imported on this phone',
                          if (row.task != null)
                            '${taskScheduleLabel(row.task!)} · ${row.task!.repeatLabel}',
                          ...row.warnings,
                        ].join('\n')))),
              const SizedBox(height: 16),
              FilledButton.icon(
                  key: const ValueKey('confirm-import'),
                  onPressed:
                      _busy || (_selected.isEmpty && archive.lists.isEmpty)
                          ? null
                          : _import,
                  icon: const Icon(Icons.add_task),
                  label: Text('Import ${_selected.length} tasks and lists')),
            ],
          ]),
        ));
  }
}
