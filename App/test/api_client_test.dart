import 'dart:async';
import 'dart:convert';
import 'package:agenda/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> session([int id = 1]) => {
  'access': 'old-access',
  'refresh': 'old-refresh',
  'user': {
    'id': id,
    'email': 'test@example.invalid',
    'timezone': 'Europe/Madrid',
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'UTF-8 JSON without charset preserves task details and error messages',
    () async {
      const words = 'Aplicación · José · demà · l’aplicació · 🗓️';
      final api = ApiClient(
        transport: MockClient((request) async {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(
                request.url.path.endsWith('/failure/')
                    ? {'detail': words}
                    : {'title': words, 'notes': words},
              ),
            ),
            request.url.path.endsWith('/failure/') ? 400 : 200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(api.close);
      final result =
          await api.request('GET', 'tasks/', authenticated: false) as Map;
      expect(result['title'], words);
      expect(result['notes'], words);
      await expectLater(
        api.request('GET', 'failure/', authenticated: false),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            words,
          ),
        ),
      );
    },
  );

  test('malformed UTF-8 is rejected instead of replacing user text', () async {
    final api = ApiClient(
      transport: MockClient(
        (_) async => http.Response.bytes(
          [123, 34, 116, 34, 58, 34, 255, 34, 125],
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.request('GET', 'tasks/', authenticated: false),
      throwsA(isA<ApiException>()),
    );
  });

  test(
    'legacy cached account receives its durable billing identity from authenticated me',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'taskflow.session': jsonEncode(session()),
      });
      final api = ApiClient(
        transport: MockClient((request) async {
          expect(request.url.path, '/api/auth/me/');
          expect(request.headers['Authorization'], 'Bearer old-access');
          return http.Response(
            jsonEncode({...session()['user'], 'billing_id': 'opaque-id'}),
            200,
          );
        }),
      );
      await api.restore();
      expect(api.account!.billingId, isNull);
      expect((await api.refreshAccount()).billingId, 'opaque-id');
      final restored = ApiClient();
      await restored.restore();
      expect(restored.account!.billingId, 'opaque-id');
      api.close();
      restored.close();
    },
  );

  test(
    'late account refresh after logout cannot restore the previous billing identity',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'taskflow.session': jsonEncode(session()),
      });
      final me = Completer<http.Response>();
      final started = Completer<void>();
      final api = ApiClient(
        transport: MockClient((request) async {
          if (request.url.path.endsWith('/me/')) {
            started.complete();
            return me.future;
          }
          return http.Response('{}', 200);
        }),
      );
      await api.restore();
      final refreshed = api.refreshAccount();
      final assertion = expectLater(refreshed, throwsA(isA<ApiException>()));
      await started.future;
      await api.signOut();
      me.complete(
        http.Response(
          jsonEncode({...session()['user'], 'billing_id': 'old-account'}),
          200,
        ),
      );
      await assertion;
      expect(api.account, isNull);
      expect(
        await const FlutterSecureStorage().read(key: 'taskflow.session'),
        isNull,
      );
      api.close();
    },
  );

  test(
    'session is persisted in secure storage and restored without a network',
    () async {
      final api = ApiClient(
        transport: MockClient(
          (request) async => http.Response(jsonEncode(session()), 200),
        ),
      );
      await api.signIn('test@example.invalid', 'a-long-password');
      final restored = ApiClient(
        transport: MockClient(
          (_) async => throw StateError('Must not call network'),
        ),
      );
      await restored.restore();
      expect(restored.account!.id, 1);
      api.close();
      restored.close();
    },
  );

  test(
    'concurrent expired requests share one refresh and use rotated tokens',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'taskflow.session': jsonEncode(session()),
      });
      int refreshes = 0;
      int oldRequests = 0;
      final bothExpired = Completer<void>();
      final api = ApiClient(
        transport: MockClient((request) async {
          if (request.url.path.endsWith('/refresh/')) {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return http.Response(
              jsonEncode({'access': 'new-access', 'refresh': 'new-refresh'}),
              200,
            );
          }
          if (request.headers['Authorization'] == 'Bearer old-access') {
            oldRequests++;
            if (oldRequests == 2) bothExpired.complete();
            await bothExpired.future;
            return http.Response('{"detail":"Expired"}', 401);
          }
          expect(request.headers['Authorization'], 'Bearer new-access');
          return http.Response('{"results":[]}', 200);
        }),
      );
      await api.restore();
      await Future.wait([
        api.request('GET', 'tasks/'),
        api.request('GET', 'tasks/'),
      ]);
      expect(refreshes, 1);
      final saved = jsonDecode(
        (await const FlutterSecureStorage().read(key: 'taskflow.session'))!,
      );
      expect(saved['refresh'], 'new-refresh');
      api.close();
    },
  );

  test(
    'account guard stops a queued request from using a different account',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'taskflow.session': jsonEncode(session(2)),
      });
      var called = false;
      final api = ApiClient(
        transport: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );
      await api.restore();
      await expectLater(
        api.request('GET', 'tasks/', accountId: 1),
        throwsA(isA<ApiException>()),
      );
      expect(called, isFalse);
      api.close();
    },
  );

  test(
    'rejected refresh clears saved credentials and invalidates the session once',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'taskflow.session': jsonEncode(session()),
      });
      final api = ApiClient(
        transport: MockClient(
          (_) async =>
              http.Response('{"detail":"Token is invalid or expired"}', 401),
        ),
      );
      final invalidations = <void>[];
      final listener = api.sessionInvalidated.listen(invalidations.add);
      await api.restore();
      await expectLater(
        api.request('GET', 'tasks/'),
        throwsA(isA<ApiException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(api.account, isNull);
      expect(
        await const FlutterSecureStorage().read(key: 'taskflow.session'),
        isNull,
      );
      expect(invalidations, hasLength(1));
      await listener.cancel();
      api.close();
    },
  );

  for (final unavailable in [false, true]) {
    test(
      'temporary refresh failure retains offline access, serverUnavailable=$unavailable',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'taskflow.session': jsonEncode(session()),
        });
        final api = ApiClient(
          transport: MockClient((request) async {
            if (request.url.path.endsWith('/refresh/')) {
              if (unavailable) return http.Response('{}', 503);
              throw http.ClientException('Offline');
            }
            return http.Response('{}', 401);
          }),
        );
        await api.restore();
        await expectLater(
          api.request('GET', 'tasks/'),
          throwsA(isA<ApiException>()),
        );
        expect(api.account!.id, 1);
        expect(
          await const FlutterSecureStorage().read(key: 'taskflow.session'),
          isNotNull,
        );
        api.close();
      },
    );
  }

  test(
    'a late refresh rejection cannot sign out a newly signed-in account',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'taskflow.session': jsonEncode(session()),
      });
      final started = Completer<void>();
      final rejected = Completer<http.Response>();
      final api = ApiClient(
        transport: MockClient((request) async {
          if (request.url.path.endsWith('/refresh/')) {
            started.complete();
            return rejected.future;
          }
          if (request.url.path.endsWith('/login/')) {
            return http.Response(jsonEncode(session(2)), 200);
          }
          return http.Response('{}', 401);
        }),
      );
      await api.restore();
      final old = expectLater(
        api.request('GET', 'tasks/'),
        throwsA(isA<ApiException>()),
      );
      await started.future;
      await api.signIn('second@example.invalid', 'another-password');
      rejected.complete(http.Response('{}', 401));
      await old;
      expect(api.account!.id, 2);
      final saved = jsonDecode(
        (await const FlutterSecureStorage().read(key: 'taskflow.session'))!,
      );
      expect(saved['user']['id'], 2);
      api.close();
    },
  );

  for (final file in [false, true]) {
    test(
      '401 after a successful refresh also locks the session, file=$file',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'taskflow.session': jsonEncode(session()),
        });
        final api = ApiClient(
          transport: MockClient(
            (request) async => request.url.path.endsWith('/refresh/')
                ? http.Response(
                    '{"access":"rotated-access","refresh":"rotated-refresh"}',
                    200,
                  )
                : http.Response('{}', 401),
          ),
        );
        await api.restore();
        await expectLater(
          file
              ? api.downloadAttachment('fixture', accountId: 1)
              : api.request('GET', 'tasks/'),
          throwsA(isA<ApiException>()),
        );
        expect(api.account, isNull);
        expect(
          await const FlutterSecureStorage().read(key: 'taskflow.session'),
          isNull,
        );
        api.close();
      },
    );
  }

  test('offline sign-out removes saved credentials', () async {
    FlutterSecureStorage.setMockInitialValues({
      'taskflow.session': jsonEncode(session()),
    });
    final api = ApiClient(
      transport: MockClient((_) async => throw http.ClientException('Offline')),
    );
    await api.restore();
    await api.signOut();
    expect(api.account, isNull);
    expect(
      await const FlutterSecureStorage().read(key: 'taskflow.session'),
      isNull,
    );
    api.close();
  });

  test('untrusted server URL parts are rejected', () async {
    final api = ApiClient();
    for (final url in [
      'ftp://example.com',
      'http://user:pass@example.com',
      'https://example.com/?secret=1',
    ]) {
      await expectLater(api.setServer(url), throwsA(isA<ApiException>()));
    }
    api.close();
  });
}
