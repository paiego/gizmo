import 'dart:math' as math;
import 'dart:ui';

import 'package:gizmo_rules/gizmo_rules.dart';

/// Circle every shape stays inside, in the 100-unit icon box.
///
/// Drawn icons scale this radius to one pixel inside the cell.
const double iconRadius = 32;

/// Center of [iconRadius] in the 100-unit box.
const Offset iconCenter = Offset(50, 50);

/// Inner points of a star, as a fraction of its [IconShape.radius].
const double starInner = 0.45;

enum IconShapeKind { circle, square, triangle, pentagon, hexagon, star }

enum IconPaint { fill, stroke }

/// One centered shape in an icon.
///
/// [radius] is the circumradius. A circle stores [rotation] 0. [thickness]
/// is 0 for a fill. [points] is 0 unless [kind] is [IconShapeKind.star].
class IconShape {
  const IconShape({
    required this.kind,
    required this.radius,
    required this.rotation,
    required this.color,
    required this.paint,
    required this.thickness,
    required this.points,
  });

  final IconShapeKind kind;
  final double radius;
  final double rotation;
  final ColorId color;
  final IconPaint paint;
  final double thickness;
  final int points;

  @override
  bool operator ==(Object other) =>
      other is IconShape &&
      other.kind == kind &&
      other.radius == radius &&
      other.rotation == rotation &&
      other.color == color &&
      other.paint == paint &&
      other.thickness == thickness &&
      other.points == points;

  @override
  int get hashCode => Object.hash(
        kind,
        radius,
        rotation,
        color,
        paint,
        thickness,
        points,
      );
}

/// The two shapes that paint [assembly], larger one first.
///
/// Body, top, side, hole, and pulse change both shapes. The first shape
/// uses [Assembly.color]. The second uses another palette color.
List<IconShape> iconShapes(Assembly assembly) {
  return [
    _shape(assembly, 0, 20, 27, 3.5, 6.5),
    _shape(assembly, 1, 10, 16, 2.0, 4.0),
  ];
}

/// Outline points. A circle reports the four compass points of its radius.
List<Offset> shapePoints(IconShape shape) {
  if (shape.kind == IconShapeKind.circle) {
    return [
      for (final angle in [0.0, math.pi / 2, math.pi, 3 * math.pi / 2])
        _at(angle, shape.radius),
    ];
  }
  final star = shape.kind == IconShapeKind.star;
  final count = star ? shape.points * 2 : _sides(shape.kind);
  final step = 2 * math.pi / count;
  return [
    for (var i = 0; i < count; i++)
      _at(
        shape.rotation - math.pi / 2 + i * step,
        star && i.isOdd ? shape.radius * starInner : shape.radius,
      ),
  ];
}

Path shapePath(IconShape shape) {
  if (shape.kind == IconShapeKind.circle) {
    return Path()
      ..addOval(Rect.fromCircle(center: iconCenter, radius: shape.radius));
  }
  return Path()..addPolygon(shapePoints(shape), true);
}

/// Greatest distance from [iconCenter] to a point on [shape].
double measuredRadius(IconShape shape) {
  var farthest = 0.0;
  for (final point in shapePoints(shape)) {
    final distance = (point - iconCenter).distance;
    if (distance > farthest) farthest = distance;
  }
  return farthest;
}

/// True when [a] and [b] would paint as the same icon.
///
/// Equal assemblies match. A different color or pulse does not. Otherwise
/// each shape's kind, radius, rotation, color, paint, thickness, and points
/// are compared.
bool samePicture(Assembly a, Assembly b) {
  if (a == b) return true;
  if (a.color != b.color || a.pulse != b.pulse) return false;
  final left = iconShapes(a);
  final right = iconShapes(b);
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

int _sides(IconShapeKind kind) {
  return switch (kind) {
    IconShapeKind.triangle => 3,
    IconShapeKind.square => 4,
    IconShapeKind.pentagon => 5,
    IconShapeKind.hexagon => 6,
    IconShapeKind.circle || IconShapeKind.star => 0,
  };
}

Offset _at(double angle, double reach) {
  return Offset(
    iconCenter.dx + math.cos(angle) * reach,
    iconCenter.dy + math.sin(angle) * reach,
  );
}

int _seed(Assembly assembly, int layer) {
  return layer +
      8 * assembly.body.index +
      32 * assembly.top.index +
      128 * assembly.side.index +
      512 * assembly.hole.index +
      2048 * assembly.pulse.index;
}

IconShape _shape(
  Assembly assembly,
  int layer,
  double radiusLo,
  double radiusHi,
  double thicknessLo,
  double thicknessHi,
) {
  final random = math.Random(_seed(assembly, layer));
  final kind = IconShapeKind.values[random.nextInt(IconShapeKind.values.length)];
  final paint = random.nextBool() ? IconPaint.fill : IconPaint.stroke;
  final thickness = paint == IconPaint.stroke
      ? thicknessLo + random.nextDouble() * (thicknessHi - thicknessLo)
      : 0.0;
  final points =
      kind == IconShapeKind.star ? 4 + random.nextInt(3) : 0;
  final rotation =
      kind == IconShapeKind.circle ? 0.0 : random.nextDouble() * 2 * math.pi;
  final outset = paint == IconPaint.stroke ? thickness / 2 : 0.0;
  return IconShape(
    kind: kind,
    radius: _radius(random, iconRadius - outset, radiusLo, radiusHi),
    rotation: rotation,
    color: layer == 0 ? assembly.color : _otherColor(assembly.color, random),
    paint: paint,
    thickness: thickness,
    points: points,
  );
}

ColorId _otherColor(ColorId base, math.Random random) {
  final index = colorRing.indexOf(base);
  final shift = 1 + random.nextInt(colorRing.length - 1);
  return colorRing[(index + shift) % colorRing.length];
}

double _radius(math.Random random, double limit, double lo, double hi) {
  final high = math.min(hi, limit - 0.05);
  final low = math.min(lo, high);
  if (high <= low) return low;
  return low + random.nextDouble() * (high - low);
}
