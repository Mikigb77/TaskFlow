import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/task_database.dart';

/// Remembers, per account on this phone, that it was asked its name, so the
/// question never comes back.
class NameAskStore {
  final TaskDatabase database;
  NameAskStore(this.database);

  Future<bool> asked(String owner) async {
    final rows = await (await database.database).query(
      'app_preferences',
      where: 'scope = ?',
      whereArgs: ['nameAsked:$owner'],
    );
    return rows.isNotEmpty &&
        (jsonDecode(rows.single['data'] as String) as Map)['asked'] == true;
  }

  Future<void> markAsked(String owner) async =>
      (await database.database).insert('app_preferences', {
        'scope': 'nameAsked:$owner',
        'data': jsonEncode({'asked': true}),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
}

final nameAskStoreProvider = Provider((ref) => NameAskStore(TaskDatabase()));

/// Accounts asked, or being asked, in this run of the app.
final _askingProvider = Provider<Set<String>>((ref) => {});

/// Asks account [accountId] its name, once on this phone, when it has none:
/// right after its first invitation goes out, or after it first joins a
/// project or group. The sheet opens over [navigator]'s top page. It counts
/// as asked as it shows, so «Ahora no», Back or a swipe never bring it back.
Future<void> askForNameOnce(
  NavigatorState navigator, {
  required int accountId,
}) async {
  if (!navigator.mounted) return;
  final container = ProviderScope.containerOf(navigator.context, listen: false);
  bool nameless() {
    final account = container.read(authProvider).account;
    return account != null &&
        account.id == accountId &&
        account.firstName.trim().isEmpty;
  }

  if (!nameless()) return;
  final owner = container.read(taskRepositoryProvider).ownerKey;
  if (!container.read(_askingProvider).add(owner)) return;
  final store = container.read(nameAskStoreProvider);
  var shown = false;
  try {
    if (await store.asked(owner) ||
        !navigator.mounted ||
        !nameless() ||
        container.read(taskRepositoryProvider).ownerKey != owner) {
      return;
    }
    shown = true;
    unawaited(store.markAsked(owner).catchError((Object _) {}));
    final email = container.read(authProvider).account!.email;
    final saved = await showModalBottomSheet<bool>(
      context: navigator.context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _NameAskSheet(suggestion: suggestedName(email)),
    );
    if (saved == true) container.invalidate(taskListsProvider);
  } catch (_) {
    // Without the saved flag the question waits for the next time.
  } finally {
    if (!shown) container.read(_askingProvider).remove(owner);
  }
}

/// Opens the name sheet from Cuenta, filled in with the account's name, or
/// with a guess from its email when it has none. It neither checks nor sets
/// the asked-once flag. A saved name reaches the people chips and «Creada
/// por» at once.
Future<void> editName(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final account = container.read(authProvider).account;
  if (account == null) return;
  final name = account.firstName.trim();
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _NameAskSheet(
      suggestion: name.isNotEmpty ? name : suggestedName(account.email),
    ),
  );
  if (saved == true) container.invalidate(taskListsProvider);
}

/// A first guess at a name, from [email]'s part before the @: up to its
/// first dot, underscore, hyphen, plus or digit, with a capital first
/// letter («paul.smith84» → «Paul»). Fewer than 2 letters left gives the
/// whole part.
String suggestedName(String email) {
  final local = email.split('@').first.trim();
  final cut = local.split(RegExp(r'[._\-+0-9]')).first;
  final letters = RegExp(r'\p{L}', unicode: true).allMatches(cut).length;
  final name = letters < 2
      ? local
      : cut.substring(0, 1).toUpperCase() + cut.substring(1);
  return name.length > 150 ? name.substring(0, 150) : name;
}

class _NameAskSheet extends ConsumerStatefulWidget {
  const _NameAskSheet({required this.suggestion});
  final String suggestion;

  @override
  ConsumerState<_NameAskSheet> createState() => _NameAskSheetState();
}

class _NameAskSheetState extends ConsumerState<_NameAskSheet> {
  late final _name = TextEditingController(text: widget.suggestion);
  bool _saving = false;
  Object? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canSave => !_saving && _name.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).setFirstName(_name.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    // Above the keyboard, in the room it leaves.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        key: const ValueKey('name-ask-sheet'),
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
              child: Text(l.nameAskTitle, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 12),
            Semantics(
              container: true,
              child: Text(
                l.nameAskBody,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              key: const ValueKey('name-ask-field'),
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              maxLength: 150,
              decoration: InputDecoration(
                labelText: l.nameAskField,
                counterText: '',
                // Only the reason: nothing here is about the tasks, and the
                // field keeps the name.
                errorText: _error == null
                    ? null
                    : requestProblemText(l, _error!, onSignIn: true),
                errorMaxLines: 6,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _canSave ? _save : null,
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: l.save,
                      ),
                    )
                  : Text(l.save, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: Text(l.nameAskNotNow, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}
