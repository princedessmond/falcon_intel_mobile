import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colour set for one brightness. Text-role colours meet WCAG AA (>= 4.5:1)
/// against [bg] and [surface]; "fill" colours carry white text.
class AppPalette {
  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color surfaceHigh; // input fill, skeletons, raised chips
  final Color border;
  final Color primaryText; // brand colour for text/icons on surfaces
  final Color accentRed;
  final Color accentOrange;
  final Color accentAmber;
  final Color accentGreen;
  final Color accentPurple;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color heroGlow; // login background glow
  final Color snackBg;
  final Color shimmerHighlight;

  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.primaryText,
    required this.accentRed,
    required this.accentOrange,
    required this.accentAmber,
    required this.accentGreen,
    required this.accentPurple,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.heroGlow,
    required this.snackBg,
    required this.shimmerHighlight,
  });

  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF0B1220),
    surface: Color(0xFF131C2E),
    surfaceHigh: Color(0xFF1C273B),
    border: Color(0xFF2A3650),
    primaryText: Color(0xFF60A5FA), // blue-400
    accentRed: Color(0xFFF87171),
    accentOrange: Color(0xFFFB923C),
    accentAmber: Color(0xFFFBBF24),
    accentGreen: Color(0xFF4ADE80),
    accentPurple: Color(0xFFC084FC),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFFA5B4CB),
    textMuted: Color(0xFF7C8BA3),
    heroGlow: Color(0xFF15264A),
    snackBg: Color(0xFF243049),
    shimmerHighlight: Color(0xFF2A3854),
  );

  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF3F5F9),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEDF1F6),
    border: Color(0xFFDDE3EC),
    primaryText: Color(0xFF1D4ED8), // blue-700
    accentRed: Color(0xFFB91C1C),
    accentOrange: Color(0xFFC2410C),
    accentAmber: Color(0xFF92400E),
    accentGreen: Color(0xFF15803D),
    accentPurple: Color(0xFF7E22CE),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF64748B),
    heroGlow: Color(0xFFDCE6FB),
    snackBg: Color(0xFF1E293B),
    shimmerHighlight: Color(0xFFF8FAFC),
  );
}

/// App theme — light and dark variants of the Falcon Intel design system.
///
/// Colours are exposed as static getters that follow the active palette
/// ([use]). The app rebuilds its whole widget tree when the palette changes.
class AppTheme {
  static AppPalette _p = AppPalette.light;
  static AppPalette get palette => _p;
  static bool get isDark => _p.brightness == Brightness.dark;
  static void use(Brightness b) => _p = b == Brightness.dark ? AppPalette.dark : AppPalette.light;

  // Brand fills — carry white text in both themes
  static const Color primaryColor = Color(0xFF2563EB); // blue-600
  static const Color dangerFill = Color(0xFFDC2626); // red-600
  static const Color successFill = Color(0xFF15803D); // green-700
  static const Color warningFill = Color(0xFFB45309); // amber-700

  static Color get primaryText => _p.primaryText;
  static Color get bg => _p.bg;
  static Color get surface => _p.surface;
  static Color get surfaceHigh => _p.surfaceHigh;
  static Color get border => _p.border;
  static Color get accentRed => _p.accentRed;
  static Color get accentOrange => _p.accentOrange;
  static Color get accentAmber => _p.accentAmber;
  static Color get accentGreen => _p.accentGreen;
  static Color get accentPurple => _p.accentPurple;
  static Color get textPrimary => _p.textPrimary;
  static Color get textSecondary => _p.textSecondary;
  static Color get textMuted => _p.textMuted;
  static Color get heroGlow => _p.heroGlow;
  static Color get shimmerHighlight => _p.shimmerHighlight;

  static const double radius = 16;

  static SystemUiOverlayStyle get overlayStyle => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: _p.surface,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      );

  static ThemeData get theme {
    final p = _p;
    final dark = isDark;
    final base = ThemeData(useMaterial3: true, brightness: p.brightness);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: p.textPrimary,
      displayColor: p.textPrimary,
    );
    final scheme = (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
      primary: p.primaryText,
      onPrimary: dark ? p.bg : Colors.white,
      primaryContainer: primaryColor,
      onPrimaryContainer: Colors.white,
      secondary: p.accentPurple,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerHighest: p.surfaceHigh,
      outline: p.border,
      outlineVariant: p.border,
      error: p.accentRed,
    );
    final selectedTint = primaryColor.withValues(alpha: dark ? 0.3 : 0.12);

    return base.copyWith(
      scaffoldBackgroundColor: p.bg,
      primaryColor: primaryColor,
      textTheme: textTheme,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyle,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 20),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: p.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryColor.withValues(alpha: dark ? 0.28 : 0.12),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 24,
              color: states.contains(WidgetState.selected) ? p.primaryText : p.textSecondary,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? p.textPrimary : p.textSecondary,
            )),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.primaryText, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border.withValues(alpha: 0.5)),
        ),
        labelStyle: TextStyle(color: p.textSecondary),
        floatingLabelStyle: TextStyle(color: p.primaryText),
        hintStyle: TextStyle(color: p.textMuted),
        prefixIconColor: p.textSecondary,
        suffixIconColor: p.textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryColor.withValues(alpha: 0.55),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryColor.withValues(alpha: 0.55),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: const Size(64, 48),
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primaryText,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: selectedTint,
        side: BorderSide(color: p.border),
        labelStyle: TextStyle(color: p.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
        secondaryLabelStyle: TextStyle(color: p.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
        checkmarkColor: p.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? selectedTint : p.surface),
          foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? p.primaryText : p.textSecondary),
          side: WidgetStatePropertyAll(BorderSide(color: p.border)),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          visualDensity: VisualDensity.compact,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? Colors.white : p.textSecondary),
        trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? primaryColor : p.surfaceHigh),
        trackOutlineColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? primaryColor : p.border),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        subtitleTextStyle: TextStyle(color: p.textSecondary, fontSize: 13),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.snackBg,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primaryText),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    );
  }

  // Platform color helper
  static Color platformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'twitter':
      case 'x':
        return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1);
      case 'reddit':
        return isDark ? const Color(0xFFFF7A45) : const Color(0xFFC2410C);
      case 'telegram':
        return isDark ? const Color(0xFF29B6F6) : const Color(0xFF0277BD);
      case 'news':
        return isDark ? const Color(0xFF34D399) : const Color(0xFF047857);
      default:
        return primaryText;
    }
  }

  // Severity color helper
  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return accentRed;
      case 'high':
        return accentOrange;
      case 'medium':
        return accentAmber;
      case 'low':
        return accentGreen;
      default:
        return textSecondary;
    }
  }

  /// Icon paired with each severity so meaning never relies on colour alone.
  static IconData severityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Icons.error_rounded;
      case 'high':
        return Icons.warning_rounded;
      case 'medium':
        return Icons.info_rounded;
      case 'low':
        return Icons.check_circle_rounded;
      default:
        return Icons.help_rounded;
    }
  }
}
