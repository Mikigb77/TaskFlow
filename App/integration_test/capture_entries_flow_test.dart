import 'dart:convert';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Android external entry retry, account isolation and fixture cleanup',
      (tester) async {
    final database = TaskDatabase();
    final store = CaptureStore(database);
    final db = await database.database;
    // These exact IDs were created by the documented native cold/warm/widget
    // checks. Never remove unrelated captures, including ones with similar text.
    const manualIds = [
      '753eb590-1948-4b7b-a917-2e38e9c4ec72',
      '9c16cf5f-ac9f-48c8-890a-521f4d0516de',
      'e53c96ee-a66c-486e-b433-e59b58d503cb'
    ];
    var retained = 0;
    for (final id in manualIds) {
      final rows = await db.query('captures', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) continue;
      final session =
          CaptureSession.fromJson(jsonDecode(rows.single['data'] as String));
      if (session.terminal) continue;
      expect(session.text.startsWith('TaskFlow entry test'), isTrue);
      retained++;
      await store.discard(id, session.ownerKey);
    }
    debugPrint(
        'Retained native cold/warm/widget captures after process restart: $retained; test inputs discarded.');
    const id = 'eab4712c-5042-43f4-998b-c397b18a6d8a';
    const owner = 'capture-entry-integration-fixture';
    final first = await store.acceptEntry(id, owner, 'UTC',
        text: 'Synthetic Android share', capturedAt: DateTime.utc(2026, 9, 22));
    if (!first!.terminal) {
      await store
          .update(first.copyWith(text: 'Edited synthetic Android share'));
      final retry = await store.acceptEntry(id, owner, 'UTC',
          text: 'Original', capturedAt: DateTime.now());
      expect(retry!.text, 'Edited synthetic Android share');
      expect(retry.capturedAt, first.capturedAt);
      expect(
          await store.acceptEntry(id, 'different-owner', 'UTC',
              text: 'Other', capturedAt: DateTime.now()),
          isNull);
      await store.discard(id, owner);
    }
    expect(await store.pending(owner), isEmpty);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Center(child: Text('Capture entry checks complete')))));
  });
}
