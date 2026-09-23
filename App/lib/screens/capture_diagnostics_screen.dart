import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:agenda/services/capture_diagnostics.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/widgets/custom_app_bar.dart';

final _summaryProvider = FutureProvider.autoDispose(
  (ref) =>
      CaptureDiagnostics(ref.watch(captureStoreProvider).database).summary(),
);

class CaptureDiagnosticsScreen extends ConsumerWidget {
  const CaptureDiagnosticsScreen({super.key});
  String _seconds(BuildContext context, Object? value) => value is int
      ? NumberFormat('0.00', context.localeName).format(value / 1000)
      : '—';

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: CustomAppBar(title: context.l10n.captureDiagnostics),
    body: ref
        .watch(_summaryProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: FilledButton(
              onPressed: () => ref.invalidate(_summaryProvider),
              child: Text(context.l10n.retry),
            ),
          ),
          data: (rows) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(context.l10n.diagnosticsPrivacy),
              const SizedBox(height: 16),
              Text(context.l10n.diagnosticsPercentiles),
              const SizedBox(height: 8),
              Text(context.l10n.diagnosticsMeasurementHelp),
              const SizedBox(height: 16),
              for (final row in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${context.l10n.diagnosticsEvent(row['event'] as String)} · ${context.l10n.diagnosticsObservations(row['samples'] as int)}${row['items'] == 0 ? '' : ' · ${context.l10n.diagnosticsItems(row['items'] as int)}'}',
                  ),
                  subtitle: row['p50_ms'] == null
                      ? null
                      : Text(
                          context.l10n.diagnosticsTiming(
                            _seconds(context, row['p50_ms']),
                            _seconds(context, row['p95_ms']),
                            row['timed_samples'] as int,
                          ),
                        ),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  try {
                    await CaptureDiagnostics(
                      ref.read(captureStoreProvider).database,
                    ).clear();
                    if (context.mounted) ref.invalidate(_summaryProvider);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.diagnosticsClearError),
                        ),
                      );
                    }
                  }
                },
                child: Text(context.l10n.clearDiagnostics),
              ),
            ],
          ),
        ),
  );
}
