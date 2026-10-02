import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Outcome of a fingerprint check, so screens can show a helpful message.
enum BioResult {
  success,
  cancelled,
  notEnrolled,
  lockedOut,
  unavailable,
  failed;

  /// Plain-language explanation for anything other than [success].
  String get message => switch (this) {
        BioResult.success => '',
        BioResult.cancelled => 'Fingerprint check was cancelled.',
        BioResult.notEnrolled =>
          'No fingerprint is set up on this phone. Add one in your phone\'s Settings → Security first.',
        BioResult.lockedOut =>
          'Too many attempts. Unlock your phone with its PIN, then try your fingerprint again.',
        BioResult.unavailable => 'Fingerprint isn\'t available on this phone right now.',
        BioResult.failed => 'Fingerprint not recognised. Please try again.',
      };
}

/// Biometric authentication service — handles fingerprint/face unlock.
///
/// Stores the user's email + password in the Android Keystore / iOS Keychain
/// (encrypted) when they opt in to biometric login, then uses local_auth to
/// confirm their fingerprint before signing in with them.
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static const _emailKey = 'bio_email';
  static const _passwordKey = 'bio_password';
  static const _enabledKey = 'bio_enabled';

  /// True when the phone can check a fingerprint (or face) right now:
  /// it has the hardware AND at least one is enrolled.
  static Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Check if biometric login is enabled by the user
  static Future<bool> isEnabled() async {
    await _migrateFromPlainPrefs();
    try {
      return await _secure.read(key: _enabledKey) == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Enable biometric login — confirms the fingerprint, then stores the
  /// (already verified) credentials encrypted.
  static Future<BioResult> enable(String email, String password) async {
    final result = await authenticate(reason: 'Confirm your fingerprint to turn on fingerprint sign-in');
    if (result != BioResult.success) return result;
    try {
      await _secure.write(key: _emailKey, value: email);
      await _secure.write(key: _passwordKey, value: password);
      await _secure.write(key: _enabledKey, value: 'true');
      return BioResult.success;
    } catch (_) {
      return BioResult.unavailable;
    }
  }

  /// Disable biometric login — clears stored credentials
  static Future<void> disable() async {
    try {
      await _secure.delete(key: _emailKey);
      await _secure.delete(key: _passwordKey);
      await _secure.delete(key: _enabledKey);
    } catch (_) {}
  }

  /// Get stored credentials (for biometric login)
  static Future<Map<String, String>?> getCredentials() async {
    if (!await isEnabled()) return null;
    try {
      final email = await _secure.read(key: _emailKey);
      final password = await _secure.read(key: _passwordKey);
      if (email == null || password == null) return null;
      return {'email': email, 'password': password};
    } catch (_) {
      return null;
    }
  }

  /// Ask for a fingerprint (or face). Biometrics only — the phone's PIN
  /// isn't accepted, since this stands in for the account password.
  static Future<BioResult> authenticate({String reason = 'Scan your fingerprint to unlock Falcon Intel'}) async {
    try {
      final ok = await _auth.authenticate(localizedReason: reason, biometricOnly: true);
      return ok ? BioResult.success : BioResult.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.userRequestedFallback ||
        LocalAuthExceptionCode.timeout =>
          BioResult.cancelled,
        LocalAuthExceptionCode.noBiometricsEnrolled || LocalAuthExceptionCode.noCredentialsSet => BioResult.notEnrolled,
        LocalAuthExceptionCode.temporaryLockout || LocalAuthExceptionCode.biometricLockout => BioResult.lockedOut,
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
          BioResult.unavailable,
        _ => BioResult.failed,
      };
    } on PlatformException {
      return BioResult.unavailable;
    } catch (_) {
      return BioResult.failed;
    }
  }

  /// Earlier versions kept the password in plain SharedPreferences. Move any
  /// saved login into encrypted storage once, then delete the plain copy.
  static Future<void> _migrateFromPlainPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_emailKey);
      final password = prefs.getString(_passwordKey);
      final enabled = prefs.getBool(_enabledKey) ?? false;
      if (email == null && password == null && !prefs.containsKey(_enabledKey)) return; // nothing to move
      if (enabled && email != null && password != null) {
        await _secure.write(key: _emailKey, value: email);
        await _secure.write(key: _passwordKey, value: password);
        await _secure.write(key: _enabledKey, value: 'true');
      }
      await prefs.remove(_emailKey);
      await prefs.remove(_passwordKey);
      await prefs.remove(_enabledKey);
    } catch (_) {}
  }
}
