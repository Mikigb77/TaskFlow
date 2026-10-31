import 'package:agenda/services/capture_entries.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const valid = {
    'id': '3b9d0032-1fe0-41fa-a1b8-fb71fba4e84a',
    'kind': 'share',
    'text': 'Buy coffee',
    'capturedAt': 1790070000000
  };
  test(
      'external entries accept bounded text and reject unsupported actions or malformed data',
      () {
    expect(CaptureEntry.fromMap(valid)!.text, 'Buy coffee');
    for (final bad in [
      {...valid, 'id': '../capture'},
      {...valid, 'kind': 'delete'},
      {...valid, 'text': ''},
      {...valid, 'text': List.filled(4001, 'x').join()},
      {...valid, 'capturedAt': -1},
    ]) {
      expect(CaptureEntry.fromMap(bad), isNull);
    }
  });
  test(
      'pending entries are acknowledged individually and platform absence remains harmless',
      () async {
    const channel = MethodChannel('test/capture-entries');
    final entries = CaptureEntries(channel: channel);
    addTearDown(entries.dispose);
    expect(await entries.pending(), isEmpty);
    expect(await entries.pinWidget(), isFalse);
    final queue = [valid];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pending') return queue;
      if (call.method == 'acknowledge') {
        queue.removeWhere(
            (entry) => entry['id'] == (call.arguments as Map)['id']);
      }
      return null;
    });
    expect((await entries.pending()).single.id, valid['id']);
    await entries.acknowledge(valid['id']! as String);
    expect(await entries.pending(), isEmpty);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
