import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'biometric_service.dart';

/// Credentials that just signed in successfully, waiting for the user to
/// decide on fingerprint sign-in.
///
/// The offer can't be shown on the login screen: signing in navigates away
/// immediately, which would tear the dialog down with it. Instead the login
/// screen leaves the offer here and the main shell shows it once it's on screen.
class BiometricOffer {
  final String email;
  final String password;

  /// The user already asked for fingerprint ("Sign in & turn on fingerprint"),
  /// so skip the question and go straight to the fingerprint check.
  final bool autoEnable;
  const BiometricOffer({required this.email, required this.password, this.autoEnable = false});
}

final biometricOfferProvider = StateProvider<BiometricOffer?>((ref) => null);

/// Shows the pending offer (if any) and clears it so it's only shown once.
Future<void> presentBiometricOffer(BuildContext context, WidgetRef ref) async {
  final offer = ref.read(biometricOfferProvider);
  if (offer == null) return;
  ref.read(biometricOfferProvider.notifier).state = null;

  final wantsIt = offer.autoEnable ||
      await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.fingerprint, color: AppTheme.primaryText),
                  const SizedBox(width: 8),
                  const Flexible(child: Text('Enable Fingerprint')), // wraps at large text sizes
                ],
              ),
              content: const Text(
                'Would you like to sign in with your fingerprint next time? '
                'No password needed — your login is stored encrypted on this phone.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Not now')),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Enable'),
                ),
              ],
            ),
          ) ==
          true;
  if (!wantsIt) return;

  final result = await BiometricService.enable(offer.email, offer.password);
  if (!context.mounted) return;
  if (result == BioResult.success) {
    showAppSnack(context, 'Fingerprint sign-in is on. Next time, just tap "Unlock with Fingerprint".', success: true);
  } else {
    showAppSnack(context, 'Fingerprint sign-in wasn\'t turned on. ${result.message}', error: true);
  }
}
