import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

import 'icon_paths.dart';

/// Paints one assembly. [size] is the cell; the ink occupies its center 72%.
class IconView extends StatelessWidget {
  const IconView({super.key, required this.assembly, required this.size});

  final Assembly assembly;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: IconPainter(assembly),
        size: Size.square(size),
      ),
    );
  }
}

class IconPainter extends CustomPainter {
  const IconPainter(this.assembly);

  final Assembly assembly;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    final silhouette = iconSilhouette(assembly).transform(
      Float64List.fromList([
        scale, 0, 0, 0, //
        0, scale, 0, 0, //
        0, 0, 1, 0, //
        0, 0, 0, 1,
      ]),
    );
    canvas.drawPath(
      silhouette.shift(const Offset(2, 4)),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      silhouette,
      Paint()
        ..color = Color(colorValue[assembly.color]!)
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(IconPainter oldDelegate) =>
      oldDelegate.assembly != assembly;
}
