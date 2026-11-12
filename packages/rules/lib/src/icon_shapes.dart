import 'dart:math' as math;

import 'grammar.dart';

/// A point in the 100-unit icon coordinate system.
class IconPoint {
  const IconPoint(this.dx, this.dy);

  final double dx;
  final double dy;

  double distanceTo(IconPoint other) {
    final ddx = dx - other.dx;
    final ddy = dy - other.dy;
    return math.sqrt(ddx * ddx + ddy * ddy);
  }
}

/// Circle every shape stays inside, in the 100-unit icon box.
const double iconRadius = 32;

/// Center of [iconRadius] in the 100-unit box.
const IconPoint iconCenter = IconPoint(50, 50);

/// Inner points of a star, as a fraction of its [IconShape.radius].
const double starInner = 0.45;

enum IconShapeKind {
  circle,
  square,
  triangle,
  pentagon,
  hexagon,
  heptagon,
  octagon,
  nonagon,
  decagon,
  star,
}

/// Side counts for the regular polygons. Stars and circles are not in here.
const Map<IconShapeKind, int> polygonSides = {
  IconShapeKind.triangle: 3,
  IconShapeKind.square: 4,
  IconShapeKind.pentagon: 5,
  IconShapeKind.hexagon: 6,
  IconShapeKind.heptagon: 7,
  IconShapeKind.octagon: 8,
  IconShapeKind.nonagon: 9,
  IconShapeKind.decagon: 10,
};

enum IconPaint { fill, stroke }

/// One centered shape in an icon.
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

/// The three shapes that paint [assembly], larger one first.
List<IconShape> iconShapes(Assembly assembly) {
  return [
    _shape(assembly, 0, 20, 27, 3.5, 6.5),
    _shape(assembly, 1, 10, 16, 2.0, 4.0),
    _shape(assembly, 2, 9.93, 9.97, 1.2, 2.4),
  ];
}

/// How many rendered shape properties differ between [a] and [b].
///
/// Each layer compares kind, radius, rotation, color, paint, thickness, and
/// points. Zero means the icons paint the same.
int visualPropertyDelta(Assembly a, Assembly b) {
  final left = iconShapes(a);
  final right = iconShapes(b);
  var count = 0;
  for (var i = 0; i < left.length; i++) {
    final l = left[i];
    final r = right[i];
    if (l.kind != r.kind) count += 1;
    if (l.radius != r.radius) count += 1;
    if (l.rotation != r.rotation) count += 1;
    if (l.color != r.color) count += 1;
    if (l.paint != r.paint) count += 1;
    if (l.thickness != r.thickness) count += 1;
    if (l.points != r.points) count += 1;
  }
  return count;
}

/// True when [a] and [b] would paint as the same icon.
bool samePicture(Assembly a, Assembly b) {
  if (a == b) return true;
  return visualPropertyDelta(a, b) == 0;
}

/// Greatest distance from [iconCenter] to a point on [shape].
double measuredRadius(IconShape shape) {
  var farthest = 0.0;
  for (final point in shapePoints(shape)) {
    final distance = point.distanceTo(iconCenter);
    if (distance > farthest) farthest = distance;
  }
  return farthest;
}

/// Outer ink radius for [shape], including half the stroke width.
double inkRadius(IconShape shape) {
  final outset = shape.paint == IconPaint.stroke ? shape.thickness / 2 : 0.0;
  return measuredRadius(shape) + outset;
}

/// Greatest ink reach across [assembly]'s painted layers.
///
/// [IconPainter] scales each assembly so this value fills the cell. Using the
/// shared [iconRadius] constant instead made assemblies with larger geometry
/// look bigger on screen than the original.
double assemblyInkRadius(Assembly assembly) {
  var farthest = 0.0;
  for (final shape in iconShapes(assembly)) {
    final reach = inkRadius(shape);
    if (reach > farthest) farthest = reach;
  }
  return farthest > 0 ? farthest : iconRadius;
}

/// Outline points. A circle reports the four compass points of its radius.
List<IconPoint> shapePoints(IconShape shape) {
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

int _sides(IconShapeKind kind) => polygonSides[kind] ?? 0;

IconPoint _at(double angle, double reach) {
  return IconPoint(
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
  final kind =
      IconShapeKind.values[random.nextInt(IconShapeKind.values.length)];
  final paint = random.nextBool() ? IconPaint.fill : IconPaint.stroke;
  final thickness = paint == IconPaint.stroke
      ? thicknessLo + random.nextDouble() * (thicknessHi - thicknessLo)
      : 0.0;
  final points = kind == IconShapeKind.star ? 4 + random.nextInt(3) : 0;
  final rotation =
      kind == IconShapeKind.circle ? 0.0 : random.nextDouble() * 2 * math.pi;
  final outset = paint == IconPaint.stroke ? thickness / 2 : 0.0;
  return IconShape(
    kind: kind,
    radius: _radius(random, iconRadius - outset, radiusLo, radiusHi),
    rotation: rotation,
    color: _layerColor(assembly, layer, random),
    paint: paint,
    thickness: thickness,
    points: points,
  );
}

/// Layer 0 follows [Assembly.color]. Deeper layers shade from a hue tied to the
/// structural catalog fields, not [Assembly.color], so a color-only change
/// alters one painted property.
ColorId _layerColor(Assembly assembly, int layer, math.Random random) {
  if (layer == 0) return assembly.color;
  final anchor = ColorId.values[
      (_structureColorBase(assembly) + layer) % ColorId.values.length];
  return _otherColor(anchor, random);
}

int _structureColorBase(Assembly assembly) {
  return assembly.body.index +
      4 * assembly.top.index +
      16 * assembly.side.index +
      64 * assembly.hole.index +
      256 * assembly.pulse.index;
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

/// Every legal assembly in the catalog.
Iterable<Assembly> legalAssemblies() sync* {
  for (final body in BodyId.values) {
    for (final top in TopId.values) {
      for (final side in SideId.values) {
        if (top == TopId.none && side == SideId.none) continue;
        for (final hole in HoleId.values) {
          for (final color in ColorId.values) {
            for (final pulse in PulseId.values) {
              yield Assembly(
                body: body,
                top: top,
                side: side,
                hole: hole,
                color: color,
                pulse: pulse,
              );
            }
          }
        }
      }
    }
  }
}
