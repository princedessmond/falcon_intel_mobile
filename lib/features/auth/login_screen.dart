import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/biometric_offer.dart';
import '../../core/auth/biometric_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  /// Lets tests simulate a fresh app launch (fingerprint auto-prompt again).
  @visibleForTesting
  static void resetAutoPrompt() => _LoginScreenState._autoPromptedThisLaunch = false;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _obscurePassword = true;
  bool _remember = true;
  bool _loading = false;
  String? _errorMessage;
  bool _bioAvailable = false;
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (!mounted) return;
    setState(() {
      _bioAvailable = available;
      _bioEnabled = enabled;
    });
    // Like a banking app: when fingerprint is on, ask for it straight away
    // when the app opens — but only the first time the login screen appears,
    // not after the user deliberately signs out.
    final firstShowThisLaunch = !_autoPromptedThisLaunch;
    _autoPromptedThisLaunch = true;
    if (firstShowThisLaunch && available && enabled && !ref.read(authStateProvider).requires2fa) {
      _handleBiometricLogin();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  /// Set by "Sign in & turn on fingerprint": skip the question after sign-in.
  bool _setupAfterLogin = false;

  /// Credentials waiting for a 2FA code before fingerprint can be offered.
  BiometricOffer? _offerAfter2fa;

  /// The fingerprint prompt opens by itself once per app launch.
  static bool _autoPromptedThisLaunch = false;

  /// After a successful password sign-in, leave a fingerprint offer for the
  /// main screen (see [BiometricOffer] for why it isn't shown here).
  void _offerFingerprint(String email, String password) {
    if (!_bioAvailable || _bioEnabled) return;
    ref.read(biometricOfferProvider.notifier).state =
        BiometricOffer(email: email, password: password, autoEnable: _setupAfterLogin);
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter email and password');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    try {
      await ref.read(authStateProvider.notifier).login(email, password, remember: _remember);
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = friendlyError(e);
      });
      return;
    }

    final auth = ref.read(authStateProvider);
    if (auth.isLoggedIn) {
      // Password is verified — offer fingerprint on the main screen.
      _offerFingerprint(email, password);
      if (mounted) context.go('/');
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);

    if (auth.error != null) {
      _setupAfterLogin = false;
      setState(() => _errorMessage = auth.error);
    } else if (auth.requires2fa) {
      // UI switches to the code entry; offer fingerprint once 2FA succeeds.
      _offerAfter2fa = BiometricOffer(email: email, password: password, autoEnable: _setupAfterLogin);
    }
  }

  Future<void> _handleBiometricLogin() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    // Get stored credentials
    final creds = await BiometricService.getCredentials();
    if (creds == null) {
      setState(() {
        _loading = false;
        _bioEnabled = false;
        _errorMessage = 'Fingerprint sign-in isn\'t set up. Sign in with your password to turn it on.';
      });
      return;
    }

    // Authenticate with fingerprint
    final result = await BiometricService.authenticate();
    if (!mounted) return;
    if (result != BioResult.success) {
      setState(() {
        _loading = false;
        // A cancelled prompt isn't an error worth shouting about.
        _errorMessage = result == BioResult.cancelled ? null : result.message;
      });
      return;
    }

    // Login with stored credentials
    try {
      await ref.read(authStateProvider.notifier).login(creds['email']!, creds['password']!, remember: true);
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = friendlyError(e);
      });
      return;
    }

    final auth = ref.read(authStateProvider);
    if (auth.isLoggedIn) {
      if (mounted) context.go('/');
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);

    final error = auth.error;
    if (error != null && _looksLikeWrongPassword(error)) {
      // The saved password no longer works (e.g. it was changed) — retire it
      // rather than fail the same way every time.
      await BiometricService.disable();
      if (!mounted) return;
      setState(() {
        _bioEnabled = false;
        _emailController.text = creds['email']!;
        _errorMessage = 'Your saved password no longer works. Sign in with your password '
            'and we\'ll set up fingerprint again.';
      });
    } else if (error != null) {
      setState(() => _errorMessage = error);
    }
  }

  static bool _looksLikeWrongPassword(String error) {
    final e = error.toLowerCase();
    return e.contains('password') || e.contains('credential') || e.contains('invalid');
  }

  /// "Sign in & turn on fingerprint": signs in with the typed password (so it
  /// is verified before being stored), then turns fingerprint on.
  Future<void> _signInAndEnableFingerprint() async {
    _setupAfterLogin = true;
    await _handleLogin();
  }

  Future<void> _handle2fa() async {
    if (_otpController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter the 6-digit code');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authStateProvider.notifier).verify2fa(_otpController.text.trim());
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = friendlyError(e);
      });
      return;
    }

    if (!mounted) return;
    final auth = ref.read(authStateProvider);
    setState(() => _loading = false);

    if (auth.error != null) {
      setState(() => _errorMessage = auth.error);
    } else if (auth.isLoggedIn) {
      final offer = _offerAfter2fa;
      if (offer != null && _bioAvailable && !_bioEnabled) {
        ref.read(biometricOfferProvider.notifier).state = offer;
      }
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.9),
            radius: 1.2,
            colors: [AppTheme.heroGlow, AppTheme.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AutofillGroup(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.35),
                                blurRadius: 40,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/icons/falcon_logo.png',
                            width: 96,
                            height: 96,
                            errorBuilder: (context, error, child) =>
                                Icon(Icons.shield, size: 96, color: AppTheme.primaryText),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Falcon Intel',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        auth.requires2fa ? 'One more step to keep your account safe' : 'Sign in to your threat intelligence feed',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                      ),
                      const SizedBox(height: 32),

                      // Fingerprint login button (if enabled)
                      if (_bioEnabled && !auth.requires2fa) ...[
                        ElevatedButton.icon(
                          onPressed: _loading ? null : _handleBiometricLogin,
                          icon: const Icon(Icons.fingerprint, size: 28),
                          label: const Text('Unlock with Fingerprint'),
                          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(58)),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('or sign in with email',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      Panel(
                        padding: const EdgeInsets.all(20),
                        child: auth.requires2fa ? _build2faForm() : _buildLoginForm(),
                      ),

                      // Error message
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        NoticeBanner.error(_errorMessage!),
                      ],

                      if (!auth.requires2fa) ...[
                        // Enable fingerprint option (if device supports it and not yet enabled)
                        if (_bioAvailable && !_bioEnabled && !_loading) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _signInAndEnableFingerprint,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Sign in & turn on fingerprint'),
                          ),
                        ],

                        // Disable fingerprint option (if already enabled)
                        if (_bioEnabled && !_loading) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () async {
                              await BiometricService.disable();
                              setState(() => _bioEnabled = false);
                            },
                            icon: const Icon(Icons.fingerprint, size: 18),
                            label: const Text('Turn off fingerprint login', style: TextStyle(fontSize: 13)),
                            style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                          ),
                        ],

                        const SizedBox(height: 24),
                        // Icon sits inline so it stays beside the words when the line wraps.
                        Text.rich(
                          TextSpan(children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(Icons.lock_outline_rounded, size: 14, color: AppTheme.textMuted),
                              ),
                            ),
                            const TextSpan(text: 'Invite-only. Need access? Contact your administrator.'),
                          ]),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email, AutofillHints.username],
          autocorrect: false,
          enabled: !_loading,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          enabled: !_loading,
          onSubmitted: (_) => _loading ? null : _handleLogin(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Whole row is tappable — bigger target than the switch alone.
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _loading ? null : () => setState(() => _remember = !_remember),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text('Keep me signed in', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
                ),
                Switch(
                  value: _remember,
                  onChanged: _loading ? null : (v) => setState(() => _remember = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _loading ? null : _handleLogin,
          child: _loading
              ? const _ButtonProgress('Signing in…')
              : const Text('Sign In'),
        ),
      ],
    );
  }

  Widget _build2faForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          alignment: Alignment.center,
          child: Icon(Icons.verified_user_outlined, size: 40, color: AppTheme.primaryText),
        ),
        const Text(
          'Enter the 6-digit code',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Open your authenticator app (e.g. Google Authenticator) and type the code shown for Falcon Intel.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          autofillHints: const [AutofillHints.oneTimeCode],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _loading ? null : _handle2fa(),
          style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            hintText: '000000',
            counterText: '',
          ),
          maxLength: 6,
          enabled: !_loading,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _loading ? null : _handle2fa,
          child: _loading ? const _ButtonProgress('Verifying…') : const Text('Verify'),
        ),
      ],
    );
  }
}

class _ButtonProgress extends StatelessWidget {
  final String label;
  const _ButtonProgress(this.label);

  @override
  Widget build(BuildContext context) {
    // Label kept for screen readers; the dots are what sighted users see.
    return Semantics(label: label, child: const DotsLoader());
  }
}
