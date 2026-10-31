import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

final googleSignInServiceProvider = Provider<GoogleSignInService>(
  (ref) => GoogleSignInService(),
);

class GoogleSignInProblem implements Exception {
  final String code;
  const GoogleSignInProblem(this.code);
}

/// Only an ID token crosses into Django. Google access/refresh tokens are not
/// needed for login and are never persisted by TaskFlow.
class GoogleSignInService {
  static const serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  Future<void>? _initializing;

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get configured =>
      supported &&
      serverClientId.isNotEmpty &&
      (defaultTargetPlatform != TargetPlatform.iOS || iosClientId.isNotEmpty);

  Future<void> _initialize() async {
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: serverClientId,
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? iosClientId
            : null,
      );
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<String?> authenticate() async {
    if (!configured) throw const GoogleSignInProblem('google_not_configured');
    try {
      await (_initializing ??= _initialize());
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const GoogleSignInProblem('google_invalid_token');
      }
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const GoogleSignInProblem('google_not_configured');
      }
      throw const GoogleSignInProblem('google_unavailable');
    }
  }

  Future<void> signOut() async {
    if (_initializing == null) return;
    try {
      await _initializing;
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Local TaskFlow credentials must still be removed if Google is offline.
    }
  }
}
