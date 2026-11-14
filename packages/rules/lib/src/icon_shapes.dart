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

  IconShape copyWith({
    IconShapeKind? kind,
    double? radius,
    double? rotation,
    ColorId? color,
    IconPaint? paint,
    double? thickness,
    int? points,
  }) {
    return IconShape(
      kind: kind ?? this.kind,
      radius: radius ?? this.radius,
      rotation: rotation ?? this.rotation,
      color: color ?? this.color,
      paint: paint ?? this.paint,
      thickness: thickness ?? this.thickness,
      points: points ?? this.points,
    );
  }

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

/// Frozen painted icon: three layers, back to front.
class IconSnapshot {
  const IconSnapshot(this.layers) : assert(layers.length == 3);

  final List<IconShape> layers;

  @override
  bool operator ==(Object other) =>
      other is IconSnapshot &&
      _layersEqual(layers, other.layers);

  @override
  int get hashCode => Object.hashAll(layers);

  IconSnapshot copyLayer(
    int index,
    IconShape Function(IconShape layer) update,
  ) {
    final copy = List<IconShape>.from(layers);
    copy[index] = update(copy[index]);
    return IconSnapshot(copy);
  }
}

bool _layersEqual(List<IconShape> a, List<IconShape> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Which single visual property may differ at similarity 1.0.
enum SingleVisualDiffKind {
  layer0Color,
  layer1Color,
  layer1Kind,
  layer2Color,
  layer2Kind,
}

/// All [SingleVisualDiffKind] values in display order.
const List<SingleVisualDiffKind> singleVisualDiffKinds = [
  SingleVisualDiffKind.layer0Color,
  SingleVisualDiffKind.layer1Color,
  SingleVisualDiffKind.layer1Kind,
  SingleVisualDiffKind.layer2Color,
  SingleVisualDiffKind.layer2Kind,
];

/// Materializes three layers from [assembly]. Seed runs only here.
IconSnapshot materializeIcon(Assembly assembly) {
  return IconSnapshot([
    _shape(assembly, 0, 20, 27, 3.5, 6.5),
    _shape(assembly, 1, 10, 16, 2.0, 4.0),
    _shape(assembly, 2, 9.93, 9.97, 1.2, 2.4),
  ]);
}

/// The three shapes that paint [assembly], larger one first.
List<IconShape> iconShapes(Assembly assembly) {
  return materializeIcon(assembly).layers;
}

/// How many rendered shape properties differ between two snapshots.
int snapshotPropertyDelta(IconSnapshot a, IconSnapshot b) {
  var count = 0;
  for (var i = 0; i < 3; i++) {
    final l = a.layers[i];
    final r = b.layers[i];
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

/// How many rendered shape properties differ between [a] and [b].
int visualPropertyDelta(Assembly a, Assembly b) {
  return snapshotPropertyDelta(materializeIcon(a), materializeIcon(b));
}

/// True when two snapshots paint the same icon.
bool samePictureSnapshots(IconSnapshot a, IconSnapshot b) {
  return a == b;
}

/// True when [a] and [b] would paint as the same icon.
bool samePicture(Assembly a, Assembly b) {
  if (a == b) return true;
  return visualPropertyDelta(a, b) == 0;
}

List<ColorId>? _nonEmptyColors(Iterable<ColorId>? options) {
  if (options == null) return null;
  final list = options.toList();
  return list.isEmpty ? null : list;
}

/// Copies [baseline] and changes exactly one property for [kind].
///
/// Returns null when no alternate value is available or delta would not be 1.
IconSnapshot? trySingleVisualDiff(
  IconSnapshot baseline,
  SingleVisualDiffKind kind,
  math.Random rng, {
  Iterable<ColorId>? layer0ColorOptions,
}) {
  switch (kind) {
    case SingleVisualDiffKind.layer0Color:
      final current = baseline.layers[0].color;
      final options = _nonEmptyColors(layer0ColorOptions) ??
          [for (final c in ColorId.values) if (c != current) c];
      if (options.isEmpty) return null;
      final picked = options.elementAt(rng.nextInt(options.length));
      final next = baseline.copyLayer(0, (l) => l.copyWith(color: picked));
      return snapshotPropertyDelta(baseline, next) == 1 ? next : null;
    case SingleVisualDiffKind.layer1Color:
      return _diffLayerColor(baseline, 1, rng);
    case SingleVisualDiffKind.layer2Color:
      return _diffLayerColor(baseline, 2, rng);
    case SingleVisualDiffKind.layer1Kind:
      return _diffLayerKind(baseline, 1, rng);
    case SingleVisualDiffKind.layer2Kind:
      return _diffLayerKind(baseline, 2, rng);
  }
}

IconSnapshot? _diffLayerColor(IconSnapshot baseline, int layer, math.Random rng) {
  final current = baseline.layers[layer].color;
  final options = [
    for (final c in ColorId.values)
      if (c != current) c,
  ];
  if (options.isEmpty) return null;
  final picked = options.elementAt(rng.nextInt(options.length));
  final next = baseline.copyLayer(layer, (l) => l.copyWith(color: picked));
  return snapshotPropertyDelta(baseline, next) == 1 ? next : null;
}

IconSnapshot? _diffLayerKind(IconSnapshot baseline, int layer, math.Random rng) {
  final current = baseline.layers[layer];
  final options = [
    for (final k in IconShapeKind.values)
      if (k != current.kind &&
          k != IconShapeKind.star &&
          current.kind != IconShapeKind.star)
        k,
  ];
  options.shuffle(rng);
  for (final picked in options) {
    var shape = current.copyWith(kind: picked, points: 0);
    if (picked == IconShapeKind.circle) {
      if (current.rotation != 0.0) continue;
      shape = shape.copyWith(rotation: 0.0);
    }
    final next = baseline.copyLayer(layer, (_) => shape);
    if (snapshotPropertyDelta(baseline, next) == 1) return next;
  }
  return null;
}

SingleVisualDiffKind? classifySingleVisualDiff(
  IconSnapshot baseline,
  IconSnapshot other,
) {
  if (snapshotPropertyDelta(baseline, other) != 1) return null;
  for (var layer = 0; layer < 3; layer++) {
    final l = baseline.layers[layer];
    final r = other.layers[layer];
    if (l.kind != r.kind) {
      return layer == 1
          ? SingleVisualDiffKind.layer1Kind
          : SingleVisualDiffKind.layer2Kind;
    }
    if (l.color != r.color) {
      if (layer == 0) return SingleVisualDiffKind.layer0Color;
      if (layer == 1) return SingleVisualDiffKind.layer1Color;
      return SingleVisualDiffKind.layer2Color;
    }
    if (l.radius != r.radius ||
        l.rotation != r.rotation ||
        l.paint != r.paint ||
        l.thickness != r.thickness ||
        l.points != r.points) {
      return null;
    }
  }
  return null;
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
    color: _layerColorAtMaterialize(assembly, layer, random),
    paint: paint,
    thickness: thickness,
    points: points,
  );
}

/// Used only while materializing from [Assembly]. Colors live on [IconSnapshot]
/// afterward.
ColorId _layerColorAtMaterialize(Assembly assembly, int layer, math.Random random) {
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