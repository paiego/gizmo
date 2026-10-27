import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizmo/widgets/icon_paths.dart';
import 'package:gizmo/widgets/icon_view.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ink stays inside the centered 72 box and parts join', () {
    for (final body in BodyId.values) {
      for (final top in TopId.values) {
        for (final side in SideId.values) {
          if (top == TopId.none && side == SideId.none) continue;
          for (final hole in HoleId.values) {
            final assembly = Assembly(
              body: body,
              top: top,
              side: side,
              hole: hole,
              color: ColorId.red,
              pulse: PulseId.none,
            );
            final path = iconSilhouette(assembly);
            final bounds = path.getBounds();
            expect(
              bounds.left,
              greaterThanOrEqualTo(13.5),
              reason: '$assembly $bounds',
            );
            expect(
              bounds.top,
              greaterThanOrEqualTo(13.5),
              reason: '$assembly $bounds',
            );
            expect(
              bounds.right,
              lessThanOrEqualTo(86.5),
              reason: '$assembly $bounds',
            );
            expect(
              bounds.bottom,
              lessThanOrEqualTo(86.5),
              reason: '$assembly $bounds',
            );
            expect(
              path.contains(const Offset(50, 50)) || hole != HoleId.none,
              isTrue,
            );

            final contours = path.computeMetrics().length;
            final loop = top == TopId.loop;
            final handle = side == SideId.handle;
            final cut = hole != HoleId.none;
            if (!loop && !handle && !cut) {
              expect(contours, 1, reason: '$assembly split into $contours');
            } else if (loop && cut && !handle) {
              expect(contours, greaterThanOrEqualTo(2), reason: '$assembly');
            }
            if (hole == HoleId.round || hole == HoleId.slot) {
              expect(
                path.contains(const Offset(50, 50)),
                isFalse,
                reason: '$assembly hole is filled',
              );
            }
          }
        }
      }
    }
  });

  test('attached parts are at least 14 units on one side', () {
    for (final body in BodyId.values) {
      for (final top in TopId.values) {
        if (top == TopId.none) continue;
        final glyph = topGlyph(body, top)!;
        final bounds = glyph.outline.getBounds();
        expect(
          mathMax(bounds.width, bounds.height),
          greaterThanOrEqualTo(14),
          reason: '$body $top $bounds',
        );
      }
      for (final side in SideId.values) {
        if (side == SideId.none) continue;
        final bounds = sideGlyph(body, side)!.getBounds();
        expect(
          mathMax(bounds.width, bounds.height),
          greaterThanOrEqualTo(14),
          reason: '$body $side $bounds',
        );
      }
    }
  });

  test('a part stays attached to the body', () {
    const samples = [
      (BodyId.disc, TopId.knob, SideId.none),
      (BodyId.slab, TopId.horn, SideId.tab),
      (BodyId.wedge, TopId.none, SideId.wing),
      (BodyId.arch, TopId.knob, SideId.tab),
    ];
    for (final sample in samples) {
      final path = iconSilhouette(
        Assembly(
          body: sample.$1,
          top: sample.$2,
          side: sample.$3,
          hole: HoleId.none,
          color: ColorId.blue,
          pulse: PulseId.none,
        ),
      );
      expect(path.contains(const Offset(50, 58)), isTrue, reason: '$sample');
      expect(path.computeMetrics().length, 1, reason: '$sample');
    }
  });

  test('a different part is not the same picture', () {
    const original = Assembly(
      body: BodyId.disc,
      top: TopId.horn,
      side: SideId.tab,
      hole: HoleId.none,
      color: ColorId.teal,
      pulse: PulseId.none,
    );
    expect(samePicture(original, original), isTrue);
    expect(
      samePicture(original, original.copyWith(hole: HoleId.round)),
      isFalse,
    );
    expect(
      samePicture(original, original.copyWith(color: ColorId.green)),
      isFalse,
    );
    expect(
      samePicture(original, original.copyWith(top: TopId.knob)),
      isFalse,
    );
    expect(
      samePicture(original, original.copyWith(pulse: PulseId.core)),
      isFalse,
    );
    expect(
      samePicture(original, original.copyWith(pulse: PulseId.rim)),
      isFalse,
    );
  });

  test('the core stays inside the ink and leaves the hole visible', () {
    for (final body in BodyId.values) {
      final core = coreGlyph(body);
      final bounds = core.getBounds();
      expect(bounds.left, greaterThanOrEqualTo(14), reason: '$body');
      expect(bounds.top, greaterThanOrEqualTo(14), reason: '$body');
      expect(bounds.right, lessThanOrEqualTo(86), reason: '$body');
      expect(bounds.bottom, lessThanOrEqualTo(86), reason: '$body');
      final ink = bodyPath(body);
      for (final hole in [HoleId.round, HoleId.slot]) {
        final cut = holeGlyph(hole)!;
        var visible = false;
        var escaped = false;
        for (var y = 14; y <= 86; y += 2) {
          for (var x = 14; x <= 86; x += 2) {
            final point = Offset(x.toDouble(), y.toDouble());
            if (!core.contains(point)) continue;
            if (!ink.contains(point)) escaped = true;
            if (!cut.contains(point)) visible = true;
          }
        }
        expect(escaped, isFalse, reason: '$body core leaves the body');
        expect(visible, isTrue, reason: '$body $hole core covers the hole');
      }
    }
  });

  testWidgets('icons paint on the board', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFFEEEEEE),
          body: Center(
            child: IconView(
              assembly: Assembly(
                body: BodyId.arch,
                top: TopId.loop,
                side: SideId.handle,
                hole: HoleId.slot,
                color: ColorId.amber,
                pulse: PulseId.none,
              ),
              size: 220,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(IconView), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('core and rim pulses build and repaint', (tester) async {
    IconPainter.paintCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              IconView(assembly: _pulsed(PulseId.core), size: 140),
              IconView(assembly: _pulsed(PulseId.rim), size: 140),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(IconView), findsNWidgets(2));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    final core = _painter(tester, 0);
    final rim = _painter(tester, 1);
    expect(core.assembly.pulse, PulseId.core);
    expect(rim.assembly.pulse, PulseId.rim);
    final painted = IconPainter.paintCount;
    expect(painted, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 250));
    final coreLater = _painter(tester, 0);
    final rimLater = _painter(tester, 1);
    expect(coreLater.phase, isNot(core.phase));
    expect(rimLater.phase, isNot(rim.phase));
    expect(coreLater.shouldRepaint(core), isTrue);
    expect(rimLater.shouldRepaint(rim), isTrue);
    expect(IconPainter.paintCount, greaterThan(painted));
  });

  testWidgets('each rim icon keeps one outline weight at the same speed', (
    tester,
  ) async {
    const count = 24;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              for (var index = 0; index < count; index++)
                IconView(assembly: _pulsed(PulseId.rim), size: 48),
            ],
          ),
        ),
      ),
    );

    final before = [
      for (var index = 0; index < count; index++) _painter(tester, index),
    ];
    expect(OutlineWeight.values, [OutlineWeight.thin, OutlineWeight.thick]);
    expect(OutlineWeight.thin.units, 4);
    expect(OutlineWeight.thick.units, 10);
    final weights = before.map((painter) => painter.outline).toSet();
    expect(weights, {OutlineWeight.thin, OutlineWeight.thick});
    for (final painter in before) {
      expect(painter.assembly.pulse, PulseId.rim);
    }

    await tester.pump(const Duration(milliseconds: 250));
    final later = [
      for (var index = 0; index < count; index++) _painter(tester, index),
    ];
    expect(later.map((painter) => painter.phase).toSet().length, 1);
    expect(later.first.phase, isNot(before.first.phase));
    for (var index = 0; index < count; index++) {
      expect(later[index].outline, before[index].outline);
    }
  });
}

Assembly _pulsed(PulseId pulse) {
  return Assembly(
    body: BodyId.disc,
    top: TopId.knob,
    side: SideId.tab,
    hole: HoleId.round,
    color: ColorId.blue,
    pulse: pulse,
  );
}

IconPainter _painter(WidgetTester tester, int index) {
  final paint = find.descendant(
    of: find.byType(IconView).at(index),
    matching: find.byType(CustomPaint),
  );
  return tester.widget<CustomPaint>(paint).painter! as IconPainter;
}

double mathMax(double a, double b) => a > b ? a : b;
