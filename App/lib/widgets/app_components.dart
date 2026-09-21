import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/theme_provider.dart';

class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
        key: const ValueKey('theme-toggle'),
        tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
        onPressed: () async {
          try {
            await ref
                .read(themeModeProvider.notifier)
                .setMode(dark ? ThemeMode.light : ThemeMode.dark);
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'Appearance changed. Could not save the preference on this device.')));
            }
          }
        },
        icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 22));
  }
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

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800)));
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.title,
      required this.message,
      this.icon = Icons.event_available_outlined,
      this.action});
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(22)),
              child: Icon(icon, size: 28, color: colors.onPrimaryContainer)),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.5)),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ]));
  }
}

class MessageBanner extends StatelessWidget {
  const MessageBanner(this.message, {super.key, this.isError = false});
  final String message;
  final bool isError;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
        color: isError ? colors.errorContainer : colors.primaryContainer,
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(isError ? Icons.info_outline : Icons.check_circle_outline,
              size: 20,
              color: isError
                  ? colors.onErrorContainer
                  : colors.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: TextStyle(
                      color: isError
                          ? colors.onErrorContainer
                          : colors.onPrimaryContainer))),
        ]));
  }
}
