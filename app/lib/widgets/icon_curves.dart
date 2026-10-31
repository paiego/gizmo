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

/// How far a stroke of [thickness] may place its centerline.
double curveReach(double thickness) => iconRadius - thickness / 2;

/// One connected curve.
///
/// For `t` in `[0, 1]`, with [reach] the greatest distance from [iconCenter]
/// the centerline may use:
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
/// so the centerline stays inside `0.95 * reach`.
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

  CurveFormula scaled(double factor) {
    return CurveFormula(
      centerAngle: centerAngle,
      span: span,
      radialBase: radialBase * factor,
      radialA: radialA * factor,
      frequencyA: frequencyA,
      phaseA: phaseA,
      radialB: radialB * factor,
      frequencyB: frequencyB,
      phaseB: phaseB,
      crossAmplitude: crossAmplitude * factor,
      crossFrequency: crossFrequency,
      crossPhase: crossPhase,
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
/// [thickness] is this curve's line thickness, in icon units.
/// [formula] is its own connected curve.
/// [color] is its own catalog color, looked up in the active palette.
class IconCurve {
  const IconCurve({
    required this.role,
    required this.formula,
    required this.thickness,
    required this.color,
  });

  final IconCurveRole role;
  final CurveFormula formula;
  final double thickness;
  final ColorId color;

  @override
  bool operator ==(Object other) =>
      other is IconCurve &&
      other.role == role &&
      other.formula == formula &&
      other.thickness == thickness &&
      other.color == color;

  @override
  int get hashCode => Object.hash(role, formula, thickness, color);
}

/// The curves that paint [assembly]. Parts are separate strokes, not one fill.
List<IconCurve> iconCurves(Assembly assembly) {
  return [
    _curve(assembly, IconCurveRole.body, 0, 6.2, 0.6),
    if (assembly.top != TopId.none)
      _curve(assembly, IconCurveRole.top, 2, 3.4, 0.4),
    if (assembly.side != SideId.none)
      _curve(assembly, IconCurveRole.side, 4, 4.6, 0.4),
    if (assembly.hole != HoleId.none)
      _curve(
        assembly,
        IconCurveRole.hole,
        5,
        2.6,
        0.3,
        closed: true,
        scale: 0.6,
      ),
    if (assembly.pulse == PulseId.core)
      _curve(
        assembly,
        IconCurveRole.core,
        1,
        5.0,
        0.3,
        closed: true,
        scale: 0.7,
      ),
    if (assembly.pulse == PulseId.rim)
      _curve(assembly, IconCurveRole.rim, 3, 7.5, 0.4, closed: true),
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

/// True when [a] and [b] would paint as the same icon.
///
/// Equal assemblies match. A different color or pulse does not. Otherwise
/// the curves' thicknesses, colors, and formulas are compared.
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
  double scale = 1,
}) {
  final random = math.Random(_seed(assembly, role));
  final thickness =
      thicknessBase + (random.nextDouble() - 0.5) * thicknessJitter;
  return IconCurve(
    role: role,
    formula: _formula(random, closed: closed).scaled(scale),
    thickness: thickness,
    color: _shift(assembly.color, colorShift),
  );
}

CurveFormula _formula(math.Random random, {required bool closed}) {
  final radialA = (random.nextDouble() * 0.08) * (random.nextBool() ? 1 : -1);
  final radialB = (random.nextDouble() * 0.05) * (random.nextBool() ? 1 : -1);
  final room = 0.75 - radialA.abs() - radialB.abs();
  final radialBase = 0.58 + random.nextDouble() * (room - 0.58);
  final crossAmplitude = 0.04 + random.nextDouble() * 0.08;
  return CurveFormula(
    centerAngle: random.nextDouble() * 2 * math.pi,
    span: closed ? 2 * math.pi : 2.6 + random.nextDouble() * 0.8,
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
