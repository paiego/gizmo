import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

import '../palette_scope.dart';
import 'icon_paths.dart';

/// Paints one assembly. [size] is the cell; the ink occupies its center 72%.
///
/// [palette] wins when set. Otherwise the surrounding [PaletteScope] is used,
/// and a missing scope paints [warmPalette].
///
/// [PulseId.core] and [PulseId.rim] brighten and dim on a one-second loop.
/// [PulseId.none] stays still.
class IconView extends StatefulWidget {
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
  State<IconView> createState() => _IconViewState();
}

class _IconViewState extends State<IconView>
    with SingleTickerProviderStateMixin {
  static const _halfLoop = Duration(milliseconds: 500);

  AnimationController? _controller;

  bool get _pulsing => widget.assembly.pulse != PulseId.none;

  @override
  void initState() {
    super.initState();
    if (_pulsing) _start();
  }

  @override
  void didUpdateWidget(IconView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pulsing) {
      _start();
    } else {
      _controller?.stop();
    }
  }

  void _start() {
    final controller = _controller ??= AnimationController(
      vsync: this,
      duration: _halfLoop,
    );
    if (!controller.isAnimating) {
      controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        widget.palette ?? PaletteScope.maybeOf(context) ?? warmPalette;
    final controller = _controller;
    if (controller == null || !controller.isAnimating) {
      return _frame(
        CustomPaint(
          painter: IconPainter(widget.assembly, colors),
          size: Size.square(widget.size),
        ),
      );
    }
    return _frame(
      AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return CustomPaint(
            painter: IconPainter(
              widget.assembly,
              colors,
              phase: Curves.easeInOut.transform(controller.value),
            ),
            size: Size.square(widget.size),
          );
        },
      ),
    );
  }

  Widget _frame(Widget child) {
    return SizedBox(width: widget.size, height: widget.size, child: child);
  }
}

class IconPainter extends CustomPainter {
  const IconPainter(this.assembly, this.palette, {this.phase = 0});

  final Assembly assembly;
  final IconPalette palette;

  /// 0 is the dim end of a pulse and 1 is the bright end. Already eased.
  final double phase;

  @visibleForTesting
  static int paintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paintCount += 1;
    final scale = size.shortestSide / 100;
    final matrix = _scaleMatrix(scale);
    final silhouette = iconSilhouette(assembly).transform(matrix);
    canvas.drawPath(
      silhouette.shift(const Offset(2, 4)),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..isAntiAlias = true,
    );
    final base = Color(palette.values[assembly.color]!);
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(
      silhouette,
      Paint()
        ..color = base
        ..isAntiAlias = true,
    );
    _paintPulse(canvas, silhouette, matrix, scale, base);
    // Clear the hole after the pulse so the flash cannot fill it.
    final hole = holeGlyph(assembly.hole);
    if (hole != null) {
      canvas.drawPath(
        hole.transform(matrix),
        Paint()
          ..blendMode = BlendMode.clear
          ..isAntiAlias = true,
      );
    }
    canvas.restore();
  }

  void _paintPulse(
    Canvas canvas,
    Path silhouette,
    Float64List matrix,
    double scale,
    Color base,
  ) {
    switch (assembly.pulse) {
      case PulseId.none:
        return;
      case PulseId.core:
      case PulseId.rim:
        break;
    }
    final ink = _pulseInk(base, phase);
    canvas.save();
    canvas.clipPath(silhouette);
    if (assembly.pulse == PulseId.core) {
      canvas.drawPath(
        coreGlyph(assembly.body).transform(matrix),
        Paint()
          ..color = ink
          ..isAntiAlias = true,
      );
    } else {
      canvas.drawPath(
        iconOutline(assembly).transform(matrix),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10 * scale
          ..strokeJoin = StrokeJoin.round
          ..color = ink
          ..isAntiAlias = true,
      );
    }
    canvas.restore();
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

Color _pulseInk(Color base, double phase) {
  final amount = 0.2 + (0.65 * phase.clamp(0.0, 1.0));
  return Color.lerp(base, const Color(0xFFFFFFFF), amount)!;
}
