import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'theme_mode';

/// Saved light/dark/system choice. [main] seeds it before the first frame.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(super.initial);

  static Future<ThemeMode> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themeModeKey);
      return ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
    } catch (_) {
      return ThemeMode.system;
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
    } catch (_) {}
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier(ThemeMode.system));

/// The device's own light/dark setting, kept current by the app root.
final platformBrightnessProvider = StateProvider<Brightness>(
  (ref) => WidgetsBinding.instance.platformDispatcher.platformBrightness,
);

/// The brightness actually in use, after applying the user's choice.
final effectiveBrightnessProvider = Provider<Brightness>((ref) {
  switch (ref.watch(themeModeProvider)) {
    case ThemeMode.light:
      return Brightness.light;
    case ThemeMode.dark:
      return Brightness.dark;
    case ThemeMode.system:
      return ref.watch(platformBrightnessProvider);
  }
});
