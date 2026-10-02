import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/biometric_service.dart';
import '../../core/preferences/user_preferences.dart';
import '../../core/theme/app_theme.dart';
import 'preferences_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Profile section
          _SectionHeader('Account'),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              backgroundImage: AssetImage('assets/icons/falcon_logo.png'),
            ),
            title: Text(auth.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(auth.email ?? ''),
          ),
          ListTile(
            leading: Icon(Icons.shield_outlined, color: AppTheme.primaryColor),
            title: const Text('Role'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (auth.role == 'admin' ? AppTheme.accentPurple : AppTheme.primaryColor).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                auth.role?.toUpperCase() ?? 'USER',
                style: TextStyle(
                  color: auth.role == 'admin' ? AppTheme.accentPurple : AppTheme.primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const Divider(),

          // My Preferences
          _SectionHeader('Personalization'),
          Consumer(builder: (context, ref, _) {
            final prefs = ref.watch(preferencesProvider);
            return ListTile(
              leading: const Icon(Icons.tune, color: AppTheme.primaryColor),
              title: const Text('My Preferences'),
              subtitle: Text(
                prefs.hasFilters
                    ? '${prefs.preferredCategories.length} categories · ${prefs.preferredCounties.length} counties'
                    : 'No filters set — showing all',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PreferencesScreen()),
              ),
            );
          }),

          const Divider(),

          // Security
          _SectionHeader('Security'),
          ListTile(
            leading: Icon(Icons.lock_outline, color: AppTheme.accentGreen),
            title: const Text('Two-Factor Authentication'),
            subtitle: const Text('Manage 2FA via Google Authenticator'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('2FA management — coming soon')),
              );
            },
          ),

          // Fingerprint login toggle
          StatefulBuilder(builder: (context, setState) {
            bool _bioAvailable = false;
            bool _bioEnabled = false;

            return FutureBuilder<List<bool>>(
              future: Future.wait([
                BiometricService.isAvailable(),
                BiometricService.isEnabled(),
              ]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final available = snapshot.data![0];
                final enabled = snapshot.data![1];

                if (!available) {
                  // Device doesn't support biometrics
                  return ListTile(
                    leading: Icon(Icons.fingerprint, color: AppTheme.textSecondary),
                    title: const Text('Fingerprint Login'),
                    subtitle: const Text('Not available on this device'),
                    trailing: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                  );
                }

                return ListTile(
                  leading: Icon(Icons.fingerprint,
                      color: enabled ? AppTheme.accentGreen : AppTheme.textSecondary),
                  title: const Text('Fingerprint Login'),
                  subtitle: Text(enabled
                      ? 'Enabled — unlock with fingerprint'
                      : 'Enable to skip password entry'),
                  trailing: Switch(
                    value: enabled,
                    activeColor: AppTheme.accentGreen,
                    onChanged: (v) async {
                      if (v) {
                        // Enable — need credentials
                        final creds = await BiometricService.getCredentials();
                        if (creds != null) {
                          // Already has stored creds, just re-enable
                          final success = await BiometricService.enable(
                              creds['email']!, creds['password']!);
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fingerprint login enabled'),
                                backgroundColor: AppTheme.accentGreen,
                              ),
                            );
                          }
                        } else {
                          // Need to enter credentials first
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please login with email + password first, then enable fingerprint from the login screen'),
                              backgroundColor: AppTheme.accentAmber,
                            ),
                          );
                        }
                      } else {
                        // Disable
                        await BiometricService.disable();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fingerprint login disabled')),
                        );
                      }
                      setState(() {});
                    },
                  ),
                );
              },
            );
          }),

          const Divider(),

          // Server
          _SectionHeader('Server'),
          ListTile(
            leading: Icon(Icons.dns_outlined, color: AppTheme.textSecondary),
            title: const Text('Server URL'),
            subtitle: const Text('https://falconintel.org'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Server URL configuration — coming soon')),
              );
            },
          ),

          const Divider(),

          // Notifications
          _SectionHeader('Notifications'),
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive alerts on this device'),
            value: true,
            onChanged: (v) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(v ? 'Notifications enabled' : 'Notifications disabled')),
              );
            },
            secondary: Icon(Icons.notifications_active, color: AppTheme.accentAmber),
          ),

          const Divider(),

          // About
          _SectionHeader('About'),
          ListTile(
            leading: Icon(Icons.info_outline, color: AppTheme.textSecondary),
            title: const Text('Falcon Intel Mobile'),
            subtitle: const Text('Version 1.0.0'),
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: AppTheme.textSecondary),
            title: const Text('Privacy & Terms'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restricted — invite-only platform')),
              );
            },
          ),

          const Divider(height: 32),

          // Logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () => _confirmLogout(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authStateProvider.notifier).logout();
              context.go('/login');
            },
            child: const Text('Sign Out', style: TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}