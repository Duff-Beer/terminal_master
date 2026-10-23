import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final decision = await showDialog<_HostKeyDecision>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.hostKeyUnknownTitle),
        content: SelectableText(
          l10n.hostKeyUnknownMessage(profile.endpoint, keyType, fingerprint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _HostKeyDecision.reject),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _HostKeyDecision.once),
            child: Text(l10n.hostKeyTrustOnce),
          ),
          FilledButton(
            key: const Key('trust-ssh-host-key'),
            onPressed: () =>
                Navigator.pop(context, _HostKeyDecision.permanently),
            child: Text(l10n.hostKeyTrustPermanently),
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
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.hostKeyChangedTitle),
        content: SelectableText(
          l10n.hostKeyChangedMessage(
            profile.endpoint,
            '${profile.hostKeyType} ${profile.hostKeyFingerprint}',
            '$keyType $fingerprint',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }
}
