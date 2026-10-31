import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:agenda/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({
        'taskflow.session': jsonEncode({
          'access': 'old',
          'refresh': 'refresh',
          'user': {'id': 1, 'email': 'file@example.invalid', 'timezone': 'UTC'}
        }),
      }));

  test(
      'multipart retry after token refresh retains the same identity and exact bytes',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('taskflow-file-client-');
    final file = File('${directory.path}/fixture.bin');
    final bytes = [0, 1, 255, 22, 13, 10];
    await file.writeAsBytes(bytes);
    addTearDown(() async {
      await file.delete();
      await directory.delete();
    });
    var uploads = 0;
    var refreshes = 0;
    final api = ApiClient(transport: MockClient((request) async {
      if (request.url.path.endsWith('/refresh/')) {
        refreshes++;
        return http.Response('{"access":"new","refresh":"rotated"}', 200);
      }
      uploads++;
      expect(request.method, 'PUT');
      expect(request.url.path,
          '/api/attachments/7e758c1e-6736-4c64-b1d1-2fcc3e73adee/');
      expect(request.followRedirects, isFalse);
      expect(latin1.decode(request.bodyBytes), contains(latin1.decode(bytes)));
      expect(latin1.decode(request.bodyBytes), contains('field-task'));
      expect(latin1.decode(request.bodyBytes), contains('Results.pdf'));
      if (request.headers['Authorization'] == 'Bearer old') {
        return http.Response('{"detail":"Expired"}', 401);
      }
      expect(request.headers['Authorization'], 'Bearer new');
      return http.Response(
          '{"id":"7e758c1e-6736-4c64-b1d1-2fcc3e73adee","size":6}', 201);
    }));
    addTearDown(api.close);
    await api.restore();
    final result = await api.uploadAttachment(
        id: '7e758c1e-6736-4c64-b1d1-2fcc3e73adee',
        taskId: 'field-task',
        name: 'Results.pdf',
        filePath: file.path,
        accountId: 1);
    expect(result['size'], 6);
    expect(uploads, 2);
    expect(refreshes, 1);
  });

  test('wrong-account and late signed-out downloads cannot return file data',
      () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    var gets = 0;
    final api = ApiClient(transport: MockClient((request) async {
      if (request.url.path.endsWith('/logout/')) {
        return http.Response('{}', 200);
      }
      gets++;
      started.complete();
      return pending.future;
    }));
    addTearDown(api.close);
    await api.restore();
    await expectLater(api.downloadAttachment('file', accountId: 2),
        throwsA(isA<ApiException>()));
    expect(gets, 0);
    final download = api.downloadAttachment('file', accountId: 1);
    final rejected = expectLater(download,
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
    await started.future;
    await api.signOut();
    pending.complete(http.Response.bytes([1, 2, 3], 200));
    await rejected;
    expect(gets, 1);
  });

  test('binary responses remain byte-exact and oversized streams are cancelled',
      () async {
    var cancelled = false;
    var large = false;
    Stream<List<int>> content() async* {
      try {
        if (large) {
          yield List.filled(6 * 1024 * 1024, 0);
          yield [1];
          fail('The client must stop consuming an oversized file.');
        } else {
          yield [0, 255, 1, 128];
        }
      } finally {
        cancelled = true;
      }
    }

    final api = ApiClient(transport: _StreamClient((request) async {
      expect(request.followRedirects, isFalse);
      expect(request.headers['Authorization'], 'Bearer old');
      return http.StreamedResponse(content(), 200,
          headers: {'content-type': 'application/octet-stream'});
    }));
    addTearDown(api.close);
    await api.restore();
    expect(
        await api.downloadAttachment('file', accountId: 1), [0, 255, 1, 128]);
    large = true;
    cancelled = false;
    await expectLater(api.downloadAttachment('file', accountId: 1),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 413)));
    expect(cancelled, isTrue);
  });
}

class _StreamClient extends http.BaseClient {
  _StreamClient(this.respond);
  final Future<http.StreamedResponse> Function(http.BaseRequest) respond;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      respond(request);
}
