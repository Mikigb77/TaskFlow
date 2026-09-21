import 'dart:async';
import 'dart:convert';
import 'package:agenda/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> session([int id = 1]) => {'access': 'old-access', 'refresh': 'old-refresh',
  'user': {'id': id, 'email': 'test@example.invalid', 'timezone': 'Europe/Madrid'}};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('session is persisted in secure storage and restored without a network', () async {
    final api = ApiClient(transport: MockClient((request) async => http.Response(jsonEncode(session()), 200)));
    await api.signIn('test@example.invalid', 'a-long-password');
    final restored = ApiClient(transport: MockClient((_) async => throw StateError('Must not call network')));
    await restored.restore();
    expect(restored.account!.id, 1);
    api.close(); restored.close();
  });

  test('concurrent expired requests share one refresh and use rotated tokens', () async {
    FlutterSecureStorage.setMockInitialValues({'taskflow.session': jsonEncode(session())});
    int refreshes = 0;
    int oldRequests = 0;
    final bothExpired = Completer<void>();
    final api = ApiClient(transport: MockClient((request) async {
      if (request.url.path.endsWith('/refresh/')) {
        refreshes++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return http.Response(jsonEncode({'access': 'new-access', 'refresh': 'new-refresh'}), 200);
      }
      if (request.headers['Authorization'] == 'Bearer old-access') {
        oldRequests++;
        if (oldRequests == 2) bothExpired.complete();
        await bothExpired.future;
        return http.Response('{"detail":"Expired"}', 401);
      }
      expect(request.headers['Authorization'], 'Bearer new-access');
      return http.Response('{"results":[]}', 200);
    }));
    await api.restore();
    await Future.wait([api.request('GET', 'tasks/'), api.request('GET', 'tasks/')]);
    expect(refreshes, 1);
    final saved = jsonDecode((await const FlutterSecureStorage().read(key: 'taskflow.session'))!);
    expect(saved['refresh'], 'new-refresh');
    api.close();
  });

  test('account guard stops a queued request from using a different account', () async {
    FlutterSecureStorage.setMockInitialValues({'taskflow.session': jsonEncode(session(2))});
    var called = false;
    final api = ApiClient(transport: MockClient((_) async { called = true; return http.Response('{}', 200); }));
    await api.restore();
    await expectLater(api.request('GET', 'tasks/', accountId: 1), throwsA(isA<ApiException>()));
    expect(called, isFalse);
    api.close();
  });

  test('offline sign-out removes saved credentials', () async {
    FlutterSecureStorage.setMockInitialValues({'taskflow.session': jsonEncode(session())});
    final api = ApiClient(transport: MockClient((_) async => throw http.ClientException('Offline')));
    await api.restore();
    await api.signOut();
    expect(api.account, isNull);
    expect(await const FlutterSecureStorage().read(key: 'taskflow.session'), isNull);
    api.close();
  });

  test('untrusted server URL parts are rejected', () async {
    final api = ApiClient();
    for (final url in ['ftp://example.com', 'http://user:pass@example.com', 'https://example.com/?secret=1']) {
      await expectLater(api.setServer(url), throwsA(isA<ApiException>()));
    }
    api.close();
  });
}
