import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../widgets/common.dart';

class AuthState {
  final bool isLoggedIn;
  final String? email;
  final String? name;
  final String? role;
  final bool requires2fa;
  final String? tempToken;
  final String? error;

  AuthState({
    this.isLoggedIn = false,
    this.email,
    this.name,
    this.role,
    this.requires2fa = false,
    this.tempToken,
    this.error,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    String? email,
    String? name,
    String? role,
    bool? requires2fa,
    String? tempToken,
    String? error,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      requires2fa: requires2fa ?? this.requires2fa,
      tempToken: tempToken ?? this.tempToken,
      error: error,
    );
  }
}

class AuthService extends StateNotifier<AuthState> {
  AuthService() : super(AuthState()) {
    _checkSession();
  }

  Future<void> _checkSession() async {
    final api = ApiClient.instance;
    final authed = await api.isAuthenticated();
    if (authed) {
      try {
        final user = await api.getMe();
        if (user != null) {
          state = AuthState(
            isLoggedIn: true,
            email: user['email'],
            name: user['name'],
            role: user['role'],
          );
        }
      } catch (_) {}
    }
  }

  Future<void> login(String email, String password, {bool remember = true}) async {
    state = state.copyWith(error: null);
    try {
      final result = await ApiClient.instance.login(email, password, remember: remember);

      if (result['requires_2fa'] == true) {
        state = AuthState(
          requires2fa: true,
          tempToken: result['temp_token'],
          email: email,
        );
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        final user = result['user'] as Map<String, dynamic>?;
        state = AuthState(
          isLoggedIn: true,
          email: user?['email'] ?? email,
          name: user?['name'],
          role: user?['role'],
        );
      }
    } catch (e) {
      state = state.copyWith(error: friendlyError(e));
    }
  }

  Future<void> verify2fa(String otp) async {
    state = state.copyWith(error: null);
    try {
      final tempToken = state.tempToken;
      if (tempToken == null) {
        state = state.copyWith(error: 'No 2FA session. Please login again.');
        return;
      }

      final result = await ApiClient.instance.verify2FA(tempToken, otp);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      final user = result['user'] as Map<String, dynamic>?;
      state = AuthState(
        isLoggedIn: true,
        email: user?['email'] ?? state.email,
        name: user?['name'],
        role: user?['role'],
      );
    } catch (e) {
      state = state.copyWith(error: friendlyError(e));
    }
  }

  Future<void> logout() async {
    await ApiClient.instance.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    state = AuthState();
  }
}

final authStateProvider = StateNotifierProvider<AuthService, AuthState>((ref) {
  return AuthService();
});
