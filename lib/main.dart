import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/theme/theme_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeMode = await ThemeModeNotifier.load();
  runApp(ProviderScope(
    overrides: [themeModeProvider.overrideWith((ref) => ThemeModeNotifier(themeMode))],
    child: const FalconIntelApp(),
  ));
}
