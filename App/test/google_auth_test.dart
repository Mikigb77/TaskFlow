import 'dart:convert';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final googleSession = {
  'access': 'taskflow-access',
  'refresh': 'taskflow-refresh',
  'user': {
    'id': 17,
    'email': 'person@example.invalid',
    'timezone': 'Europe/Madrid',
    'billing_id': 'stable-billing-id',
    'google_linked': true,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'Google token is exchanged once and only TaskFlow credentials persist',
    () async {
      final api = ApiClient(
        transport: MockClient((request) async {
          expect(request.url.path, '/api/auth/google/');
          expect(request.headers['Authorization'], isNull);
          expect(jsonDecode(request.body), {
            'id_token': 'synthetic-google-id-token',
            'timezone': 'Europe/Madrid',
          });
          return http.Response(jsonEncode(googleSession), 200);
        }),
      );
      addTearDown(api.close);
      await api.signInWithGoogle(
        'synthetic-google-id-token',
        timezone: 'Europe/Madrid',
      );
      expect(api.account!.googleLinked, isTrue);
      expect(api.account!.billingId, 'stable-billing-id');
      final stored = await const FlutterSecureStorage().read(
        key: 'taskflow.session',
      );
      expect(stored, isNot(contains('synthetic-google-id-token')));
      final restored = ApiClient();
      addTearDown(restored.close);
      await restored.restore();
      expect(restored.account!.id, 17);
    },
  );

  test(
    'linking uses the existing session and refreshes linked status',
    () async {
      final old = {
        ...googleSession,
        'user': {...googleSession['user'] as Map, 'google_linked': false},
      };
      FlutterSecureStorage.setMockInitialValues({
        'taskflow.session': jsonEncode(old),
      });
      final paths = <String>[];
      final api = ApiClient(
        transport: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.headers['Authorization'], 'Bearer taskflow-access');
          if (request.url.path.endsWith('/link/')) {
            expect(jsonDecode(request.body), {
              'id_token': 'synthetic-link-token',
              'password': 'synthetic-password',
            });
          }
          return http.Response(jsonEncode(googleSession['user']), 200);
        }),
      );
      addTearDown(api.close);
      await api.restore();
      await api.linkGoogle('synthetic-link-token', 'synthetic-password');
      expect(paths, ['/api/auth/google/link/', '/api/auth/me/']);
      expect(api.account!.googleLinked, isTrue);
      expect(api.account!.billingId, 'stable-billing-id');
    },
  );

  test('link-required response never overwrites a cached session', () async {
    final api = ApiClient(
      transport: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 'google_link_required',
            'detail': 'Link explicitly',
          }),
          409,
        ),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.signInWithGoogle('token'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.body?['code'],
          'code',
          'google_link_required',
        ),
      ),
    );
    expect(api.account, isNull);
    expect(
      await const FlutterSecureStorage().read(key: 'taskflow.session'),
      isNull,
    );
  });

  for (final language in ['en', 'es', 'ca']) {
    test(
      'Google failures use localized recovery guidance in $language',
      () async {
        final strings = await AppLocalizations.delegate.load(Locale(language));
        final message = requestProblemText(
          strings,
          ApiException(409, 'English server diagnostic', {
            'code': 'google_link_required',
          }),
        );
        expect(message, strings.googleSignInError('google_link_required'));
        expect(message, isNot(contains('English server diagnostic')));
        expect(
          requestProblemText(
            strings,
            const GoogleSignInProblem('google_not_configured'),
          ),
          strings.googleSignInError('google_not_configured'),
        );
      },
    );
  }
}
