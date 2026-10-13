import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/revenuecat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = 'd5d734ae-9a3f-44c5-84d5-557aa423eb91';
  const code = 'a-safe-fixture-code-123456';
  Uri link(String scheme, {String kind = 'group'}) =>
      Uri.parse('$scheme://invite?kind=$kind&id=$id&code=$code');

  test('staging and production invitation schemes remain isolated', () {
    expect(
      InvitationLink.parse(
        link('taskflow-staging'),
        environment: 'staging',
      )?.id,
      id,
    );
    expect(
      InvitationLink.parse(link('taskflow-staging'), environment: 'production'),
      isNull,
    );
    expect(
      InvitationLink.parse(link('taskflow'), environment: 'staging'),
      isNull,
    );
    expect(
      InvitationLink.parse(
        link('taskflow'),
        environment: 'production',
      )?.endpoint,
      'group-invitations',
    );
    expect(
      InvitationLink.parse(
        link('taskflow', kind: 'list'),
        environment: 'production',
      )?.endpoint,
      'invitations',
    );
  });

  test(
    'rejects malformed links, duplicate parameters and arbitrary endpoints',
    () {
      for (final value in [
        'taskflow://evil?kind=group&id=$id&code=$code',
        'taskflow://invite?kind=admin&id=$id&code=$code',
        'taskflow://invite?kind=group&id=../../admin&code=$code',
        'taskflow://invite?kind=group&id=$id&code=$code&code=another',
        'taskflow://invite?kind=group&id=$id&code=$code&server=https://evil.invalid',
        'https://example.invalid/?kind=group&id=$id&code=$code',
        'taskflow://invite?kind=group&id=$id&code=short',
      ]) {
        expect(
          InvitationLink.parse(Uri.parse(value), environment: 'production'),
          isNull,
          reason: value,
        );
      }
    },
  );

  test(
    'test purchases work in an explicit staging release, never production',
    () {
      expect(
        const BillingConfiguration(
          apiKey: 'test_fixture',
          supported: true,
          release: true,
          staging: true,
          supportsStagingTestStore: true,
        ).issue,
        isNull,
      );
      expect(
        const BillingConfiguration(
          apiKey: 'test_fixture',
          supported: true,
          release: true,
        ).issue,
        BillingIssue.configuration,
      );
      expect(
        const BillingConfiguration(
          apiKey: 'sk_secret',
          supported: true,
          release: true,
          staging: true,
        ).issue,
        BillingIssue.configuration,
      );
    },
  );
}
