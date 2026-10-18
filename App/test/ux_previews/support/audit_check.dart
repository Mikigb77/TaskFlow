// Runs before the previews: a page with known problems, so a change to the
// audit that stops it finding them fails the run instead of passing quietly.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'audit.dart';

void auditSelfCheck() {
  testWidgets('the audit finds the problems it should (self-check)', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final boundary = GlobalKey();
    Widget square(String label) => SizedBox.square(
      dimension: 32,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: () {},
          child: const ColoredBox(color: Color(0xFF136B5C)),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Manrope'),
        home: RepaintBoundary(
          key: boundary,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // A custom control that says «Guardar» and shows «Añadir».
                Semantics(
                  button: true,
                  label: 'Guardar',
                  onTap: () {},
                  excludeSemantics: true,
                  child: FilledButton(onPressed: () {}, child: const Text('Añadir')),
                ),
                // No label and no tooltip.
                IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
                // Two 32 dp targets 2 dp apart.
                Row(children: [square('Uno'), const SizedBox(width: 2), square('Dos')]),
                const Text(
                  'Una línea demasiado larga para caber entera en la pantalla de un teléfono',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // A list stretches its children: Align keeps the box narrow.
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SizedBox(
                    width: 64,
                    child: Text('Configuració', style: TextStyle(fontSize: 24)),
                  ),
                ),
                const Text('Gris claro', style: TextStyle(color: Color(0xFFCCCCCC))),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final box = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    late Json measured;
    late ui.Image image;
    final raw = await tester.runAsync(() async {
      image = await box.toImage(pixelRatio: 2);
      return image.toByteData(format: ui.ImageByteFormat.rawRgba);
    });
    measured = await audit(
      tester,
      errors: const [],
      screen: const Size(360, 800),
      image: raw!,
      imageWidth: image.width,
      imageHeight: image.height,
      pixelRatio: 2,
    );
    image.dispose();
    final flags = measured['semanticsFlags']! as Json;
    final targets = (measured['targets']! as List).cast<Json>();
    final cuts = (measured['text']! as List).cast<Json>();
    final contrast = (measured['contrast']! as List).cast<Json>();
    expect(
      (flags['mismatches']! as List).cast<Json>().map((m) => m['label']),
      contains('Guardar'),
      reason: 'a label that differs from the visible text',
    );
    expect(
      (flags['unlabeled']! as List),
      isNotEmpty,
      reason: 'an icon button with no label',
    );
    final small = targets.where((t) => (t['w']! as num) < minTarget).toList();
    expect(small.map((t) => t['label']), containsAll(['Uno', 'Dos']));
    expect(
      small.every((t) => (t['gap']! as num) < minGap),
      isTrue,
      reason: 'the two squares are 2 dp apart',
    );
    expect(
      cuts.map((c) => c['why'] as String),
      containsAll([
        contains('ellipsis at 1 line'),
        contains('the word «Configuració» splits across lines'),
      ]),
    );
    expect(contrast.map((c) => c['text']), contains('Gris claro'));
    final guidelines = measured['guidelines']! as Json;
    expect(((guidelines['tapTarget']! as Json)['failures']! as List), isNotEmpty);
    expect(((guidelines['labeled']! as Json)['failures']! as List), isNotEmpty);
    semantics.dispose();
  });
}
