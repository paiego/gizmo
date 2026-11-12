import 'package:gizmo_rules/gizmo_rules.dart';
import 'package:test/test.dart';

void main() {
  test('inkRadius includes half the stroke width', () {
    const shape = IconShape(
      kind: IconShapeKind.circle,
      radius: 20,
      rotation: 0,
      color: ColorId.red,
      paint: IconPaint.stroke,
      thickness: 4,
      points: 0,
    );
    expect(inkRadius(shape), closeTo(22, 1e-9));
  });

  test('assembly ink radii differ across the catalog', () {
    var minInk = double.infinity;
    var maxInk = 0.0;
    for (final assembly in legalAssemblies()) {
      final ink = assemblyInkRadius(assembly);
      if (ink < minInk) minInk = ink;
      if (ink > maxInk) maxInk = ink;
    }
    expect(maxInk - minInk, greaterThan(3));
    expect(maxInk, lessThanOrEqualTo(iconRadius + 1e-6));
  });

  test('per-assembly scale normalizes on-screen ink reach', () {
    const side = 200.0;
    final reach = side / 2 - 1;
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
    expect(smallest, isNotNull);
    expect(largest, isNotNull);
    for (final assembly in [smallest!, largest!]) {
      final scale = reach / assemblyInkRadius(assembly);
      expect(scale * assemblyInkRadius(assembly), closeTo(reach, 1e-9));
    }
  });
}
