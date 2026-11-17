import 'dart:math' as math;

enum BodyId { disc, slab, wedge, arch }

enum TopId { none, knob, horn, loop }

enum SideId { none, tab, handle, wing }

enum HoleId { none, round, slot }

enum PulseId { none, core, rim }

enum ColorId { red, orange, amber, green, teal, blue, purple, pink }

/// Ring order. Adjacent colors are the previous and next entries, wrapping.
const List<ColorId> colorRing = [
  ColorId.red,
  ColorId.orange,
  ColorId.amber,
  ColorId.green,
  ColorId.teal,
  ColorId.blue,
  ColorId.purple,
  ColorId.pink,
];

/// Opaque ARGB values. Amber is the yellow so it stays readable on `#EEEEEE`.
const Map<ColorId, int> colorValue = {
  ColorId.red: 0xFFE53935,
  ColorId.orange: 0xFFFB8C00,
  ColorId.amber: 0xFFF9A825,
  ColorId.green: 0xFF43A047,
  ColorId.teal: 0xFF00897B,
  ColorId.blue: 0xFF1E88E5,
  ColorId.purple: 0xFF8E24AA,
  ColorId.pink: 0xFFD81B60,
};

/// One icon: a body, a top, a side, a hole, a color, and a pulse.
class Assembly {
  const Assembly({
    required this.body,
    required this.top,
    required this.side,
    required this.hole,
    required this.color,
    required this.pulse,
  });

  final BodyId body;
  final TopId top;
  final SideId side;
  final HoleId hole;
  final ColorId color;
  final PulseId pulse;

  /// Top and side are not both `none`.
  bool get isLegal => top != TopId.none || side != SideId.none;

  Assembly copyWith({
    BodyId? body,
    TopId? top,
    SideId? side,
    HoleId? hole,
    ColorId? color,
    PulseId? pulse,
  }) {
    return Assembly(
      body: body ?? this.body,
      top: top ?? this.top,
      side: side ?? this.side,
      hole: hole ?? this.hole,
      color: color ?? this.color,
      pulse: pulse ?? this.pulse,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Assembly &&
      other.body == body &&
      other.top == top &&
      other.side == side &&
      other.hole == hole &&
      other.color == color &&
      other.pulse == pulse;

  @override
  int get hashCode => Object.hash(body, top, side, hole, color, pulse);

  @override
  String toString() =>
      '${body.name}/${top.name}/${side.name}/${hole.name}/${color.name}/${pulse.name}';
}

/// Bodies, tops, sides, holes, colors, and pulses, excluding a bare body.
///
/// `4 * (4 * 4 - 1) * 3 * 8 * 3 = 4320`.
const int assemblyCount = 4320;

List<ColorId> adjacentColors(ColorId color) {
  final index = colorRing.indexOf(color);
  final count = colorRing.length;
  return [
    colorRing[(index - 1 + count) % count],
    colorRing[(index + 1) % count],
  ];
}

List<ColorId> nonAdjacentColors(ColorId color) {
  final adjacent = adjacentColors(color).toSet();
  return [
    for (final candidate in colorRing)
      if (candidate != color && !adjacent.contains(candidate)) candidate,
  ];
}

/// Shortest step count between [a] and [b] along [colorRing], wrapping.
int colorRingSteps(ColorId a, ColorId b) {
  final ia = colorRing.indexOf(a);
  final ib = colorRing.indexOf(b);
  if (ia < 0 || ib < 0) return colorRing.length;
  final count = colorRing.length;
  final diff = (ia - ib).abs();
  return math.min(diff, count - diff);
}

/// Ring neighbors sit one step away. Color-only decoys must step past them.
///
/// Two steps still allows pink/blue beside purple and reads as the same hue
/// on small inner layers.
const int minDecoyColorRingSteps = 3;

bool _isCoolHue(ColorId color) =>
    color == ColorId.teal ||
    color == ColorId.blue ||
    color == ColorId.purple ||
    color == ColorId.pink;

bool _isWarmHue(ColorId color) =>
    color == ColorId.red ||
    color == ColorId.orange ||
    color == ColorId.amber;

/// Picks for a color-only decoy: at least [minDecoyColorRingSteps] on the ring
/// and at least [minDecoyColorDistance] in painted RGB ([colorValue]).
///
/// High-chroma cool bases skew toward warm opposites so purple/teal read as a
/// hue change, not a violet or cyan tint shift.
List<ColorId> separatedDecoyColors(ColorId color) {
  final base = [
    for (final candidate in colorRing)
      if (candidate != color &&
          colorRingSteps(color, candidate) >= minDecoyColorRingSteps &&
          colorDistance(color, candidate) >= minDecoyColorDistance)
        candidate,
  ];
  if (_isCoolHue(color)) {
    final warm = base.where(_isWarmHue).toList();
    if (warm.length >= 2) return warm;
  }
  if (_isWarmHue(color)) {
    final cool = base.where(_isCoolHue).toList();
    if (cool.length >= 2) return cool;
  }
  return base;
}

/// Floor used by [distantColors], in Euclidean RGB distance (0 to about 441).
///
/// Near pairs such as purple/pink (~105 RGB at two ring steps) sit under this.
/// A round may use a nearer color; this floor only marks the far set.
const double minDecoyColorDistance = 155;

/// Minimum ring steps between polygon layer colors on one icon (same floor as
/// color-only decoys).
const int minIconPolygonColorRingSteps = minDecoyColorRingSteps;

/// Minimum painted RGB distance between polygon layer colors on one icon.
const double minIconPolygonColorDistance = minDecoyColorDistance;

/// On the eight-color ring, at most two polygons can all be at ring step ≥3
/// apart. When an icon paints three polygon layers, pairs use this ring floor
/// and keep [minIconPolygonColorDistance].
const int minIconPolygonThreeLayerRingSteps = 2;

/// Ring floor for [polygonLayerCount] regular-polygon layers on one icon.
int minIconPolygonRingStepsForLayerCount(int polygonLayerCount) =>
    polygonLayerCount >= 3
        ? minIconPolygonThreeLayerRingSteps
        : minIconPolygonColorRingSteps;

/// True when [a] and [b] are distinct and satisfy the ring and RGB floors for
/// [polygonLayerCount] polygon layers on one icon.
bool iconPolygonColorsSeparatedForLayerCount(
  ColorId a,
  ColorId b,
  int polygonLayerCount,
) {
  if (a == b) return false;
  final ringFloor = minIconPolygonRingStepsForLayerCount(polygonLayerCount);
  return colorRingSteps(a, b) >= ringFloor &&
      colorDistance(a, b) >= minIconPolygonColorDistance;
}

/// True when [a] and [b] meet the two-polygon icon floors (ring ≥3, RGB ≥155).
bool iconPolygonColorsSeparated(ColorId a, ColorId b) =>
    iconPolygonColorsSeparatedForLayerCount(a, b, 2);

/// True when [candidate] is separated from every color in [polygonPeerColors].
bool iconPolygonColorCompatible(
  ColorId candidate,
  Iterable<ColorId> polygonPeerColors, {
  required int polygonLayerCount,
}) {
  for (final peer in polygonPeerColors) {
    if (!iconPolygonColorsSeparatedForLayerCount(
      candidate,
      peer,
      polygonLayerCount,
    )) {
      return false;
    }
  }
  return true;
}

/// Catalog colors that satisfy [iconPolygonColorCompatible] with [polygonPeerColors].
List<ColorId> iconPolygonColorOptions(
  Iterable<ColorId> polygonPeerColors, {
  required int polygonLayerCount,
}) {
  return [
    for (final candidate in ColorId.values)
      if (iconPolygonColorCompatible(
        candidate,
        polygonPeerColors,
        polygonLayerCount: polygonLayerCount,
      ))
        candidate,
  ];
}

/// Opaque ARGB painted for [color] (same slots as [warmPalette]).
int paintedColorArgb(ColorId color) => colorValue[color]!;

/// Euclidean RGB distance between on-screen palette colors for [a] and [b].
double colorDistance(ColorId a, ColorId b) {
  final left = paintedColorArgb(a);
  final right = paintedColorArgb(b);
  var sum = 0;
  for (final shift in const [16, 8, 0]) {
    final delta = ((left >> shift) & 0xFF) - ((right >> shift) & 0xFF);
    sum += delta * delta;
  }
  return math.sqrt(sum);
}

/// Colors that sit far from [color].
///
/// Skips the color itself and both ring neighbors, and keeps only colors at
/// least [minDecoyColorDistance] away. The neighbor pairs orange/amber,
/// red/pink, and green/teal sit under that floor.
List<ColorId> distantColors(ColorId color) => separatedDecoyColors(color);

BodyId? parseBody(String raw) => _byName(BodyId.values, raw);

TopId? parseTop(String raw) => _byName(TopId.values, raw);

SideId? parseSide(String raw) => _byName(SideId.values, raw);

HoleId? parseHole(String raw) => _byName(HoleId.values, raw);

ColorId? parseColor(String raw) => _byName(ColorId.values, raw);

PulseId? parsePulse(String raw) => _byName(PulseId.values, raw);

T? _byName<T extends Enum>(List<T> values, String raw) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return null;
}
