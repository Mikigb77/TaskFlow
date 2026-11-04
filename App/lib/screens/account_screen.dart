import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:agenda/services/meeting_controller.dart';
import 'package:agenda/widgets/google_login_button.dart';
import 'package:agenda/widgets/meeting_banners.dart';
import 'package:agenda/widgets/name_ask_sheet.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/screens/login_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.debug = kDebugMode});

  /// Only debug builds show the server address here; staging builds reach it
  /// from the version line in Other settings.
  final bool debug;
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

enum _Action { sync, import, google, signOut }

enum _MeetingsChoice { send, discard }

/// «Save notes and sign out» was tapped and still runs: the notes are being
/// saved, then the account signs out. Held outside Cuenta, so leaving it
/// doesn't hide the wait: Cuenta opened again shows it, and can't start a
/// second sign-out.
final meetingSignOutPendingProvider = StateProvider<bool>((ref) => false);

class _AccountScreenState extends ConsumerState<AccountScreen> {
  _Action? _running;
  bool _failed = false;
  String? _message;
  Object? _failure;
  late Future<int> _localItems = ref
      .read(taskRepositoryProvider)
      .localTaskCount();

  Future<void> _run(_Action kind, Future<void> Function() action) async {
    setState(() {
      _running = kind;
      _message = null;
      _failure = null;
      _failed = false;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _failure = error;
          _failed = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _running = null);
      }
    }
  }

  Future<void> _sync() =>
      _run(_Action.sync, () => ref.read(taskProvider.notifier).loadTasks());

  Future<void> _import() async {
    final count = await _localItems;
    if (count == 0 || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(context.l10n.importLocalItemsQuestion),
        content: Text(context.l10n.importLocalItemsHelp(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.importItems),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(_Action.import, () async {
      final repository = ref.read(taskRepositoryProvider);
      final imported = await repository.importLocalTasks();
      await ref.read(taskProvider.notifier).loadTasks();
      if (mounted) {
        setState(() {
          _message = context.l10n.itemsImported(imported);
          _localItems = repository.localTaskCount();
        });
      }
    });
  }

  Future<void> _signOut() async {
    // Read before any wait, so a confirmed sign-out finishes even when
    // Cuenta is left meanwhile.
    final auth = ref.read(authProvider.notifier);
    // Meeting recordings waiting here belong to this account (MN-13).
    // Right after launch they may not have been read yet: read them now.
    final reading = ref.read(meetingControllerProvider.notifier);
    try {
      await reading.ready;
      await reading.refresh();
    } catch (_) {
      /* Counted from what the app has read. */
    }
    if (!mounted) return;
    final meetings = ref.read(meetingsProvider);
    if (meetings.recording != null ||
        meetings.stopped.isNotEmpty ||
        meetings.waiting.isNotEmpty) {
      return _signOutWithMeetings(meetings, reading, auth);
    }
    // Signing out cancels every reminder on this phone, so ask first.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        content: Text(context.l10n.signOutQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.signOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // A meeting's notes just saved: the server hears it may delete the
    // meeting while this account can still tell it (MN-24).
    final unacknowledged = meetings.ready.any(
      (meeting) => meeting.phase == MeetingPhase.saved,
    );
    await _run(_Action.signOut, () async {
      if (unacknowledged) await tellServerBeforeSignOut(reading);
      await auth.signOut();
    });
  }

  /// Recordings still wait to be sent (MN-13): save their notes first, or
  /// discard them, then sign out. If they can't all be sent, the account
  /// stays. Recordings that can only fail to send are offered no send.
  Future<void> _signOutWithMeetings(
    MeetingsState meetings,
    MeetingController controller,
    AuthNotifier auth,
  ) async {
    final l = context.l10n;
    final pending = ref.read(meetingSignOutPendingProvider.notifier);
    final others = meetings.stopped.length + meetings.waiting.length;
    final heldBack =
        meetings.recording == null &&
        [...meetings.stopped, ...meetings.waiting].every(meetingHeldBack);
    final body = [
      if (heldBack)
        meetingHeldBackReason(l, meetings)!
      else ...[
        if (meetings.recording != null) l.meetingSignOutRecording,
        if (others > 0) l.meetingSignOutQuestion(others),
      ],
      l.meetingSignOutReminders,
    ].join(' ');
    final choice = await showDialog<_MeetingsChoice>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        actionsOverflowButtonSpacing: 8,
        // TalkBack opens on the question, not on «Alerta».
        semanticLabel: l.meetingSignOutTitle,
        title: Text(l.meetingSignOutTitle),
        content: Text(body),
        // Cancel sits between the irreversible Discard and the main action.
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, _MeetingsChoice.discard),
            child: Text(l.meetingDiscardAndSignOut),
          ),
          if (heldBack)
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.cancel),
            )
          else ...[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _MeetingsChoice.send),
              child: Text(l.meetingSendFirst),
            ),
          ],
        ],
      ),
    );
    if (choice == null || !mounted) return;
    // As they are now: one recording stops, and those that stopped by
    // themselves are finished into notes.
    final now = ref.read(meetingsProvider);
    await _run(_Action.signOut, () async {
      if (choice == _MeetingsChoice.discard) {
        // Deleted on the server too, before the account's token goes
        // (MN-13, MN-25).
        await controller.discardAll();
        await tellServerBeforeSignOut(controller);
      } else {
        // The line under Cerrar sesión stays until sign-in shows, or the
        // send fails, in this Cuenta or one opened again meanwhile.
        pending.state = true;
        final MeetingSendResult result;
        try {
          if (now.recording != null) {
            final stopped = await controller.stop();
            // A quiet recording kept at Stop (UX-2717): its notes are
            // made too, as the question said.
            if (stopped?.phase == MeetingPhase.interrupted) {
              await controller.finishMeeting(stopped!.id);
            }
          }
          for (final meeting in now.stopped) {
            await controller.finishMeeting(meeting.id);
          }
          result = await controller.uploadNow();
          if (result == MeetingSendResult.done) await auth.signOut();
        } finally {
          pending.state = false;
        }
        if (result != MeetingSendResult.done) {
          // With Cuenta left, nothing more: the account stays, and the
          // Notes line says why the recording waits.
          if (mounted) {
            setState(() {
              _message = meetingSendFailure(
                l,
                ref.read(meetingsProvider),
                result,
              );
              _failed = true;
            });
          }
        }
        return;
      }
      await auth.signOut();
    });
  }

  Future<void> _linkGoogle() async {
    final current = ref.read(authProvider).account;
    if (current == null) return;
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _GoogleLinkDialog(),
    );
    if (password == null || !mounted) return;
    await _run(_Action.google, () async {
      final token = await ref.read(googleSignInServiceProvider).authenticate();
      if (token == null || !mounted) return;
      if (ref.read(authProvider).account?.id != current.id) return;
      await ref.read(authProvider.notifier).linkGoogle(token, password);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (auth.account == null) return const LoginScreen();
    // A sign-out started from an earlier Cuenta may still be saving notes.
    final savingNotes = ref.watch(meetingSignOutPendingProvider);
    final signingOut = _running == _Action.signOut || savingNotes;
    final busy = _running != null || auth.loading || savingNotes;
    final colors = Theme.of(context).colorScheme;
    final google = ref.watch(googleSignInServiceProvider);
    ref.watch(taskProvider);
    final syncError = ref.read(taskRepositoryProvider).syncError;
    final name = auth.account!.firstName.trim();
    final email = auth.account!.email;
    // In-button progress names what is happening, so TalkBack says it.
    Widget progress(String label, {Color? color}) => SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color,
        semanticsLabel: label,
      ),
    );
    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.yourAccount),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 32,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // The person's name, when the account has one; then the email.
              if (name.isNotEmpty) ...[
                Semantics(
                  header: true,
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                breakableAddress(email),
                semanticsLabel: email,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              // Sets or fixes the name people see on shared projects.
              ListTile(
                key: const ValueKey('account-name'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: Text(
                  name.isEmpty
                      ? context.l10n.accountAddName
                      : context.l10n.nameAskField,
                ),
                subtitle: name.isEmpty ? null : Text(name),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: busy ? null : () => editName(context),
              ),
              const SizedBox(height: 12),
              if (auth.account!.googleLinked) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(context.l10n.googleAccountLinked),
                ),
                const SizedBox(height: 12),
              ] else if (google.configured) ...[
                GoogleLoginButton(
                  label: context.l10n.linkGoogleAccount,
                  onPressed: busy ? null : _linkGoogle,
                ),
                if (_running == _Action.google) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 20),
              ],
              // The sync state in one line; a failed sync says so here, once.
              if (syncError == null)
                ListTile(
                  key: const ValueKey('account-sync-status'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.cloud_done_outlined,
                    color: colors.primary,
                  ),
                  title: Text(context.l10n.accountSaved),
                )
              else
                MessageBanner(
                  requestProblemText(context.l10n, syncError),
                  key: const ValueKey('account-sync-status'),
                  isError: true,
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: busy ? null : _sync,
                  icon: _running == _Action.sync
                      ? progress(context.l10n.accountSyncing)
                      : const Icon(Icons.sync_rounded, size: 20),
                  label: Text(context.l10n.syncNow),
                ),
              ),
              FutureBuilder<int>(
                future: _localItems,
                builder: (context, snapshot) {
                  if ((snapshot.data ?? 0) == 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : _import,
                      icon: _running == _Action.import
                          ? progress(context.l10n.accountImporting)
                          : const Icon(Icons.file_upload_outlined, size: 20),
                      label: Text(context.l10n.importLocalItems),
                    ),
                  );
                },
              ),
              if (_message != null || _failure != null || auth.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: MessageBanner(
                    _message ??
                        requestProblemText(
                          context.l10n,
                          _failure ?? auth.error!,
                        ),
                    isError: auth.error != null || _failed,
                  ),
                ),
              if (widget.debug) ...[
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(context.l10n.connectionDetails),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: SelectableText(
                        ref.read(apiClientProvider).baseUrl,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: AlignmentDirectional.centerStart,
                // Sign-out can wait on the server; show progress in the button,
                // and nothing at rest.
                child: TextButton.icon(
                  onPressed: busy ? null : _signOut,
                  icon: signingOut
                      ? progress(
                          savingNotes
                              ? context.l10n.meetingSending
                              : context.l10n.accountSigningOut,
                          color: colors.error,
                        )
                      : null,
                  label: Text(
                    context.l10n.signOut,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ),
              // Saving a meeting's notes can take minutes: say so, and that
              // signing out follows.
              if (savingNotes)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      context.l10n.meetingSavingNotes,
                      key: const ValueKey('account-saving-notes'),
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                ),
              // Deleting the account is its own group, kept apart from
              // signing out.
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const ValueKey('account-delete'),
                  onPressed: busy
                      ? null
                      : () => Navigator.pushNamed(context, '/deleteAccount'),
                  child: Text(
                    context.l10n.deleteAccount,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleLinkDialog extends StatefulWidget {
  const _GoogleLinkDialog();
  @override
  State<_GoogleLinkDialog> createState() => _GoogleLinkDialogState();
}

class _GoogleLinkDialogState extends State<_GoogleLinkDialog> {
  final password = TextEditingController();
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(context.l10n.linkGoogleAccount),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.l10n.googleLinkHelp),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('google-link-password'),
          controller: password,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(labelText: context.l10n.password),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: password.text.isEmpty
            ? null
            : () => Navigator.pop(context, password.text),
        child: Text(context.l10n.continueWithGoogle),
      ),
    ],
  );
}
