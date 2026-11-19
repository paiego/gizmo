import 'grammar.dart';
import 'icon_shapes.dart';

/// Wire format version for [encodeAssembly], [encodeIconSnapshot], etc.
const int iconCodecVersion = 1;

const int _assemblyFieldCount = 6;
const int _shapeFieldCount = 7;
const int _snapshotLayerCount = 3;

/// Ordered numeric fields for [assembly] (starts with [iconCodecVersion]).
List<num> encodeAssembly(Assembly assembly) {
  return [
    iconCodecVersion,
    assembly.body.index,
    assembly.top.index,
    assembly.side.index,
    assembly.hole.index,
    assembly.color.index,
    assembly.pulse.index,
  ];
}

Assembly decodeAssembly(List<num> vector) {
  _expectVersion(vector);
  if (vector.length < 1 + _assemblyFieldCount) {
    throw FormatException(
      'Assembly vector needs ${1 + _assemblyFieldCount} values, got ${vector.length}.',
    );
  }
  return Assembly(
    body: BodyId.values[vector[1].toInt()],
    top: TopId.values[vector[2].toInt()],
    side: SideId.values[vector[3].toInt()],
    hole: HoleId.values[vector[4].toInt()],
    color: ColorId.values[vector[5].toInt()],
    pulse: PulseId.values[vector[6].toInt()],
  );
}

/// One layer's paint geometry (no leading version).
List<num> encodeIconShape(IconShape shape) {
  return [
    shape.kind.index,
    shape.radius,
    shape.rotation,
    shape.color.index,
    shape.paint.index,
    shape.thickness,
    shape.points,
  ];
}

IconShape decodeIconShape(List<num> vector, {int offset = 0}) {
  if (vector.length < offset + _shapeFieldCount) {
    throw FormatException(
      'IconShape needs $_shapeFieldCount values at offset $offset.',
    );
  }
  return IconShape(
    kind: IconShapeKind.values[vector[offset].toInt()],
    radius: vector[offset + 1].toDouble(),
    rotation: vector[offset + 2].toDouble(),
    color: ColorId.values[vector[offset + 3].toInt()],
    paint: IconPaint.values[vector[offset + 4].toInt()],
    thickness: vector[offset + 5].toDouble(),
    points: vector[offset + 6].toInt(),
  );
}

/// Frozen paint for three layers (starts with [iconCodecVersion]).
List<num> encodeIconSnapshot(IconSnapshot snapshot) {
  final out = <num>[iconCodecVersion];
  for (final layer in snapshot.layers) {
    out.addAll(encodeIconShape(layer));
  }
  return out;
}

IconSnapshot decodeIconSnapshot(List<num> vector) {
  _expectVersion(vector);
  const needed = 1 + _snapshotLayerCount * _shapeFieldCount;
  if (vector.length < needed) {
    throw FormatException(
      'IconSnapshot vector needs $needed values, got ${vector.length}.',
    );
  }
  final layers = <IconShape>[
    for (var layer = 0; layer < _snapshotLayerCount; layer++)
      decodeIconShape(
        vector,
        offset: 1 + layer * _shapeFieldCount,
      ),
  ];
  return IconSnapshot(layers);
}

/// Assembly + appearance + optional single-diff tag for admin logs.
List<num> encodeRoundChoicePayload({
  required Assembly assembly,
  required IconSnapshot appearance,
  SingleVisualDiffKind? singleDiffKind,
}) {
  final diffIndex = singleDiffKind == null
      ? -1
      : singleVisualDiffKinds.indexOf(singleDiffKind);
  return [
  iconCodecVersion,
    ...encodeAssembly(assembly).skip(1),
    ...encodeIconSnapshot(appearance).skip(1),
    diffIndex,
  ];
}

/// `false` when re-materializing [assembly] does not match [appearance].
bool assemblyMaterializesToSnapshot(Assembly assembly, IconSnapshot appearance) {
  return materializeIcon(assembly) == appearance;
}

void _expectVersion(List<num> vector) {
  if (vector.isEmpty) {
    throw const FormatException('Icon codec vector is empty.');
  }
  final version = vector.first.toInt();
  if (version != iconCodecVersion) {
    throw FormatException(
      'Unsupported icon codec version $version (expected $iconCodecVersion).',
    );
  }
}

String describeAssembly(Assembly assembly) {
  return '${assembly.body.name} · ${assembly.top.name} · ${assembly.side.name} · '
      '${assembly.hole.name} · ${assembly.color.name} · ${assembly.pulse.name}';
}

String describeIconShape(IconShape shape, {required int layer}) {
  final paint = shape.paint == IconPaint.fill ? 'fill' : 'stroke';
  final kind = shape.kind.name;
  final rot = shape.rotation == 0
      ? ''
      : ', rot ${shape.rotation.toStringAsFixed(4)}';
  final thick = shape.paint == IconPaint.stroke
      ? ', thick ${shape.thickness.toStringAsFixed(3)}'
      : '';
  final pts = shape.kind == IconShapeKind.star ? ', pts ${shape.points}' : '';
  return 'L$layer $kind r=${shape.radius.toStringAsFixed(3)} '
      '${shape.color.name} $paint$rot$thick$pts';
}

String describeIconSnapshot(IconSnapshot snapshot) {
  final parts = <String>[
    for (var i = 0; i < snapshot.layers.length; i++)
      describeIconShape(snapshot.layers[i], layer: i),
  ];
  return parts.join(' | ');
}

String describeSingleDiffKind(SingleVisualDiffKind? kind) {
  if (kind == null) return '—';
  switch (kind) {
    case SingleVisualDiffKind.layer0Color:
      return 'layer0 color';
    case SingleVisualDiffKind.layer1Color:
      return 'layer1 color';
    case SingleVisualDiffKind.layer1Kind:
      return 'layer1 kind';
    case SingleVisualDiffKind.layer2Color:
      return 'layer2 color';
    case SingleVisualDiffKind.layer2Kind:
      return 'layer2 kind';
  }
}

String formatCodecVector(List<num> vector) {
  return vector
      .map((n) => n is int || n == n.roundToDouble() ? '${n.toInt()}' : '$n')
      .join(', ');
}