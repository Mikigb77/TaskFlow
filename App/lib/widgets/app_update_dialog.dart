import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/app_update_provider.dart';
import 'package:agenda/services/app_update.dart';

/// Offers the staging app's newer build (MainShell). Update downloads it, if
/// it isn't yet, and installs it: Android replaces the app and closes it.
class AppUpdateDialog extends ConsumerStatefulWidget {
  const AppUpdateDialog({super.key, required this.update});
  final AppUpdate update;

  @override
  ConsumerState<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends ConsumerState<AppUpdateDialog> {
  bool _busy = false;
  AppInstallResult? _result;

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    final result = await ref.read(appUpdateProvider.notifier).install();
    if (!mounted) return;
    if (result == AppInstallResult.started) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
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
    return AlertDialog(
      // At 2× text on a small phone the words scroll.
      scrollable: true,
      title: Text(l10n.appUpdateTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.appUpdateBody(version)),
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
