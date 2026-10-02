import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/biometric_service.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

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
    if (mounted) {
      setState(() {
        _bioAvailable = available;
        _bioEnabled = enabled;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
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

    try {
      await ref.read(authStateProvider.notifier).login(
        _emailController.text.trim(),
        _passwordController.text,
        remember: _remember,
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      return;
    }

    if (!mounted) return;
    final auth = ref.read(authStateProvider);
    setState(() => _loading = false);

    if (auth.error != null) {
      setState(() => _errorMessage = auth.error);
    } else if (auth.isLoggedIn) {
      // Check if we should prompt to enable fingerprint
      if (_bioAvailable && !_bioEnabled) {
        _promptEnableBiometric(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        context.go('/');
      }
    }
    // If requires2fa, UI switches automatically
  }

  void _promptEnableBiometric(String email, String password) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.fingerprint, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Enable Fingerprint'),
          ],
        ),
        content: const Text(
          'Would you like to enable fingerprint login? '
          'Next time, you can unlock the app with just your fingerprint — no password needed.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.go('/');
            },
            child: const Text('Not now'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await BiometricService.enable(email, password);
              if (success && mounted) {
                setState(() => _bioEnabled = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fingerprint login enabled! Next time, just tap the fingerprint button.'),
                    backgroundColor: AppTheme.accentGreen,
                    duration: Duration(seconds: 4),
                  ),
                );
              }
              context.go('/');
            },
            icon: const Icon(Icons.fingerprint),
            label: const Text('Enable'),
          ),
        ],
      ),
    );
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
        _errorMessage = 'Biometric login not configured';
      });
      return;
    }

    // Authenticate with fingerprint
    final didAuth = await BiometricService.authenticate();
    if (!didAuth) {
      setState(() {
        _loading = false;
        _errorMessage = 'Biometric authentication failed';
      });
      return;
    }

    // Login with stored credentials
    try {
      await ref.read(authStateProvider.notifier).login(
        creds['email']!,
        creds['password']!,
        remember: true,
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      return;
    }

    if (!mounted) return;
    final auth = ref.read(authStateProvider);
    setState(() => _loading = false);

    if (auth.error != null) {
      setState(() => _errorMessage = auth.error);
    } else if (auth.isLoggedIn) {
      context.go('/');
    }
  }

  Future<void> _enableBiometric() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Enter your credentials first to enable fingerprint');
      return;
    }

    final success = await BiometricService.enable(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      if (success) {
        setState(() {
          _bioEnabled = true;
          _errorMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fingerprint login enabled'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to enable fingerprint'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
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
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      return;
    }

    if (!mounted) return;
    final auth = ref.read(authStateProvider);
    setState(() => _loading = false);

    if (auth.error != null) {
      setState(() => _errorMessage = auth.error);
    } else if (auth.isLoggedIn) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Image.asset(
                    'assets/icons/falcon_logo.png',
                    width: 80,
                    height: 80,
                    errorBuilder: (context, error, child) => Icon(
                      Icons.shield,
                      size: 80,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Falcon Intel',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Threat Intelligence',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 40),

                  // Fingerprint login button (if enabled)
                  if (_bioEnabled && !auth.requires2fa) ...[
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _handleBiometricLogin,
                      icon: const Icon(Icons.fingerprint, size: 28),
                      label: const Text('Unlock with Fingerprint', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Divider
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppTheme.textSecondary)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or sign in manually',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ),
                        const Expanded(child: Divider(color: AppTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (auth.requires2fa) ...[
                    // 2FA verification
                    Text(
                      'Enter your 6-digit verification code',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, letterSpacing: 8),
                      decoration: const InputDecoration(
                        hintText: '000000',
                        counterText: '',
                      ),
                      maxLength: 6,
                      enabled: !_loading,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loading ? null : _handle2fa,
                      child: _loading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(height: 20, width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                SizedBox(width: 12),
                                Text('Verifying...'),
                              ],
                            )
                          : const Text('Verify'),
                    ),
                  ] else ...[
                    // Login form
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_loading,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_loading,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Switch(
                          value: _remember,
                          onChanged: _loading ? null : (v) => setState(() => _remember = v),
                          activeColor: AppTheme.primaryColor,
                        ),
                        const Text('Keep me signed in',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loading ? null : _handleLogin,
                      child: _loading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(height: 20, width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                SizedBox(width: 12),
                                Text('Signing in...'),
                              ],
                            )
                          : const Text('Sign In'),
                    ),

                    // Enable fingerprint option (if device supports it and not yet enabled)
                    if (_bioAvailable && !_bioEnabled && !_loading) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _enableBiometric,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Enable Fingerprint Login'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],

                    // Disable fingerprint option (if already enabled)
                    if (_bioEnabled && !_loading) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () async {
                          await BiometricService.disable();
                          setState(() => _bioEnabled = false);
                        },
                        icon: const Icon(Icons.fingerprint, size: 18),
                        label: const Text('Disable Fingerprint Login',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                      ),
                    ],

                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'Need access? Contact your administrator.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],

                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.accentRed.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMessage!,
                                style: const TextStyle(color: AppTheme.accentRed, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
