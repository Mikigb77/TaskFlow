import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/invitation_review_screen.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';

const _link = InvitationLink(
  'group',
  'f4ec527c-44b7-462d-943f-094932762ee1',
  'synthetic-code-1234',
);

void main() {
  for (final available in [true, false]) {
    testWidgets(
      available
          ? 'Invitation needs explicit confirmation with account and role visible'
          : 'Wrong account cannot accept an invitation',
      (tester) async {
        final api = _InvitationApi(available);
        final container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
            taskProvider.overrideWith((ref) => DesignTaskNotifier()),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(api.close);
        container.read(authProvider);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const InvitationReviewScreen(invitation: _link),
                      ),
                    ),
                    child: const Text('Open invitation'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open invitation'));
        await tester.pumpAndSettle();
        expect(api.accepted, isNull);
        expect(find.text('design@example.invalid'), findsOneWidget);
        if (available) {
          expect(find.text('Staging crew'), findsOneWidget);
          expect(find.text('Editor'), findsOneWidget);
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          expect(api.accepted, {'decision': 'accept', 'code': _link.code});
          expect(api.acceptedAccount, 1);
          expect(find.byType(InvitationReviewScreen), findsNothing);
        } else {
          expect(find.byType(FilledButton), findsNothing);
          expect(find.textContaining('email address'), findsWidgets);
          expect(api.accepted, isNull);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _InvitationApi extends OfflineApiClient {
  _InvitationApi(this.available);
  final bool available;
  Map<String, dynamic>? accepted;
  int? acceptedAccount;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    if (method == 'GET' && path == 'group-invitations/') {
      return {
        'invitations': available
            ? [
                {
                  'id': _link.id,
                  'group_name': 'Staging crew',
                  'role': 'editor',
                },
              ]
            : [],
      };
    }
    if (method == 'POST' && path == 'group-invitations/${_link.id}/respond/') {
      accepted = data;
      acceptedAccount = accountId;
      return {};
    }
    throw StateError('Unexpected invitation request');
  }
}
