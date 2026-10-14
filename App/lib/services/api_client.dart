import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int status;
  final String message;
  final Map<String, dynamic>? body;
  ApiException(this.status, this.message, [this.body]);
  @override
  String toString() => message;
}

class Account {
  final int id;
  final String email;
  final String timezone;
  final String? billingId;
  final bool googleLinked;
  final bool complimentaryPro;
  Account.fromJson(Map<String, dynamic> data)
    : id = data['id'] as int,
      email = data['email'] as String,
      timezone = data['timezone'] as String,
      billingId = data['billing_id'] as String?,
      googleLinked = data['google_linked'] == true,
      complimentaryPro = data['complimentary_pro'] == true;
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
  int _generation = 0;
  final _sessionInvalidated = StreamController<void>.broadcast();

  Stream<void> get sessionInvalidated => _sessionInvalidated.stream;

  ApiClient({
    http.Client? transport,
    FlutterSecureStorage? storage,
    String? url,
  }) : _http = transport ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage(),
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

  Future<void> signIn(
    String email,
    String password, {
    bool register = false,
    String timezone = 'UTC',
  }) async {
    final result = await request(
      'POST',
      'auth/${register ? 'register' : 'login'}/',
      authenticated: false,
      data: {'email': email.trim(), 'password': password, 'timezone': timezone},
    );
    final session = Map<String, dynamic>.from(result as Map);
    await _persist(session, ++_generation);
  }

  Future<Account> refreshAccount() async {
    final generation = _generation;
    final current = account;
    if (current == null) throw ApiException(401, 'Sign in to continue.');
    final user = await request('GET', 'auth/me/', accountId: current.id);
    if (generation != _generation || _session == null) {
      throw ApiException(401, 'The account changed. Please try again.');
    }
    final next = {..._session!, 'user': Map<String, dynamic>.from(user as Map)};
    await _persist(next, generation);
    if (generation != _generation) {
      throw ApiException(401, 'The account changed. Please try again.');
    }
    return Account.fromJson(next['user']);
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
    _generation++;
    _session = null;
    await _persist(null, _generation);
  }

  Future<void> _persist(Map<String, dynamic>? session, int generation) {
    _persisting = _persisting.catchError((_) {}).then((_) async {
      if (generation != _generation) return;
      if (session == null) {
        await _storage.delete(key: 'taskflow.session');
      } else {
        await _storage.write(
          key: 'taskflow.session',
          value: jsonEncode(session),
        );
      }
      if (generation == _generation) _session = session;
    });
    return _persisting;
  }

  Future<void> _refresh(int generation) async {
    final previous = _session;
    if (previous == null) throw ApiException(401, 'Sign in to continue.');
    dynamic result;
    try {
      result = await request(
        'POST',
        'auth/refresh/',
        authenticated: false,
        data: {'refresh': previous['refresh']},
      );
    } on ApiException catch (error) {
      // An offline/server failure retains the saved session. Only an explicit
      // authentication rejection locks the app and removes the credentials.
      if (error.status == 401) await _invalidateSession(generation);
      rethrow;
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
      await _persist(null, invalidated);
    } finally {
      if (!_sessionInvalidated.isClosed && _generation == invalidated) {
        _sessionInvalidated.add(null);
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
      if (response.statusCode == 401 && authenticated && attempt == 0) {
        _refreshing ??= _refresh(
          generation,
        ).whenComplete(() => _refreshing = null);
        await _refreshing;
        continue;
      }
      if (response.statusCode == 401 && authenticated) {
        await _invalidateSession(generation);
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
        );
      }
      return body;
    }
    throw ApiException(401, 'Your session has ended. Please sign in again.');
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
        Duration(seconds: path.startsWith('ai/') ? 100 : 12),
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
        response = await transfer().timeout(const Duration(seconds: 45));
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
      if (response.statusCode == 401 && attempt == 0) {
        _refreshing ??= _refresh(
          generation,
        ).whenComplete(() => _refreshing = null);
        await _refreshing;
        continue;
      }
      if (response.statusCode == 401) await _invalidateSession(generation);
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
        );
      }
      return response;
    }
    throw ApiException(401, 'Your session has ended. Please sign in again.');
  }

  void close() {
    _http.close();
    unawaited(_sessionInvalidated.close());
  }
}
