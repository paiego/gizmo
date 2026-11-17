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

/// Minimum side-count gap for a shape-only decoy when the baseline layer is a
/// regular polygon (e.g. pentagon may not decoy to square or hexagon).
const int minPolygonDecoySideGap = 2;

/// True when [kind] is a regular polygon listed in [polygonSides].
bool isRegularPolygonKind(IconShapeKind kind) =>
    polygonSides.containsKey(kind);

/// Whether [to] is allowed as a shape-kind-only decoy for regular polygon [from].
bool polygonKindDecoyAllowed(IconShapeKind from, IconShapeKind to) {
  if (!isRegularPolygonKind(from)) return true;
  final fromSides = polygonSides[from]!;
  final toSides = isRegularPolygonKind(to) ? polygonSides[to]! : 0;
  return (toSides - fromSides).abs() >= minPolygonDecoySideGap;
}

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

/// Colors of regular-polygon layers on [snapshot], excluding [layer] when set.
int _polygonLayerCount(IconSnapshot snapshot) {
  var count = 0;
  for (final shape in snapshot.layers) {
    if (isRegularPolygonKind(shape.kind)) count += 1;
  }
  return count;
}

List<ColorId> polygonLayerPeerColors(IconSnapshot snapshot, int layer) {
  final peers = <ColorId>[];
  for (var i = 0; i < snapshot.layers.length; i++) {
    if (i == layer) continue;
    final shape = snapshot.layers[i];
    if (isRegularPolygonKind(shape.kind)) peers.add(shape.color);
  }
  return peers;
}

/// True when every pair of polygon layers on [snapshot] meets the icon color gap.
bool iconSnapshotPolygonColorGapSatisfied(IconSnapshot snapshot) {
  final polygonColors = <ColorId>[];
  for (final shape in snapshot.layers) {
    if (!isRegularPolygonKind(shape.kind)) continue;
    polygonColors.add(shape.color);
  }
  if (polygonColors.length < 2) return true;
  final count = polygonColors.length;
  for (var i = 0; i < polygonColors.length; i++) {
    for (var j = i + 1; j < polygonColors.length; j++) {
      if (!iconPolygonColorsSeparatedForLayerCount(
        polygonColors[i],
        polygonColors[j],
        count,
      )) {
        return false;
      }
    }
  }
  return true;
}

/// Materializes three layers from [assembly]. Seed runs only here.
IconSnapshot materializeIcon(Assembly assembly) {
  final geometry = [
    _shapeGeometry(assembly, 0, 20, 27, 3.5, 6.5),
    _shapeGeometry(assembly, 1, 10, 16, 2.0, 4.0),
    _shapeGeometry(assembly, 2, 9.93, 9.97, 1.2, 2.4),
  ];
  const maxAttempts = 48;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      final layers = _materializeLayerColors(assembly, geometry, attempt);
      final snapshot = IconSnapshot(layers);
      if (iconSnapshotPolygonColorGapSatisfied(snapshot)) return snapshot;
    } on StateError {
      continue;
    }
  }
  throw StateError(
    'Could not assign separated polygon colors for $assembly.',
  );
}

List<IconShape> _materializeLayerColors(
  Assembly assembly,
  List<IconShape> geometry,
  int attempt,
) {
  final polygonColors = <ColorId>[];
  final polygonLayerIndices = _polygonLayerIndices(geometry);
  final polygonLayerCount = polygonLayerIndices.length;
  final layers = <IconShape>[];
  for (var layer = 0; layer < 3; layer++) {
    final base = geometry[layer];
    final colorRandom = math.Random(_seed(assembly, layer) + 9001 + attempt * 37);
    final color = _assignLayerPaintColor(
      assembly,
      layer,
      base.kind,
      polygonColors,
      colorRandom,
      geometry,
      polygonLayerIndices,
      polygonLayerCount,
    );
    if (isRegularPolygonKind(base.kind)) polygonColors.add(color);
    layers.add(base.copyWith(color: color));
  }
  return layers;
}

List<int> _polygonLayerIndices(List<IconShape> geometry) {
  return [
    for (var i = 0; i < geometry.length; i++)
      if (isRegularPolygonKind(geometry[i].kind)) i,
  ];
}

bool _polygonColorAssignmentCompletable(
  List<int> remainingPolygonLayers,
  List<ColorId> polygonColorsSoFar,
  int polygonLayerCount,
) {
  if (remainingPolygonLayers.isEmpty) return true;
  final options = iconPolygonColorOptions(
    polygonColorsSoFar,
    polygonLayerCount: polygonLayerCount,
  );
  for (final pick in options) {
    if (_polygonColorAssignmentCompletable(
      remainingPolygonLayers.sublist(1),
      [...polygonColorsSoFar, pick],
      polygonLayerCount,
    )) {
      return true;
    }
  }
  return false;
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

/// True when changing [layer]'s paint color would show on screen.
///
/// If a higher layer already uses the same [ColorId], recoloring [layer] stays
/// hidden behind that ink — the decoy still looks like the same hue (levels
/// 13–14 purple square / teal + purple diamond cases).
bool colorDecoyLayerIsVisible(IconSnapshot baseline, int layer) {
  final color = baseline.layers[layer].color;
  for (var i = layer + 1; i < baseline.layers.length; i++) {
    if (baseline.layers[i].color == color) return false;
  }
  return true;
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
      if (!colorDecoyLayerIsVisible(baseline, 0)) return null;
      final current = baseline.layers[0].color;
      var options = _nonEmptyColors(layer0ColorOptions) ??
          separatedDecoyColors(current);
      if (isRegularPolygonKind(baseline.layers[0].kind)) {
        final peers = polygonLayerPeerColors(baseline, 0);
        final polygonCount = _polygonLayerCount(baseline);
        options = [
          for (final value in options)
            if (iconPolygonColorCompatible(
              value,
              peers,
              polygonLayerCount: polygonCount,
            ))
              value,
        ];
      }
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
  if (!colorDecoyLayerIsVisible(baseline, layer)) return null;
  final current = baseline.layers[layer].color;
  var options = separatedDecoyColors(current);
  if (isRegularPolygonKind(baseline.layers[layer].kind)) {
    final peers = polygonLayerPeerColors(baseline, layer);
    final polygonCount = _polygonLayerCount(baseline);
    options = [
      for (final value in options)
        if (iconPolygonColorCompatible(
          value,
          peers,
          polygonLayerCount: polygonCount,
        ))
          value,
    ];
  }
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
    if (!polygonKindDecoyAllowed(current.kind, picked)) continue;
    if (isRegularPolygonKind(picked)) {
      final peers = polygonLayerPeerColors(baseline, layer);
      final nextCount = _polygonLayerCount(baseline) +
          (isRegularPolygonKind(baseline.layers[layer].kind) ? 0 : 1);
      if (!iconPolygonColorCompatible(
        current.color,
        peers,
        polygonLayerCount: nextCount,
      )) {
        continue;
      }
    }
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
  return snapshotInkRadius(materializeIcon(assembly));
}

/// Greatest ink reach across frozen [snapshot] layers.
double snapshotInkRadius(IconSnapshot snapshot) {
  var farthest = 0.0;
  for (final shape in snapshot.layers) {
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

IconShape _shapeGeometry(
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
    color: ColorId.red,
    paint: paint,
    thickness: thickness,
    points: points,
  );
}

ColorId _assignLayerPaintColor(
  Assembly assembly,
  int layer,
  IconShapeKind kind,
  List<ColorId> polygonPeers,
  math.Random random,
  List<IconShape> geometry,
  List<int> polygonLayerIndices,
  int polygonLayerCount,
) {
  if (!isRegularPolygonKind(kind)) {
    return _layerColorAtMaterialize(assembly, layer, random);
  }
  if (layer == 0) {
    final later = polygonLayerIndices.where((i) => i > 0).toList();
    if (later.isNotEmpty &&
        !_polygonColorAssignmentCompletable(
          later,
          [assembly.color],
          polygonLayerCount,
        )) {
      throw StateError(
        'Assembly color ${assembly.color} cannot complete polygon layers on '
        '$assembly.',
      );
    }
    return assembly.color;
  }
  if (polygonPeers.isEmpty) {
    final anchor = ColorId.values[
        (_structureColorBase(assembly) + layer) % ColorId.values.length];
    return _otherColor(anchor, random);
  }
  final layerIndex = polygonLayerIndices.indexOf(layer);
  final remaining =
      layerIndex >= 0 ? polygonLayerIndices.sublist(layerIndex + 1) : <int>[];
  var candidates = iconPolygonColorOptions(
    polygonPeers,
    polygonLayerCount: polygonLayerCount,
  );
  if (remaining.isNotEmpty) {
    candidates = [
      for (final value in candidates)
        if (_polygonColorAssignmentCompletable(
          remaining,
          [...polygonPeers, value],
          polygonLayerCount,
        ))
          value,
    ];
  }
  if (candidates.isEmpty) {
    throw StateError(
      'No separated polygon paint color for layer $layer of $assembly.',
    );
  }
  return candidates[random.nextInt(candidates.length)];
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