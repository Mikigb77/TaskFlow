import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const CustomAppBar({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(fontSize: 22.0, color: Colors.white),
      ),
      backgroundColor:
          Colors.grey[800], // A dark grey color for a more cohesive dark theme
      actions: [
        IconButton(
          icon: const Icon(Icons.home, color: Colors.white70),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (Route<dynamic> route) => false,
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.calendar_today, color: Colors.white70),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/calendar',
              (Route<dynamic> route) => false,
            );
          },
        ),
        PopupMenuButton<String>(
          color: Colors.grey[800],
          onSelected: (value) {
            if (value == 'Home') {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (Route<dynamic> route) => false,
              );
            } else if (value == 'Completed Tasks') {
              Navigator.pushNamed(context, '/completedTasks');
            } else if (value == 'Calendar') {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/calendar',
                (Route<dynamic> route) => false,
              );
            } else if (value == 'Settings') {
              Navigator.pushNamed(context, '/settings');
            }
          },
          itemBuilder: (BuildContext context) {
            return [
              const PopupMenuItem<String>(
                value: 'Home',
                child: Text(
                  'Home',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'Completed Tasks',
                child: Text(
                  'Completed Tasks',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'Calendar',
                child: Text(
                  'Calendar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ];
          },
          icon: const Icon(
            Icons.more_vert,
            color: Colors.white70, // Slightly off-white icon for less contrast
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
