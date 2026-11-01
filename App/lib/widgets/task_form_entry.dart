import 'dart:async';

import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/free_voice_notice_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/screens/edit_task_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the task form for a new task: how an account without Pro creates
/// tasks once there is no mic, or from the capture sheet's `Escribir`. The
/// first time in a month that its free dictations are used up, a notice
/// says why first, once; it offers the form and Pro. [words] are words
/// already heard, typed or shared, for the title and notes; [readsDates]
/// marks words dictated or shared, heard or shared at [heardAt], whose day
/// and time the form reads; [captureId] is the capture that keeps them
/// until the task is saved.
/// [person] is the person whose chip is on, on the shared project's page it
/// opens from: a task going into [projectId] is theirs (D7).
/// [askedToSpeak]
/// marks the ways in that ask to speak (the widget, the voice shortcut):
/// without the mic, the form says why. The form's route is pushed, not
/// awaited.
Future<void> openTaskForm(
  BuildContext context, {
  String? projectId,
  ProjectMember? person,
  DateTime? day,
  Object? page,
  bool showCalendar = false,
  String words = '',
  bool readsDates = false,
  DateTime? heardAt,
  String? captureId,
  bool askedToSpeak = false,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final free = container.read(authProvider).account?.freeVoice;
  final arguments = NewTaskArguments(
    day: day,
    projectId: projectId,
    person: person,
    page: page,
    showCalendar: showCalendar,
    words: words,
    readsDates: readsDates,
    heardAt: heardAt,
    captureId: captureId,
    askedToSpeak: askedToSpeak,
  );
  if (container.read(freeVoiceUsedUpProvider) && free != null) {
    final resets = container.read(freeVoiceResetsProvider);
    // While it's decided on and while it shows, the notice stands for the
    // form (UX-2110).
    final notice = _Notice(fromEntry: arguments.blank);
    _notices.add(notice);
    try {
      final shows = await container
          .read(freeVoiceNoticeProvider.notifier)
          .claim(resets);
      if (!context.mounted) return;
      if (shows) {
        final create = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (sheetContext) {
            notice.route ??= ModalRoute.of(sheetContext);
            return _UsedUpNotice(limit: free.limit, resets: resets);
          },
        );
        if (!context.mounted || create == null) return;
        if (!create) {
          // `Ver Pro`, as the capture sheet's opens it.
          unawaited(Navigator.pushNamed(context, '/subscription'));
          return;
        }
      }
    } finally {
      _notices.remove(notice);
    }
  }
  if (!context.mounted) return;
  unawaited(Navigator.pushNamed(context, '/newTask', arguments: arguments));
}

/// Whether what's on top of [navigator] stands for the form a widget or
/// shortcut entry would open, still empty, so the entry opens no second
/// form over it (UX-2110): the month's used-up notice an entry opened, which
/// says itself that dictations are used up; or an entry's form with no
/// title, as [emptyEntryFormOnTop] tells. A typing entry ([askedToSpeak]
/// false) takes either kind; one that asks to speak only a form that says
/// why the mic is missing (UX-2642). A form or notice opened in the app,
/// with a day, a project, a person or words, never stands for an entry's.
bool emptyTaskFormOnTop(
  NavigatorState navigator, {
  required bool askedToSpeak,
}) {
  final form = emptyEntryFormOnTop(navigator);
  if (form != null && (form || !askedToSpeak)) return true;
  return _notices.any((notice) {
    final route = notice.route;
    // Still decided on, or pushed and not yet built: it's the next on top.
    return notice.fromEntry &&
        (route == null || (route.navigator == navigator && route.isCurrent));
  });
}

// The used-up notices on their way or showing.
final _notices = <_Notice>{};

class _Notice {
  _Notice({required this.fromEntry});

  /// Opened as an entry opens the form: no day, project, person, words or
  /// capture (UX-2642).
  final bool fromEntry;
  ModalRoute<Object?>? route;
}

/// Free dictations used up: the form has no limit, and dictations come back
/// on [resets]. Pops true for `Crear una tarea`, false for `Ver Pro`.
class _UsedUpNotice extends StatelessWidget {
  const _UsedUpNotice({required this.limit, required this.resets});
  final int limit;
  final DateTime resets;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      key: const ValueKey('free-voice-notice'),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Read out by TalkBack as the sheet opens; its own node, so the
          // line under it isn't read as part of the heading.
          Semantics(
            container: true,
            header: true,
            liveRegion: true,
            child: Text(
              l.freeVoiceNoticeTitle(limit),
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          // Read after the heading, not before it.
          Semantics(
            container: true,
            child: Text(
              l.freeVoiceNoticeBody(limit, context.shortDate(resets.toLocal())),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.freeVoiceNoticeCreate, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.voiceProAction, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
