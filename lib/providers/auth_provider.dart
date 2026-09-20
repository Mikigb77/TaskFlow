import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/notification_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.close);
  return client;
});

class AuthState {
  final Account? account;
  final bool loading;
  final String? error;
  const AuthState({this.account, this.loading = false, this.error});
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
    (ref) => AuthNotifier(ref.read(apiClientProvider)));

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient api;
  AuthNotifier(this.api) : super(const AuthState(loading: true)) {
    restore();
  }

  Future<void> restore() async {
    try {
      await api.restore();
      if (mounted) state = AuthState(account: api.account);
    } catch (_) {
      if (mounted) {
        state = const AuthState(
            error: 'Could not restore your session. Please sign in.');
      }
    }
  }

  Future<void> signIn(String email, String password,
      {bool register = false, String timezone = 'Europe/Madrid'}) async {
    state = AuthState(account: state.account, loading: true);
    try {
      await api.signIn(email, password, register: register, timezone: timezone);
      await TaskReminders.sync([]);
      if (mounted) state = AuthState(account: api.account);
    } catch (error) {
      if (mounted) {
        state = AuthState(account: state.account, error: error.toString());
      }
    }
  }

  Future<void> signOut() async {
    await api.signOut();
    await TaskReminders.sync([]);
    if (mounted) state = const AuthState();
  }
}
