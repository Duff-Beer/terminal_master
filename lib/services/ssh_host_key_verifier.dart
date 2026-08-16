import 'package:flutter/material.dart';

import '../models/ssh_connection_profile.dart';
import 'ssh_connection_profile_store.dart';

abstract interface class SshHostKeyVerifier {
  Future<bool> verify(
    SshConnectionProfile profile,
    String keyType,
    String fingerprint,
  );
}

class TrustAllSshHostKeyVerifier implements SshHostKeyVerifier {
  const TrustAllSshHostKeyVerifier();

  @override
  Future<bool> verify(
    SshConnectionProfile profile,
    String keyType,
    String fingerprint,
  ) async => true;
}

enum _HostKeyDecision { reject, once, permanently }

class DialogSshHostKeyVerifier implements SshHostKeyVerifier {
  final GlobalKey<NavigatorState> navigatorKey;
  final SshConnectionProfileStore profileStore;

  const DialogSshHostKeyVerifier({
    required this.navigatorKey,
    required this.profileStore,
  });

  @override
  Future<bool> verify(
    SshConnectionProfile profile,
    String keyType,
    String fingerprint,
  ) async {
    final trustedFingerprint = profile.hostKeyFingerprint;
    if (trustedFingerprint != null) {
      final matches =
          trustedFingerprint == fingerprint && profile.hostKeyType == keyType;
      if (!matches) await _showChangedKey(profile, keyType, fingerprint);
      return matches;
    }

    final context = navigatorKey.currentContext;
    if (context == null) return false;
    final decision = await showDialog<_HostKeyDecision>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Unbekannter SSH-Server'),
        content: SelectableText(
          'Für ${profile.endpoint} ist noch kein Host-Key gespeichert.\n\n'
          'Typ: $keyType\nFingerprint: $fingerprint\n\n'
          'Vergleiche den Fingerprint mit einer vertrauenswürdigen Quelle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _HostKeyDecision.reject),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _HostKeyDecision.once),
            child: const Text('Einmal vertrauen'),
          ),
          FilledButton(
            key: const Key('trust-ssh-host-key'),
            onPressed: () =>
                Navigator.pop(context, _HostKeyDecision.permanently),
            child: const Text('Dauerhaft vertrauen'),
          ),
        ],
      ),
    );
    if (decision == _HostKeyDecision.permanently) {
      return profileStore.trustHostKey(
        id: profile.id,
        expectedHost: profile.host,
        expectedPort: profile.port,
        keyType: keyType,
        fingerprint: fingerprint,
      );
    }
    return decision == _HostKeyDecision.once;
  }

  Future<void> _showChangedKey(
    SshConnectionProfile profile,
    String keyType,
    String fingerprint,
  ) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('SSH-Host-Key geändert'),
        content: SelectableText(
          'Die Identität von ${profile.endpoint} stimmt nicht mit dem '
          'gespeicherten Host-Key überein. Die Verbindung wurde blockiert.\n\n'
          'Gespeichert: ${profile.hostKeyType} '
          '${profile.hostKeyFingerprint}\n'
          'Empfangen: $keyType $fingerprint',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }
}
