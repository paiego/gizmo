import 'grammar.dart';

/// One recoloring of the eight [ColorId] slots.
///
/// [values] follow [colorRing], so neighbors stay neighbors. A saved run
/// still stores the [ColorId] name, not a palette id.
class IconPalette {
  const IconPalette({
    required this.id,
    required this.label,
    required this.values,
  });

  final String id;
  final String label;
  final Map<ColorId, int> values;

  @override
  bool operator ==(Object other) =>
      other is IconPalette &&
      other.id == id &&
      other.label == label &&
      other.values == values;

  @override
  int get hashCode => Object.hash(id, label, values);
}

/// The original ring. [colorValue] is this palette.
const warmPalette = IconPalette(
  id: 'warm',
  label: 'Warm',
  values: colorValue,
);

/// Deep teal through plum. No red, orange, amber, or bright green.
const coldPalette = IconPalette(
  id: 'cold',
  label: 'Cold',
  values: {
    ColorId.red: 0xFF11887C,
    ColorId.orange: 0xFF0F7595,
    ColorId.amber: 0xFF1753A1,
    ColorId.green: 0xFF1A2A93,
    ColorId.teal: 0xFF4027A5,
    ColorId.blue: 0xFF662BA1,
    ColorId.purple: 0xFF832197,
    ColorId.pink: 0xFF91277F,
  },
);

/// Bark, olive, and pine.
const forestPalette = IconPalette(
  id: 'forest',
  label: 'Forest',
  values: {
    ColorId.red: 0xFF893F24,
    ColorId.orange: 0xFF8C6121,
    ColorId.amber: 0xFF7A7829,
    ColorId.green: 0xFF547529,
    ColorId.teal: 0xFF2D7425,
    ColorId.blue: 0xFF1E7137,
    ColorId.purple: 0xFF196B4D,
    ColorId.pink: 0xFF156F69,
  },
);

/// Dark ink across the wheel, high contrast on the gray board.
const inkPalette = IconPalette(
  id: 'ink',
  label: 'Ink',
  values: {
    ColorId.red: 0xFF7F1A22,
    ColorId.orange: 0xFF8B4218,
    ColorId.amber: 0xFF846E15,
    ColorId.green: 0xFF426A25,
    ColorId.teal: 0xFF1E673C,
    ColorId.blue: 0xFF14617B,
    ColorId.purple: 0xFF271F84,
    ColorId.pink: 0xFF772255,
  },
);

/// Warm is first. It is the default.
const List<IconPalette> iconPalettes = [
  warmPalette,
  coldPalette,
  forestPalette,
  inkPalette,
];

IconPalette paletteById(String? id) {
  for (final palette in iconPalettes) {
    if (palette.id == id) return palette;
  }
  return warmPalette;
}
