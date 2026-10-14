import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/google_sign_in_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.close);
  return client;
});

class AuthState {
  final Account? account;
  final bool loading;
  final bool restoring;
  final Object? error;
  const AuthState({
    this.account,
    this.loading = false,
    this.restoring = false,
    this.error,
  });
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(
    ref.read(apiClientProvider),
    google: ref.read(googleSignInServiceProvider),
  ),
);

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient api;
  final GoogleSignInService? google;
  late final StreamSubscription<void> _sessionInvalidated;
  late final StreamSubscription<void> _accountUpdated;
  AuthNotifier(this.api, {this.google})
    : super(const AuthState(loading: true, restoring: true)) {
    _sessionInvalidated = api.sessionInvalidated.listen((_) {
      if (!mounted || api.account != null) return;
      state = AuthState(error: ApiException(401, 'Please sign in again.'));
      unawaited(TaskReminders.activate('signed-out'));
    });
    // A dictation's answer or a refused upload updated the saved account.
    _accountUpdated = api.accountUpdated.listen((_) {
      final account = api.account;
      if (!mounted ||
          state.loading ||
          account == null ||
          state.account?.id != account.id) {
        return;
      }
      state = AuthState(account: account);
    });
    restore();
  }

  @override
  void dispose() {
    _sessionInvalidated.cancel();
    _accountUpdated.cancel();
    super.dispose();
  }

  void clearError() {
    state = AuthState(
      account: state.account,
      loading: state.loading,
      restoring: state.restoring,
    );
  }

  Future<void> restore() async {
    try {
      await api.restore();
      await TaskReminders.activate(
        api.account == null
            ? 'signed-out'
            : '${api.baseUrl}/users/${api.account!.id}',
      );
      if (mounted) state = AuthState(account: api.account);
      await TaskReminders.handleLaunch();
      await refreshAccount();
    } catch (_) {
      if (mounted) {
        state = const AuthState(
          error: 'Could not restore your session. Please sign in.',
        );
      }
    }
  }

  Future<void> refreshAccount() async {
    if (state.loading || state.account == null) return;
    try {
      final account = await api.refreshAccount();
      if (mounted && !state.loading && state.account?.id == account.id) {
        state = AuthState(account: account);
      }
    } catch (_) {
      // Keep the same account's offline profile. The API independently checks
      // paid access and invalidates expired/revoked login sessions.
    }
  }

  Future<void> signIn(
    String email,
    String password, {
    bool register = false,
    String timezone = 'UTC',
  }) async {
    state = AuthState(account: state.account, loading: true);
    try {
      await api.signIn(email, password, register: register, timezone: timezone);
      await TaskReminders.activate('${api.baseUrl}/users/${api.account!.id}');
      if (mounted) state = AuthState(account: api.account);
    } catch (error) {
      if (mounted) {
        state = AuthState(account: state.account, error: error);
      }
    }
  }

  Future<void> signOut() async {
    await api.signOut();
    await google?.signOut();
    await TaskReminders.activate('signed-out');
    if (mounted) state = const AuthState();
  }

  Future<void> signInWithGoogle(String token, {String timezone = 'UTC'}) async {
    state = AuthState(account: state.account, loading: true);
    try {
      await api.signInWithGoogle(token, timezone: timezone);
      await TaskReminders.activate('${api.baseUrl}/users/${api.account!.id}');
      if (mounted) state = AuthState(account: api.account);
    } catch (error) {
      if (mounted) state = AuthState(account: state.account, error: error);
    }
  }

  Future<void> linkGoogle(String token, String password) async {
    state = AuthState(account: state.account, loading: true);
    try {
      await api.linkGoogle(token, password);
      if (mounted) state = AuthState(account: api.account);
    } catch (error) {
      if (mounted) state = AuthState(account: state.account, error: error);
    }
  }
}
