import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TaskFlow's Lagoon palette, shared with the website: deep night teal,
/// a bright mint for the one main tap, and a lime spark. The roles keep the
/// site's names so both stay in step.
abstract final class Lagoon {
  /// The deep teal of dark mode, the listening screen and the toast.
  static const night = Color(0xFF032229);
  static const night2 = Color(0xFF0A3A44);

  /// The mint of `Añadir tarea` and the other main taps on night.
  static const hot = Color(0xFF3EF0B0);

  /// Text and icons on [hot]: night, 12:1.
  static const onHot = Color(0xFF032229);

  /// The lime spark: the orb's heart, the burst, the mark's light.
  static const sun = Color(0xFFD9FF6B);

  /// Soft aqua for events, and its pale page wash.
  static const tint = Color(0xFF8BE9E0);
  static const tintBg = Color(0xFFDAF4EF);

  /// The teal that reads on the light page (5:1 on white).
  static const accent = Color(0xFF0A7A63);
  static const accent2 = Color(0xFF1FB5A6);

  /// A warm coral, for the little that should stand out on night.
  static const coral = Color(0xFFFF8F7A);

  static const page = Color(0xFFF3F8F4);
  static const ink = Color(0xFF062A31);
  static const onNight = Color(0xFFF1FBF8);
  static const onNight2 = Color(0xFFC6E4DE);

  /// The display face: Bricolage Grotesque, for titles only.
  static const display = 'Bricolage';
}

/// Shared palette, type and controls for every screen and native picker.
abstract final class AppTheme {
  /// Each tab's main tap (`Añadir tarea`, `Añadir nota`): night on mint, in
  /// the display face, as on the website. Wrapped in LivelyButton, so its
  /// halo breathes; one look for every "add" in the app.
  static final ButtonStyle mainTap = FilledButton.styleFrom(
      backgroundColor: Lagoon.hot,
      foregroundColor: Lagoon.onHot,
      iconSize: 24,
      textStyle: const TextStyle(
          fontFamily: Lagoon.display,
          fontSize: 15,
          fontWeight: FontWeight.w700));

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  /// The listening sheet's face in either mode: Lagoon night.
  static final ThemeData night = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
            seedColor: Lagoon.accent, brightness: brightness)
        .copyWith(
      primary: dark ? Lagoon.hot : Lagoon.accent,
      onPrimary: dark ? Lagoon.onHot : Colors.white,
      primaryContainer:
          dark ? const Color(0xFF0D4A47) : Lagoon.tintBg,
      onPrimaryContainer:
          dark ? const Color(0xFFB6F7DC) : const Color(0xFF064B3E),
      secondary: dark ? Lagoon.tint : const Color(0xFF0F6F69),
      tertiary: dark ? Lagoon.coral : const Color(0xFFB24A33),
      surface: dark ? const Color(0xFF072D35) : const Color(0xFFFFFFFF),
      onSurface: dark ? Lagoon.onNight : Lagoon.ink,
      onSurfaceVariant:
          dark ? const Color(0xFFA9CBC5) : const Color(0xFF4D6A6A),
      surfaceContainerLow:
          dark ? const Color(0xFF0A3540) : const Color(0xFFEAF3EF),
      surfaceContainerHighest:
          dark ? const Color(0xFF15474F) : const Color(0xFFDDEBE6),
      outline: dark ? const Color(0xFF6F9A94) : const Color(0xFF6B8784),
      outlineVariant: dark ? const Color(0xFF1B4C55) : const Color(0xFFD3E5DF),
      error: dark ? const Color(0xFFFFB4AA) : const Color(0xFFB44238),
    );
    final base = ThemeData(
        useMaterial3: true, colorScheme: scheme, fontFamily: 'Manrope');
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
    // The main taps are pills, as on the website.
    const pill = StadiumBorder();
    return base.copyWith(
      scaffoldBackgroundColor:
          dark ? Lagoon.night : Lagoon.page,
      textTheme: base.textTheme.copyWith(
        // Titles in Bricolage Grotesque, tight and bold, as on the site;
        // everything read at length stays in Manrope.
        displaySmall: base.textTheme.displaySmall!.copyWith(
            fontFamily: Lagoon.display,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.4),
        headlineLarge: base.textTheme.headlineLarge!.copyWith(
            fontFamily: Lagoon.display,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.3,
            height: 1.1),
        headlineMedium: base.textTheme.headlineMedium!.copyWith(
            fontFamily: Lagoon.display,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            height: 1.12),
        headlineSmall: base.textTheme.headlineSmall!.copyWith(
            fontFamily: Lagoon.display,
            fontSize: 25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
            height: 1.18),
        titleLarge: base.textTheme.titleLarge!.copyWith(
            fontFamily: Lagoon.display,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            // Bricolage's own line is taller than Manrope's: keep titles
            // the height they had.
            height: 1.15),
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
              fontFamily: Lagoon.display,
              color: scheme.onSurface,
              fontSize: 20,
              letterSpacing: -0.4,
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
      // Filled buttons are the app's main taps: 60 dp tall (UX-2108), with
      // 12 dp above and below a label that wraps (UX-2608). The density adds
      // 12 dp to the 48 dp minimum and to the top and bottom padding, and
      // leaves the default horizontal padding as it is. The form's one
      // ElevatedButton («Añadir tarea», «Guardar cambios»), the confirming
      // tap of every free account, matches it.
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              visualDensity: const VisualDensity(vertical: 3),
              shape: pill)),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              minimumSize: const Size(48, 48),
              visualDensity: const VisualDensity(vertical: 3),
              elevation: 0,
              shape: pill,
              textStyle: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w700))),
      // Outlined buttons stay 52 dp at one line: the density adds 8 dp to
      // the 44 dp minimum, and 8 dp above and below a label that wraps
      // (UX-2631).
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 44),
              visualDensity: const VisualDensity(vertical: 2),
              shape: pill,
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
          backgroundColor: Lagoon.hot,
          foregroundColor: Lagoon.onHot,
          elevation: 2,
          shape: pill),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          // The night toast of `2 tareas añadidas · Deshacer`; in dark mode
          // a lighter teal, so it still stands off the page.
          backgroundColor: dark ? const Color(0xFF15535C) : Lagoon.night,
          contentTextStyle: base.textTheme.bodyMedium!
              .copyWith(color: Lagoon.onNight, fontWeight: FontWeight.w600),
          actionTextColor: Lagoon.hot,
          closeIconColor: Lagoon.onNight2,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18))),
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
