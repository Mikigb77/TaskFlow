// Sharing a project and its invitations, groups, and the activity of
// shared projects.
import 'package:agenda/models/task_group.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/screens/activity_screen.dart';
import 'package:agenda/screens/groups_screen.dart';
import 'package:agenda/screens/invitation_review_screen.dart';
import 'package:agenda/screens/list_sharing_screen.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/name_ask_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app.dart';
import 'support/fixtures.dart';
import 'support/preview.dart';

const sharing = Screen(
  'sharing',
  'project-sharing',
  'Sharing a project: people, invitations and the project\'s own settings',
  sources: [
    'lib/screens/list_sharing_screen.dart',
    'lib/widgets/project_preferences.dart',
    'lib/widgets/app_components.dart',
  ],
);

const review = Screen(
  'sharing',
  'invitation',
  'An invitation opened from its link (InvitationReviewScreen)',
  sources: [
    'lib/screens/invitation_review_screen.dart',
    'lib/widgets/invitation_cards.dart',
    'lib/services/invitation_links.dart',
  ],
);

const groupsList = Screen(
  'sharing',
  'groups',
  'Groups: every group of people',
  sources: ['lib/screens/groups_screen.dart', 'lib/widgets/invitation_cards.dart'],
);

const groupDetail = Screen(
  'sharing',
  'group',
  'One group: its people, invitations and projects',
  sources: ['lib/screens/groups_screen.dart'],
);

const activity = Screen(
  'sharing',
  'activity',
  'Activity in shared projects (from the people button on Calendar)',
  sources: ['lib/screens/activity_screen.dart'],
);

/// Nobody asked its name yet on this phone.
class _NameAsks extends NameAskStore {
  _NameAsks() : super(TaskDatabase());
  final owners = <String>{};
  @override
  Future<bool> asked(String owner) async => owners.contains(owner);
  @override
  Future<void> markAsked(String owner) async {
    owners.add(owner);
  }
}

Map<String, dynamic> _sharingData({String role = 'owner', String name = 'Matemáticas'}) => {
  'list': {'name': name, 'role': role, 'version': 3},
  'members': [
    {'user_id': ana, 'user__email': 'ana.garcia@example.com', 'role': 'editor'},
    {'user_id': paul, 'user__email': 'paul.martin@example.com', 'role': 'editor'},
  ],
  'invitations': [
    {'id': 'inv-9', 'email': 'lucia.ruiz@example.com', 'role': 'editor'},
  ],
};

final _club = TaskListInfo(
  id: 'club',
  name: 'Club de lectura',
  color: 'violet',
  version: 1,
  role: 'viewer',
  shared: true,
  ownerId: lucia,
  people: const [
    ProjectMember(id: lucia, name: 'Lucía', role: 'owner'),
    ProjectMember(id: me, name: 'María', role: 'viewer'),
  ],
);

const _familia = TaskGroupInfo(
  id: 'familia',
  name: 'Familia López',
  ownerId: me,
  version: 2,
  role: 'owner',
  projectCount: 2,
  people: [
    ProjectMember(id: me, name: 'María', role: 'owner'),
    ProjectMember(id: paul, name: 'Paul', role: 'admin'),
    ProjectMember(id: lucia, name: 'Lucía', role: 'member'),
  ],
);

const _colegio = TaskGroupInfo(
  id: 'colegio',
  name: 'Profesores de 4.º B',
  ownerId: ana,
  version: 1,
  role: 'member',
  projectCount: 1,
  people: [
    ProjectMember(id: ana, name: 'Ana', role: 'owner'),
    ProjectMember(id: me, name: 'María', role: 'member'),
  ],
);

Map<String, dynamic> _groupJson(TaskGroupInfo group) => {
  'id': group.id,
  'name': group.name,
  'owner_id': group.ownerId,
  'version': group.version,
  'role': group.role,
  'project_count': group.projectCount,
  'people': [
    for (final person in group.people)
      {'user_id': person.id, 'name': person.name, 'role': person.role},
  ],
};

void sharingPreviews() {
  previewArea('sharing', 'Sharing, invitations and groups', () {
    preview(
      sharing,
      'owner',
      'Your shared project: Invitar a una persona, its people, a pending invitation.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ...sharedProjectTasks()],
          projects: allProjects,
          overrides: [
            listSharingProvider.overrideWith((ref, id) async => _sharingData()),
          ],
        );
        await app.pushPage(const ListSharingScreen(listId: 'matematicas'));
        await p.shoot();
      },
    );

    preview(
      sharing,
      'invite',
      'Invitar a una persona: the email to invite, typed.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          projects: allProjects,
          overrides: [
            listSharingProvider.overrideWith((ref, id) async => _sharingData()),
          ],
        );
        await app.pushPage(const ListSharingScreen(listId: 'matematicas'));
        await p.tester.tap(find.byKey(const ValueKey('invite-person')));
        await p.tester.pumpAndSettle();
        await p.tester.enterText(
          find.byType(TextFormField).last,
          'jordi.puig@example.com',
        );
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      sharing,
      'name-ask',
      'An account with no name has just sent its first invitation and closed «Invitación enviada»: «¿Cómo te llamas?», once, prefilled from its email.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          projects: allProjects,
          overrides: [
            listSharingProvider.overrideWith((ref, id) async => _sharingData()),
            nameAskStoreProvider.overrideWithValue(_NameAsks()),
          ],
        );
        app.api.handlers['POST lists/matematicas/invite/'] =
            (_) => {'code': 'K7P2Q9MX'};
        await app.pushPage(const ListSharingScreen(listId: 'matematicas'));
        await p.tester.tap(find.byKey(const ValueKey('invite-person')));
        await p.tester.pumpAndSettle();
        await p.tester.enterText(
          find.byType(TextFormField).last,
          'jordi.puig@example.com',
        );
        await p.tester.pumpAndSettle();
        await p.tester.testTextInput.receiveAction(TextInputAction.send);
        await p.tester.pumpAndSettle();
        await app.tap(p.l.done);
        await p.shoot();
      },
    );

    preview(
      sharing,
      'reader',
      'A project shared with you as a reader: your access, and what it means.',
      [es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          projects: [...allProjects, _club],
          overrides: [
            listSharingProvider.overrideWith(
              (ref, id) async => {
                'list': {'name': 'Club de lectura', 'role': 'viewer', 'version': 1},
                'members': [],
                'invitations': [],
              },
            ),
          ],
        );
        await app.pushPage(const ListSharingScreen(listId: 'club'));
        await p.shoot();
      },
    );

    // ------------------------------------------------------- invitations
    preview(
      review,
      'from-ana',
      'Ana\'s invitation to «Excursión de fin de curso», opened from its link.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay(), projects: allProjects);
        app.api.handlers['GET invitations/'] = (_) => {
          'invitations': [
            {
              'id': 'inv-1',
              'list_name': 'Excursión de fin de curso',
              'list_id': 'excursion',
              'role': 'editor',
              'invited_by_name': 'Ana',
            },
          ],
        };
        await app.pushPage(
          const InvitationReviewScreen(
            invitation: InvitationLink('list', 'inv-1', 'K7P2Q9MX'),
          ),
        );
        await p.shoot();
      },
    );

    preview(
      review,
      'unavailable',
      'An invitation this account can\'t see any more (used, withdrawn or for another address).',
      [es1],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        app.api.handlers['GET invitations/'] = (_) => {'invitations': []};
        await app.pushPage(
          const InvitationReviewScreen(
            invitation: InvitationLink('list', 'inv-1', 'K7P2Q9MX'),
          ),
        );
        await p.shoot();
      },
    );

    preview(
      review,
      'offline',
      'An invitation opened with no connection.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.pushPage(
          const InvitationReviewScreen(
            invitation: InvitationLink('list', 'inv-1', 'K7P2Q9MX'),
          ),
        );
        await p.shoot();
      },
    );

    // ------------------------------------------------------------ groups
    preview(
      groupsList,
      'two-groups',
      'Two groups: one you own, one you belong to.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          projects: allProjects,
          groups: const [_familia, _colegio],
        );
        await app.pushPage(const GroupsScreen());
        await p.shoot();
      },
    );

    preview(
      groupsList,
      'empty',
      'No groups yet.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.pushPage(const GroupsScreen());
        await p.shoot();
      },
    );

    preview(
      groupDetail,
      'owner',
      '«Familia López»: its people, a pending invitation, Invitar a una persona.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          projects: allProjects,
          groups: const [_familia, _colegio],
          overrides: [
            groupDetailsProvider('familia').overrideWith(
              (ref) async => {
                'group': _groupJson(_familia),
                'invitations': [
                  {'id': 'gi-1', 'email': 'carmen.lopez@example.com'},
                ],
              },
            ),
          ],
        );
        await app.pushPage(const GroupScreen(groupId: 'familia'));
        await p.shoot();
      },
    );

    // ---------------------------------------------------------- activity
    preview(
      activity,
      'list',
      'What others did in shared projects: unread first, in bold.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          projects: allProjects,
          unread: 2,
          activity: [
            {
              'id': 'a1',
              'action': 'completed',
              'actor_name': 'Ana',
              'task_title': 'Corregir los ejercicios del tema 4',
              'project_name': 'Matemáticas',
              'created_at': previewNow.subtract(const Duration(minutes: 40)).toUtc().toIso8601String(),
              'read_at': null,
            },
            {
              'id': 'a2',
              'action': 'assigned',
              'actor_name': 'Paul',
              'task_title': 'Reservar el autobús',
              'project_name': 'Excursión de fin de curso',
              'created_at': previewNow.subtract(const Duration(hours: 3)).toUtc().toIso8601String(),
              'read_at': null,
            },
            {
              'id': 'a3',
              'action': 'created',
              'actor_name': 'Lucía',
              'task_title': 'Recoger las autorizaciones firmadas',
              'project_name': 'Excursión de fin de curso',
              'created_at': previewNow.subtract(const Duration(days: 1)).toUtc().toIso8601String(),
              'read_at': previewNow.subtract(const Duration(hours: 20)).toUtc().toIso8601String(),
            },
          ],
        );
        await app.pushPage(const ActivityScreen());
        await p.shoot();
      },
    );

    preview(
      activity,
      'empty',
      'Nothing new in shared projects.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay(), projects: allProjects);
        await app.pushPage(const ActivityScreen());
        await p.shoot();
      },
    );
  });
}
