import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---- Brand palette ----
const kGreen = Color(0xFF00E27A);
const kGreenCore = Color(0xFF00C46B);
const kGreenDeep = Color(0xFF00934F);
const kMint = Color(0xFF7BFFC4);
const kAqua = Color(0xFF12D9A8);
const kInk = Color(0xFF0A0F1A);

/// Theme-aware colour helper. `AppColors.of(context)` reads the current
/// brightness and exposes the tokens used across the app.
class AppColors {
  final bool dark;
  const AppColors(this.dark);

  static AppColors of(BuildContext c) =>
      AppColors(Theme.of(c).brightness == Brightness.dark);

  Color get bg => dark ? const Color(0xFF05070C) : const Color(0xFFE9EFF7);
  Color get ink => dark ? Colors.white : kInk;
  Color get sub => dark ? Colors.white70 : const Color(0xFF56617A);
  Color get faint => dark ? Colors.white38 : const Color(0xFF8B95A8);
  Color get glass =>
      dark ? Colors.white.withOpacity(0.055) : Colors.white.withOpacity(0.70);
  Color get glassBorder =>
      dark ? Colors.white.withOpacity(0.09) : Colors.white.withOpacity(0.85);
  Color get track =>
      dark ? Colors.white.withOpacity(0.10) : const Color(0xFFD6DEEA);
}

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: kGreenCore, brightness: b);
  final baseText =
      (b == Brightness.dark ? ThemeData.dark() : ThemeData.light()).textTheme;
  final c = AppColors(b == Brightness.dark);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    textTheme: GoogleFonts.interTextTheme(baseText),
    splashFactory: InkRipple.splashFactory,
  );
}

/// Display font (headings / numbers-with-character).
TextStyle display(double size,
        {FontWeight weight = FontWeight.w700,
        Color? color,
        double? spacing}) =>
    GoogleFonts.spaceGrotesk(
        fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing);

/// Monospace (metrics, timers, codes).
TextStyle mono(double size,
        {FontWeight weight = FontWeight.w600, Color? color}) =>
    GoogleFonts.robotoMono(fontSize: size, fontWeight: weight, color: color);
