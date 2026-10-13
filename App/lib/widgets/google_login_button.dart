import 'package:flutter/material.dart';

class GoogleLoginButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const GoogleLoginButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: dark ? const Color(0xff131314) : Colors.white,
          foregroundColor: dark
              ? const Color(0xffe3e3e3)
              : const Color(0xff1f1f1f),
          disabledBackgroundColor: dark
              ? const Color(0xff131314)
              : Colors.white,
          disabledForegroundColor: const Color(0xff747775),
          side: BorderSide(
            color: dark ? const Color(0xff8e918f) : const Color(0xff747775),
          ),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        icon: Image.asset(
          'assets/brand/google-g.png',
          width: 20,
          height: 20,
          excludeFromSemantics: true,
        ),
        label: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
