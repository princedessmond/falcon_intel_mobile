import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:falcon_intel_mobile/app.dart';
import 'package:falcon_intel_mobile/core/auth/auth_service.dart';
import 'package:falcon_intel_mobile/core/widgets/common.dart';

/// Sign-in that updates auth state immediately (as the real one does) and then
/// waits for the "server" until the test completes it.
class _SlowAuth extends AuthService {
  final response = Completer<void>();

  @override
  Future<void> login(String email, String password, {bool remember = true}) async {
    state = state.copyWith(error: null);
    await response.future;
    state = state.copyWith(error: 'Invalid email or password');
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Sign In shows the dots loader while waiting for the server', (tester) async {
    final auth = _SlowAuth();
    await tester.pumpWidget(ProviderScope(
      overrides: [authStateProvider.overrideWith((ref) => auth)],
      child: const FalconIntelApp(),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Still waiting on the server: button shows dots, not the label.
    expect(find.byType(DotsLoader), findsOneWidget);
    expect(find.text('Sign In'), findsNothing);

    // Server answers with an error: label and error message come back.
    auth.response.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(DotsLoader), findsNothing);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Invalid email or password'), findsOneWidget);
  });
}
