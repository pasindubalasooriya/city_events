import 'package:flutter/material.dart';

/// The app's colour system, in one place.
///
/// Everything visual in CityEvents - button colours, text colours, card and
/// background colours, in both light and dark mode - is generated from the
/// single seed colour below. Screens never name a colour directly; they ask
/// the theme for one, so the whole app stays consistent and both modes stay
/// readable.
class AppTheme {
  /// The one colour the entire palette is built from.
  ///
  /// A deep teal: civic and calm, and clearly a deliberate choice rather than
  /// the purple that a new Flutter project starts with. Everything else is
  /// derived from it, so changing this one line re-colours the whole app.
  static const Color seedColor = Color(0xFF00696D);

  /// The theme used when the device is set to light mode.
  static ThemeData light() => _themeFor(Brightness.light);

  /// The theme used when the device is set to dark mode.
  static ThemeData dark() => _themeFor(Brightness.dark);

  /// Builds a complete theme for one brightness.
  ///
  /// Both modes are built the same way from the same seed, which is why they
  /// look like the same app rather than two different designs. Takes the
  /// brightness to build for; gives back the finished [ThemeData].
  static ThemeData _themeFor(Brightness brightness) {
    // fromSeed does the real work: from one colour it calculates a full set of
    // matching colours, and for each background it also calculates the colour
    // text must be to stay readable on it (the "onSurface", "onPrimary" pairs).
    // That is what keeps contrast acceptable in dark mode without us hand-
    // picking a second palette.
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,

      // Tinting the app bar with the generated container colour, instead of
      // leaving it plain, makes the app read as Material 3 rather than as an
      // untouched template.
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        centerTitle: false,
      ),

      // Every Card in the app gets the same elevation and corner radius from
      // here, so event cards can't drift apart visually as we add screens.
      cardTheme: CardThemeData(
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Text fields on the login, register and event forms all get the same
      // outlined box, set once here rather than repeated on every field.
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
      ),
    );
  }
}
