import 'package:flutter/services.dart';
// sqflite exposes no public native-invocation hook. Keep this small adapter
// covered by the Android multi-connection integration test when upgrading it.
// ignore: implementation_imports
import 'package:sqflite/src/factory_impl.dart';

/// Lets another Flutter engine finish its transaction on sqflite's shared
/// Android worker instead of waiting for its lock on that very same worker.
class AndroidDatabaseFactory extends SqfliteDatabaseFactoryImpl {
  @override
  Future<T> invokeMethod<T>(String method, [Object? arguments]) async {
    final watch = Stopwatch()..start();
    var delay = 5;
    while (true) {
      try {
        return await super.invokeMethod<T>(method, arguments);
      } on PlatformException catch (error) {
        // Retry individual rejected statements, never batches or transaction
        // callbacks. SQLITE_BUSY_SNAPSHOT (517) needs a rollback, not a retry.
        final code =
            RegExp(r'\(code (\d+)\b').firstMatch(error.message ?? '')?.group(1);
        if (error.code != 'sqlite_error' ||
            code != '5' ||
            !const ['execute', 'insert', 'update', 'query'].contains(method) ||
            watch.elapsed >= const Duration(seconds: 5)) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: delay));
        if (delay < 40) delay *= 2;
      }
    }
  }
}
