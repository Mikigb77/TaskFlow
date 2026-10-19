import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/widgets/app_components.dart';

/// The website, the one place the app links to it from.
const siteBase = 'https://taskflow.garbar.tech';

/// The site's pages the app links to.
enum SitePage {
  privacy('privacy'),
  terms('terms');

  const SitePage(this.path);
  final String path;
}

/// [page] in [language]: the site has Spanish and Catalan pages, and English
/// for every other language. It builds with trailing slashes.
Uri sitePageUri(SitePage page, String language) {
  final prefix = switch (language) {
    'es' => '/es',
    'ca' => '/ca',
    _ => '',
  };
  return Uri.parse('$siteBase$prefix/${page.path}/');
}

/// Opens a web page outside the app; false when nothing could open it.
final openWebPageProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Opens [uri] outside the app, or says briefly that it couldn't.
Future<void> openWebPage(BuildContext context, WidgetRef ref, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  final error = context.l10n.webPageOpenError;
  var opened = false;
  try {
    opened = await ref.read(openWebPageProvider)(uri);
  } catch (_) {
    opened = false;
  }
  if (!opened && messenger.mounted) unawaited(showFeedback(messenger, error));
}

/// Opens [page] in the app's language.
Future<void> openSitePage(BuildContext context, WidgetRef ref, SitePage page) =>
    openWebPage(
      context,
      ref,
      sitePageUri(page, Localizations.localeOf(context).languageCode),
    );
