import 'package:flutter/material.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

import '../palette_scope.dart';
import 'icon_shapes.dart';

/// Painted ink uses this fraction of the cell reach (half of the prior fill).
const double iconPaintScale = 0.5;

/// Paints one assembly as three shapes, one pixel inside the cell.
///
/// When [appearance] is set, those frozen layers paint instead of materializing
/// [assembly] from the catalog seed.
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
    this.appearance,
    this.palette,
  });

  final Assembly assembly;
  final IconSnapshot? appearance;
  final double size;
  final IconPalette? palette;

  @override
  Widget build(BuildContext context) {
    final colors = palette ?? PaletteScope.maybeOf(context) ?? warmPalette;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: IconPainter(
          assembly,
          colors,
          appearance: appearance,
        ),
        size: Size.square(size),
      ),
    );
  }
}

class IconPainter extends CustomPainter {
  const IconPainter(
    this.assembly,
    this.palette, {
    this.appearance,
    this.phase = 0,
  });

  final Assembly assembly;
  final IconSnapshot? appearance;
  final IconPalette palette;

  /// Held at 0 while pulses stay still.
  final double phase;

  @visibleForTesting
  static int paintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paintCount += 1;
    final side = size.shortestSide;
    final reach = side / 2 - 1;
    final scale = reach <= 0 ? side / 100 : reach / iconRadius;
    canvas.save();
    canvas.translate(side / 2, side / 2);
    canvas.scale(scale);
    canvas.translate(-iconCenter.dx, -iconCenter.dy);
    final layers = appearance?.layers ?? materializeIcon(assembly).layers;
    for (final shape in layers) {
      canvas.drawPath(shapePath(shape), _paint(shape, scale));
    }
    canvas.restore();
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
      oldDelegate.appearance != appearance ||
      oldDelegate.palette != palette ||
      oldDelegate.phase != phase;
}