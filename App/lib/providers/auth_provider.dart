import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/services/account_deletion.dart';
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

  /// The server ended this [account]'s session. Sign-in shows over the open
  /// screens, which keep what was typed until the same account signs back in.
  final bool expired;
  final Object? error;

  /// The account was just deleted: sign-in says so until the next attempt.
  final bool deleted;
  const AuthState({
    this.account,
    this.loading = false,
    this.restoring = false,
    this.expired = false,
    this.error,
    this.deleted = false,
  });
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(
    ref.read(apiClientProvider),
    google: ref.read(googleSignInServiceProvider),
    prepareErase: (accountId) => prepareAccountErase(ref.read, accountId),
  ),
);

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient api;
  final GoogleSignInService? google;

  /// Points reminders at an account, or at no one ('signed-out').
  final Future<void> Function(String owner) activateReminders;

  /// Readies erasing what a deleted account left on this phone. Called while
  /// it is still signed in: its own providers go as soon as it does. Null
  /// leaves the phone as it is.
  final Future<void> Function() Function(int accountId)? prepareErase;
  late final StreamSubscription<void> _sessionInvalidated;
  late final StreamSubscription<void> _accountUpdated;
  late final StreamSubscription<int> _accountDeleted;
  Future<void> _reminders = Future.value();
  int? _deletedAccount;
  Future<void> _forgettingDeleted = Future.value();
  AuthNotifier(
    this.api, {
    this.google,
    this.activateReminders = TaskReminders.activate,
    this.prepareErase,
  }) : super(const AuthState(loading: true, restoring: true)) {
    _sessionInvalidated = api.sessionInvalidated.listen((_) {
      if (!mounted || api.account != null) return;
      final account = state.restoring ? null : state.account;
      state = AuthState(
        account: account,
        expired: account != null,
        error: ApiException(401, 'Please sign in again.'),
      );
      _remind('signed-out');
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
    // The server says the account no longer exists: deleted on another
    // phone, or on this one with the answer lost. Another account's
    // session is never touched.
    _accountDeleted = api.accountDeleted.listen((accountId) {
      if (mounted && state.account?.id == accountId) {
        unawaited(forgetDeletedAccount().catchError((Object _) {}));
      }
    });
    restore();
  }

  @override
  void dispose() {
    _sessionInvalidated.cancel();
    _accountUpdated.cancel();
    _accountDeleted.cancel();
    super.dispose();
  }

  void clearError() {
    state = AuthState(
      account: state.account,
      loading: state.loading,
      restoring: state.restoring,
      expired: state.expired,
    );
  }

  String get _owner => api.account == null
      ? 'signed-out'
      : '${api.baseUrl}/users/${api.account!.id}';

  /// Sets up reminders for [owner] in the background, one change at a time:
  /// reconciling can wait seconds for another job, and nobody waits for it.
  void _remind(String owner, {bool launch = false}) {
    _reminders = _reminders
        .then((_) async {
          await activateReminders(owner);
          // Opened from a reminder: act on it once its account is active.
          if (launch) await TaskReminders.handleLaunch();
        })
        .catchError((Object _) {});
  }

  Future<void> restore() async {
    try {
      await api.restore();
      if (mounted) state = AuthState(account: api.account);
      _remind(_owner, launch: true);
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
    if (state.loading || state.expired || state.account == null) return;
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

  /// Failures are kept in [AuthState.error], except
  /// [EmailVerificationRequired], which is thrown: it isn't a problem to
  /// show, and the caller opens the screen that asks for the code.
  Future<void> signIn(
    String email,
    String password, {
    bool register = false,
    String timezone = 'UTC',
    String? language,
  }) async {
    state = AuthState(
      account: state.account,
      loading: true,
      expired: state.expired,
    );
    try {
      await api.signIn(
        email,
        password,
        register: register,
        timezone: timezone,
        language: language,
      );
      if (mounted) state = AuthState(account: api.account);
      _remind(_owner);
    } on EmailVerificationRequired {
      if (mounted) {
        state = AuthState(account: state.account, expired: state.expired);
      }
      rethrow;
    } catch (error) {
      if (mounted) {
        state = AuthState(
          account: state.account,
          expired: state.expired,
          error: error,
        );
      }
    }
  }

  /// Confirms [email] with its 6-digit [code] and the [password] just typed
  /// for it, which signs in as [signIn] does. Failures are thrown, not kept:
  /// the confirm screen shows them under its field.
  Future<void> verifyEmail(String email, String code, String password) async {
    state = AuthState(
      account: state.account,
      loading: true,
      expired: state.expired,
    );
    try {
      await api.verifyEmail(email, code, password);
    } catch (_) {
      if (mounted) {
        state = AuthState(account: state.account, expired: state.expired);
      }
      rethrow;
    }
    if (mounted) state = AuthState(account: api.account);
    _remind(_owner);
  }

  Future<void> signOut() async {
    await api.signOut();
    await google?.signOut();
    if (mounted) state = const AuthState();
    _remind('signed-out');
  }

  /// After the server deleted the signed-in account: the delete page's
  /// answer, or any request learning that the account no longer exists.
  /// Like [signOut], but nothing more is sent and sign-in says the account
  /// was deleted; once every reminder is cancelled, what the account left
  /// on this phone is erased, which signing out keeps. Runs once per
  /// account, however many requests learn it.
  Future<void> forgetDeletedAccount() {
    final accountId = state.account?.id;
    if (accountId != null && accountId != _deletedAccount) {
      _deletedAccount = accountId;
      _forgettingDeleted = _forgetDeleted(accountId);
    }
    return _forgettingDeleted;
  }

  Future<void> _forgetDeleted(int accountId) async {
    Future<void> Function()? erase;
    try {
      // Readied first, while the account's providers are still its own.
      erase = prepareErase?.call(accountId);
    } catch (_) {
      // Leaving the deleted account matters more than the erase.
    }
    try {
      await api.forgetSession();
    } catch (_) {
      // Already forgotten in memory; a saved copy is refused when next used.
    }
    await google?.signOut();
    if (mounted) state = const AuthState(deleted: true);
    _remind('signed-out');
    await _reminders;
    await erase?.call();
  }

  Future<void> signInWithGoogle(String token, {String timezone = 'UTC'}) async {
    state = AuthState(
      account: state.account,
      loading: true,
      expired: state.expired,
    );
    try {
      await api.signInWithGoogle(token, timezone: timezone);
      if (mounted) state = AuthState(account: api.account);
      _remind(_owner);
    } catch (error) {
      if (mounted) {
        state = AuthState(
          account: state.account,
          expired: state.expired,
          error: error,
        );
      }
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
