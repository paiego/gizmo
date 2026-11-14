import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizmo/widgets/icon_shapes.dart';
import 'package:gizmo/widgets/icon_view.dart';
import 'package:gizmo_rules/gizmo_rules.dart'
    hide shapePoints, measuredRadius, iconCenter;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a triangle points up and a star nests its inner points', () {
    const triangle = IconShape(
      kind: IconShapeKind.triangle,
      radius: 10,
      rotation: 0,
      color: ColorId.red,
      paint: IconPaint.fill,
      thickness: 0,
      points: 0,
    );
    expect(shapePoints(triangle).first, const Offset(50, 40));
    expect(measuredRadius(triangle), closeTo(10, 1e-9));

    const star = IconShape(
      kind: IconShapeKind.star,
      radius: 20,
      rotation: 0,
      color: ColorId.red,
      paint: IconPaint.stroke,
      thickness: 2,
      points: 5,
    );
    final points = shapePoints(star);
    expect(points, hasLength(10));
    expect(
      (points[1] - iconCenter).distance,
      closeTo(20 * starInner, 1e-9),
    );
  });

  test('regular polygons from the triangle through the decagon close', () {
    const sides = {
      IconShapeKind.triangle: 3,
      IconShapeKind.square: 4,
      IconShapeKind.pentagon: 5,
      IconShapeKind.hexagon: 6,
      IconShapeKind.heptagon: 7,
      IconShapeKind.octagon: 8,
      IconShapeKind.nonagon: 9,
      IconShapeKind.decagon: 10,
    };
    expect(polygonSides, sides);
    for (final entry in sides.entries) {
      final shape = IconShape(
        kind: entry.key,
        radius: 12,
        rotation: 0,
        color: ColorId.red,
        paint: IconPaint.fill,
        thickness: 0,
        points: 0,
      );
      final points = shapePoints(shape);
      expect(points, hasLength(entry.value), reason: '${entry.key}');
      expect(points.first.dx, closeTo(50, 1e-9), reason: '${entry.key}');
      expect(points.first.dy, closeTo(38, 1e-9), reason: '${entry.key}');
    }
  });

  test('three shapes stay inside the icon and keep their own properties', () {
    expect(iconRadius, 32);
    final kinds = <IconShapeKind>{};
    final paints = <IconPaint>{};
    final starPoints = <int>{};
    var sharedKind = false;
    var splitKind = false;
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
              final shapes = iconShapes(assembly);
              expect(shapes, iconShapes(assembly), reason: '$assembly');
              expect(shapes, hasLength(3), reason: '$assembly');
              expect(
                shapes[0].radius,
                greaterThan(shapes[1].radius),
                reason: '$assembly draws the larger shape underneath',
              );
              expect(
                shapes[1].radius,
                greaterThan(shapes[2].radius),
                reason: '$assembly',
              );
              expect(shapes[0].color, assembly.color, reason: '$assembly');
              expect(shapes[1].color, isNot(shapes[0].color),
                  reason: '$assembly');
              expect(shapes[2].color, isNot(shapes[0].color),
                  reason: '$assembly');
              if (shapes[2].kind != shapes[0].kind &&
                  shapes[2].kind != shapes[1].kind) {
                splitKind = true;
              }
              if (shapes.first.kind == shapes.last.kind) {
                sharedKind = true;
              } else {
                splitKind = true;
              }
              for (final shape in shapes) {
                kinds.add(shape.kind);
                paints.add(shape.paint);
                expect(
                  measuredRadius(shape),
                  closeTo(shape.radius, 1e-6),
                  reason: '$assembly ${shape.kind}',
                );
                final outset =
                    shape.paint == IconPaint.stroke ? shape.thickness / 2 : 0.0;
                expect(
                  shape.radius + outset,
                  lessThanOrEqualTo(iconRadius + 1e-6),
                  reason: '$assembly ${shape.kind}',
                );
                final bounds = _bounds(shape);
                expect(
                  math.max(bounds.width, bounds.height),
                  greaterThanOrEqualTo(14),
                  reason: '$assembly ${shape.kind} $bounds',
                );
                if (shape.kind == IconShapeKind.circle) {
                  expect(shape.rotation, 0, reason: '$assembly');
                }
                if (shape.kind == IconShapeKind.star) {
                  expect(shape.points, inInclusiveRange(4, 6));
                  starPoints.add(shape.points);
                } else {
                  expect(shape.points, 0, reason: '$assembly ${shape.kind}');
                }
                if (shape.paint == IconPaint.fill) {
                  expect(shape.thickness, 0, reason: '$assembly');
                } else {
                  expect(shape.thickness, greaterThan(0), reason: '$assembly');
                }
              }
            }
          }
        }
      }
    }
    expect(kinds, IconShapeKind.values.toSet());
    expect(paints, IconPaint.values.toSet());
    expect(starPoints, {4, 5, 6});
    expect(sharedKind, isTrue);
    expect(splitKind, isTrue);
  });

  test('different assemblies share the same on-screen ink reach', () {
    const side = 200.0;
    final reach = (side / 2 - 1) * inkReachFactor;
    Assembly? smallest;
    Assembly? largest;
    var minInk = double.infinity;
    var maxInk = 0.0;
    for (final assembly in legalAssemblies()) {
      final ink = assemblyInkRadius(assembly);
      if (ink < minInk) {
        minInk = ink;
        smallest = assembly;
      }
      if (ink > maxInk) {
        maxInk = ink;
        largest = assembly;
      }
    }
    expect(maxInk - minInk, greaterThan(3));
    for (final assembly in [smallest!, largest!]) {
      final scale = reach / assemblyInkRadius(assembly);
      expect(scale * assemblyInkRadius(assembly), closeTo(reach, 1e-9));
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

  testWidgets('core and rim pulses stay still', (tester) async {
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
    expect(tester.binding.transientCallbackCount, 0);
    final core = _painter(tester, 0);
    final rim = _painter(tester, 1);
    expect(core.assembly.pulse, PulseId.core);
    expect(rim.assembly.pulse, PulseId.rim);
    expect(core.phase, 0);
    expect(rim.phase, 0);
    final painted = IconPainter.paintCount;
    expect(painted, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 250));
    final coreLater = _painter(tester, 0);
    final rimLater = _painter(tester, 1);
    expect(coreLater.phase, core.phase);
    expect(rimLater.phase, rim.phase);
    expect(coreLater.shouldRepaint(core), isFalse);
    expect(rimLater.shouldRepaint(rim), isFalse);
    expect(IconPainter.paintCount, painted);
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

Rect _bounds(IconShape shape) {
  final points = shapePoints(shape);
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = -double.infinity;
  var maxY = -double.infinity;
  for (final point in points) {
    if (point.dx < minX) minX = point.dx;
    if (point.dy < minY) minY = point.dy;
    if (point.dx > maxX) maxX = point.dx;
    if (point.dy > maxY) maxY = point.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}
