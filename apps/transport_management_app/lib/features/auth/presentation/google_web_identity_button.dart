import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_web_button.dart';

class GoogleWebIdentityButton extends StatefulWidget {
  const GoogleWebIdentityButton({
    required this.clientId,
    required this.onIdToken,
    super.key,
  });

  final String clientId;
  final Future<void> Function(String idToken) onIdToken;

  @override
  State<GoogleWebIdentityButton> createState() =>
      _GoogleWebIdentityButtonState();
}

class _GoogleWebIdentityButtonState extends State<GoogleWebIdentityButton> {
  static Future<void>? _initialization;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  late final Future<void> _ready = _initialize();

  Future<void> _initialize() async {
    await (_initialization ??= GoogleSignIn.instance.initialize(
      clientId: widget.clientId,
    ));
    _subscription = GoogleSignIn.instance.authenticationEvents.listen(
      _onAuthentication,
    );
  }

  Future<void> _onAuthentication(
    GoogleSignInAuthenticationEvent event,
  ) async {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    final idToken = event.user.authentication.idToken;
    if (idToken == null || idToken.isEmpty) return;
    await widget.onIdToken(idToken);
    await GoogleSignIn.instance.signOut();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const SizedBox.shrink();
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        key: const Key('google-sign-in'),
        child: renderGoogleButton(),
      );
    },
  );
}
