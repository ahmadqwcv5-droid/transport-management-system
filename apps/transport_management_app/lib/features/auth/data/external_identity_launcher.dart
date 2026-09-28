import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

final class ExternalIdentityCredential {
  const ExternalIdentityCredential({required this.idToken, this.nonce});
  final String idToken;
  final String? nonce;
}

abstract interface class ExternalIdentityLauncher {
  bool get isAvailable;
  Future<ExternalIdentityCredential?> authenticate(String provider);
}

final class UnavailableExternalIdentityLauncher
    implements ExternalIdentityLauncher {
  const UnavailableExternalIdentityLauncher();
  @override
  bool get isAvailable => false;
  @override
  Future<ExternalIdentityCredential?> authenticate(String provider) async =>
      null;
}

final class GoogleExternalIdentityLauncher implements ExternalIdentityLauncher {
  GoogleExternalIdentityLauncher();

  static const _androidClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_CLIENT_ID',
  );
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  Future<void>? _initialization;

  @override
  bool get isAvailable =>
      !kIsWeb &&
      (_androidClientId.isNotEmpty || _serverClientId.isNotEmpty);

  Future<void> _initialize() => _initialization ??= GoogleSignIn.instance
      .initialize(
        clientId: _androidClientId.isEmpty ? null : _androidClientId,
        serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
      );

  @override
  Future<ExternalIdentityCredential?> authenticate(String provider) async {
    if (!isAvailable || provider.toLowerCase() != 'google') return null;
    await _initialize();
    if (!GoogleSignIn.instance.supportsAuthenticate()) return null;
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) return null;
    return ExternalIdentityCredential(idToken: idToken);
  }
}

final externalIdentityLauncherProvider = Provider<ExternalIdentityLauncher>(
  (_) => GoogleExternalIdentityLauncher(),
);
