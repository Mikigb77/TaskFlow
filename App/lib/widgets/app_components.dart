import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/services/feedback_timeout.dart';

/// Every brief message goes through here: it replaces the one on screen,
/// floats above the bottom bar and goes away by itself, after Android's
/// accessibility timeout when that is longer. A [margin] lifts it above a
/// button it would otherwise cover.
Future<ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?>
    showFeedback(ScaffoldMessengerState messenger, String text,
        {String? actionLabel,
        VoidCallback? onAction,
        EdgeInsetsGeometry? margin}) async {
  messenger.hideCurrentSnackBar();
  final duration = await FeedbackTimeout.forAction();
  if (!messenger.mounted) return null;
  return messenger.showSnackBar(SnackBar(
    // Snackbars with an action persist by default in the current SDK.
    persist: false,
    duration: duration,
    behavior: SnackBarBehavior.floating,
    margin: margin,
    padding: actionLabel == null
        ? null
        : const EdgeInsetsDirectional.only(start: 16),
    content: actionLabel == null
        ? Text(text)
        : _FeedbackWithAction(
            text,
            SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
          ),
  ));
}

/// Lays the action out as the SDK does (beside a short label, under a long
/// one) but, when it goes under, lets the message use the whole width: the
/// SDK keeps 40% of it empty, which at large text pushes a long message off
/// a small screen.
class _FeedbackWithAction extends StatelessWidget {
  const _FeedbackWithAction(this.text, this.action);
  final String text;
  final SnackBarAction action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final label = TextPainter(
            text: TextSpan(
              text: action.label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
            maxLines: 1,
          )..layout();
          final beside =
              label.width + 16 <= (constraints.maxWidth + 16) * 0.25;
          label.dispose();
          final button = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: action,
          );
          const vertical = EdgeInsets.symmetric(vertical: 14);
          return beside
              ? Row(children: [
                  Expanded(
                      child: Padding(padding: vertical, child: Text(text))),
                  button,
                ])
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                        top: 14, bottom: 14, end: 16),
                    child: SizedBox(width: double.infinity, child: Text(text)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: button),
                  ),
                ]);
        },
      );
}

class AppSurface extends StatelessWidget {
  const AppSurface(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20),
      this.color});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Material(
      color: color ?? Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side:
              BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child));
}

/// The ▾ that says a chip can be changed, as large as the text lets it be
/// seen: 18 dp at normal text, growing with the text size up to 28 dp.
/// It always takes 18 dp beside the label, as before, so the label keeps all
/// its room: the glyph's triangle is far narrower than its box and stays
/// inside those 18 dp.
class DropDownMark extends StatelessWidget {
  const DropDownMark({super.key});
  @override
  Widget build(BuildContext context) {
    final size = math.min(28.0, MediaQuery.textScalerOf(context).scale(18));
    return Align(
        widthFactor: 18 / size,
        heightFactor: 1,
        child: Icon(Icons.arrow_drop_down_rounded, size: size));
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // A heading, so a screen reader can jump between sections.
      child: Semantics(
          header: true,
          child: Text(text.toUpperCase(),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800))));
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.title,
      required this.message,
      this.icon = Icons.event_available_outlined,
      this.action});
  // Without a title, the message is the state's one line.
  final String? title;
  final String message;
  final IconData? icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = this.icon;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(22)),
                child: Icon(icon, size: 28, color: colors.onPrimaryContainer)),
            const SizedBox(height: 16),
          ],
          if (title case final title?) ...[
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
          ],
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.5)),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ]));
  }
}

class MessageBanner extends StatelessWidget {
  const MessageBanner(this.message,
      {super.key, this.isError = false, this.icon, this.liveRegion});
  final String message;
  final bool isError;
  final IconData? icon;
  // Read out as it appears; by default, only an error is.
  final bool? liveRegion;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // An address in it is read without its line breaks.
    final spoken = withoutAddressBreaks(message);
    // Its own node, so only its line is read; an error is read out as soon
    // as it appears or changes.
    return Semantics(
        container: true,
        liveRegion: liveRegion ?? isError,
        child: AppSurface(
            color: isError ? colors.errorContainer : colors.primaryContainer,
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                  icon ??
                      (isError ? Icons.info_outline : Icons.check_circle_outline),
                  size: 20,
                  color: isError
                      ? colors.onErrorContainer
                      : colors.onPrimaryContainer),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(message,
                      semanticsLabel: spoken == message ? null : spoken,
                      style: TextStyle(
                          color: isError
                              ? colors.onErrorContainer
                              : colors.onPrimaryContainer))),
            ])));
  }
}
