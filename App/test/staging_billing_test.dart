import 'package:agenda/services/revenuecat_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const purchasesChannel = MethodChannel('purchases_flutter');
  const stagingChannel = MethodChannel('taskflow/staging-billing');
  const staging = BillingConfiguration(
    apiKey: 'test_fixture',
    supported: true,
    release: true,
    staging: true,
    supportsStagingTestStore: true,
  );
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(purchasesChannel, (call) async {
      calls.add(call);
      if (call.method == 'isConfigured') return false;
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(purchasesChannel, null);
    messenger.setMockMethodCallHandler(stagingChannel, null);
  });

  test(
    'private Android release uses the native opt-in and passes identity',
    () async {
      MethodCall? nativeCall;
      messenger.setMockMethodCallHandler(stagingChannel, (call) async {
        nativeCall = call;
        return {
          'configured': true,
          'internalTestStore': true,
          'debuggable': false,
        };
      });
      await NativeRevenueCatGateway().configure(staging, 'opaque-owner-id');
      expect(nativeCall?.method, 'configure');
      expect(nativeCall?.arguments, {
        'apiKey': 'test_fixture',
        'appUserId': 'opaque-owner-id',
      });
      expect(calls.map((call) => call.method), ['setLogLevel']);
    },
  );

  for (final result in [
    null,
    {'configured': true},
  ]) {
    test(
      'an unconfirmed native opt-in cannot fall back to unsafe configure: $result',
      () async {
        messenger.setMockMethodCallHandler(stagingChannel, (_) async => result);
        await expectLater(
          NativeRevenueCatGateway().configure(staging, null),
          throwsA(isA<PlatformException>()),
        );
        expect(calls.any((call) => call.method == 'setupPurchases'), isFalse);
      },
    );
  }

  test(
    'missing native bridge fails without starting the fatal SDK path',
    () async {
      await expectLater(
        NativeRevenueCatGateway().configure(staging, null),
        throwsA(isA<MissingPluginException>()),
      );
      expect(calls.any((call) => call.method == 'setupPurchases'), isFalse);
    },
  );

  test(
    'production and unsupported staging releases reject Test Store',
    () async {
      for (final config in [
        const BillingConfiguration(
          apiKey: 'test_fixture',
          supported: true,
          release: true,
          supportsStagingTestStore: true,
        ),
        const BillingConfiguration(
          apiKey: 'test_fixture',
          supported: true,
          release: true,
          staging: true,
        ),
      ]) {
        expect(config.issue, BillingIssue.configuration);
        await expectLater(
          NativeRevenueCatGateway().configure(config, null),
          throwsA(isA<PlatformException>()),
        );
      }
      expect(calls, isEmpty);
    },
  );

  test(
    'production platform keys keep the standard Flutter SDK initialization',
    () async {
      await NativeRevenueCatGateway().configure(
        const BillingConfiguration(
          apiKey: 'goog_fixture',
          supported: true,
          release: true,
        ),
        'opaque-owner-id',
      );
      final setup = calls.singleWhere(
        (call) => call.method == 'setupPurchases',
      );
      expect(setup.arguments['apiKey'], 'goog_fixture');
      expect(setup.arguments['appUserId'], 'opaque-owner-id');
      expect(
        setup.arguments['automaticDeviceIdentifierCollectionEnabled'],
        isFalse,
      );
    },
  );
}
