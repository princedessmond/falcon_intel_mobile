import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:falcon_intel_mobile/app.dart';
import 'package:falcon_intel_mobile/core/auth/auth_service.dart';

class _SignedIn extends AuthService {
  _SignedIn() {
    state = AuthState(isLoggedIn: true, email: 'user@example.com', name: 'Test User');
  }
}

Future<void> _openPreferencesFromSettings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [authStateProvider.overrideWith((ref) => _SignedIn())],
    child: const FalconIntelApp(),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('My Preferences'));
  await tester.pumpAndSettle();
  expect(find.text('My Preferences'), findsOneWidget);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('saving preferences lands on the News feed', (tester) async {
    await _openPreferencesFromSettings(tester);
    await tester.tap(find.text('Critical'));
    await tester.pump();
    await tester.tap(find.text('Save 1 filter'));
    await tester.pumpAndSettle();

    expect(find.text('My Preferences'), findsNothing, reason: 'preferences screen closed');
    expect(find.text('Last 24 hours · All severities'), findsOneWidget, reason: 'News filter bar is showing');
    expect(find.text('Preferences saved — your feeds are now filtered'), findsOneWidget);
  });

  testWidgets('clearing preferences lands on the News feed', (tester) async {
    await _openPreferencesFromSettings(tester);
    await tester.tap(find.text('Critical'));
    await tester.pump();
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear all'));
    await tester.pumpAndSettle();

    expect(find.text('My Preferences'), findsNothing);
    expect(find.text('Last 24 hours · All severities'), findsOneWidget, reason: 'News filter bar is showing');
    expect(find.text('Preferences cleared — showing everything'), findsOneWidget);
  });
}
