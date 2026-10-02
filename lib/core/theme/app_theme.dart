import 'package:flutter/material.dart';

/// Dark SOC theme — optimized for watch-floor displays and night ops
class AppTheme {
  static const Color primaryColor = Color(0xFF2563EB); // blue-600
  static const Color darkBg = Color(0xFF0F172A); // slate-900
  static const Color darkSurface = Color(0xFF1E293B); // slate-800
  static const Color darkCard = Color(0xFF334155); // slate-700
  static const Color accentRed = Color(0xFFDC2626);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentGreen = Color(0xFF16A34A);
  static const Color accentPurple = Color(0xFF9333EA);
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentPurple,
        surface: darkSurface,
        error: accentRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: primaryColor.withOpacity(0.2),
        labelTextStyle: MaterialStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkCard,
        thickness: 1,
      ),
    );
  }

  // Platform color helper
  static Color platformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'twitter':
      case 'x':
        return const Color(0xFF1DA1F2);
      case 'reddit':
        return const Color(0xFFFF4500);
      case 'telegram':
        return const Color(0xFF0088CC);
      case 'news':
        return const Color(0xFF10B981);
      default:
        return primaryColor;
    }
  }

  // Severity color helper
  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return accentRed;
      case 'high':
        return const Color(0xFFEA580C); // orange-600
      case 'medium':
        return accentAmber;
      case 'low':
        return accentGreen;
      default:
        return textSecondary;
    }
  }
}
