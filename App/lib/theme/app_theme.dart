import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared palette, type and controls for every screen and native picker.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
            seedColor: const Color(0xFF16786A), brightness: brightness)
        .copyWith(
      primary: dark ? const Color(0xFF8BD7C3) : const Color(0xFF146C5C),
      onPrimary: dark ? const Color(0xFF103D34) : Colors.white,
      primaryContainer:
          dark ? const Color(0xFF203F37) : const Color(0xFFE0EEE5),
      onPrimaryContainer:
          dark ? const Color(0xFFC0F0DD) : const Color(0xFF205443),
      surface: dark ? const Color(0xFF1C2221) : const Color(0xFFFFFFFF),
      onSurface: dark ? const Color(0xFFF0F3EF) : const Color(0xFF202C28),
      onSurfaceVariant:
          dark ? const Color(0xFFADB9B2) : const Color(0xFF626F68),
      surfaceContainerLow:
          dark ? const Color(0xFF222B27) : const Color(0xFFF0F3EC),
      surfaceContainerHighest:
          dark ? const Color(0xFF303B35) : const Color(0xFFE6ECE4),
      outline: dark ? const Color(0xFF7F9188) : const Color(0xFF77877D),
      outlineVariant: dark ? const Color(0xFF34413A) : const Color(0xFFDFE5DC),
      error: dark ? const Color(0xFFFFB4AA) : const Color(0xFFB44238),
    );
    final base = ThemeData(
        useMaterial3: true, colorScheme: scheme, fontFamily: 'Manrope');
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
    return base.copyWith(
      scaffoldBackgroundColor:
          dark ? const Color(0xFF121816) : const Color(0xFFF7F8F2),
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge!.copyWith(
            fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.2),
        headlineMedium: base.textTheme.headlineMedium!.copyWith(
            fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8),
        headlineSmall: base.textTheme.headlineSmall!.copyWith(
            fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.6),
        titleLarge: base.textTheme.titleLarge!.copyWith(
            fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4),
        titleMedium: base.textTheme.titleMedium!
            .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        bodyLarge: base.textTheme.bodyLarge!.copyWith(height: 1.5),
        bodyMedium: base.textTheme.bodyMedium!.copyWith(height: 1.5),
        labelLarge:
            base.textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: scheme.onSurface,
          // A transparent app bar cannot infer the surface behind it.
          systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarBrightness: brightness,
              statusBarIconBrightness:
                  dark ? Brightness.light : Brightness.dark),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
              fontFamily: 'Manrope',
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800)),
      cardTheme: CardThemeData(
          color: scheme.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: shape),
      dividerTheme: DividerThemeData(
          color: scheme.outlineVariant, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.all(18),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: scheme.outline)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: scheme.primary, width: 2)),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(48, 52), shape: shape)),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              minimumSize: const Size(48, 54),
              elevation: 0,
              shape: shape,
              textStyle: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w700))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 52),
              shape: shape,
              // `outline`, as chips and fields: a border that shows (3:1).
              side: BorderSide(color: scheme.outline))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48))),
      iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
      navigationBarTheme: NavigationBarThemeData(
          height: 72,
          backgroundColor: scheme.surface,
          indicatorColor: scheme.primaryContainer,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                letterSpacing: 0,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant);
          })),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 2,
          shape: shape),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: scheme.surfaceContainerHighest,
          contentTextStyle: base.textTheme.bodyMedium!
              .copyWith(color: scheme.onSurface),
          actionTextColor: scheme.primary,
          closeIconColor: scheme.onSurfaceVariant,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: scheme.outlineVariant))),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: scheme.surface,
          showDragHandle: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
      chipTheme: ChipThemeData(
          side: BorderSide(color: scheme.outline),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }

  static String priorityLabel(int value) =>
      switch (value) { 3 => 'High', 2 => 'Medium', _ => 'Low' };
  static Color priorityColor(BuildContext context, int value) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (value) {
      3 => dark ? const Color(0xFFF1A59C) : const Color(0xFFA83E32),
      2 => dark ? const Color(0xFFEAC587) : const Color(0xFF88600B),
      _ => dark ? const Color(0xFFADC3D0) : const Color(0xFF516C7A),
    };
  }
}
