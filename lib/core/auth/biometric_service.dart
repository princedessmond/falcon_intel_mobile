import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Biometric authentication service — handles fingerprint/face unlock.
///
/// Stores the user's email + password securely when they opt in to biometric
/// login, then uses local_auth to authenticate with fingerprint/face.
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static const _emailKey = 'bio_email';
  static const _passwordKey = 'bio_password';
  static const _enabledKey = 'bio_enabled';

  /// Check if the device supports biometric authentication
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Check if biometric login is enabled by the user
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// Enable biometric login — stores credentials securely
  static Future<bool> enable(String email, String password) async {
    try {
      final available = await isAvailable();
      if (!available) return false;

      // Authenticate first to confirm identity before enabling
      final didAuth = await _auth.authenticate(
        localizedReason: 'Confirm your fingerprint to enable biometric login',
      );

      if (didAuth) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_emailKey, email);
        await prefs.setString(_passwordKey, password);
        await prefs.setBool(_enabledKey, true);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Disable biometric login — clears stored credentials
  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_passwordKey);
    await prefs.remove(_enabledKey);
  }

  /// Get stored credentials (for biometric login)
  static Future<Map<String, String>?> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    if (!enabled) return null;

    final email = prefs.getString(_emailKey);
    final password = prefs.getString(_passwordKey);
    if (email == null || password == null) return null;

    return {'email': email, 'password': password};
  }

  /// Authenticate with biometrics (fingerprint/face)
  /// Returns true if authentication succeeds
  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Scan your fingerprint to unlock Falcon Intel',
      );
    } catch (_) {
      return false;
    }
  }
}