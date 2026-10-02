import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:falcon_intel_mobile/app.dart';
import 'package:falcon_intel_mobile/core/auth/auth_service.dart';
import 'package:falcon_intel_mobile/core/auth/biometric_service.dart';
import 'package:falcon_intel_mobile/features/auth/login_screen.dart';

/// Stands in for the phone's fingerprint sensor.
class FakeSensor extends LocalAuthPlatform {
  bool enrolled = true;
  bool fingerMatches = true;
  int prompts = 0;

  @override
  Future<bool> deviceSupportsBiometrics() async => true;
  @override
  Future<bool> isDeviceSupported() async => true;
  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async => enrolled ? [BiometricType.strong] : [];
  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    prompts++;
    return fingerMatches;
  }
}

/// Password "right" signs in; anything else fails like the real server.
class FakeAuth extends AuthService {
  @override
  Future<void> login(String email, String password, {bool remember = true}) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    state = password == 'right'
        ? AuthState(isLoggedIn: true, email: email, name: 'Test User')
        : AuthState(error: 'Invalid email or password');
  }

  @override
  Future<void> logout() async => state = AuthState();
}

Future<void> pumpApp(WidgetTester tester, FakeAuth auth) async {
  // A phone-sized screen, so buttons below the form are reachable.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [authStateProvider.overrideWith((ref) => auth)],
    child: const FalconIntelApp(),
  ));
  await tester.pumpAndSettle();
}

Future<void> signIn(WidgetTester tester, String password) async {
  await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
  await tester.enterText(find.byType(TextField).at(1), password);
  await tester.tap(find.text('Sign In'));
  await tester.pumpAndSettle();
}

void main() {
  late FakeSensor sensor;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    LoginScreen.resetAutoPrompt();
    GoogleFonts.config.allowRuntimeFetching = false;
    sensor = FakeSensor();
    LocalAuthPlatform.instance = sensor;
  });

  testWidgets('after a password sign-in, the app offers fingerprint and it stays on screen', (tester) async {
    await pumpApp(tester, FakeAuth());
    await signIn(tester, 'right');

    expect(find.text('Enable Fingerprint'), findsOneWidget);
  });

  testWidgets('full cycle: enable after sign-in, sign out, unlock with fingerprint', (tester) async {
    // (Signing out must NOT auto-prompt — the user chose to leave.)
    final auth = FakeAuth();
    await pumpApp(tester, auth);
    await signIn(tester, 'right');

    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();
    expect(sensor.prompts, 1, reason: 'fingerprint confirmed before storing');
    expect(await BiometricService.isEnabled(), isTrue);
    expect(await BiometricService.getCredentials(), {'email': 'user@example.com', 'password': 'right'});

    // Sign out → login screen offers fingerprint.
    await auth.logout();
    await tester.pumpAndSettle();
    expect(find.text('Unlock with Fingerprint'), findsOneWidget);

    await tester.tap(find.text('Unlock with Fingerprint'));
    await tester.pumpAndSettle();
    expect(sensor.prompts, 2);
    expect(auth.state.isLoggedIn, isTrue, reason: 'signed in with the stored password');
  });

  testWidgets('"Not now" stores nothing', (tester) async {
    await pumpApp(tester, FakeAuth());
    await signIn(tester, 'right');
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(await BiometricService.isEnabled(), isFalse);
    expect(sensor.prompts, 0);
  });

  testWidgets('a wrong password is never stored for fingerprint', (tester) async {
    await pumpApp(tester, FakeAuth());
    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'typo');
    await tester.tap(find.text('Sign in & turn on fingerprint'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password'), findsOneWidget);
    expect(await BiometricService.isEnabled(), isFalse);
    expect(sensor.prompts, 0);
  });

  testWidgets('"Sign in & turn on fingerprint" skips the question after a correct password', (tester) async {
    await pumpApp(tester, FakeAuth());
    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'right');
    await tester.tap(find.text('Sign in & turn on fingerprint'));
    await tester.pumpAndSettle();

    expect(find.text('Enable Fingerprint'), findsNothing);
    expect(sensor.prompts, 1);
    expect(await BiometricService.isEnabled(), isTrue);
  });

  testWidgets('if the saved password stops working, fingerprint is switched off with an explanation', (tester) async {
    FlutterSecureStorage.setMockInitialValues(
        {'bio_email': 'user@example.com', 'bio_password': 'old-password', 'bio_enabled': 'true'});
    final auth = FakeAuth();
    await pumpApp(tester, auth); // auto-prompts on launch

    expect(sensor.prompts, 1);
    expect(auth.state.isLoggedIn, isFalse);
    expect(find.textContaining('saved password no longer works'), findsOneWidget);
    expect(await BiometricService.isEnabled(), isFalse);
  });

  testWidgets('a rejected fingerprint does not sign in', (tester) async {
    FlutterSecureStorage.setMockInitialValues(
        {'bio_email': 'user@example.com', 'bio_password': 'right', 'bio_enabled': 'true'});
    sensor.fingerMatches = false;
    final auth = FakeAuth();
    await pumpApp(tester, auth);

    expect(auth.state.isLoggedIn, isFalse);
    expect(find.text('Fingerprint not recognised. Please try again.'), findsOneWidget);
  });

  testWidgets('no fingerprint enrolled on the phone → nothing is offered', (tester) async {
    sensor.enrolled = false;
    await pumpApp(tester, FakeAuth());
    expect(find.text('Sign in & turn on fingerprint'), findsNothing);
    await signIn(tester, 'right');
    expect(find.text('Enable Fingerprint'), findsNothing);
  });

  test('a password saved by the old app version moves to encrypted storage', () async {
    SharedPreferences.setMockInitialValues(
        {'bio_email': 'old@example.com', 'bio_password': 'pw', 'bio_enabled': true});
    expect(await BiometricService.getCredentials(), {'email': 'old@example.com', 'password': 'pw'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('bio_password'), isNull, reason: 'plain-text copy deleted');
  });
}
