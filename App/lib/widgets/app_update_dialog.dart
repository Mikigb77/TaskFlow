import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/app_update_provider.dart';
import 'package:agenda/services/app_update.dart';

/// Offers the staging app's newer build (MainShell). Update downloads it, if
/// it isn't yet, with a bar showing how far along it is, and installs it:
/// Android replaces the app and closes it.
class AppUpdateDialog extends ConsumerStatefulWidget {
  const AppUpdateDialog({super.key, required this.update});
  final AppUpdate update;

  @override
  ConsumerState<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends ConsumerState<AppUpdateDialog> {
  bool _busy = false;
  AppInstallResult? _result;

  /// Whether a download is under way, and how far along: null while its
  /// size is unknown.
  bool _downloading = false;
  double? _done;

  void _progress(double? done) {
    if (!mounted) return;
    // A whole percent at a time: the build arrives in thousands of chunks.
    final percent = done == null ? null : (done * 100).floor();
    final shown = _done == null ? null : (_done! * 100).floor();
    if (_downloading && percent == shown) return;
    setState(() {
      _downloading = true;
      _done = done;
    });
  }

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    final result = await ref
        .read(appUpdateProvider.notifier)
        .install(onProgress: _progress);
    if (!mounted) return;
    if (result == AppInstallResult.started) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _downloading = false;
      _done = null;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final update = widget.update;
    final version = update.version.isEmpty
        ? '${update.versionCode}'
        : '${update.version} (${update.versionCode})';
    final note = switch (_result) {
      AppInstallResult.permission => l10n.appUpdateAllow,
      AppInstallResult.failed => l10n.appUpdateFailed,
      _ => null,
    };
    final done = _done;
    final percent = done == null
        ? null
        : NumberFormat.percentPattern(
            Localizations.localeOf(context).toString(),
          ).format((done * 100).floor() / 100);
    return AlertDialog(
      // At 2× text on a small phone the words scroll.
      scrollable: true,
      title: Text(l10n.appUpdateTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.appUpdateBody(version)),
          if (_downloading) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: _done,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              semanticsLabel: l10n.appUpdateDownloading,
              semanticsValue: percent,
            ),
            if (percent != null) ...[
              const SizedBox(height: 8),
              Text(
                percent,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
          if (note != null) ...[
            const SizedBox(height: 12),
            Text(
              note,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.later),
        ),
        FilledButton(
          onPressed: _busy ? null : _install,
          child: Text(
            _busy ? l10n.appUpdateDownloading : l10n.appUpdateInstall,
          ),
        ),
      ],
    );
  }
}
