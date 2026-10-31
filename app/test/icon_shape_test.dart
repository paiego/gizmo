import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizmo/widgets/icon_curves.dart';
import 'package:gizmo/widgets/icon_view.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the formula is the curve', () {
    const formula = CurveFormula(
      centerAngle: 0,
      span: 0,
      radialBase: 0.5,
      radialA: 0,
      radialB: 0,
      frequencyA: 1,
      phaseA: 0,
      frequencyB: 1,
      phaseB: 0,
      crossAmplitude: 0,
      crossFrequency: 1,
      crossPhase: 0,
    );
    final point = formula.at(0.5, reach: 20);
    expect(point.dx, closeTo(60, 1e-9));
    expect(point.dy, closeTo(50, 1e-9));
  });

  test('each curve owns a thickness and a connected formula inside the radius',
      () {
    expect(iconRadius, 32);
    for (final body in BodyId.values) {
      for (final top in TopId.values) {
        for (final side in SideId.values) {
          if (top == TopId.none && side == SideId.none) continue;
          for (final hole in HoleId.values) {
            for (final pulse in PulseId.values) {
              final assembly = Assembly(
                body: body,
                top: top,
                side: side,
                hole: hole,
                color: ColorId.red,
                pulse: pulse,
              );
              final curves = iconCurves(assembly);
              expect(curves, isNotEmpty, reason: '$assembly');
              expect(
                curves.map((curve) => curve.role).toSet().length,
                curves.length,
                reason: '$assembly shares a role',
              );
              final thicknesses =
                  curves.map((curve) => curve.thickness).toSet();
              expect(
                thicknesses.length,
                curves.length,
                reason: '$assembly shares a thickness',
              );
              final formulas = curves.map((curve) => curve.formula).toSet();
              expect(
                formulas.length,
                curves.length,
                reason: '$assembly shares a formula',
              );
              for (final curve in curves) {
                expect(curve.formula.bounded, isTrue, reason: '$assembly');
                final painted = [
                  curve.thickness,
                  if (curve.role == IconCurveRole.rim) ...[
                    OutlineWeight.thin.units,
                    OutlineWeight.thick.units,
                  ],
                ];
                for (final thickness in painted) {
                  final reach = curveReach(thickness);
                  final samples = [
                    for (var i = 0; i <= 48; i++)
                      curve.formula.at(i / 48, reach: reach),
                  ];
                  for (final point in samples) {
                    final extent =
                        (point - iconCenter).distance + thickness / 2;
                    expect(
                      extent,
                      lessThanOrEqualTo(iconRadius + 1e-6),
                      reason: '$assembly ${curve.role} $point',
                    );
                  }
                  var widest = 0.0;
                  for (var i = 1; i < samples.length; i++) {
                    final step = (samples[i] - samples[i - 1]).distance;
                    if (step > widest) widest = step;
                  }
                  expect(
                    widest,
                    lessThan(iconRadius),
                    reason: '$assembly ${curve.role} jumps',
                  );
                }
              }
            }
          }
        }
      }
    }
  });

  test('each part curve spans at least 14 units', () {
    for (final body in BodyId.values) {
      for (final top in TopId.values) {
        for (final side in SideId.values) {
          if (top == TopId.none && side == SideId.none) continue;
          final curves = iconCurves(
            Assembly(
              body: body,
              top: top,
              side: side,
              hole: HoleId.none,
              color: ColorId.red,
              pulse: PulseId.none,
            ),
          );
          for (final curve in curves) {
            final bounds = _bounds(curve);
            expect(
              mathMax(bounds.width, bounds.height),
              greaterThanOrEqualTo(14),
              reason: '$body $top $side ${curve.role} $bounds',
            );
          }
        }
      }
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

  test('the core and the hole are different curves inside the radius', () {
    for (final body in BodyId.values) {
      for (final hole in [HoleId.round, HoleId.slot]) {
        final curves = iconCurves(
          Assembly(
            body: body,
            top: TopId.knob,
            side: SideId.tab,
            hole: hole,
            color: ColorId.blue,
            pulse: PulseId.core,
          ),
        );
        final core =
            curves.singleWhere((curve) => curve.role == IconCurveRole.core);
        final opening =
            curves.singleWhere((curve) => curve.role == IconCurveRole.hole);
        expect(core.formula, isNot(opening.formula));
        expect(core.thickness, isNot(opening.thickness));
        expect(core.color, isNot(opening.color));
        for (var i = 0; i <= 24; i++) {
          final point = core.formula.at(
            i / 24,
            reach: curveReach(core.thickness),
          );
          expect(
            (point - iconCenter).distance + core.thickness / 2,
            lessThanOrEqualTo(iconRadius + 1e-6),
            reason: '$body $hole',
          );
        }
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

Rect _bounds(IconCurve curve) {
  final reach = curveReach(curve.thickness);
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = -double.infinity;
  var maxY = -double.infinity;
  for (var i = 0; i <= 48; i++) {
    final point = curve.formula.at(i / 48, reach: reach);
    if (point.dx < minX) minX = point.dx;
    if (point.dy < minY) minY = point.dy;
    if (point.dx > maxX) maxX = point.dx;
    if (point.dy > maxY) maxY = point.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}
