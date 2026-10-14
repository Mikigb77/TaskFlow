import 'package:agenda/widgets/app_components.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agenda/l10n/region.dart';

/// Plain selectable content with explicit, user-triggered web links. No HTML,
/// remote previews, embedded scripts or automatic network requests.
List<Uri> noteLinks(String text) {
  final result = <String, Uri>{};
  for (final match in RegExp(r'''https?://[^\s<>"']+''', caseSensitive: false)
      .allMatches(text)) {
    final raw = match.group(0)!.replaceFirst(RegExp(r'[.,;!?)\]}]+$'), '');
    final uri = Uri.tryParse(raw);
    if (uri != null &&
        ['http', 'https'].contains(uri.scheme) &&
        uri.hasAuthority &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty) {
      result.putIfAbsent(uri.toString(), () => uri);
      if (result.length == 20) break;
    }
  }
  return result.values.toList();
}

class NoteText extends StatelessWidget {
  const NoteText(this.text, {super.key, this.onTap});
  final String text;

  /// Called for a tap on the text; long-press still selects it.
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final links = noteLinks(text);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SelectableText(text, style: const TextStyle(height: 1.6), onTap: onTap),
      if (links.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(context.l10n.noteLinks,
            style: Theme.of(context).textTheme.labelLarge),
        for (final uri in links)
          TextButton.icon(
              style: TextButton.styleFrom(alignment: Alignment.centerLeft),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(uri.toString(), softWrap: true),
              onPressed: () async {
                try {
                  if (await launchUrl(uri,
                      mode: LaunchMode.externalApplication)) {
                    return;
                  }
                } catch (_) {/* Keep the original selectable text available. */}
                if (context.mounted) {
                  showFeedback(ScaffoldMessenger.of(context),
                      context.l10n.linkOpenError);
                }
              }),
      ],
    ]);
  }
}
