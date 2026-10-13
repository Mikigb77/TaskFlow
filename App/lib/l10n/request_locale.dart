import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'generated/app_localizations.dart';

/// Keep server diagnostics separate from UI copy. Unknown responses must not
/// leak raw English, internal field names or exception details into the UI.
String requestProblemText(AppLocalizations strings, Object error) {
  Object? code;
  if (error is GoogleSignInProblem) code = error.code;
  if (error is ApiException && error.body != null) code = error.body!['code'];
  if (code is String && code.startsWith('google_')) {
    return strings.googleSignInError(code);
  }
  final message = error.toString().toLowerCase();
  if (message.contains('staging version is for invited testers')) {
    return strings.stagingInviteOnly;
  }
  final sharing = switch (message) {
    _ when message.contains('already has access') => 'alreadyMember',
    _
        when message.contains('20 members') ||
            message.contains('membership limit') =>
      'memberLimit',
    _ when message.contains('invitation was already accepted') => 'accepted',
    _ when message.contains('owner cannot leave') => 'owner',
    _ when message.contains('invitation is no longer available') => 'expired',
    _ when message.contains('current invitation code') => 'code',
    _ when message.contains('refresh before deleting') => 'refresh',
    _ when message.contains('only the list owner') => 'ownerOnly',
    _ when message.contains('read-only for your account') => 'readOnly',
    _ => null,
  };
  if (sharing != null) return strings.sharingProblem(sharing);
  // These older sync notices are persisted as text. Preserve their recovery
  // instructions while translating at render time, including after a switch.
  final sync = switch (message) {
    _ when message.contains('task responsibility changed') =>
      'assignmentChanged',
    _ when message.contains('a list changed on another device') =>
      'listConflict',
    _ when message.contains('list is now read-only') => 'readOnly',
    _ when message.contains('shared-list access changed') => 'accessChanged',
    _ when message.contains('a task changed on another device') =>
      'taskConflict',
    _ when message.contains('update this server') => 'serverUpdate',
    _ when message.contains('did not preserve this content type') =>
      'contentType',
    _ => null,
  };
  return sync == null
      ? strings.requestError(requestProblem(error))
      : strings.syncProblem(sync);
}

String requestProblem(Object error) {
  final message = error.toString().toLowerCase();
  final status = error is ApiException ? error.status : null;
  final body = error is ApiException ? error.body : null;
  if (message.contains('sign out before changing servers')) {
    return 'signOutFirst';
  }
  if (message.contains('https server')) return 'https';
  if (message.contains('enter a server address')) return 'serverAddress';
  if (message.contains('email already exists')) return 'emailUsed';
  if (body?.containsKey('email') == true) return 'email';
  if (message.contains('no active account') ||
      message.contains('invalid credentials')) {
    return 'credentials';
  }
  if (message.contains('restore your session')) return 'session';
  if (message.contains('account changed')) return 'accountChanged';
  if (message.contains('password') &&
      (status == 400 || body?.containsKey('password') == true)) {
    return 'password';
  }
  if ((status == 400 && body?.containsKey('code') == true) ||
      message.contains('invalid or expired') ||
      message.contains('invalid reset')) {
    return 'recoveryCode';
  }
  if (status == 401 || message.contains('sign in')) return 'session';
  if (status == 403) return 'forbidden';
  if (status == 429) return 'rateLimit';
  if (status == 413 || message.contains('6 mib')) return 'fileLimit';
  if (message.contains('checksum') || message.contains('file changed')) {
    return 'fileChanged';
  }
  if (status == 0 ||
      message.contains('connection') ||
      message.contains('timed out') ||
      message.contains('too long') ||
      message.contains('cannot reach')) {
    return 'network';
  }
  if (status != null && status >= 500) return 'unavailable';
  if (status == 400) return 'validation';
  return 'other';
}
