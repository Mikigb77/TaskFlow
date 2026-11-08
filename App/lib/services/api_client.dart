import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

class ApiException implements Exception {
  final int status;
  final String message;
  final Map<String, dynamic>? body;

  /// How long the server asked to wait (`Retry-After`, in seconds), when it
  /// said.
  final Duration? retryAfter;
  ApiException(this.status, this.message, [this.body, this.retryAfter]);
  @override
  String toString() => message;
}

/// Sign-in refused the email and password: a 401 from `auth/login/`,
/// whatever its wording. The app's own marker, so the answer is read by
/// where it came from rather than by the server's English.
class WrongCredentials extends ApiException {
  WrongCredentials(ApiException error)
    : super(error.status, error.message, error.body, error.retryAfter);
}

/// The account's email address isn't confirmed yet: the server has emailed a
/// 6-digit code to [email], and signs in only once it is typed. Thrown by
/// [ApiClient.signIn] for a new account, and for a right password whose
/// address waits for its code.
class EmailVerificationRequired implements Exception {
  const EmailVerificationRequired(this.email);
  final String email;
  @override
  String toString() => 'Confirm your email address to continue.';
}

/// The free dictations of an account without Pro, this calendar month (UTC).
class FreeVoice {
  const FreeVoice({
    required this.limit,
    required this.left,
    required this.resetsAt,
  });
  final int limit;
  final int left;
  final DateTime resetsAt;

  /// Null when the server sent no block (an older server) or a malformed one.
  static FreeVoice? fromJson(Object? data) {
    if (data is! Map) return null;
    final limit = data['limit'];
    final left = data['left'];
    final resetsAt = DateTime.tryParse('${data['resets_at']}');
    if (limit is! num || left is! num || resetsAt == null) return null;
    return FreeVoice(
      limit: limit.toInt(),
      left: left.toInt(),
      resetsAt: resetsAt,
    );
  }

  /// What is left at [now]: a saved count from before the reset counts as the
  /// whole new month.
  int leftAt(DateTime now) => now.isBefore(resetsAt) ? left : limit;

  /// When they come back without a saved date: the next calendar month, in
  /// UTC, as the server counts them.
  static DateTime nextReset(DateTime now) {
    final utc = now.toUtc();
    return DateTime.utc(utc.year, utc.month + 1);
  }
}

/// What the account has uploaded as files, against its allowance. Removed
/// and cleaned-up files still count. Without Pro: everything ever uploaded,
/// against [limitBytes]. With Pro: this UTC month's, against
/// [monthLimitBytes], until [resetsAt]. An older server sends only the first.
class AccountStorage {
  const AccountStorage({
    required this.usedBytes,
    required this.limitBytes,
    this.monthUsedBytes,
    this.monthLimitBytes,
    this.resetsAt,
  });
  final int usedBytes;
  final int limitBytes;
  final int? monthUsedBytes;
  final int? monthLimitBytes;
  final DateTime? resetsAt;

  static AccountStorage? fromJson(Object? data) {
    if (data is! Map) return null;
    final used = data['used_bytes'];
    final limit = data['limit_bytes'];
    if (used is! num || limit is! num) return null;
    final monthUsed = data['month_used_bytes'];
    final monthLimit = data['month_limit_bytes'];
    final resets = data['resets_at'];
    return AccountStorage(
      usedBytes: used.toInt(),
      limitBytes: limit.toInt(),
      monthUsedBytes: monthUsed is num ? monthUsed.toInt() : null,
      monthLimitBytes: monthLimit is num ? monthLimit.toInt() : null,
      resetsAt: resets is String ? DateTime.tryParse(resets) : null,
    );
  }
}

class Account {
  final int id;
  final String email;

  /// The name others see on shared projects; '' when the account has none.
  final String firstName;
  final String timezone;
  final String? billingId;
  final bool googleLinked;
  final bool complimentaryPro;

  /// Saved with the session, so both work offline. Null for sessions saved
  /// before the server sent them.
  final FreeVoice? freeVoice;
  final AccountStorage? storage;
  Account.fromJson(Map<String, dynamic> data)
    : id = data['id'] as int,
      email = data['email'] as String,
      firstName = (data['first_name'] as String?) ?? '',
      timezone = data['timezone'] as String,
      billingId = data['billing_id'] as String?,
      googleLinked = data['google_linked'] == true,
      complimentaryPro = data['complimentary_pro'] == true,
      freeVoice = FreeVoice.fromJson(data['free_voice']),
      storage = AccountStorage.fromJson(data['storage']);
}

class ApiClient {
  static const timeoutMessage =
      'The server took too long to respond. Your local tasks are safe.';
  static const offlineMessage =
      'Cannot reach the server. Check your connection and server address.';
  static const unreachableMessage =
      'The server did not answer. Your local tasks are safe.';

  /// No network at all, rather than a server that doesn't answer: the phone
  /// can't look the server up, or has no route to any network.
  static bool _noNetwork(SocketException error) {
    final reason = error.osError?.message.toLowerCase() ?? '';
    return error.message.contains('host lookup') ||
        reason.contains('network is unreachable');
  }

  final http.Client _http;
  final FlutterSecureStorage _storage;
  String baseUrl;
  Map<String, dynamic>? _session;
  Future<void>? _refreshing;
  Future<void> _persisting = Future.value();

  /// The refresh token this engine last read from or wrote to the phone's
  /// storage. Another engine of the app (the background meeting uploader)
  /// may refresh the same session meanwhile, and the server then refuses
  /// the token this engine holds: a saved token that differs from this one
  /// is that newer session ([_newerSaved]).
  String? _knownRefresh;
  int _generation = 0;
  final _sessionInvalidated = StreamController<void>.broadcast();

  Stream<void> get sessionInvalidated => _sessionInvalidated.stream;
  final _accountUpdated = StreamController<void>.broadcast();

  /// The saved account changed outside a sign-in or refresh: a dictation's
  /// answer carried the free dictations left, or a refused upload the file
  /// space used.
  Stream<void> get accountUpdated => _accountUpdated.stream;
  final _accountDeleted = StreamController<int>.broadcast();

  /// The server said the signed-in account no longer exists: it was deleted,
  /// on another phone or on this one with the answer lost. Its session is
  /// already forgotten here; carries that account's id, once.
  Stream<int> get accountDeleted => _accountDeleted.stream;

  /// Whether this is a second engine of the app (the background meeting
  /// uploader) rather than the app itself. It never removes the saved
  /// session when the server refuses its login: it stops, and the app,
  /// which the person sees, decides when it next uses the login.
  final bool background;

  /// How long a refused refresh waits for the session another engine may
  /// be saving at that moment before taking the refusal as final. Only
  /// Android runs a second engine (the background uploader).
  final Duration sessionRaceWait;

  ApiClient({
    http.Client? transport,
    FlutterSecureStorage? storage,
    String? url,
    this.background = false,
    Duration? sessionRaceWait,
  }) : _http = transport ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage(),
       sessionRaceWait =
           sessionRaceWait ??
           (Platform.isAndroid ? const Duration(seconds: 1) : Duration.zero),
       baseUrl =
           url ??
           const String.fromEnvironment(
             'API_BASE_URL',
             defaultValue: 'http://10.0.2.2:8088',
           );

  Account? get account => _session == null
      ? null
      : Account.fromJson(Map<String, dynamic>.from(_session!['user']));

  Future<void> restore() async {
    baseUrl = await _storage.read(key: 'taskflow.server') ?? baseUrl;
    final raw = await _storage.read(key: 'taskflow.session');
    if (raw == null) return;
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      Account.fromJson(Map<String, dynamic>.from(value['user']));
      if (value['access'] is! String || value['refresh'] is! String) {
        throw const FormatException();
      }
      _session = value;
      _knownRefresh = value['refresh'] as String;
    } on FormatException {
      await _storage.delete(key: 'taskflow.session');
    } on TypeError {
      await _storage.delete(key: 'taskflow.session');
    }
  }

  Future<void> setServer(String value) async {
    if (account != null) {
      throw ApiException(400, 'Sign out before changing servers.');
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !['', '/'].contains(uri.path)) {
      throw ApiException(
        400,
        'Enter a server address such as http://192.168.1.20:8088.',
      );
    }
    if (!kDebugMode && uri.scheme != 'https') {
      throw ApiException(400, 'Release builds require an HTTPS server.');
    }
    baseUrl = value.trim().replaceFirst(RegExp(r'/$'), '');
    await _storage.write(key: 'taskflow.server', value: baseUrl);
  }

  /// Signs in, or with [register] creates the account. A new account sends
  /// [language] (`es`, `ca` or `en`), the language of the emails it gets.
  /// Throws [EmailVerificationRequired] when the address waits for its
  /// code; a server that doesn't ask for one signs straight in.
  Future<void> signIn(
    String email,
    String password, {
    bool register = false,
    String timezone = 'UTC',
    String? language,
  }) async {
    final address = email.trim();
    final dynamic result;
    try {
      result = await request(
        'POST',
        'auth/${register ? 'register' : 'login'}/',
        authenticated: false,
        data: {
          'email': address,
          'password': password,
          'timezone': timezone,
          if (register && language != null) 'language': language,
        },
      );
    } on ApiException catch (error) {
      // The password is right, but the address isn't confirmed yet. The
      // server has already emailed a fresh code.
      if (error.status == 403 && error.body?['code'] == 'email_unverified') {
        throw EmailVerificationRequired(_emailIn(error.body) ?? address);
      }
      // Signing in, the server's 401 (it has a body, unlike the app's own
      // "account changed") can only mean the email or the password is wrong.
      if (!register && error.status == 401 && error.body != null) {
        throw WrongCredentials(error);
      }
      rethrow;
    }
    // Created, with a code on its way instead of a session.
    if (result is Map && result['verification_required'] == true) {
      throw EmailVerificationRequired(_emailIn(result) ?? address);
    }
    await _persist(Map<String, dynamic>.from(result as Map), ++_generation);
  }

  static String? _emailIn(Map? body) {
    final email = body?['email'];
    return email is String && email.trim().isNotEmpty ? email.trim() : null;
  }

  /// Confirms [email] with the 6-digit [code] it received and the
  /// [password] just typed for it, and signs in with the session the server
  /// answers, as [signIn] does. The password is only sent, never kept. A
  /// wrong code is a 400 `code_invalid`; an expired one, or one tried too
  /// often, a 400 `code_expired`; a 400 `signup_replaced` means the address
  /// was registered again, with another password, before it was confirmed.
  Future<void> verifyEmail(String email, String code, String password) async {
    final result = await request(
      'POST',
      'auth/verify-email/',
      authenticated: false,
      data: {'email': email, 'code': code, 'password': password},
    );
    await _persist(Map<String, dynamic>.from(result as Map), ++_generation);
  }

  /// Emails [email] a new code, in [language]. The server answers the same
  /// whether or not the address waits for one.
  Future<void> resendVerificationCode(String email, {String? language}) =>
      request(
        'POST',
        'auth/verify-email/resend/',
        authenticated: false,
        data: {'email': email, 'language': ?language},
      );

  Future<Account> refreshAccount() async {
    final generation = _generation;
    final current = account;
    if (current == null) throw ApiException(401, 'Sign in to continue.');
    final user = await request('GET', 'auth/me/', accountId: current.id);
    if (generation != _generation || _session == null) {
      throw ApiException(401, 'The account changed. Please try again.');
    }
    final next = {..._session!, 'user': Map<String, dynamic>.from(user as Map)};
    await _persist(next, generation, update: true);
    if (generation != _generation) {
      throw ApiException(401, 'The account changed. Please try again.');
    }
    return Account.fromJson(next['user']);
  }

  /// Sets the account's first name, the name others see on shared
  /// projects, and saves the user the server answers, as [refreshAccount]
  /// does. The server tidies [firstName]; a blank one clears it.
  Future<Account> setFirstName(String firstName) async {
    final generation = _generation;
    final current = account;
    if (current == null) throw ApiException(401, 'Sign in to continue.');
    final user = await request(
      'PATCH',
      'auth/me/',
      data: {'first_name': firstName},
      accountId: current.id,
    );
    if (generation != _generation || _session == null) {
      throw ApiException(401, 'The account changed. Please try again.');
    }
    final next = {..._session!, 'user': Map<String, dynamic>.from(user as Map)};
    await _persist(next, generation, update: true);
    if (generation != _generation) {
      throw ApiException(401, 'The account changed. Please try again.');
    }
    return Account.fromJson(next['user']);
  }

  /// A dictation's 200 or 402 body carries the free dictations left: write
  /// them into the saved account at once, for account [accountId] only.
  Future<void> rememberFreeVoice(Object? block, {required int accountId}) =>
      FreeVoice.fromJson(block) == null
      ? Future.value()
      : _remember('free_voice', block as Map, accountId);

  /// An upload refused for a full file space carries the account's usage.
  Future<void> rememberStorage(Object? block, {required int accountId}) =>
      AccountStorage.fromJson(block) == null
      ? Future.value()
      : _remember('storage', block as Map, accountId);

  /// After an upload, fetch account [accountId]'s file space usage and save
  /// it, so the usage line shows the space the upload took.
  Future<void> refreshStorage({required int accountId}) async {
    final user = await request('GET', 'auth/me/', accountId: accountId);
    if (user is Map) await rememberStorage(user['storage'], accountId: accountId);
  }

  Future<void> _remember(String key, Map block, int accountId) {
    final generation = _generation;
    _persisting = _persisting.catchError((_) {}).then((_) async {
      final session = _session;
      if (generation != _generation ||
          session == null ||
          account?.id != accountId) {
        return;
      }
      final next = _withTokens({
        ...session,
        'user': {
          ...Map<String, dynamic>.from(session['user']),
          key: Map<String, dynamic>.from(block),
        },
      }, await _newerSaved(session));
      await _storage.write(key: 'taskflow.session', value: jsonEncode(next));
      _knownRefresh = next['refresh'] as String?;
      if (generation != _generation) return;
      _session = next;
      if (!_accountUpdated.isClosed) _accountUpdated.add(null);
    });
    return _persisting;
  }

  Future<void> signInWithGoogle(
    String idToken, {
    String timezone = 'UTC',
  }) async {
    final result = await request(
      'POST',
      'auth/google/',
      authenticated: false,
      data: {'id_token': idToken, 'timezone': timezone},
    );
    await _persist(Map<String, dynamic>.from(result as Map), ++_generation);
  }

  Future<void> linkGoogle(String idToken, String password) async {
    final current = account;
    if (current == null) throw ApiException(401, 'Sign in to continue.');
    await request(
      'POST',
      'auth/google/link/',
      accountId: current.id,
      data: {'id_token': idToken, 'password': password},
    );
    await refreshAccount();
  }

  Future<void> signOut() async {
    // When offline, local credentials are still removed; server sessions expire.
    try {
      await request('POST', 'auth/logout/', data: {});
    } on ApiException {
      /* Local sign-out still succeeds. */
    }
    await forgetSession();
  }

  /// Forgets the session on this phone without telling the server: after the
  /// account was deleted there, nothing is left to sign out of. Requests
  /// still under way are refused when they answer.
  Future<void> forgetSession() {
    _generation++;
    _session = null;
    return _persist(null, _generation);
  }

  /// Saves [session]. With [update], it's this engine's session with new
  /// account details: tokens another engine saved meanwhile are kept.
  Future<void> _persist(
    Map<String, dynamic>? session,
    int generation, {
    bool update = false,
  }) {
    _persisting = _persisting.catchError((_) {}).then((_) async {
      if (generation != _generation) return;
      var value = session;
      if (value == null) {
        await _storage.delete(key: 'taskflow.session');
      } else {
        if (update) value = _withTokens(value, await _newerSaved(value));
        await _storage.write(key: 'taskflow.session', value: jsonEncode(value));
      }
      _knownRefresh = value?['refresh'] as String?;
      if (generation == _generation) _session = value;
    });
    return _persisting;
  }

  static Map<String, dynamic> _withTokens(
    Map<String, dynamic> session,
    Map<String, dynamic>? tokens,
  ) => tokens == null
      ? session
      : {...session, 'access': tokens['access'], 'refresh': tokens['refresh']};

  /// The session saved on the phone, when another engine of this app
  /// refreshed [current]'s account since this one last saw it.
  Future<Map<String, dynamic>?> _newerSaved(
    Map<String, dynamic> current,
  ) async {
    try {
      final raw = await _storage.read(key: 'taskflow.session');
      if (raw == null) return null;
      final saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final refresh = saved['refresh'];
      if (saved['access'] is! String ||
          refresh is! String ||
          refresh == _knownRefresh ||
          refresh == current['refresh'] ||
          Map<String, dynamic>.from(saved['user'] as Map)['id'] !=
              Map<String, dynamic>.from(current['user'] as Map)['id']) {
        return null;
      }
      return saved;
    } catch (_) {
      return null;
    }
  }

  /// Takes the tokens another engine saved for this session's account.
  /// True when there were any.
  Future<bool> _adoptNewerSaved(int generation) async {
    final current = _session;
    if (current == null) return false;
    final saved = await _newerSaved(current);
    if (saved == null || generation != _generation || _session == null) {
      return false;
    }
    _session = _withTokens(_session!, saved);
    _knownRefresh = saved['refresh'] as String;
    return true;
  }

  /// After a refused refresh: whether another engine refreshed the same
  /// session at that moment, its tokens now taken. It may still be saving
  /// them, so storage is read again after [sessionRaceWait].
  Future<bool> _adoptRacing(int generation) async {
    if (await _adoptNewerSaved(generation)) return true;
    if (sessionRaceWait <= Duration.zero) return false;
    for (var i = 0; i < 2; i++) {
      await Future<void>.delayed(sessionRaceWait);
      if (generation != _generation) return false;
      if (await _adoptNewerSaved(generation)) return true;
    }
    return false;
  }

  Future<void> _refresh(int generation) async {
    if (_session == null) throw ApiException(401, 'Sign in to continue.');
    // The background uploader may have refreshed this session already: its
    // refresh token replaced the one held here.
    await _adoptNewerSaved(generation);
    var previous = _session;
    if (previous == null) throw ApiException(401, 'Sign in to continue.');
    dynamic result;
    for (var attempt = 0; ; attempt++) {
      try {
        result = await request(
          'POST',
          'auth/refresh/',
          authenticated: false,
          data: {'refresh': previous!['refresh']},
        );
        break;
      } on ApiException catch (error) {
        // An offline/server failure retains the saved session. Only an
        // explicit authentication rejection locks the app and removes the
        // credentials, unless another engine refreshed it at the same time.
        if (error.status == 401) {
          if (error.body?['code'] == _userNotFound) {
            await _accountGone(generation);
          } else if (attempt == 0 && await _adoptRacing(generation)) {
            previous = _session;
            continue;
          } else {
            await _invalidateSession(generation);
          }
        }
        rethrow;
      }
    }
    if (generation != _generation) {
      throw ApiException(401, 'The account changed. Please try again.');
    }
    final next = {...previous, ...Map<String, dynamic>.from(result as Map)};
    await _persist(next, generation);
  }

  Future<void> _invalidateSession(int generation) async {
    if (generation != _generation || _session == null) return;
    _session = null;
    final invalidated = ++_generation;
    try {
      // The background engine only stops: the saved session is the app's.
      if (!background) await _persist(null, invalidated);
    } finally {
      if (!_sessionInvalidated.isClosed && _generation == invalidated) {
        _sessionInvalidated.add(null);
      }
    }
  }

  /// simplejwt's answer when a signed token's account no longer exists.
  static const _userNotFound = 'user_not_found';

  /// Whether a 401's [body] says the account is gone, rather than only the
  /// session: no refresh can help then.
  static bool _accountGoneIn(List<int> body) {
    try {
      final data = jsonDecode(utf8.decode(body));
      return data is Map && data['code'] == _userNotFound;
    } on FormatException {
      return false;
    }
  }

  /// The account of the session that sent the request at [generation] no
  /// longer exists. Forgets that session and says so once: other answers
  /// for it, or for a session that came later, change nothing.
  Future<void> _accountGone(int generation) async {
    final accountId = account?.id;
    if (generation != _generation || accountId == null) return;
    _session = null;
    final gone = ++_generation;
    try {
      if (!background) await _persist(null, gone);
    } finally {
      if (!_accountDeleted.isClosed && _generation == gone) {
        _accountDeleted.add(accountId);
      }
    }
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    final generation = _generation;
    if (authenticated &&
        (account == null || (accountId != null && account!.id != accountId))) {
      throw ApiException(401, 'Sign in to this account to sync.');
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      if (generation != _generation) {
        throw ApiException(401, 'The account changed. Please try again.');
      }
      final response = await _send(
        method,
        path,
        data,
        audioPath,
        authenticated,
      );
      if (generation != _generation) {
        throw ApiException(401, 'The account changed. Please try again.');
      }
      if (response.statusCode == 401 && authenticated) {
        if (_accountGoneIn(response.bodyBytes)) {
          await _accountGone(generation);
        } else if (attempt == 0) {
          _refreshing ??= _refresh(
            generation,
          ).whenComplete(() => _refreshing = null);
          await _refreshing;
          continue;
        } else {
          await _invalidateSession(generation);
        }
      }
      dynamic body;
      try {
        // JSON is UTF-8 even when application/json omits a charset. http 1.2
        // otherwise falls back to Latin-1 and corrupts accents and emoji.
        body = response.bodyBytes.isEmpty
            ? null
            : jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw ApiException(
          response.statusCode,
          'The server returned an invalid response.',
        );
      }
      if (response.statusCode >= 400) {
        final map = body is Map
            ? Map<String, dynamic>.from(body)
            : <String, dynamic>{};
        final message = map['detail'] is String
            ? map['detail'] as String
            : map.entries
                  .map(
                    (e) =>
                        '${e.key}: ${e.value is List ? (e.value as List).join(' ') : e.value}',
                  )
                  .join('\n');
        throw ApiException(
          response.statusCode,
          message.isEmpty ? 'The request failed. Please try again.' : message,
          map,
          _retryAfter(response),
        );
      }
      return body;
    }
    throw ApiException(401, 'Your session has ended. Please sign in again.');
  }

  /// How long the server asked to wait (`Retry-After`, in seconds).
  static Duration? _retryAfter(http.Response response) {
    final seconds = int.tryParse(
      response.headers['retry-after']?.trim() ?? '',
    );
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  Future<http.Response> _send(
    String method,
    String path,
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated,
  ) async {
    Future<http.Response> perform() async {
      final url = Uri.parse('$baseUrl/api/$path');
      final http.BaseRequest request;
      if (audioPath != null) {
        request = http.MultipartRequest(method, url)
          ..fields.addAll(
            (data ?? {}).map((key, value) => MapEntry(key, value.toString())),
          )
          ..files.add(
            await http.MultipartFile.fromPath(
              'audio',
              audioPath,
              filename: 'task.wav',
            ),
          );
      } else {
        request = http.Request(method, url)
          ..headers['Content-Type'] = 'application/json'
          ..body = data == null ? '' : jsonEncode(data);
      }
      if (authenticated) {
        request.headers['Authorization'] = 'Bearer ${_session!['access']}';
      }
      return http.Response.fromStream(await _http.send(request));
    }

    try {
      return await perform().timeout(
        Duration(
          seconds: path.startsWith('ai/')
              ? 100
              // The call that completes a meeting can write its last
              // chapter's notes and then the final notes: two AI calls of
              // up to 90 s each on the server (MEETINGS.md).
              : path.startsWith('meetings/') && path.endsWith('/finish/')
              ? 200
              : path.startsWith('meetings/')
              ? 100
              // Deleting an account removes all of it at once; giving up
              // early would leave the phone unsure whether it happened.
              : method == 'POST' && path == 'auth/delete-account/'
              ? 60
              : 12,
        ),
      );
    } on TimeoutException {
      throw ApiException(0, timeoutMessage);
    } on SocketException catch (error) {
      throw ApiException(
        0,
        _noNetwork(error) ? offlineMessage : unreachableMessage,
      );
    } on http.ClientException {
      throw ApiException(0, offlineMessage);
    }
  }

  Future<Map<String, dynamic>> uploadAttachment({
    required String id,
    required String taskId,
    required String name,
    required String filePath,
    required int accountId,
  }) async {
    final response = await _fileRequest(
      'attachments/$id/',
      accountId,
      (url) async => http.MultipartRequest('PUT', url)
        ..fields.addAll({'task_id': taskId, 'name': name})
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            filePath,
            filename: 'upload.bin',
          ),
        ),
      maxResponseBytes: 64 * 1024,
    );
    try {
      return Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map,
      );
    } on FormatException {
      throw ApiException(502, 'The server returned invalid file information.');
    } on TypeError {
      throw ApiException(502, 'The server returned invalid file information.');
    }
  }

  /// Sends piece [index] of meeting [meetingId] (Backend/docs/MEETINGS.md),
  /// for account [accountId] only. The server transcribes it before it
  /// answers, so the wait is long.
  Future<Map<String, dynamic>> uploadMeetingPiece({
    required String meetingId,
    required int index,
    required String filePath,
    required String contentType,
    required String filename,
    required Map<String, String> fields,
    required int accountId,
  }) async {
    final response = await _fileRequest(
      'meetings/$meetingId/pieces/$index/',
      accountId,
      (url) async => http.MultipartRequest('PUT', url)
        ..fields.addAll(fields)
        ..files.add(
          await http.MultipartFile.fromPath(
            'audio',
            filePath,
            filename: filename,
            contentType: MediaType.parse(contentType),
          ),
        ),
      maxResponseBytes: 64 * 1024,
      // Up to 120 s to transcribe it, then up to 90 s for its chapter's
      // notes when it completes one, on the server.
      timeout: const Duration(seconds: 240),
    );
    try {
      return Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map,
      );
    } on FormatException {
      throw ApiException(502, 'The server returned an invalid response.');
    } on TypeError {
      throw ApiException(502, 'The server returned an invalid response.');
    }
  }

  Future<Uint8List> downloadAttachment(
    String id, {
    required int accountId,
  }) async => (await _fileRequest(
    'attachments/$id/content/',
    accountId,
    (url) async => http.Request('GET', url),
    maxResponseBytes: 6 * 1024 * 1024,
  )).bodyBytes;

  Future<http.Response> _fileRequest(
    String path,
    int accountId,
    Future<http.BaseRequest> Function(Uri) create, {
    required int maxResponseBytes,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final generation = _generation;
    void checkAccount() {
      if (generation != _generation || account?.id != accountId) {
        throw ApiException(401, 'Sign in to this account to transfer files.');
      }
    }

    checkAccount();
    for (var attempt = 0; attempt < 2; attempt++) {
      checkAccount();
      final request = await create(Uri.parse('$baseUrl/api/$path'));
      checkAccount();
      request.followRedirects = false;
      request.headers['Authorization'] = 'Bearer ${_session!['access']}';
      Future<http.Response> transfer() async {
        final response = await _http.send(request);
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > maxResponseBytes) {
            throw ApiException(
              413,
              'The server file is larger than the supported limit.',
            );
          }
          bytes.add(chunk);
        }
        return http.Response.bytes(
          bytes.takeBytes(),
          response.statusCode,
          headers: response.headers,
        );
      }

      late http.Response response;
      try {
        response = await transfer().timeout(timeout);
      } on TimeoutException {
        throw ApiException(
          0,
          'The file transfer timed out. Your local copy is safe; retry when connected.',
        );
      } on SocketException {
        throw ApiException(
          0,
          'Cannot reach the server. Your local file is safe.',
        );
      } on http.ClientException {
        throw ApiException(
          0,
          'The connection was interrupted. Retry this file.',
        );
      }
      checkAccount();
      if (response.statusCode == 401) {
        if (_accountGoneIn(response.bodyBytes)) {
          await _accountGone(generation);
        } else if (attempt == 0) {
          _refreshing ??= _refresh(
            generation,
          ).whenComplete(() => _refreshing = null);
          await _refreshing;
          continue;
        } else {
          await _invalidateSession(generation);
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        Map<String, dynamic>? body;
        try {
          final value = jsonDecode(utf8.decode(response.bodyBytes));
          if (value is Map) body = Map<String, dynamic>.from(value);
        } on FormatException {
          /* A proxy can return non-JSON errors. */
        }
        final detail = body?['detail'];
        final message = detail is String
            ? detail
            : body?.entries
                  .map(
                    (e) =>
                        '${e.key}: ${e.value is List ? (e.value as List).join(' ') : e.value}',
                  )
                  .join('\n');
        throw ApiException(
          response.statusCode,
          message?.isNotEmpty == true
              ? message!
              : 'The file transfer failed. Please retry.',
          body,
          _retryAfter(response),
        );
      }
      return response;
    }
    throw ApiException(401, 'Your session has ended. Please sign in again.');
  }

  void close() {
    _http.close();
    unawaited(_sessionInvalidated.close());
    unawaited(_accountUpdated.close());
    unawaited(_accountDeleted.close());
  }
}
