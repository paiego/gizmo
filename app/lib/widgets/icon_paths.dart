import 'dart:math' as math;
import 'dart:ui';

import 'package:gizmo_rules/gizmo_rules.dart';

/// Body, top, and side, without the hole cut out.
Path iconOutline(Assembly assembly) {
  var path = bodyPath(assembly.body);
  final top = topGlyph(assembly.body, assembly.top);
  if (top != null) {
    path = Path.combine(PathOperation.union, path, top.outline);
    final cutout = top.cutout;
    if (cutout != null) {
      path = Path.combine(PathOperation.difference, path, cutout);
    }
  }
  final side = sideGlyph(assembly.body, assembly.side);
  if (side != null) {
    path = Path.combine(PathOperation.union, path, side);
  }
  return path;
}

/// One filled silhouette in a 100 by 100 box.
///
/// The ink stays inside the centered 72 by 72 region. Holes and the loop's
/// inner circle are cutouts. A handle is a thick arch opening onto the body.
Path iconSilhouette(Assembly assembly) {
  final outline = iconOutline(assembly);
  final hole = holeGlyph(assembly.hole);
  if (hole == null) return outline;
  return Path.combine(PathOperation.difference, outline, hole);
}

/// True when [a] and [b] would paint as the same icon.
///
/// Equal assemblies match. A different color or pulse does not. Otherwise the
/// silhouettes are sampled on a 2-unit grid covering the ink.
bool samePicture(Assembly a, Assembly b) {
  if (a == b) return true;
  if (a.color != b.color || a.pulse != b.pulse) return false;
  final left = iconSilhouette(a);
  final right = iconSilhouette(b);
  for (var y = 14; y <= 86; y += 2) {
    for (var x = 14; x <= 86; x += 2) {
      final point = Offset(x.toDouble(), y.toDouble());
      if (left.contains(point) != right.contains(point)) return false;
    }
  }
  return true;
}

Path bodyPath(BodyId body) {
  switch (body) {
    case BodyId.disc:
      return Path()
        ..addOval(Rect.fromCircle(center: const Offset(50, 50), radius: 24));
    case BodyId.slab:
      return Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(27, 27, 73, 73),
            const Radius.circular(10),
          ),
        );
    case BodyId.wedge:
      return Path()
        ..moveTo(50, 27)
        ..lineTo(75, 73)
        ..lineTo(25, 73)
        ..close();
    case BodyId.arch:
      return Path()
        ..moveTo(27, 47.5)
        ..arcTo(
          Rect.fromCircle(center: const Offset(50, 47.5), radius: 23),
          math.pi,
          math.pi,
          false,
        )
        ..lineTo(73, 75.5)
        ..lineTo(27, 75.5)
        ..close();
  }
}

/// Smaller body shape in the middle, for [PulseId.core].
///
/// The painter clears the hole afterward, so this path may cross it.
Path coreGlyph(BodyId body) {
  switch (body) {
    case BodyId.disc:
      return Path()
        ..addOval(Rect.fromCircle(center: const Offset(50, 50), radius: 16));
    case BodyId.slab:
      return Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(38, 38, 62, 62),
            const Radius.circular(6),
          ),
        );
    case BodyId.wedge:
      return Path()
        ..moveTo(50, 39)
        ..lineTo(65.5, 67)
        ..lineTo(34.5, 67)
        ..close();
    case BodyId.arch:
      return Path()
        ..moveTo(35, 50)
        ..arcTo(
          Rect.fromCircle(center: const Offset(50, 50), radius: 15),
          math.pi,
          math.pi,
          false,
        )
        ..lineTo(65, 68)
        ..lineTo(35, 68)
        ..close();
  }
}

class TopGlyph {
  const TopGlyph(this.outline, [this.cutout]);

  final Path outline;
  final Path? cutout;
}

TopGlyph? topGlyph(BodyId body, TopId top) {
  final anchor = _topAnchor(body);
  switch (top) {
    case TopId.none:
      return null;
    case TopId.knob:
      return TopGlyph(
        Path()..addOval(Rect.fromCircle(center: anchor, radius: 9)),
      );
    case TopId.horn:
      final tipY = math.max(14.0, anchor.dy - 20);
      final baseY = tipY + 20;
      return TopGlyph(
        Path()
          ..moveTo(anchor.dx, tipY)
          ..lineTo(anchor.dx + 8, baseY)
          ..lineTo(anchor.dx - 8, baseY)
          ..close(),
      );
    case TopId.loop:
      return TopGlyph(
        Path()..addOval(Rect.fromCircle(center: anchor, radius: 10)),
        Path()..addOval(Rect.fromCircle(center: anchor, radius: 5)),
      );
  }
}

Path? sideGlyph(BodyId body, SideId side) {
  final spec = _sides[body]!;
  switch (side) {
    case SideId.none:
      return null;
    case SideId.tab:
      return Path()
        ..addRRect(RRect.fromRectAndRadius(spec.tab, const Radius.circular(4)));
    case SideId.handle:
      return _handle(spec.handle);
    case SideId.wing:
      return Path()
        ..moveTo(spec.wingTip.dx, spec.wingTip.dy)
        ..lineTo(spec.wingBase, spec.wingTip.dy - 11)
        ..lineTo(spec.wingBase, spec.wingTip.dy + 11)
        ..close();
  }
}

Path? holeGlyph(HoleId hole) {
  switch (hole) {
    case HoleId.none:
      return null;
    case HoleId.round:
      return Path()
        ..addOval(Rect.fromCircle(center: const Offset(50, 50), radius: 8));
    case HoleId.slot:
      return Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(39, 46, 61, 54),
            const Radius.circular(4),
          ),
        );
  }
}

Offset _topAnchor(BodyId body) {
  switch (body) {
    case BodyId.disc:
      return const Offset(50, 26);
    case BodyId.slab:
      return const Offset(50, 27);
    case BodyId.wedge:
      return const Offset(50, 27);
    case BodyId.arch:
      return const Offset(50, 24.5);
  }
}

Path _handle(Offset center) {
  const outerRadius = 14.0;
  const innerRadius = 8.0;
  return Path()
    ..moveTo(center.dx, center.dy - outerRadius)
    ..arcTo(
      Rect.fromCircle(center: center, radius: outerRadius),
      -math.pi / 2,
      math.pi,
      false,
    )
    ..lineTo(center.dx, center.dy + innerRadius)
    ..arcTo(
      Rect.fromCircle(center: center, radius: innerRadius),
      math.pi / 2,
      -math.pi,
      false,
    )
    ..close();
}

class _SideSpec {
  const _SideSpec({
    required this.handle,
    required this.tab,
    required this.wingTip,
    required this.wingBase,
  });

  final Offset handle;
  final Rect tab;
  final Offset wingTip;
  final double wingBase;
}

const _sides = {
  BodyId.disc: _SideSpec(
    handle: Offset(72, 50),
    tab: Rect.fromLTRB(68, 43, 84, 57),
    wingTip: Offset(86, 50),
    wingBase: 68,
  ),
  BodyId.slab: _SideSpec(
    handle: Offset(70, 50),
    tab: Rect.fromLTRB(67, 43, 83, 57),
    wingTip: Offset(85, 50),
    wingBase: 67,
  ),
  BodyId.wedge: _SideSpec(
    handle: Offset(57, 50),
    tab: Rect.fromLTRB(54, 43, 70, 57),
    wingTip: Offset(72, 50),
    wingBase: 54,
  ),
  BodyId.arch: _SideSpec(
    handle: Offset(71, 61.5),
    tab: Rect.fromLTRB(67, 54.5, 83, 68.5),
    wingTip: Offset(86, 61.5),
    wingBase: 68,
  ),
};
