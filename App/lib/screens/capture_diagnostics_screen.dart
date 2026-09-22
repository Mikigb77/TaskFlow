import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/services/capture_diagnostics.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/widgets/custom_app_bar.dart';

final _summaryProvider = FutureProvider.autoDispose((ref) =>
    CaptureDiagnostics(ref.watch(captureStoreProvider).database).summary());

class CaptureDiagnosticsScreen extends ConsumerWidget {
  const CaptureDiagnosticsScreen({super.key});
  String _seconds(Object? value) =>
      value is int ? '${(value / 1000).toStringAsFixed(2)}s' : '—';

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: const CustomAppBar(title: 'Capture diagnostics'),
      body: ref.watch(_summaryProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: FilledButton(
                    onPressed: () => ref.invalidate(_summaryProvider),
                    child: const Text('Retry'))),
            data: (rows) =>
                ListView(padding: const EdgeInsets.all(24), children: [
              const Text(
                  'Local counts and timing from the last 1,000 events. No task titles, words, recordings or account identifiers are included. Nothing here is uploaded.'),
              const SizedBox(height: 16),
              const Text(
                  'Median is the middle observation. P95 is the time that 95% of observations finish within. Failed requests are counted separately.'),
              const SizedBox(height: 8),
              const Text(
                  'Keeping a capture for later is not a failure. Counts can include several visits to the same draft; they are not a user conversion rate. Correction time covers open editing dialogs, including cancelled ones. Local save timing excludes cloud sync. Audio transcription excludes typed and on-device input.'),
              const SizedBox(height: 16),
              for (final row in rows)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        '${row['label']} · ${row['samples']} observations${row['items'] == 0 ? '' : ' · ${row['items']} tasks'}'),
                    subtitle: row['p50_ms'] == null
                        ? null
                        : Text(
                            'Median ${_seconds(row['p50_ms'])} · P95 ${_seconds(row['p95_ms'])} · ${row['timed_samples']} timed')),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: () async {
                    try {
                      await CaptureDiagnostics(
                              ref.read(captureStoreProvider).database)
                          .clear();
                      if (context.mounted) ref.invalidate(_summaryProvider);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Could not clear diagnostics. Try again.')));
                      }
                    }
                  },
                  child: const Text('Clear local diagnostics')),
            ]),
          ));
}
