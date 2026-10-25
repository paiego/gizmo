enum BodyId { disc, slab, wedge, arch }

enum TopId { none, knob, horn, loop }

enum SideId { none, tab, handle, wing }

enum HoleId { none, round, slot }

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

/// One icon: a body, a top, a side, a hole, and a color.
class Assembly {
  const Assembly({
    required this.body,
    required this.top,
    required this.side,
    required this.hole,
    required this.color,
  });

  final BodyId body;
  final TopId top;
  final SideId side;
  final HoleId hole;
  final ColorId color;

  /// Top and side are not both `none`.
  bool get isLegal => top != TopId.none || side != SideId.none;

  Assembly copyWith({
    BodyId? body,
    TopId? top,
    SideId? side,
    HoleId? hole,
    ColorId? color,
  }) {
    return Assembly(
      body: body ?? this.body,
      top: top ?? this.top,
      side: side ?? this.side,
      hole: hole ?? this.hole,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Assembly &&
      other.body == body &&
      other.top == top &&
      other.side == side &&
      other.hole == hole &&
      other.color == color;

  @override
  int get hashCode => Object.hash(body, top, side, hole, color);

  @override
  String toString() =>
      '${body.name}/${top.name}/${side.name}/${hole.name}/${color.name}';
}

/// Bodies, tops, sides, holes, and colors, excluding a bare body.
///
/// `4 * (4 * 4 - 1) * 3 * 8 = 1440`.
const int assemblyCount = 1440;

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

BodyId? parseBody(String raw) => _byName(BodyId.values, raw);

TopId? parseTop(String raw) => _byName(TopId.values, raw);

SideId? parseSide(String raw) => _byName(SideId.values, raw);

HoleId? parseHole(String raw) => _byName(HoleId.values, raw);

ColorId? parseColor(String raw) => _byName(ColorId.values, raw);

T? _byName<T extends Enum>(List<T> values, String raw) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return null;
}
