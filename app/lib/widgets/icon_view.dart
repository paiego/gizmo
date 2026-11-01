import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

import '../palette_scope.dart';
import 'icon_shapes.dart';

/// Paints one assembly as two shapes inside [iconRadius].
///
/// [palette] wins when set. Otherwise the surrounding [PaletteScope] is used,
/// and a missing scope paints [warmPalette].
///
/// Pulses stay still. Drawing uses only the shape properties.
class IconView extends StatelessWidget {
  const IconView({
    super.key,
    required this.assembly,
    required this.size,
    this.palette,
  });

  final Assembly assembly;
  final double size;
  final IconPalette? palette;

  @override
  Widget build(BuildContext context) {
    final colors = palette ?? PaletteScope.maybeOf(context) ?? warmPalette;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: IconPainter(assembly, colors),
        size: Size.square(size),
      ),
    );
  }
}

class IconPainter extends CustomPainter {
  const IconPainter(
    this.assembly,
    this.palette, {
    this.phase = 0,
  });

  final Assembly assembly;
  final IconPalette palette;

  /// Held at 0 while pulses stay still.
  final double phase;

  @visibleForTesting
  static int paintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paintCount += 1;
    final scale = size.shortestSide / 100;
    final matrix = _scaleMatrix(scale);
    for (final shape in iconShapes(assembly)) {
      canvas.drawPath(
        shapePath(shape).transform(matrix),
        _paint(shape, scale),
      );
    }
  }

  Color _ink(IconShape shape) => Color(palette.values[shape.color]!);

  Paint _paint(IconShape shape, double scale) {
    final paint = Paint()
      ..isAntiAlias = true
      ..color = _ink(shape);
    if (shape.paint == IconPaint.fill) {
      paint.style = PaintingStyle.fill;
      return paint;
    }
    return paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = shape.thickness * scale
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
  }

  @override
  bool shouldRepaint(IconPainter oldDelegate) =>
      oldDelegate.assembly != assembly ||
      oldDelegate.palette != palette ||
      oldDelegate.phase != phase;
}

Float64List _scaleMatrix(double scale) {
  return Float64List.fromList([
    scale, 0, 0, 0, //
    0, scale, 0, 0, //
    0, 0, 1, 0, //
    0, 0, 0, 1,
  ]);
}
