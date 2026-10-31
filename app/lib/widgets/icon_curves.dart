import 'dart:math' as math;
import 'dart:ui';

import 'package:gizmo_rules/gizmo_rules.dart';

/// Circle every curve stays inside, in the 100-unit icon box.
///
/// Choice cells are the crowded part of the play board: at most 140 points
/// and at least 48, two columns, a 12-point gap, and 20 points of side inset.
/// The look icon is at most 280, with 24 points of slack on each side. A
/// radius of 32 leaves 18 units of the 50-unit half-cell empty, about the
/// same proportion as that 20-point inset on a 140-point cell, so the whole
/// composite sits inside the cell instead of running to its edges.
const double iconRadius = 32;

/// Center of [iconRadius] in the 100-unit box.
const Offset iconCenter = Offset(50, 50);

/// One connected curve.
///
/// For `t` in `[0, 1]`, with [reach] the curve's own radius:
///
/// ```text
/// angle(t)  = centerAngle + (t - 1/2) * span
/// radial(t) = reach * (radialBase
///             + radialA * sin(2π * frequencyA * t + phaseA)
///             + radialB * sin(2π * frequencyB * t + phaseB))
/// cross(t)  = reach * crossAmplitude * sin(2π * crossFrequency * t + crossPhase)
/// x(t)      = 50 + cos(angle) * radial - sin(angle) * cross
/// y(t)      = 50 + sin(angle) * radial + cos(angle) * cross
/// ```
///
/// `|radialBase| + |radialA| + |radialB| ≤ 0.75` and `|crossAmplitude| ≤ 0.20`,
/// so every point stays inside `0.95 * reach`.
class CurveFormula {
  const CurveFormula({
    required this.centerAngle,
    required this.span,
    required this.radialBase,
    required this.radialA,
    required this.frequencyA,
    required this.phaseA,
    required this.radialB,
    required this.frequencyB,
    required this.phaseB,
    required this.crossAmplitude,
    required this.crossFrequency,
    required this.crossPhase,
  });

  final double centerAngle;
  final double span;
  final double radialBase;
  final double radialA;
  final double frequencyA;
  final double phaseA;
  final double radialB;
  final double frequencyB;
  final double phaseB;
  final double crossAmplitude;
  final double crossFrequency;
  final double crossPhase;

  bool get bounded =>
      radialBase.abs() + radialA.abs() + radialB.abs() <= 0.75 + 1e-9 &&
      crossAmplitude.abs() <= 0.20 + 1e-9;

  Offset at(double t, {required double reach}) {
    final angle = centerAngle + (t - 0.5) * span;
    final radial = reach *
        (radialBase +
            radialA * math.sin(2 * math.pi * frequencyA * t + phaseA) +
            radialB * math.sin(2 * math.pi * frequencyB * t + phaseB));
    final cross = reach *
        crossAmplitude *
        math.sin(2 * math.pi * crossFrequency * t + crossPhase);
    return Offset(
      iconCenter.dx + math.cos(angle) * radial - math.sin(angle) * cross,
      iconCenter.dy + math.sin(angle) * radial + math.cos(angle) * cross,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CurveFormula &&
      other.centerAngle == centerAngle &&
      other.span == span &&
      other.radialBase == radialBase &&
      other.radialA == radialA &&
      other.frequencyA == frequencyA &&
      other.phaseA == phaseA &&
      other.radialB == radialB &&
      other.frequencyB == frequencyB &&
      other.phaseB == phaseB &&
      other.crossAmplitude == crossAmplitude &&
      other.crossFrequency == crossFrequency &&
      other.crossPhase == crossPhase;

  @override
  int get hashCode => Object.hash(
        centerAngle,
        span,
        radialBase,
        radialA,
        frequencyA,
        phaseA,
        radialB,
        frequencyB,
        phaseB,
        crossAmplitude,
        crossFrequency,
        crossPhase,
      );
}

enum IconCurveRole { body, top, side, hole, core, rim }

/// One stroke in an icon.
///
/// Each curve owns its own [thickness], [color], [radius], [formula],
/// [cap], [join], and [dash]. [radius] is the centerline circle: every
/// point of the formula lies inside it, and [measuredRadius] reads that
/// size back off the points. The stroked result, including cap and join,
/// still fits in [iconRadius].
class IconCurve {
  const IconCurve({
    required this.role,
    required this.formula,
    required this.thickness,
    required this.color,
    required this.radius,
    required this.cap,
    required this.join,
    required this.dash,
  });

  final IconCurveRole role;
  final CurveFormula formula;
  final double thickness;
  final ColorId color;

  /// This curve's own centerline radius, in icon units.
  final double radius;

  final StrokeCap cap;
  final StrokeJoin join;

  /// On/off lengths in icon units. Empty means a solid stroke.
  final List<double> dash;

  @override
  bool operator ==(Object other) =>
      other is IconCurve &&
      other.role == role &&
      other.formula == formula &&
      other.thickness == thickness &&
      other.color == color &&
      other.radius == radius &&
      other.cap == cap &&
      other.join == join &&
      _sameDash(other.dash, dash);

  @override
  int get hashCode => Object.hash(
        role,
        formula,
        thickness,
        color,
        radius,
        cap,
        join,
        Object.hashAll(dash),
      );
}

/// How far past the centerline [cap] and [join] can push the ink.
///
/// The extra unit covers a square cap's corner and a miter clipped at 1.5.
double strokeInset(double thickness, StrokeCap cap, StrokeJoin join) {
  final capFactor = switch (cap) {
    StrokeCap.butt || StrokeCap.round => 1.0,
    StrokeCap.square => math.sqrt2,
  };
  final joinFactor = switch (join) {
    StrokeJoin.miter => 1.5,
    StrokeJoin.round || StrokeJoin.bevel => 1.0,
  };
  return thickness / 2 * math.max(capFactor, joinFactor) + 1;
}

/// Greatest distance from [iconCenter] to a point on [curve].
double measuredRadius(IconCurve curve, {int steps = 64}) {
  var farthest = 0.0;
  for (var i = 0; i <= steps; i++) {
    final point = curve.formula.at(i / steps, reach: curve.radius);
    final distance = (point - iconCenter).distance;
    if (distance > farthest) farthest = distance;
  }
  return farthest;
}

/// The curves that paint [assembly]. Parts are separate strokes, not one fill.
List<IconCurve> iconCurves(Assembly assembly) {
  return [
    _curve(assembly, IconCurveRole.body, 0, 4.4, 0.4),
    if (assembly.top != TopId.none)
      _curve(assembly, IconCurveRole.top, 2, 2.4, 0.3),
    if (assembly.side != SideId.none)
      _curve(assembly, IconCurveRole.side, 4, 3.1, 0.3),
    if (assembly.hole != HoleId.none)
      _curve(assembly, IconCurveRole.hole, 5, 1.8, 0.3, closed: true),
    if (assembly.pulse == PulseId.core)
      _curve(assembly, IconCurveRole.core, 1, 3.7, 0.3, closed: true),
    if (assembly.pulse == PulseId.rim)
      _curve(assembly, IconCurveRole.rim, 3, 5.2, 0.4, closed: true),
  ];
}

/// Stroke width actually drawn. A rim pulse uses the icon's one outline weight.
double paintedThickness(IconCurve curve, {double? rimThickness}) {
  if (curve.role == IconCurveRole.rim && rimThickness != null) {
    return rimThickness;
  }
  return curve.thickness;
}

Path formulaPath(CurveFormula formula,
    {required double reach, int steps = 48}) {
  final path = Path();
  for (var i = 0; i <= steps; i++) {
    final point = formula.at(i / steps, reach: reach);
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path;
}

/// The formula, broken into this curve's dash. A solid curve is unchanged.
Path curvePath(IconCurve curve) {
  return dashPath(
    formulaPath(curve.formula, reach: curve.radius),
    curve.dash,
  );
}

Path dashPath(Path source, List<double> pattern) {
  if (pattern.isEmpty) return source;
  final dashed = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    var draw = true;
    var index = 0;
    while (distance < metric.length) {
      final length = pattern[index % pattern.length];
      final next = math.min(distance + length, metric.length);
      if (draw && next > distance) {
        dashed.addPath(metric.extractPath(distance, next), Offset.zero);
      }
      distance = next;
      draw = !draw;
      index += 1;
      if (length <= 0) break;
    }
  }
  return dashed;
}

/// True when [a] and [b] would paint as the same icon.
///
/// Equal assemblies match. A different color or pulse does not. Otherwise
/// each curve's thickness, color, radius, formula, cap, join, and dash
/// are compared.
bool samePicture(Assembly a, Assembly b) {
  if (a == b) return true;
  if (a.color != b.color || a.pulse != b.pulse) return false;
  final left = iconCurves(a);
  final right = iconCurves(b);
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

bool _sameDash(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _seed(Assembly assembly, IconCurveRole role) {
  return role.index +
      8 * assembly.body.index +
      32 * assembly.top.index +
      128 * assembly.side.index +
      512 * assembly.hole.index;
}

ColorId _shift(ColorId color, int steps) {
  final index = colorRing.indexOf(color);
  return colorRing[(index + steps) % colorRing.length];
}

IconCurve _curve(
  Assembly assembly,
  IconCurveRole role,
  int colorShift,
  double thicknessBase,
  double thicknessJitter, {
  bool closed = false,
}) {
  final random = math.Random(_seed(assembly, role));
  final thickness =
      thicknessBase + (random.nextDouble() - 0.5) * thicknessJitter;
  final cap = StrokeCap.values[random.nextInt(StrokeCap.values.length)];
  final join = StrokeJoin.values[random.nextInt(StrokeJoin.values.length)];
  final dash = _dash(random);
  final formula = _formula(random, closed: closed);
  final limit = iconRadius -
      strokeInset(
        role == IconCurveRole.rim ? 10 : thickness,
        cap,
        join,
      );
  return IconCurve(
    role: role,
    formula: formula,
    thickness: thickness,
    color: _shift(assembly.color, colorShift),
    radius: _radius(random, role, limit),
    cap: cap,
    join: join,
    dash: dash,
  );
}

double _radius(math.Random random, IconCurveRole role, double limit) {
  final (lo, hi) = switch (role) {
    IconCurveRole.hole => (12.0, 13.8),
    IconCurveRole.core => (16.0, 17.8),
    IconCurveRole.rim => (20.0, 21.8),
    IconCurveRole.top => (23.4, 24.2),
    IconCurveRole.side => (24.5, 25.3),
    IconCurveRole.body => (25.6, 26.6),
  };
  final high = math.min(hi, limit - 0.05);
  final low = math.min(lo, high);
  if (high <= low) return low;
  return low + random.nextDouble() * (high - low);
}

List<double> _dash(math.Random random) {
  switch (random.nextInt(3)) {
    case 0:
      return const [];
    case 1:
      return [5 + random.nextDouble() * 4, 2.5 + random.nextDouble() * 2];
    default:
      return [
        3 + random.nextDouble() * 2,
        2 + random.nextDouble(),
        1.2,
        2 + random.nextDouble(),
      ];
  }
}

CurveFormula _formula(math.Random random, {required bool closed}) {
  final radialA = (random.nextDouble() * 0.08) * (random.nextBool() ? 1 : -1);
  final radialB = (random.nextDouble() * 0.05) * (random.nextBool() ? 1 : -1);
  final room = 0.75 - radialA.abs() - radialB.abs();
  final radialBase = 0.58 + random.nextDouble() * (room - 0.58);
  final crossAmplitude = 0.03 + random.nextDouble() * 0.05;
  return CurveFormula(
    centerAngle: random.nextDouble() * 2 * math.pi,
    span: closed ? 2 * math.pi : math.pi,
    radialBase: radialBase,
    radialA: radialA,
    frequencyA: 1 + random.nextInt(3).toDouble(),
    phaseA: random.nextDouble() * 2 * math.pi,
    radialB: radialB,
    frequencyB: 1 + random.nextInt(3).toDouble(),
    phaseB: random.nextDouble() * 2 * math.pi,
    crossAmplitude: crossAmplitude,
    crossFrequency: 1 + random.nextInt(3).toDouble(),
    crossPhase: random.nextDouble() * 2 * math.pi,
  );
}
