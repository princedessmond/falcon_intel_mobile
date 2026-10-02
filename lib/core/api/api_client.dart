import 'package:dio/dio.dart';
import 'package:dio/browser.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'endpoints.dart';

/// Singleton Dio HTTP client with JWT token management.
///
/// On native (Android/iOS), extracts tokens from Set-Cookie headers and
/// stores them in SharedPreferences, then injects them as Cookie headers.
///
/// On web (Chrome), Set-Cookie headers are not accessible to JavaScript, so
/// we use the browser's native cookie jar via `withCredentials: true` (XHR
/// automatically sends and receives cookies for the same domain).
class ApiClient {
  static ApiClient? _instance;
  late final Dio dio;
  String? _accessToken;
  String? _refreshToken;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  ApiClient._() {
    dio = Dio(BaseOptions(
      baseUrl: Endpoints.apiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      followRedirects: true,
      validateStatus: (status) => status != null && status < 500,
    ));

    // On web, enable native cookie management (browser handles Set-Cookie)
    if (kIsWeb) {
      dio.httpClientAdapter = BrowserHttpClientAdapter()
        ..withCredentials = true;
    }

    // Load stored tokens (for native platforms)
    _loadTokens();

    // Auth interceptor
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final isAuthEndpoint = options.path.contains('/auth/login') ||
            options.path.contains('/auth/refresh') ||
            options.path.contains('/auth/verify-2fa');

        // On native: inject token manually (SharedPreferences)
        // On web: browser handles cookies automatically (withCredentials)
        if (!kIsWeb && _accessToken != null && !isAuthEndpoint) {
          options.headers['Cookie'] = 'access_token=$_accessToken';
        }
        handler.next(options);
      },
      onError: (DioException e, ErrorInterceptorHandler handler) async {
        if (e.response?.statusCode == 401) {
          // On web, the browser handles cookie refresh automatically
          if (!kIsWeb && _refreshToken != null) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              final retryResp = await dio.fetch(e.requestOptions);
              return handler.resolve(retryResp);
            }
          }
        }
        handler.next(e);
      },
    ));

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ));
    }
  }

  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  Future<void> _loadTokens() async {
    if (kIsWeb) return; // Web uses browser cookies
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_accessKey);
      _refreshToken = prefs.getString(_refreshKey);
    } catch (_) {}
  }

  /// Extract tokens from Set-Cookie headers and store them (native only)
  Future<void> _saveTokensFromResponse(Response response) async {
    if (kIsWeb) return; // Web: browser handles cookies

    final setCookies = response.headers.map['set-cookie'];
    if (setCookies == null) return;

    final prefs = await SharedPreferences.getInstance();
    for (final cookie in setCookies) {
      if (cookie.startsWith('access_token=')) {
        _accessToken = cookie.split(';')[0].split('=')[1];
        await prefs.setString(_accessKey, _accessToken!);
      }
      if (cookie.startsWith('refresh_token=')) {
        _refreshToken = cookie.split(';')[0].split('=')[1];
        await prefs.setString(_refreshKey, _refreshToken!);
      }
    }
  }

  Future<bool> _tryRefresh() async {
    if (kIsWeb) return false;
    try {
      final refreshDio = Dio(BaseOptions(
        baseUrl: Endpoints.apiBase,
        followRedirects: true,
        validateStatus: (status) => status != null && status < 500,
      ));
      final resp = await refreshDio.post(
        Endpoints.refresh,
        options: Options(headers: {'Cookie': 'refresh_token=$_refreshToken'}),
      );
      if (resp.statusCode == 200) {
        await _saveTokensFromResponse(resp);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Login
  Future<Map<String, dynamic>> login(String email, String password,
      {bool remember = true}) async {
    if (!kIsWeb) {
      // Clear old tokens before login (native only)
      _accessToken = null;
      _refreshToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessKey);
      await prefs.remove(_refreshKey);
    }

    final resp = await dio.post(Endpoints.login, data: {
      'email': email,
      'password': password,
      'remember_me': remember,
    });

    if (resp.statusCode == 200) {
      final data = resp.data as Map<String, dynamic>;
      if (data['requires_2fa'] == true) {
        return {'requires_2fa': true, 'temp_token': data['temp_token']};
      }
      // Save cookies (native only — web browser handles automatically)
      await _saveTokensFromResponse(resp);
      return {'requires_2fa': false, 'user': data['user']};
    }
    final data = resp.data;
    String error = 'Login failed';
    if (data is Map) {
      error = data['detail']?.toString() ?? 'Login failed';
    }
    throw Exception(error);
  }

  /// Verify 2FA
  Future<Map<String, dynamic>> verify2FA(String tempToken, String otp) async {
    final resp = await dio.post(Endpoints.verify2fa, data: {
      'temp_token': tempToken,
      'otp': otp,
    });

    if (resp.statusCode == 200) {
      await _saveTokensFromResponse(resp);
      return {'success': true, 'user': resp.data['user']};
    }
    final data = resp.data;
    String error = '2FA verification failed';
    if (data is Map) {
      error = data['detail']?.toString() ?? '2FA failed';
    }
    throw Exception(error);
  }

  /// Get current user
  Future<Map<String, dynamic>?> getMe() async {
    final resp = await dio.get(Endpoints.me);
    if (resp.statusCode == 200) return resp.data;
    return null;
  }

  /// Logout
  Future<void> logout() async {
    try { await dio.post(Endpoints.logout); } catch (_) {}
    if (!kIsWeb) {
      _accessToken = null;
      _refreshToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessKey);
      await prefs.remove(_refreshKey);
    }
  }

  /// Check if authenticated
  Future<bool> isAuthenticated() async {
    if (kIsWeb) {
      // On web, try a request and see if we get 401
      try {
        final resp = await dio.get(Endpoints.me);
        return resp.statusCode == 200;
      } catch (_) {
        return false;
      }
    }
    if (_accessToken == null) await _loadTokens();
    return _accessToken != null;
  }

  // ── Standard HTTP methods ──────────────────────────────────────────────

  Future<Response> get(String path, {Map<String, dynamic>? query}) {
    return dio.get(path, queryParameters: query);
  }

  Future<Response> post(String path, {dynamic data}) {
    return dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return dio.delete(path);
  }
}
