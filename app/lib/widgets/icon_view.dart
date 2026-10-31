import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

import '../palette_scope.dart';
import 'icon_curves.dart';

/// Paints one assembly as separate curves inside [iconRadius].
///
/// [palette] wins when set. Otherwise the surrounding [PaletteScope] is used,
/// and a missing scope paints [warmPalette].
///
/// [PulseId.core] and [PulseId.rim] brighten and dim on a one-second loop.
/// [PulseId.none] stays still. A rim icon draws one outline and keeps a single
/// weight chosen for that instance. Every weight uses the same loop.
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
  late final OutlineWeight _outline;

  bool get _pulsing => widget.assembly.pulse != PulseId.none;

  @override
  void initState() {
    super.initState();
    _outline = OutlineWeight.pick(math.Random());
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
          painter: IconPainter(
            widget.assembly,
            colors,
            outline: _outline,
          ),
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
              outline: _outline,
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

/// One rim outline. [thick] is the original 10-unit stroke.
enum OutlineWeight {
  thin(4),
  thick(10);

  const OutlineWeight(this.units);

  /// Stroke width in the 100-unit icon box, before the cell scale.
  final double units;

  static OutlineWeight pick(math.Random random) =>
      values[random.nextInt(values.length)];
}

class IconPainter extends CustomPainter {
  const IconPainter(
    this.assembly,
    this.palette, {
    this.phase = 0,
    this.outline = OutlineWeight.thick,
  });

  final Assembly assembly;
  final IconPalette palette;

  /// 0 is the dim end of a pulse and 1 is the bright end. Already eased.
  final double phase;

  /// The one outline this icon would draw. Ignored unless the pulse is rim.
  final OutlineWeight outline;

  @visibleForTesting
  static int paintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paintCount += 1;
    final scale = size.shortestSide / 100;
    final matrix = _scaleMatrix(scale);
    for (final curve in iconCurves(assembly)) {
      final thickness = paintedThickness(
        curve,
        rimThickness: outline.units,
      );
      final path = curvePath(curve).transform(matrix);
      final ink = _ink(curve);
      canvas.drawPath(
        path.shift(const Offset(2, 4)),
        _stroke(curve, thickness * scale, const Color(0x33000000), blur: true),
      );
      canvas.drawPath(path, _stroke(curve, thickness * scale, ink));
    }
  }

  Color _ink(IconCurve curve) {
    final base = Color(palette.values[curve.color]!);
    final pulsing =
        (assembly.pulse == PulseId.core && curve.role == IconCurveRole.core) ||
            (assembly.pulse == PulseId.rim && curve.role == IconCurveRole.rim);
    if (!pulsing) return base;
    return _pulseInk(base, phase);
  }

  Paint _stroke(IconCurve curve, double width, Color color,
      {bool blur = false}) {
    return Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = curve.cap
      ..strokeJoin = curve.join
      ..strokeMiterLimit = 1.5
      ..color = color
      ..isAntiAlias = true
      ..maskFilter = blur ? const MaskFilter.blur(BlurStyle.normal, 6) : null;
  }

  @override
  bool shouldRepaint(IconPainter oldDelegate) =>
      oldDelegate.assembly != assembly ||
      oldDelegate.palette != palette ||
      oldDelegate.phase != phase ||
      oldDelegate.outline != outline;
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
