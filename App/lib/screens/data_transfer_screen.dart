import 'package:agenda/models/archive_diagnostic.dart';
import 'package:agenda/l10n/archive_locale.dart';
import 'package:agenda/l10n/region.dart';
import 'dart:async';
import 'dart:math';
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
  String Function(BuildContext)? _message;
  bool _error = false;
  final _bannerKey = GlobalKey();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Each result shows once, in the banner: bring it into view, such as after
  /// «Importar» at the end of a long preview, where the banner isn't built
  /// yet. Then go back to the top, and down until it is.
  void _revealMessage() {
    var steps = 0;
    Future<void> reveal(Duration _) async {
      if (!mounted) return;
      final banner = _bannerKey.currentContext;
      if (banner == null) {
        if (!_scroll.hasClients || steps++ > 8) return;
        final position = _scroll.position;
        _scroll.jumpTo(steps == 1
            ? 0
            : min(position.pixels + position.viewportDimension,
                position.maxScrollExtent));
        WidgetsBinding.instance.addPostFrameCallback(reveal);
        return;
      }
      for (final policy in [
        ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        ScrollPositionAlignmentPolicy.keepVisibleAtEnd
      ]) {
        if (!banner.mounted) return;
        await Scrollable.ensureVisible(banner,
            duration: MediaQuery.disableAnimationsOf(banner)
                ? Duration.zero
                : const Duration(milliseconds: 250),
            alignmentPolicy: policy);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback(reveal);
  }

  Future<void> _run(
      Future<String Function(BuildContext)?> Function(ArchiveStore)
          operation) async {
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
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          final issue = error is ArchiveDiagnostic
              ? error
              : const ArchiveDiagnostic(ArchiveCode.invalidFile);
          _message = (context) => context.archiveDiagnostic(issue);
          _error = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = (context) => context.l10n.transferError;
          _error = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_message != null) _revealMessage();
      }
    }
  }

  Future<void> _export() => _run((store) async {
        final contents = await store.export();
        if (!mounted || !identical(store, ref.read(archiveStoreProvider))) {
          return null;
        }
        return await ref.read(archiveFilesProvider).save(contents)
            ? (BuildContext context) => context.l10n.exportSaved
            : null;
      });

  Future<void> _preview() => _run((store) async {
        final file = await ref.read(archiveFilesProvider).choose();
        if (file == null ||
            !mounted ||
            !identical(store, ref.read(archiveStoreProvider))) {
          return null;
        }
        // Selecting another file replaces the preview even if parsing fails.
        // Keep a cancelled picker separate so it can preserve the prior choice.
        setState(() {
          _archive = null;
          _selected = {};
          _imported = {};
        });
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
        return (BuildContext context) => [
              context.l10n.importResult(result.added, result.listsAdded),
              if (result.alreadyImported > 0)
                context.l10n.importSkipped(result.alreadyImported)
            ].join(' ');
      });

  @override
  Widget build(BuildContext context) {
    final archive = _archive;
    final colors = Theme.of(context).colorScheme;
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: CustomAppBar(title: context.l10n.exportImport),
          body: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(24),
              children: [
            Text(context.l10n.exportImportIntro),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(context.l10n.exportTaskFlowFile)),
              OutlinedButton.icon(
                  onPressed: _busy ? null : _preview,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(context.l10n.chooseImportFile)),
            ]),
            const SizedBox(height: 8),
            Text(context.l10n.chooseImportFileHelp),
            if (_busy)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator()),
            if (_message != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  // Read out as it appears: no snackbar repeats it.
                  child: MessageBanner(_message!(context),
                      key: _bannerKey, isError: _error, liveRegion: true)),
            if (archive != null) ...[
              const SizedBox(height: 24),
              Text(context.l10n.importPreview,
                  style: Theme.of(context).textTheme.titleLarge),
              Text(context.l10n.importCounts(
                  archive.source == ArchiveSource.taskflow
                      ? context.l10n.taskFlowExportSource
                      : context.l10n.todoistCsvSource,
                  archive.tasks
                      .where((item) => item.task?.isNote != true)
                      .length,
                  archive.tasks
                      .where((item) => item.task?.isNote == true)
                      .length,
                  archive.lists.length)),
              const SizedBox(height: 12),
              for (final warning in archive.warnings)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(context.archiveDiagnostic(warning),
                        style: TextStyle(color: colors.onSurfaceVariant))),
              Text(context.l10n.importCopiesHelp),
              if (archive.lists.isNotEmpty)
                ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(context.l10n.listsIncluded),
                    children: [
                      for (final list in archive.lists)
                        ListTile(
                            title: Text(list.name),
                            subtitle: Text(list.archived
                                ? context.l10n.archivedPersonalCopy
                                : context.l10n.personalCopy))
                    ]),
              const SizedBox(height: 12),
              for (final (index, row) in archive.tasks.indexed)
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
                        title: Text(
                            row.title.isEmpty
                                ? context.l10n.importRow(index + 1)
                                : row.title,
                            style: TextStyle(color: colors.onSurface)),
                        subtitle: Text(
                            [
                              if (row.error != null)
                                context.l10n.cannotImport(
                                    context.archiveDiagnostic(row.error!)),
                              if (_imported.contains(row.sourceId))
                                context.l10n.alreadyImported,
                              if (row.task != null)
                                row.task!.isNote
                                    ? context.l10n.note
                                    : '${taskScheduleLabel(row.task!, context: context)} · ${context.repeatLabel(row.task!)}',
                              ...row.warnings.map(context.archiveDiagnostic),
                            ].join('\n'),
                            style: TextStyle(color: colors.onSurfaceVariant)))),
              const SizedBox(height: 16),
              FilledButton.icon(
                  key: const ValueKey('confirm-import'),
                  onPressed:
                      _busy || (_selected.isEmpty && archive.lists.isEmpty)
                          ? null
                          : _import,
                  icon: const Icon(Icons.add_task),
                  label: Text(context.l10n.importSelected(_selected.length))),
            ],
          ]),
        ));
  }
}
