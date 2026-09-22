import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  Account.fromJson(Map<String, dynamic> data)
      : id = data['id'] as int,
        email = data['email'] as String,
        timezone = data['timezone'] as String;
}

class ApiClient {
  final http.Client _http;
  final FlutterSecureStorage _storage;
  String baseUrl;
  Map<String, dynamic>? _session;
  Future<void>? _refreshing;
  Future<void> _persisting = Future.value();
  int _generation = 0;

  ApiClient(
      {http.Client? transport, FlutterSecureStorage? storage, String? url})
      : _http = transport ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage(),
        baseUrl = url ??
            const String.fromEnvironment('API_BASE_URL',
                defaultValue: 'http://10.0.2.2:8088');

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
          400, 'Enter a server address such as http://192.168.1.20:8088.');
    }
    if (!kDebugMode && uri.scheme != 'https') {
      throw ApiException(400, 'Release builds require an HTTPS server.');
    }
    baseUrl = value.trim().replaceFirst(RegExp(r'/$'), '');
    await _storage.write(key: 'taskflow.server', value: baseUrl);
  }

  Future<void> signIn(String email, String password,
      {bool register = false, String timezone = 'UTC'}) async {
    final result = await request(
        'POST', 'auth/${register ? 'register' : 'login'}/',
        authenticated: false,
        data: {
          'email': email.trim(),
          'password': password,
          'timezone': timezone
        });
    final session = Map<String, dynamic>.from(result as Map);
    await _persist(session, ++_generation);
  }

  Future<void> signOut() async {
    // When offline, local credentials are still removed; server sessions expire.
    try {
      await request('POST', 'auth/logout/', data: {});
    } on ApiException {/* Local sign-out still succeeds. */}
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
            key: 'taskflow.session', value: jsonEncode(session));
      }
      if (generation == _generation) _session = session;
    });
    return _persisting;
  }

  Future<void> _refresh(int generation) async {
    final previous = _session;
    if (previous == null) throw ApiException(401, 'Sign in to continue.');
    final result = await request('POST', 'auth/refresh/',
        authenticated: false, data: {'refresh': previous['refresh']});
    if (generation != _generation) {
      throw ApiException(401, 'The account changed. Please try again.');
    }
    final next = {...previous, ...Map<String, dynamic>.from(result as Map)};
    await _persist(next, generation);
  }

  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId}) async {
    final generation = _generation;
    if (authenticated &&
        (account == null || (accountId != null && account!.id != accountId))) {
      throw ApiException(401, 'Sign in to this account to sync.');
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      if (generation != _generation) {
        throw ApiException(401, 'The account changed. Please try again.');
      }
      final response =
          await _send(method, path, data, audioPath, authenticated);
      if (generation != _generation) {
        throw ApiException(401, 'The account changed. Please try again.');
      }
      if (response.statusCode == 401 && authenticated && attempt == 0) {
        _refreshing ??=
            _refresh(generation).whenComplete(() => _refreshing = null);
        await _refreshing;
        continue;
      }
      dynamic body;
      try {
        body = response.body.isEmpty ? null : jsonDecode(response.body);
      } on FormatException {
        throw ApiException(
            response.statusCode, 'The server returned an invalid response.');
      }
      if (response.statusCode >= 400) {
        final map =
            body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
        final message = map['detail'] is String
            ? map['detail'] as String
            : map.entries
                .map((e) =>
                    '${e.key}: ${e.value is List ? (e.value as List).join(' ') : e.value}')
                .join('\n');
        throw ApiException(
            response.statusCode,
            message.isEmpty ? 'The request failed. Please try again.' : message,
            map);
      }
      return body;
    }
    throw ApiException(401, 'Your session has ended. Please sign in again.');
  }

  Future<http.Response> _send(String method, String path,
      Map<String, dynamic>? data, String? audioPath, bool authenticated) async {
    Future<http.Response> perform() async {
      final url = Uri.parse('$baseUrl/api/$path');
      final http.BaseRequest request;
      if (audioPath != null) {
        request = http.MultipartRequest(method, url)
          ..fields.addAll(
              (data ?? {}).map((key, value) => MapEntry(key, value.toString())))
          ..files.add(await http.MultipartFile.fromPath('audio', audioPath,
              filename: 'task.wav'));
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
      return await perform()
          .timeout(Duration(seconds: path.startsWith('ai/') ? 100 : 12));
    } on TimeoutException {
      throw ApiException(
          0, 'The server took too long to respond. Your local tasks are safe.');
    } on SocketException {
      throw ApiException(0,
          'Cannot reach the server. Check your connection and server address.');
    } on http.ClientException {
      throw ApiException(0,
          'Cannot reach the server. Check your connection and server address.');
    }
  }

  void close() => _http.close();
}
