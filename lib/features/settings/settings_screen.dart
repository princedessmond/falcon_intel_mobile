import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/biometric_service.dart';
import '../../core/preferences/user_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode.dart';
import '../../core/widgets/common.dart';
import 'preferences_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final isAdmin = auth.role == 'admin';
    final roleColor = isAdmin ? AppTheme.accentPurple : AppTheme.primaryText;

    return Scaffold(
      appBar: const ScreenHeader(title: 'Settings', subtitle: 'Your account, security and appearance'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Profile card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Panel(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      _initials(auth.name ?? auth.email),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(auth.name ?? 'Unknown',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                        const SizedBox(height: 2),
                        Text(auth.email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5)),
                        const SizedBox(height: 8),
                        Pill(
                          text: formatLabel(auth.role ?? 'user'),
                          color: roleColor,
                          icon: isAdmin ? Icons.admin_panel_settings_outlined : Icons.shield_outlined,
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Appearance
          _SettingsGroup(
            title: 'Appearance',
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('"System" follows your phone\'s light or dark setting',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                              value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('System')),
                          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                        ],
                        selected: {ref.watch(themeModeProvider)},
                        onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // My Preferences
          _SettingsGroup(
            title: 'Personalization',
            children: [
              Consumer(builder: (context, ref, _) {
                final prefs = ref.watch(preferencesProvider);
                return _SettingsTile(
                  icon: Icons.tune_rounded,
                  iconColor: AppTheme.primaryText,
                  title: 'My Preferences',
                  subtitle: prefs.hasFilters
                      ? '${prefs.preferredCategories.length} topics · ${prefs.preferredCounties.length} counties'
                      : 'No filters set — showing everything',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PreferencesScreen()),
                  ),
                );
              }),
            ],
          ),

          // Security
          _SettingsGroup(
            title: 'Security',
            children: [
              _SettingsTile(
                icon: Icons.verified_user_outlined,
                iconColor: AppTheme.accentGreen,
                title: 'Two-Factor Authentication',
                subtitle: 'Manage 2FA via Google Authenticator',
                onTap: () => showAppSnack(context, '2FA management — coming soon'),
              ),
              const _FingerprintTile(),
            ],
          ),

          // Notifications
          _SettingsGroup(
            title: 'Notifications',
            children: [
              _SettingsTile(
                icon: Icons.notifications_active_outlined,
                iconColor: AppTheme.accentAmber,
                title: 'Push Notifications',
                subtitle: 'Receive alerts on this device',
                trailing: Switch(
                  value: true,
                  onChanged: (v) =>
                      showAppSnack(context, v ? 'Notifications enabled' : 'Notifications disabled'),
                ),
              ),
            ],
          ),

          // Server & About
          _SettingsGroup(
            title: 'About',
            children: [
              _SettingsTile(
                icon: Icons.dns_outlined,
                title: 'Server',
                subtitle: 'https://falconintel.org',
                onTap: () => showAppSnack(context, 'Server URL configuration — coming soon'),
              ),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy & Terms',
                onTap: () => showAppSnack(context, 'Restricted — invite-only platform'),
              ),
              const _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'Falcon Intel Mobile',
                subtitle: 'Version 1.0.0',
              ),
            ],
          ),

          // Logout
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentRed,
                side: BorderSide(color: AppTheme.accentRed.withValues(alpha: 0.5)),
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out'),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'[\s@._]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You\'ll need to sign in again to see your alerts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.dangerFill),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

/// Titled group of settings rows inside one rounded card.
class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(title, padding: const EdgeInsets.only(left: 4, bottom: 8)),
          Material(
            color: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              side: BorderSide(color: AppTheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(indent: 64),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.iconColor,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = this.iconColor ?? AppTheme.textSecondary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right_rounded) : null),
      onTap: onTap,
    );
  }
}

/// Fingerprint sign-in switch. Turning it on asks for the account password
/// once (checked with the server), then the fingerprint, and stores the login
/// encrypted on the phone.
class _FingerprintTile extends ConsumerStatefulWidget {
  const _FingerprintTile();

  @override
  ConsumerState<_FingerprintTile> createState() => _FingerprintTileState();
}

class _FingerprintTileState extends ConsumerState<_FingerprintTile> {
  bool? _available;
  bool _enabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (!mounted) return;
    setState(() {
      _available = available;
      _enabled = enabled;
    });
  }

  Future<void> _turnOn() async {
    final email = ref.read(authStateProvider).email;
    if (email == null || email.isEmpty) return;
    final password = await showDialog<String>(context: context, builder: (_) => _ConfirmPasswordDialog(email: email));
    if (password == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final ok = await ApiClient.instance.verifyPassword(email, password);
      if (!mounted) return;
      if (!ok) {
        showAppSnack(context, 'That password isn\'t right. Fingerprint sign-in wasn\'t turned on.', error: true);
        return;
      }
      final result = await BiometricService.enable(email, password);
      if (!mounted) return;
      if (result == BioResult.success) {
        showAppSnack(context, 'Fingerprint sign-in is on', success: true);
      } else if (result != BioResult.cancelled) {
        showAppSnack(context, result.message, error: true);
      }
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  Future<void> _turnOff() async {
    await BiometricService.disable();
    if (mounted) showAppSnack(context, 'Fingerprint sign-in is off');
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_available == null) {
      return const _SettingsTile(icon: Icons.fingerprint, title: 'Fingerprint Login', subtitle: 'Checking this phone…');
    }
    if (_available == false) {
      return const _SettingsTile(
        icon: Icons.fingerprint,
        title: 'Fingerprint Login',
        subtitle: 'Add a fingerprint in your phone\'s Settings → Security to use this',
      );
    }
    return _SettingsTile(
      icon: Icons.fingerprint,
      iconColor: _enabled ? AppTheme.accentGreen : AppTheme.textSecondary,
      title: 'Fingerprint Login',
      subtitle: _enabled ? 'On — sign in with your fingerprint' : 'Off — turn on to skip typing your password',
      trailing: _busy
          ? SizedBox(width: 56, child: DotsLoader(color: AppTheme.primaryText, size: 18))
          : Switch(value: _enabled, onChanged: (v) => v ? _turnOn() : _turnOff()),
    );
  }
}

class _ConfirmPasswordDialog extends StatefulWidget {
  final String email;
  const _ConfirmPasswordDialog({required this.email});

  @override
  State<_ConfirmPasswordDialog> createState() => _ConfirmPasswordDialogState();
}

class _ConfirmPasswordDialogState extends State<_ConfirmPasswordDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.isNotEmpty) Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm your password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enter the password for ${widget.email} to turn on fingerprint sign-in.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Continue')),
      ],
    );
  }
}
