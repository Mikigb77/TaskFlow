// P20 (UX-121, UX-119, UX-125, UX-420): the words and icons Android and iOS
// show outside the app — launcher shortcuts, the widget picker, share
// toasts and the microphone prompt. Checked in the resource files, since no
// widget test can render them; a phone still has to show them.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

/// The `<string>` values of one Android strings.xml, by name, unescaped as
/// Android reads them.
Map<String, String> _strings(String folder) {
  final xml = File('$_res/$folder/strings.xml').readAsStringSync();
  return {
    for (final match in RegExp(
      r'<string name="([^"]+)"[^>]*>([\s\S]*?)</string>',
    ).allMatches(xml))
      match[1]!: match[2]!
          .replaceAll(r"\'", "'")
          .replaceAll(r'\"', '"')
          .replaceAll('&amp;', '&'),
  };
}

/// NSMicrophoneUsageDescription in one InfoPlist.strings.
String _microphone(String language) {
  final text = File(
    'ios/Runner/$language.lproj/InfoPlist.strings',
  ).readAsStringSync();
  return RegExp(
    r'"NSMicrophoneUsageDescription"\s*=\s*"([^"]*)";',
  ).firstMatch(text)![1]!;
}

/// The bounds, in viewport units, of every point an Android path names: end
/// points and control points (a Bézier curve stays inside its control points'
/// hull, so these bounds contain the drawing).
({double left, double top, double right, double bottom}) _pathBounds(
  String data,
) {
  final tokens = RegExp(
    r'[MmLlHhVvCcSsQqTtAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?',
  ).allMatches(data).map((m) => m[0]!).toList();
  var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;
  final xs = <double>[], ys = <double>[];
  void point(double px, double py) {
    xs.add(px);
    ys.add(py);
  }

  var i = 0;
  var command = '';
  bool isCommand(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (isCommand(tokens[i])) command = tokens[i++];
    final relative = command == command.toLowerCase();
    final ox = relative ? x : 0.0, oy = relative ? y : 0.0;
    switch (command.toUpperCase()) {
      case 'Z':
        x = startX;
        y = startY;
        continue;
      case 'M':
        x = ox + next();
        y = oy + next();
        startX = x;
        startY = y;
        point(x, y);
        // Further pairs after a moveto are linetos.
        command = relative ? 'l' : 'L';
      case 'L':
      case 'T':
        x = ox + next();
        y = oy + next();
        point(x, y);
      case 'H':
        x = ox + next();
        point(x, y);
      case 'V':
        y = oy + next();
        point(x, y);
      case 'C':
        for (var k = 0; k < 2; k++) {
          point(ox + next(), oy + next());
        }
        x = ox + next();
        y = oy + next();
        point(x, y);
      case 'S':
      case 'Q':
        point(ox + next(), oy + next());
        x = ox + next();
        y = oy + next();
        point(x, y);
      case 'A':
        final rx = next(), ry = next();
        next();
        next();
        next();
        x = ox + next();
        y = oy + next();
        // An arc can bulge by its radius beyond its end points.
        point(x - rx, y - ry);
        point(x + rx, y + ry);
      default:
        fail('unknown path command `$command` in $data');
    }
  }
  return (
    left: xs.reduce(math.min),
    top: ys.reduce(math.min),
    right: xs.reduce(math.max),
    bottom: ys.reduce(math.max),
  );
}

typedef _Vector = ({
  String xml,
  String width,
  String height,
  double viewportWidth,
  double viewportHeight,
  List<String> paths,
  List<String> fills,
});

/// One vector drawable's size, viewport, path data and colours.
_Vector _vector(String name) {
  final file = File('$_res/drawable/$name.xml');
  expect(file.existsSync(), isTrue, reason: '$name.xml exists');
  final xml = file.readAsStringSync();
  String attribute(String name) =>
      RegExp('android:$name="([^"]+)"').firstMatch(xml)![1]!;
  return (
    xml: xml,
    width: attribute('width'),
    height: attribute('height'),
    viewportWidth: double.parse(attribute('viewportWidth')),
    viewportHeight: double.parse(attribute('viewportHeight')),
    paths: [
      for (final m in RegExp(r'android:pathData="([^"]+)"').allMatches(xml))
        m[1]!,
    ],
    fills: [
      for (final m in RegExp(
        r'android:(?:fillColor|strokeColor)="([^"]+)"',
      ).allMatches(xml))
        m[1]!,
    ],
  );
}

void main() {
  final en = _strings('values');
  final es = _strings('values-es');
  final ca = _strings('values-ca');

  test(
    'UX-121: the widget picker says Toca para dictar una tarea. in EN, ES and CA',
    () {
      expect(en['capture_widget_description'], 'Tap to dictate a task.');
      expect(es['capture_widget_description'], 'Toca para dictar una tarea.');
      expect(ca['capture_widget_description'], 'Toca per dictar una tasca.');
      for (final strings in [en, es, ca]) {
        final description = strings['capture_widget_description']!;
        expect(description, isNot(contains('captur')));
        expect(description, isNot(contains('retained')));
      }
    },
  );

  test(
    'UX-121: the shortcuts read Dictar una tarea / Escribir una tarea, matching the app',
    () {
      expect(en['capture_voice'], 'Dictate a task');
      expect(es['capture_voice'], 'Dictar una tarea');
      expect(ca['capture_voice'], 'Dicta una tasca');
      expect(es['capture_text'], 'Escribir una tarea');
      for (final strings in [en, es, ca]) {
        expect(strings['capture_text'], isNotNull);
        expect(strings['capture_text'], isNotEmpty);
      }
    },
  );

  test(
    'UX-119: the three share messages exist in EN, ES and CA with the agreed copy',
    () {
      final names = ['share_too_long', 'share_queue_full', 'share_not_saved'];
      for (final strings in [en, es, ca]) {
        expect(strings.keys, containsAll(names));
      }
      expect(
        en['share_too_long'],
        'That text is too long. Share a shorter one.',
      );
      expect(
        es['share_too_long'],
        'Texto demasiado largo. Comparte uno más corto.',
      );
      expect(
        ca['share_too_long'],
        'Text massa llarg. Comparteix-ne un de més curt.',
      );
      expect(
        en['share_queue_full'],
        'Open TaskFlow and finish what you shared.',
      );
      expect(
        es['share_queue_full'],
        'Abre TaskFlow y acaba lo que ya has compartido.',
      );
      expect(
        ca['share_queue_full'],
        'Obre TaskFlow i acaba el que ja has compartit.',
      );
      // The catalogs write the apostrophe as ’.
      expect(
        en['share_not_saved']!.replaceAll('’', "'"),
        "Couldn't save it. Please share it again.",
      );
      expect(
        es['share_not_saved'],
        'No se ha podido guardar. Vuelve a compartirlo.',
      );
      expect(
        ca['share_not_saved'],
        'No s’ha pogut desar. Torna-ho a compartir.',
      );
    },
  );

  test(
    'UX-119: CaptureEntryBridge.kt shows its toasts from resources, with no hard-coded text',
    () {
      final kotlin = File(
        'android/app/src/main/kotlin/com/example/agenda/CaptureEntryBridge.kt',
      ).readAsStringSync();
      final toasts = RegExp(
        r'Toast\.makeText\(\s*[^,]+,\s*([^,]+),',
      ).allMatches(kotlin).map((match) => match[1]!.trim()).toList();
      expect(toasts, hasLength(4));
      expect(toasts, [
        'R.string.share_empty',
        'R.string.share_too_long',
        'R.string.share_queue_full',
        'R.string.share_not_saved',
      ]);
      for (final english in [
        'Share between',
        'pending captures',
        'Could not retain',
      ]) {
        expect(kotlin, isNot(contains(english)));
      }
    },
  );

  test(
    'UX-125: the shortcuts point at a microphone and a pencil drawable, which are vector XML',
    () {
      // Published from code (CaptureShortcuts.kt): a static shortcuts.xml can't name the
      // package of each build, so its shortcuts never started.
      final shortcuts = File(
        'android/app/src/main/kotlin/com/example/agenda/CaptureShortcuts.kt',
      ).readAsStringSync();
      String iconOf(String id) => RegExp(
        '"$id",(?:\\s*R\\.string\\.[a-z_]+,)+\\s*R\\.drawable\\.([a-z_]+)',
      ).firstMatch(shortcuts)![1]!;
      expect(iconOf('capture_voice'), 'capture_shortcut_voice');
      expect(iconOf('capture_text'), 'capture_shortcut_text');
      expect(shortcuts, isNot(contains('R.drawable.app_icon')));
      expect(File('$_res/xml/capture_shortcuts.xml').existsSync(), isFalse);
      for (final name in ['capture_shortcut_voice', 'capture_shortcut_text']) {
        final file = File('$_res/drawable/$name.xml');
        expect(file.existsSync(), isTrue, reason: name);
        final xml = file.readAsStringSync().trim();
        expect(
          xml,
          startsWith(
            '<vector xmlns:android="http://schemas.android.com/apk/res/android"',
          ),
          reason: name,
        );
        expect(xml, endsWith('</vector>'), reason: name);
        for (final attribute in [
          'android:width',
          'android:height',
          'android:viewportWidth',
          'android:viewportHeight',
        ]) {
          expect(xml, contains('$attribute="'), reason: '$name $attribute');
        }
        final paths = RegExp(
          r'<path\s[^>]*android:pathData="([^"]+)"[^>]*/>',
        ).allMatches(xml).toList();
        // The light circle and the symbol.
        expect(paths.length, greaterThanOrEqualTo(2), reason: name);
        for (final path in paths) {
          expect(
            path[1],
            matches(RegExp(r'^[MmLlHhVvCcSsQqTtAaZz0-9.,\s-]+$')),
          );
        }
        // Every opened tag is closed.
        final opened = RegExp(r'<(vector|group)\b').allMatches(xml).length;
        final closed = RegExp(r'</(vector|group)>').allMatches(xml).length;
        expect(opened, closed, reason: name);
      }
    },
  );

  test(
    'UX-420: the iOS microphone prompt says TaskFlow listens only while you use the microphone, in EN, ES and CA',
    () {
      const english =
          'TaskFlow listens only while you use the microphone, so you can say a task instead of typing it.';
      expect(_microphone('en'), english);
      expect(
        _microphone('es'),
        'TaskFlow solo escucha mientras usas el micrófono, para que puedas dictar una tarea en lugar de escribirla.',
      );
      expect(
        _microphone('ca'),
        'TaskFlow només escolta mentre fas servir el micròfon, perquè puguis dictar una tasca en lloc d’escriure-la.',
      );
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(
        RegExp(
          r'<key>NSMicrophoneUsageDescription</key>\s*<string>([^<]*)</string>',
        ).firstMatch(plist)![1],
        english,
      );
      for (final language in ['en', 'es', 'ca']) {
        expect(_microphone(language), isNot(contains('draft')));
        expect(_microphone(language), isNot(contains('borrador')));
        expect(_microphone(language), isNot(contains('esborrany')));
      }
    },
  );

  // ---- P84 (UX-494): an empty share says there's no text ----

  test(
    'UX-494: share_empty exists in values, values-es and values-ca with the agreed copy',
    () {
      expect(en['share_empty'], 'No text to add.');
      expect(es['share_empty'], 'No hay texto que añadir.');
      expect(ca['share_empty'], 'No hi ha cap text per afegir.');
      // Not the too-long message, in any language.
      for (final strings in [en, es, ca]) {
        expect(strings['share_empty'], isNot(strings['share_too_long']));
        expect(strings['share_empty'], isNot(contains('4')));
      }
      // A straight apostrophe must be escaped for Android; none is left raw.
      for (final folder in ['values', 'values-es', 'values-ca']) {
        final xml = File('$_res/$folder/strings.xml').readAsStringSync();
        final line = RegExp(
          r'<string name="share_empty"[^>]*>([\s\S]*?)</string>',
        ).firstMatch(xml)![1]!;
        expect(RegExp(r"(?<!\\)'").hasMatch(line), isFalse, reason: folder);
      }
    },
  );

  test(
    'UX-494: CaptureEntryBridge.kt shows share_empty for an empty share and share_too_long only for one over 4,000 characters',
    () {
      final kotlin = File(
        'android/app/src/main/kotlin/com/example/agenda/CaptureEntryBridge.kt',
      ).readAsStringSync();
      // Each `if (…) { Toast.makeText(…, R.string.x, …) … return }` branch.
      final branches = {
        for (final match in RegExp(
          r'if\s*\(([^{]*)\)\s*\{\s*Toast\.makeText\(\s*[^,]+,\s*R\.string\.(\w+),[^\n]*\n\s*return\b',
        ).allMatches(kotlin))
          match[2]!: match[1]!.replaceAll(RegExp(r'\s+'), ' ').trim(),
      };
      expect(branches.keys, containsAll(['share_empty', 'share_too_long']));
      expect(branches['share_empty'], contains('text.isEmpty()'));
      expect(branches['share_empty'], isNot(contains('4000')));
      expect(branches['share_too_long'], contains('text.length > 4000'));
      expect(branches['share_too_long'], isNot(contains('isEmpty')));
      // Each message is shown in one place only.
      expect(
        RegExp(r'R\.string\.share_empty').allMatches(kotlin),
        hasLength(1),
      );
      expect(
        RegExp(r'R\.string\.share_too_long').allMatches(kotlin),
        hasLength(1),
      );
    },
  );

  // ---- P186 (UX-1316, UX-1319, UX-1621): whole words at large text, short
  // share messages, the app's language ----

  test(
    'UX-1316: the shortcuts have one-word short labels Dictar / Escribir, at most 10 characters',
    () {
      expect(en['capture_voice_short'], 'Dictate');
      expect(en['capture_text_short'], 'Type');
      expect(es['capture_voice_short'], 'Dictar');
      expect(es['capture_text_short'], 'Escribir');
      expect(ca['capture_voice_short'], 'Dicta');
      expect(ca['capture_text_short'], 'Escriu');
      for (final strings in [en, es, ca]) {
        for (final name in ['capture_voice_short', 'capture_text_short']) {
          final label = strings[name]!;
          expect(label.length, lessThanOrEqualTo(10), reason: name);
          expect(label, isNot(contains(' ')), reason: '$name is one word');
        }
        // The long labels stay as they were.
        expect(strings['capture_voice'], isNotEmpty);
        expect(strings['capture_text'], isNotEmpty);
      }
      // Translators are told the limits (PL-9).
      for (final folder in ['values', 'values-es', 'values-ca']) {
        final xml = File('$_res/$folder/strings.xml').readAsStringSync();
        for (final name in ['capture_voice_short', 'capture_text_short']) {
          expect(
            RegExp(
              '<!--[^>]*10[^>]*-->${r'\s*'}<string name="$name"',
            ).hasMatch(xml),
            isTrue,
            reason: '$folder $name has a translator comment with its limit',
          );
        }
      }
    },
  );

  test(
    'UX-1316: CaptureShortcuts sets the short label and the long label on both shortcuts',
    () {
      final kotlin = File(
        'android/app/src/main/kotlin/com/example/agenda/CaptureShortcuts.kt',
      ).readAsStringSync();
      final calls = {
        for (final match in RegExp(
          r'"(capture_voice|capture_text)",\s*R\.string\.(\w+),\s*R\.string\.(\w+),',
        ).allMatches(kotlin))
          match[1]!: [match[2]!, match[3]!],
      };
      expect(calls['capture_voice'], ['capture_voice_short', 'capture_voice']);
      expect(calls['capture_text'], ['capture_text_short', 'capture_text']);
      expect(
        RegExp(
          r'\.setShortLabel\(\s*context\.getString\(\s*shortLabel\s*\)\s*\)',
        ).hasMatch(kotlin),
        isTrue,
      );
      expect(
        RegExp(
          r'\.setLongLabel\(\s*context\.getString\(\s*longLabel\s*\)\s*\)',
        ).hasMatch(kotlin),
        isTrue,
      );
    },
  );

  test(
    'UX-1316: the widget has a 24 dp mic, 6 dp padding and a label that auto-sizes from 9 to 12 sp on at most 2 lines',
    () {
      final xml = File('$_res/layout/capture_widget.xml').readAsStringSync();
      final root = RegExp(r'<LinearLayout\b[^>]*>').firstMatch(xml)![0]!;
      expect(root, contains('android:orientation="vertical"'));
      expect(root, contains('android:padding="6dp"'));
      final image = RegExp(r'<ImageView\b[^>]*/>').firstMatch(xml)![0]!;
      expect(image, contains('android:layout_width="24dp"'));
      expect(image, contains('android:layout_height="24dp"'));
      final label = RegExp(r'<TextView\b[^>]*/>').firstMatch(xml)![0]!;
      expect(label, contains('android:text="@string/capture_widget_label"'));
      expect(label, contains('android:layout_width="match_parent"'));
      expect(label, contains('android:layout_height="0dp"'));
      expect(label, contains('android:layout_weight="1"'));
      expect(label, contains('android:autoSizeTextType="uniform"'));
      expect(label, contains('android:autoSizeMinTextSize="9sp"'));
      expect(label, contains('android:autoSizeMaxTextSize="12sp"'));
      expect(label, contains('android:maxLines="2"'));
      // API 24-25 keep today's 12 sp.
      expect(label, contains('android:textSize="12sp"'));
    },
  );

  test(
    'UX-1319: the four share messages are at most 50 characters in EN, ES and CA',
    () {
      for (final entry in {'en': en, 'es': es, 'ca': ca}.entries) {
        for (final name in [
          'share_too_long',
          'share_empty',
          'share_queue_full',
          'share_not_saved',
        ]) {
          final text = entry.value[name];
          expect(text, isNotNull, reason: '${entry.key} $name');
          expect(
            text!.length,
            lessThanOrEqualTo(50),
            reason: '${entry.key} $name: "$text"',
          );
        }
      }
    },
  );

  test(
    'UX-1621: the activity keeps locale in configChanges, and a language change republishes the shortcuts and redraws the widget',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final changes = RegExp(
        r'android:configChanges="([^"]+)"',
      ).firstMatch(manifest)![1]!.split('|');
      expect(changes, contains('locale'));
      final activity = File(
        'android/app/src/main/kotlin/com/example/agenda/MainActivity.kt',
      ).readAsStringSync();
      final onChange = RegExp(
        r'override fun onConfigurationChanged\([^)]*\)\s*\{([\s\S]*?)\n    \}',
      ).firstMatch(activity);
      expect(onChange, isNotNull);
      expect(onChange![1], contains('CaptureShortcuts.publish(this)'));
      expect(onChange[1], contains('CaptureWidget.refresh(this)'));
      final bridge = File(
        'android/app/src/main/kotlin/com/example/agenda/AppLanguageBridge.kt',
      ).readAsStringSync();
      expect(bridge, contains('"taskflow/app-language"'));
      expect(bridge, contains('applicationLocales'));
      expect(bridge, contains('Build.VERSION_CODES.TIRAMISU'));
    },
  );

  // ---- Run 2026-10-19-app · P195 (UX-1608): the launcher icon is the
  // in-app mark, adaptive, with a themed-icon layer ----

  test(
    'UX-1608: the manifest icon is @mipmap/ic_launcher, an adaptive icon with background, foreground and monochrome layers on #146C5C',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final application = RegExp(
        r'<application\b[^>]*>',
      ).firstMatch(manifest)![0]!;
      expect(
        RegExp(r'android:icon="([^"]+)"').firstMatch(application)?[1],
        '@mipmap/ic_launcher',
      );
      final file = File('$_res/mipmap-anydpi-v26/ic_launcher.xml');
      expect(file.existsSync(), isTrue);
      final xml = file.readAsStringSync();
      expect(xml, contains('<adaptive-icon'));
      expect(xml, contains('</adaptive-icon>'));
      String layer(String tag) {
        final match = RegExp(
          '<$tag\\s[^>]*android:drawable="([^"]+)"',
        ).firstMatch(xml);
        expect(match, isNotNull, reason: 'the icon has a <$tag> layer');
        return match![1]!;
      }

      expect(layer('foreground'), '@drawable/ic_launcher_foreground');
      expect(layer('monochrome'), '@drawable/ic_launcher_monochrome');
      // The background is #146C5C, the light theme's primary, as a colour
      // resource or written in place.
      var colour = layer('background');
      if (colour.startsWith('@color/')) {
        final name = colour.substring('@color/'.length);
        final values = Directory('$_res/values')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.xml'))
            .map((f) => f.readAsStringSync())
            .join('\n');
        final match = RegExp(
          '<color name="$name">([^<]+)</color>',
        ).firstMatch(values);
        expect(match, isNotNull, reason: '@color/$name is defined');
        colour = match![1]!.trim();
      }
      expect(
        colour.toUpperCase(),
        anyOf('#146C5C', '#FF146C5C'),
        reason: 'the icon background is the in-app mark’s teal',
      );
    },
  );

  test(
    'UX-1608: both icon layers are 108 × 108 dp ticks drawn inside the central 66 dp (21–87 dp), at the in-app mark’s size',
    () {
      final foreground = _vector('ic_launcher_foreground');
      final monochrome = _vector('ic_launcher_monochrome');
      for (final (name, layer) in [
        ('foreground', foreground),
        ('monochrome', monochrome),
      ]) {
        expect(layer.width, '108dp', reason: name);
        expect(layer.height, '108dp', reason: name);
        expect(layer.paths, isNotEmpty, reason: name);
        expect(
          layer.xml,
          isNot(contains('<group')),
          reason: '$name: no transform moves the drawing',
        );
        // Viewport units to dp.
        final sx = 108 / layer.viewportWidth;
        final sy = 108 / layer.viewportHeight;
        var left = double.infinity, top = double.infinity;
        var right = -double.infinity, bottom = -double.infinity;
        for (final path in layer.paths) {
          final b = _pathBounds(path);
          left = math.min(left, b.left * sx);
          top = math.min(top, b.top * sy);
          right = math.max(right, b.right * sx);
          bottom = math.max(bottom, b.bottom * sy);
        }
        final reason = '$name draws x $left–$right, y $top–$bottom dp';
        expect(left, greaterThanOrEqualTo(21), reason: reason);
        expect(top, greaterThanOrEqualTo(21), reason: reason);
        expect(right, lessThanOrEqualTo(87), reason: reason);
        expect(bottom, lessThanOrEqualTo(87), reason: reason);
        // Not a small mark lost in the icon (the finding's 26 of 61 dp): the
        // double tick spans most of the safe zone, centred.
        expect(right - left, greaterThanOrEqualTo(40), reason: reason);
        expect(((left + right) / 2 - 54).abs(), lessThan(3), reason: reason);
        expect(((top + bottom) / 2 - 54).abs(), lessThan(3), reason: reason);
      }
      // The foreground's tick is white on the teal.
      expect(foreground.fills, isNotEmpty);
      for (final fill in foreground.fills) {
        expect(fill.toUpperCase(), anyOf('#FFFFFF', '#FFFFFFFF'));
      }
      // The themed icon is the same tick.
      expect(monochrome.paths, foreground.paths);
    },
  );

  test(
    'UX-1608: nothing names app_icon; app_icon.png and the nested drawable-*dpi folders are gone',
    () {
      expect(File('$_res/drawable/app_icon.png').existsSync(), isFalse);
      final nested = Directory(
        '$_res/drawable',
      ).listSync().whereType<Directory>().map((d) => d.path).toList();
      expect(nested, isEmpty, reason: 'Android never reads $nested');
      final named = <String>[];
      for (final root in ['android/app/src', 'lib']) {
        for (final entity in Directory(root).listSync(recursive: true)) {
          if (entity is! File) continue;
          final path = entity.path.replaceAll(r'\', '/');
          if (RegExp(r'/app_icon\.[a-z]+$').hasMatch(path)) named.add(path);
          if (!RegExp(r'\.(dart|kt|kts|java|xml|gradle)$').hasMatch(path)) {
            continue;
          }
          if (RegExp(r'\bapp_icon\b').hasMatch(entity.readAsStringSync())) {
            named.add(path);
          }
        }
      }
      expect(named, isEmpty, reason: 'these still name app_icon: $named');
    },
  );

  testWidgets(
    'UX-1608: the legacy ic_launcher.png at every density is the teal mark with the white tick, not Flutter’s logo',
    (tester) async {
      const sizes = {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      };
      for (final MapEntry(key: density, value: side) in sizes.entries) {
        final file = File('$_res/mipmap-$density/ic_launcher.png');
        expect(file.existsSync(), isTrue, reason: density);
        final bytes = file.readAsBytesSync();
        final decoded = await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          final image = frame.image;
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          );
          final result = (image.width, image.height, data!);
          image.dispose();
          codec.dispose();
          return result;
        });
        final (width, height, data) = decoded!;
        expect(width, side, reason: '$density width');
        expect(height, side, reason: '$density height');
        var opaque = 0, teal = 0, white = 0, centreWhite = 0;
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final o = (y * width + x) * 4;
            final r = data.getUint8(o), g = data.getUint8(o + 1);
            final b = data.getUint8(o + 2), a = data.getUint8(o + 3);
            if (a < 250) continue;
            opaque++;
            if ((r - 0x14).abs() <= 12 &&
                (g - 0x6C).abs() <= 12 &&
                (b - 0x5C).abs() <= 12) {
              teal++;
            }
            if (r >= 245 && g >= 245 && b >= 245) {
              white++;
              if ((x - width / 2).abs() < width / 3 &&
                  (y - height / 2).abs() < height / 3) {
                centreWhite++;
              }
            }
          }
        }
        final reason =
            '$density: $opaque opaque px, $teal teal, $white white '
            '($centreWhite in the centre)';
        // A filled teal square: most of the icon is #146C5C.
        expect(opaque, greaterThan(width * height * 0.6), reason: reason);
        expect(teal, greaterThan(opaque * 0.6), reason: reason);
        // The white tick, in the middle.
        expect(white, greaterThan(width * height * 0.015), reason: reason);
        expect(centreWhite, greaterThan(white * 0.9), reason: reason);
      }
    },
  );

  test(
    'UX-1608: app_notifications_icon is a white 24 dp vector, and the notification service uses it, also as the default icon',
    () {
      final icon = _vector('app_notifications_icon');
      expect(icon.xml, contains('<vector'));
      expect(icon.width, '24dp');
      expect(icon.height, '24dp');
      expect(icon.paths, isNotEmpty);
      expect(icon.fills, isNotEmpty);
      for (final fill in icon.fills) {
        expect(fill.toUpperCase(), anyOf('#FFFFFF', '#FFFFFFFF'));
      }
      final b = _pathBounds(icon.paths.join(' '));
      expect(b.left, greaterThanOrEqualTo(0));
      expect(b.top, greaterThanOrEqualTo(0));
      expect(b.right, lessThanOrEqualTo(icon.viewportWidth));
      expect(b.bottom, lessThanOrEqualTo(icon.viewportHeight));
      // No bitmap of the old «M» notepad shadows the vector at any density.
      final bitmaps = Directory(_res)
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where(
            (p) =>
                RegExp(r'/app_notifications_icon\.(png|webp|jpg)$').hasMatch(p),
          )
          .toList();
      expect(bitmaps, isEmpty);

      final service = File(
        'lib/services/notification_service.dart',
      ).readAsStringSync();
      final defaults = RegExp(
        r"AndroidInitializationSettings\(\s*'([^']+)'\s*\)",
      ).allMatches(service).map((m) => m[1]).toList();
      expect(defaults, isNotEmpty);
      expect(defaults, everyElement('app_notifications_icon'));
      final icons = RegExp(
        r"icon:\s*'([^']+)'",
      ).allMatches(service).map((m) => m[1]).toList();
      expect(icons, isNotEmpty);
      expect(icons, everyElement('app_notifications_icon'));
    },
  );

  // ---- Run 2026-10-19-app · P221 (UX-1656): English shortcuts fall back to
  // their one-word labels at large text ----

  test(
    'UX-1656, UX-1658: each English long shortcut label is 13-16 characters or its short label, and the short labels are one word',
    () {
      expect(en['capture_voice_short'], 'Dictate');
      expect(en['capture_text_short'], 'Type');
      for (final (long, short) in [
        ('capture_voice', 'capture_voice_short'),
        ('capture_text', 'capture_text_short'),
      ]) {
        final longLabel = en[long]!;
        final shortLabel = en[short]!;
        expect(
          shortLabel,
          matches(RegExp(r'^\S+$')),
          reason: '$short is one word',
        );
        // The Pixel Launcher keeps a long label it thinks fits, without the
        // pin button beside it, and cuts it. On the emulator (2026-10-21):
        // 10-11 characters were cut at 2.0 («Say a ta…»), 18 were cut at 1.0
        // («Dictate a new ta…»), and 15 («Type a new task») read whole at 1.0
        // and fell back to «Type» at 2.0.
        expect(
          (longLabel.length >= 13 && longLabel.length <= 16) ||
              longLabel == shortLabel,
          isTrue,
          reason:
              '$long "$longLabel" is ${longLabel.length} characters: the '
              'Pixel Launcher shows it cut at 1.0 or 2.0 instead of whole, '
              'or of falling back to "$shortLabel"',
        );
        expect(longLabel.trim(), longLabel);
        expect(longLabel, isNot(contains('  ')));
      }
    },
  );

  test(
    'UX-1656: the Spanish and Catalan shortcut labels and widget are unchanged; the English widget reads Dictate a task on every surface',
    () {
      expect(es['capture_voice'], 'Dictar una tarea');
      expect(es['capture_text'], 'Escribir una tarea');
      expect(ca['capture_voice'], 'Dicta una tasca');
      expect(ca['capture_text'], 'Escriu una tasca');
      expect(es['capture_voice_short'], 'Dictar');
      expect(ca['capture_voice_short'], 'Dicta');
      expect(es['capture_text_short'], 'Escribir');
      expect(ca['capture_text_short'], 'Escriu');
      expect(en['capture_widget_description'], 'Tap to dictate a task.');
      expect(es['capture_widget_description'], 'Toca para dictar una tarea.');
      expect(ca['capture_widget_description'], 'Toca per dictar una tasca.');

      // Whatever string each widget surface names, it reads Dictate a task
      // in English and as before in Spanish and Catalan.
      final layout = File('$_res/layout/capture_widget.xml').readAsStringSync();
      final text = RegExp(
        r'<TextView\b[^>]*android:text="@string/(\w+)"',
      ).firstMatch(layout)![1]!;
      final description = RegExp(
        r'<LinearLayout\b[^>]*android:contentDescription="@string/(\w+)"',
      ).firstMatch(layout)![1]!;
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final picker = RegExp(
        r'<receiver\s+android:name="\.CaptureWidget"[^>]*android:label="@string/(\w+)"',
      ).firstMatch(manifest)![1]!;
      final kotlin = File(
        'android/app/src/main/kotlin/com/example/agenda/CaptureWidget.kt',
      ).readAsStringSync();
      final runtime = RegExp(
        r'val label = [^\n]*getString\(R\.string\.(\w+)\)',
      ).firstMatch(kotlin)![1]!;
      for (final (surface, name) in [
        ('widget label', text),
        ('widget TalkBack name', description),
        ('widget picker name', picker),
        ('widget label on Android 13+', runtime),
      ]) {
        expect(
          en[name],
          'Dictate a task',
          reason: 'EN $surface (@string/$name)',
        );
        expect(es[name], 'Dictar una tarea', reason: 'ES $surface');
        expect(ca[name], 'Dicta una tasca', reason: 'CA $surface');
      }
    },
  );
  // ---- Run 2026-10-19-app round 2 · P222 (UX-1656): the widget gets its own
  // string; UX-1658 then made the English voice shortcut “Dictate a task” ----

  test(
    'UX-1656, UX-1658: the English shortcuts read Dictate a task / Type a new task: the voice one is the widget label, and each fits the launcher at 1.0 and falls back at 2.0',
    () {
      expect(en['capture_voice'], 'Dictate a task');
      expect(en['capture_voice'], en['capture_widget_label']);
      expect(en['capture_text'], 'Type a new task');
      expect(en['capture_voice_short'], 'Dictate');
      expect(en['capture_text_short'], 'Type');
      for (final name in ['capture_voice', 'capture_text']) {
        expect(en[name]!.length, inInclusiveRange(13, 16), reason: name);
        // Each long label starts with its short label, so both name the
        // same action.
        expect(en[name], startsWith(en['${name}_short']!), reason: name);
      }
    },
  );

  test(
    'UX-1656: capture_widget_label reads Dictate a task / Dictar una tarea / Dicta una tasca, with a translator comment, after capture_text_short',
    () {
      expect(en['capture_widget_label'], 'Dictate a task');
      expect(es['capture_widget_label'], 'Dictar una tarea');
      expect(ca['capture_widget_label'], 'Dicta una tasca');
      for (final folder in ['values', 'values-es', 'values-ca']) {
        final xml = File('$_res/$folder/strings.xml').readAsStringSync();
        expect(
          RegExp(
            r'<!--[^>]*80 dp[^>]*20[^>]*-->\s*<string name="capture_widget_label"',
          ).hasMatch(xml),
          isTrue,
          reason:
              '$folder capture_widget_label has a translator comment '
              'with its limit',
        );
        final textShort = xml.indexOf('<string name="capture_text_short"');
        final label = xml.indexOf('<string name="capture_widget_label"');
        final description = xml.indexOf(
          '<string name="capture_widget_description"',
        );
        expect(textShort, greaterThanOrEqualTo(0), reason: folder);
        expect(label, greaterThan(textShort), reason: folder);
        expect(description, greaterThan(label), reason: folder);
      }
    },
  );

  test(
    'UX-1656: every widget surface names capture_widget_label and none names capture_voice; only the voice shortcut does',
    () {
      final layout = File('$_res/layout/capture_widget.xml').readAsStringSync();
      final root = RegExp(r'<LinearLayout\b[^>]*>').firstMatch(layout)![0]!;
      expect(
        root,
        contains('android:contentDescription="@string/capture_widget_label"'),
      );
      final label = RegExp(r'<TextView\b[^>]*/>').firstMatch(layout)![0]!;
      expect(label, contains('android:text="@string/capture_widget_label"'));
      // The view id keeps its name.
      expect(label, contains('android:id="@+id/capture_widget_label"'));
      expect(layout, isNot(contains('@string/capture_voice')));

      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final receiver = RegExp(
        r'<receiver\s+android:name="\.CaptureWidget"[^>]*>',
      ).firstMatch(manifest)![0]!;
      expect(
        receiver,
        contains('android:label="@string/capture_widget_label"'),
      );
      expect(manifest, isNot(contains('@string/capture_voice')));

      final widget = File(
        'android/app/src/main/kotlin/com/example/agenda/CaptureWidget.kt',
      ).readAsStringSync();
      expect(
        RegExp(
          r'val label = if \(Build\.VERSION\.SDK_INT >= Build\.VERSION_CODES\.TIRAMISU\) '
          r'context\.getString\(R\.string\.capture_widget_label\) else null',
        ).hasMatch(widget),
        isTrue,
        reason: 'Android 13+ reads the widget label in the app’s language',
      );
      expect(widget, isNot(matches(RegExp(r'R\.string\.capture_voice\b'))));

      // Across the native code, only CaptureShortcuts names capture_voice,
      // as the voice shortcut's long label.
      final users = <String>[
        for (final file in Directory(
          'android/app/src/main/kotlin',
        ).listSync(recursive: true).whereType<File>())
          if (RegExp(
            r'R\.string\.capture_voice\b',
          ).hasMatch(file.readAsStringSync()))
            file.uri.pathSegments.last,
      ];
      expect(users, ['CaptureShortcuts.kt']);
    },
  );

  // ---- Run 2026-10-19-app round 3 · P223 (UX-1657): the English widget
  // reads “Dictate a task”, like the voice shortcut and the app ----

  Map<String, dynamic> arb(String language) =>
      jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
          as Map<String, dynamic>;

  test(
    'UX-1657: capture_widget_label is Dictate a task (at most 20 characters), after its translator comment, and the picker line is Tap to dictate a task.',
    () {
      expect(en['capture_widget_label'], 'Dictate a task');
      expect(en['capture_widget_label']!.length, lessThanOrEqualTo(20));
      expect(en['capture_widget_description'], 'Tap to dictate a task.');
      final xml = File('$_res/values/strings.xml').readAsStringSync();
      expect(
        RegExp(
          r'<string name="capture_text_short">[^<]*</string>\s*'
          r'<!--[^>]*-->\s*'
          r'<string name="capture_widget_label">[^<]*</string>\s*'
          r'<string name="capture_widget_description">',
        ).hasMatch(xml),
        isTrue,
        reason:
            'capture_text_short, the translator comment, '
            'capture_widget_label, capture_widget_description, in that order',
      );
    },
  );

  test(
    'UX-1657: in English the voice shortcut, its short label and the widget all start with Dictate, and no English Android string says “say a task”',
    () {
      expect(en['capture_voice'], 'Dictate a task');
      expect(en['capture_voice_short'], 'Dictate');
      for (final name in [
        'capture_voice',
        'capture_voice_short',
        'capture_widget_label',
      ]) {
        expect(en[name], startsWith('Dictate'), reason: name);
      }
      expect(en['capture_widget_description'], contains('dictate'));
      for (final entry in en.entries) {
        expect(
          entry.value.toLowerCase(),
          isNot(contains('say a task')),
          reason: entry.key,
        );
      }
    },
  );

  test(
    'UX-1657: every widget surface reads Dictate a task / Dictar una tarea / Dicta una tasca',
    () {
      final layout = File('$_res/layout/capture_widget.xml').readAsStringSync();
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final widget = File(
        'android/app/src/main/kotlin/com/example/agenda/CaptureWidget.kt',
      ).readAsStringSync();
      final root = RegExp(r'<LinearLayout\b[^>]*>').firstMatch(layout)![0]!;
      final text = RegExp(r'<TextView\b[^>]*/>').firstMatch(layout)![0]!;
      final receiver = RegExp(
        r'<receiver\s+android:name="\.CaptureWidget"[^>]*>',
      ).firstMatch(manifest)![0]!;
      final names = {
        'layout contentDescription': RegExp(
          r'android:contentDescription="@string/([a-z_]+)"',
        ).firstMatch(root)![1]!,
        'layout text': RegExp(
          r'android:text="@string/([a-z_]+)"',
        ).firstMatch(text)![1]!,
        'receiver label': RegExp(
          r'android:label="@string/([a-z_]+)"',
        ).firstMatch(receiver)![1]!,
        'CaptureWidget.kt getString': RegExp(
          r'context\.getString\(R\.string\.([a-z_]+)\)',
        ).firstMatch(widget)![1]!,
      };
      for (final MapEntry(key: surface, value: name) in names.entries) {
        expect(name, 'capture_widget_label', reason: surface);
        expect(en[name], 'Dictate a task', reason: 'EN $surface');
        expect(es[name], 'Dictar una tarea', reason: 'ES $surface');
        expect(ca[name], 'Dicta una tasca', reason: 'CA $surface');
      }
    },
  );

  test(
    'UX-1657: Settings, Other, in English names the widget by its label: homeCaptureInstructions reads the Dictate a task widget, and has an @ description',
    () {
      final catalog = arb('en');
      expect(
        catalog['homeCaptureInstructions'],
        'On Android, long-press the TaskFlow icon for its shortcuts, or add '
        'the ${en['capture_widget_label']} widget from your launcher. Share '
        'text to TaskFlow from another app.',
      );
      expect(
        catalog['homeCaptureInstructions'],
        contains('the Dictate a task widget'),
      );
      final meta = catalog['@homeCaptureInstructions'] as Map<String, dynamic>?;
      expect(meta, isNotNull);
      expect(meta!['description'], contains('capture_widget_label'));
      // The @ entry sits right after its key.
      final keys = catalog.keys.toList();
      expect(
        keys.indexOf('@homeCaptureInstructions'),
        keys.indexOf('homeCaptureInstructions') + 1,
      );
      // No English ARB string still names the old widget wording.
      for (final entry in catalog.entries) {
        if (entry.key.startsWith('@') || entry.value is! String) continue;
        expect(
          (entry.value as String).toLowerCase(),
          isNot(contains('say a task')),
          reason: entry.key,
        );
      }
    },
  );

  test(
    'UX-1657: nothing changed in Spanish and Catalan, nor in the English shortcut and share strings',
    () {
      expect(es, {
        'capture_voice': 'Dictar una tarea',
        'capture_voice_short': 'Dictar',
        'capture_text': 'Escribir una tarea',
        'capture_text_short': 'Escribir',
        'capture_widget_label': 'Dictar una tarea',
        'capture_widget_description': 'Toca para dictar una tarea.',
        'share_empty': 'No hay texto que añadir.',
        'share_too_long': 'Texto demasiado largo. Comparte uno más corto.',
        'share_queue_full': 'Abre TaskFlow y acaba lo que ya has compartido.',
        'share_not_saved': 'No se ha podido guardar. Vuelve a compartirlo.',
      });
      expect(ca, {
        'capture_voice': 'Dicta una tasca',
        'capture_voice_short': 'Dicta',
        'capture_text': 'Escriu una tasca',
        'capture_text_short': 'Escriu',
        'capture_widget_label': 'Dicta una tasca',
        'capture_widget_description': 'Toca per dictar una tasca.',
        'share_empty': 'No hi ha cap text per afegir.',
        'share_too_long': 'Text massa llarg. Comparteix-ne un de més curt.',
        'share_queue_full': 'Obre TaskFlow i acaba el que ja has compartit.',
        'share_not_saved': 'No s’ha pogut desar. Torna-ho a compartir.',
      });
      expect(en['capture_voice'], 'Dictate a task');
      expect(en['capture_voice_short'], 'Dictate');
      expect(en['capture_text'], 'Type a new task');
      expect(en['capture_text_short'], 'Type');
      expect(en['share_empty'], 'No text to add.');
      expect(
        en['share_too_long'],
        'That text is too long. Share a shorter one.',
      );
      expect(
        en['share_queue_full'],
        'Open TaskFlow and finish what you shared.',
      );
      expect(en['share_not_saved'], 'Couldn’t save it. Please share it again.');
      expect(
        arb('es')['homeCaptureInstructions'],
        'En Android, mantén pulsado el icono de TaskFlow para ver los accesos '
        'directos, o añade el widget de micrófono desde el lanzador. Comparte '
        'texto con TaskFlow desde otra aplicación.',
      );
      expect(
        arb('ca')['homeCaptureInstructions'],
        'A Android, mantén premuda la icona de TaskFlow per veure’n les '
        'dreceres o afegeix el giny ${ca['capture_widget_label']} des de la '
        'pantalla d’inici. També pots compartir text amb TaskFlow des d’una '
        'altra aplicació.',
      );
    },
  );
}
