import 'dart:async';

import 'package:agenda/models/task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design_fixtures.dart';

/// Tasks on the phone whose cloud sync never completes: the first load (the
/// notifier's own, at start) shows [given] or the design samples; every
/// later `loadTasks()` is counted in [syncs] and returns [sync]'s future,
/// which completes only when a test completes it. A screen that waits for it
/// before answering shows nothing.
class HangingSyncTasks extends DesignTaskNotifier {
  HangingSyncTasks([this.given]);

  /// The tasks on the phone; the design samples when null.
  final List<Task>? given;

  /// How many syncs were started after the first load.
  int syncs = 0;

  /// The running sync; complete it, or call [finishSync], to let a waiting
  /// screen answer.
  final sync = Completer<void>();

  /// Completes [sync], first showing [tasks] as the sync brought them when
  /// given.
  void finishSync([List<Task>? tasks]) {
    if (tasks != null) state = AsyncData(tasks);
    sync.complete();
  }
  bool _loaded = false;

  @override
  Future<void> loadTasks() {
    if (!_loaded) {
      _loaded = true;
      state = AsyncData(given ?? DesignTaskNotifier.samples());
      return Future.value();
    }
    syncs++;
    return sync.future;
  }
}
