// The preview harness: each preview is a widget test that drives the real
// app to one state, writes a PNG to build/ux/<area>/ and measures it (see
// audit.dart). Areas write a manifest; report.dart turns the manifests into
// build/ux/INDEX.md and build/ux/AUDIT.md.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'audit.dart';

/// Renders only on request: `--dart-define=WRITE_UX_PREVIEWS=true`.
const writeUxPreviews = bool.fromEnvironment('WRITE_UX_PREVIEWS');

/// Where the previews go, relative to `App/`.
const uxRoot = 'build/ux';

/// PNG pixels per dp.
const pixelRatio = 2.0;

/// The status bar and the gesture bar, in dp, as on an Android phone drawn
/// edge to edge.
const statusBar = 24.0;
const gestureBar = 24.0;

/// One way to see a screen: language, theme, text scale and phone size.
class Variant {
  const Variant(
    this.lang,
    this.dark,
    this.scale, {
    this.width = 360,
    this.height = 800,
  });
  final String lang;
  final bool dark;
  final double scale;
  final double width;
  final double height;

  String get theme => dark ? 'dark' : 'light';
  String get scaleTag => scale == scale.roundToDouble()
      ? '${scale.round()}x'
      : '${scale}x';

  /// `es.light.2x`, or `es.light.2x-393` on the wider phone.
  String get tag => '$lang.$theme.$scaleTag${width == 360 ? '' : '-${width.round()}'}';
  Size get size => Size(width, height);
}

const es1 = Variant('es', false, 1);
const es13 = Variant('es', false, 1.3);
const es2 = Variant('es', false, 2);
const esDark = Variant('es', true, 1);
const ca2 = Variant('ca', false, 2);
const en2 = Variant('en', false, 2);
const ca1 = Variant('ca', false, 1);
const es1Wide = Variant('es', false, 1, width: 393, height: 852);
const es2Wide = Variant('es', false, 2, width: 393, height: 852);

/// Every screen: Spanish, light, at 1× and 2× text.
const everywhere = [es1, es2];

/// The main screens add 1.3× text and dark.
const mainScreen = [es1, es13, es2, esDark];

/// Screens whose text is long enough to clip or wrap: Catalan and English at
/// 2× text.
const longText = [ca2, en2];

/// The capture sheet and Calendar also on a 393 dp phone.
const wider = [es1Wide, es2Wide];

/// A screen or a part of one: its file name, what it is, and the app files
/// that draw it.
class Screen {
  const Screen(this.area, this.name, this.title, {required this.sources});
  final String area;
  final String name;
  final String title;
  final List<String> sources;
}

typedef PreviewBody = Future<void> Function(Preview p);

/// The area being rendered, and every file each area expects.
_AreaRun? _area;
final _expected = <String, Set<String>>{};
final _areaTitles = <String, String>{};

String _fileFor(Screen screen, String state, Variant v) =>
    '${screen.name}.$state.${v.tag}.png';

/// A group of previews written to `build/ux/<key>/`. Renders from an
/// earlier run stay for previews filtered out of this one; renders of states
/// that no longer exist are removed.
void previewArea(String key, String title, void Function() body) {
  _areaTitles[key] = title;
  group(key, () {
    final run = _AreaRun(key, title);
    setUpAll(() {
      _area = run;
      Directory('$uxRoot/$key').createSync(recursive: true);
      run.loadPrevious();
    });
    tearDownAll(() {
      run.write(_expected[key] ?? const {});
      _area = null;
    });
    body();
  });
}

/// Registers [state] of [screen] once per variant. [then] names more states
/// the same flow shoots later, with what each shows.
void preview(
  Screen screen,
  String state,
  String note,
  List<Variant> variants,
  PreviewBody body, {
  Map<String, String> then = const {},
}) {
  for (final v in variants) {
    final files = _expected.putIfAbsent(screen.area, () => {});
    files.add(_fileFor(screen, state, v));
    for (final more in then.keys) {
      files.add(_fileFor(screen, more, v));
    }
    testWidgets('${screen.area}/${screen.name}.$state.${v.tag}', (tester) async {
      final p = Preview._(tester, screen, state, note, v, then);
      await p._setUp();
      try {
        await body(p);
        p._checkShots();
      } finally {
        await p._tearDown();
      }
    });
  }
}

/// One preview test: the phone, the app's language, and [shoot].
class Preview {
  Preview._(
    this.tester,
    this.screen,
    this.state,
    this.note,
    this.variant,
    this.then,
  );
  final WidgetTester tester;
  final Screen screen;
  final String state;
  final String note;
  final Variant variant;
  final Map<String, String> then;

  /// Wraps the app (and the keyboard stand-in) for the PNG.
  final boundary = GlobalKey();

  /// The keyboard's height in dp, 0 when it's down.
  final keyboard = ValueNotifier<double>(0);

  /// Layout and build errors since the last shot.
  final _errors = <FlutterErrorDetails>[];
  final _shot = <String>{};
  final _cleanups = <Future<void> Function()>[];
  late final SemanticsHandle _semantics;
  FlutterExceptionHandler? _onError;

  AppLocalizations get l => lookupAppLocalizations(Locale(variant.lang));

  /// Runs before the next test, after the app is gone.
  void onTearDown(Future<void> Function() cleanup) => _cleanups.add(cleanup);

  Future<void> _setUp() async {
    tester.view.physicalSize = variant.size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(
      top: statusBar,
      bottom: gestureBar,
    );
    tester.view.viewPadding = const FakeViewPadding(
      top: statusBar,
      bottom: gestureBar,
    );
    tester.platformDispatcher.textScaleFactorTestValue = variant.scale;
    _semantics = tester.ensureSemantics();
    final messenger = tester.binding.defaultBinaryMessenger;
    // The phone's time zone, and no accessibility timeout set.
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => 'Europe/Madrid',
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('taskflow/accessibility'),
      (_) async => null,
    );
    _onError = FlutterError.onError;
    FlutterError.onError = _errors.add;
  }

  Future<void> _tearDown() async {
    FlutterError.onError = _onError;
    for (final cleanup in _cleanups.reversed) {
      await cleanup();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    _semantics.dispose();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('taskflow/accessibility'),
      null,
    );
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.reset();
    keyboard.dispose();
  }

  void _checkShots() {
    final missing = {state, ...then.keys}.difference(_shot);
    if (missing.isNotEmpty) {
      throw StateError('Not shot: ${missing.join(', ')}');
    }
  }

  /// The app wrapped for the PNG, with a stand-in for the keyboard.
  Widget frame(Widget app) => RepaintBoundary(
    key: boundary,
    child: Stack(
      textDirection: TextDirection.ltr,
      children: [
        Positioned.fill(child: app),
        ValueListenableBuilder<double>(
          valueListenable: keyboard,
          builder: (context, height, _) => height == 0
              ? const SizedBox.shrink()
              : Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: height,
                  child: ExcludeSemantics(
                    child: _KeyboardStandIn(height: height, dark: variant.dark),
                  ),
                ),
        ),
      ],
    ),
  );

  /// The keyboard comes up: the app gets the inset a phone gives it, and the
  /// render shows a grey stand-in where the keyboard covers the screen.
  Future<void> showKeyboard([double height = 300]) async {
    tester.view.viewInsets = FakeViewPadding(bottom: height);
    tester.view.padding = const FakeViewPadding(top: statusBar);
    keyboard.value = height;
    await tester.pumpAndSettle();
  }

  /// Frames for something that never settles (a spinner, listening).
  Future<void> frames([int count = 6, Duration step = const Duration(milliseconds: 50)]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(step);
    }
  }

  /// Writes the PNG for [as] (the preview's own state by default) and
  /// measures it.
  Future<void> shoot([String? as]) async {
    final name = as ?? state;
    if (name != state && !then.containsKey(name)) {
      throw StateError('Undeclared state $name');
    }
    _shot.add(name);
    await tester.pump();
    final file = _fileFor(screen, name, variant);
    final box = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    late ByteData raw;
    late int width, height;
    await tester.runAsync(() async {
      final image = await box.toImage(pixelRatio: pixelRatio);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      raw = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      width = image.width;
      height = image.height;
      image.dispose();
      await File(
        '$uxRoot/${screen.area}/$file',
      ).writeAsBytes(png.buffer.asUint8List());
    });
    final errors = [..._errors];
    _errors.clear();
    final measured = await audit(
      tester,
      errors: errors,
      screen: variant.size,
      image: raw,
      imageWidth: width,
      imageHeight: height,
      pixelRatio: pixelRatio,
    );
    _area?.add({
      'file': file,
      'screen': screen.name,
      'screenTitle': screen.title,
      'state': name,
      'note': name == state ? note : then[name],
      'sources': screen.sources,
      'lang': variant.lang,
      'theme': variant.theme,
      'scale': variant.scale,
      'width': variant.width,
      'height': variant.height,
      'keyboard': keyboard.value,
      'renderedAt': DateTime.now().toIso8601String(),
      'audit': measured,
    });
  }
}

class _KeyboardStandIn extends StatelessWidget {
  const _KeyboardStandIn({required this.height, required this.dark});
  final double height;
  final bool dark;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Container(
      color: dark ? const Color(0xFF2B2D30) : const Color(0xFFD5D8DC),
      alignment: Alignment.center,
      child: Text(
        'Keyboard · ${height.round()} dp (not part of the app)',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          color: dark ? const Color(0xFFB0B4B8) : const Color(0xFF5F6368),
        ),
      ),
    ),
  );
}

/// One area's renders: those of this run, and those of earlier runs for
/// previews filtered out of it.
class _AreaRun {
  _AreaRun(this.key, this.title);
  final String key;
  final String title;
  final _shots = <String, Map<String, Object?>>{};

  File get _manifest => File('$uxRoot/$key/manifest.json');

  void loadPrevious() {
    if (!_manifest.existsSync()) return;
    try {
      final data = jsonDecode(_manifest.readAsStringSync()) as Map;
      for (final shot in (data['shots'] as List).cast<Map>()) {
        _shots[shot['file'] as String] = shot.cast<String, Object?>();
      }
    } catch (_) {
      // An unreadable manifest: this run writes a new one.
    }
  }

  void add(Map<String, Object?> shot) => _shots[shot['file']! as String] = shot;

  void write(Set<String> expected) {
    // States removed from the suite: their renders go too.
    final dir = Directory('$uxRoot/$key');
    for (final file in dir.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (name.endsWith('.png') && !expected.contains(name)) file.deleteSync();
    }
    _shots.removeWhere(
      (file, _) =>
          !expected.contains(file) || !File('$uxRoot/$key/$file').existsSync(),
    );
    final ordered = [
      for (final file in expected)
        if (_shots.containsKey(file)) _shots[file]!,
    ];
    _manifest.writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({
        'area': key,
        'title': title,
        'shots': ordered,
      }),
    );
  }
}

/// The areas this suite defines, in order, for the report.
Map<String, String> get areaTitles => Map.unmodifiable(_areaTitles);
