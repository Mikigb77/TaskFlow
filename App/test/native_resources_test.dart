// P20 (UX-121, UX-119, UX-125, UX-420): the words and icons Android and iOS
// show outside the app — launcher shortcuts, the widget picker, share
// toasts and the microphone prompt. Checked in the resource files, since no
// widget test can render them; a phone still has to show them.
import 'dart:io';

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

void main() {
  final en = _strings('values');
  final es = _strings('values-es');
  final ca = _strings('values-ca');

  test(
    'UX-121: the widget picker says Toca para dictar una tarea. in EN, ES and CA',
    () {
      expect(en['capture_widget_description'], 'Tap to say a task.');
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
      expect(en['capture_voice'], 'Say a task');
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
        RegExp(r'\.setShortLabel\(\s*context\.getString\(\s*shortLabel\s*\)\s*\)')
            .hasMatch(kotlin),
        isTrue,
      );
      expect(
        RegExp(r'\.setLongLabel\(\s*context\.getString\(\s*longLabel\s*\)\s*\)')
            .hasMatch(kotlin),
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
      expect(label, contains('android:text="@string/capture_voice"'));
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
}
