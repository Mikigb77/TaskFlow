import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class InvitationLink {
  const InvitationLink(this.kind, this.id, this.code);
  final String kind;
  final String id;
  final String code;
  String get endpoint => kind == 'group' ? 'group-invitations' : 'invitations';
  static InvitationLink? parse(Uri uri, {String? environment}) {
    final staging =
        (environment ?? const String.fromEnvironment('APP_ENV')) == 'staging';
    if (uri.scheme != (staging ? 'taskflow-staging' : 'taskflow') ||
        uri.host != 'invite' ||
        uri.path.isNotEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment) {
      return null;
    }
    final q = uri.queryParametersAll;
    if (q.length != 3 || ['kind', 'id', 'code'].any((k) => q[k]?.length != 1)) {
      return null;
    }
    final kind = q['kind']!.single,
        id = q['id']!.single,
        code = q['code']!.single;
    if (!['group', 'list'].contains(kind) ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(id) ||
        !RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(code)) {
      return null;
    }
    return InvitationLink(kind, id.toLowerCase(), code);
  }
}

final invitationLinkProvider =
    StateNotifierProvider<InvitationLinks, InvitationLink?>(
      (ref) => InvitationLinks(),
    );

/// Keeps an invitation across sign-in/process restarts; never stores it in logs.
class InvitationLinks extends StateNotifier<InvitationLink?> {
  InvitationLinks({FlutterSecureStorage? storage, bool listen = true})
    : _storage = storage ?? const FlutterSecureStorage(),
      super(null) {
    if (listen) {
      _subscription = AppLinks().uriLinkStream.listen(
        receive,
        onError: (Object _) {},
      );
      unawaited(_restore());
    }
  }
  final FlutterSecureStorage _storage;
  StreamSubscription<Uri>? _subscription;
  Future<void> _writes = Future.value();
  int _revision = 0;
  static const _key = 'taskflow.pending-invitation';

  Future<void> _restore() async {
    final revision = _revision;
    try {
      final raw = await _storage.read(key: _key);
      if (!mounted || revision != _revision || raw == null) return;
      final value = jsonDecode(raw) as Map;
      final saved = DateTime.parse(value['saved'] as String);
      if (DateTime.now().difference(saved) > const Duration(days: 7)) return;
      state = InvitationLink.parse(Uri.parse(value['uri'] as String));
    } catch (_) {
      /* Unsupported storage/platform must not block app startup. */
    }
  }

  void receive(Uri uri) {
    final link = InvitationLink.parse(uri);
    if (link == null || !mounted) return;
    _revision++;
    state = link;
    _writes = _writes
        .then(
          (_) => _storage.write(
            key: _key,
            value: jsonEncode({
              'uri': uri.toString(),
              'saved': DateTime.now().toUtc().toIso8601String(),
            }),
          ),
        )
        .catchError((Object _) {});
  }

  void clear(InvitationLink expected) {
    if (!identical(state, expected)) return;
    _revision++;
    state = null;
    _writes = _writes
        .then((_) => _storage.delete(key: _key))
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
