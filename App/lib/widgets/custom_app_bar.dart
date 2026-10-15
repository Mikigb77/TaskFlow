import 'package:agenda/l10n/region.dart';
import 'package:agenda/screens/activity_screen.dart';
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    required this.title,
    this.isRoot = false,
    this.canGoBack = true,
    this.actions = const [],
  });
  final String title;
  final bool isRoot;

  /// False hides the back arrow but keeps its space, so the title doesn’t
  /// move. For a moment when leaving isn’t possible.
  final bool canGoBack;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: !isRoot && canGoBack,
    leading: !isRoot && !canGoBack ? const SizedBox.shrink() : null,
    titleSpacing: isRoot ? 24 : null,
    toolbarHeight: 64,
    title: isRoot
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.done_all_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 10),
              const Flexible(
                child: Text(
                  'taskflow',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        : Text(title),
    actions: [
      ...actions,
      if (isRoot) const ActivityButton(),
      if (isRoot)
        IconButton(
          tooltip: context.l10n.account,
          icon: const Icon(Icons.person_outline_rounded, size: 23),
          onPressed: () => Navigator.pushNamed(context, '/account'),
        ),
      const SizedBox(width: 8),
    ],
  );
  @override
  Size get preferredSize => const Size.fromHeight(64);
}
