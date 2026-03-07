import 'package:flutter/material.dart';

/// Baby-friendly theme with bright colors, large touch targets,
/// and rounded corners. No small text or complex UI elements.
class BabyTheme {
  BabyTheme._();

  // Bright, cheerful primary colors
  static const Color primaryColor = Color(0xFFFF6B6B); // Coral red
  static const Color secondaryColor = Color(0xFF4ECDC4); // Teal
  static const Color accentYellow = Color(0xFFFFE66D); // Sunny yellow
  static const Color accentPurple = Color(0xFFa855f7); // Playful purple
  static const Color accentGreen = Color(0xFF6BCB77); // Leaf green
  static const Color accentBlue = Color(0xFF4D96FF); // Sky blue
  static const Color bgColor = Color(0xFFF8F9FA); // Soft white

  /// List of fun colors for game elements.
  static const List<Color> funColors = [
    primaryColor,
    secondaryColor,
    accentYellow,
    accentPurple,
    accentGreen,
    accentBlue,
  ];

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: bgColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: bgColor,
      // Large, rounded buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(120, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      // No app bar by default (baby games are fullscreen)
      appBarTheme: const AppBarTheme(
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
