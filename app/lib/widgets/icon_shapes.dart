import 'dart:ui';

import 'package:gizmo_rules/gizmo_rules.dart' hide shapePoints, measuredRadius, iconCenter;
import 'package:gizmo_rules/gizmo_rules.dart' as rules
    show measuredRadius, shapePoints;

export 'package:gizmo_rules/gizmo_rules.dart'
    hide shapePoints, measuredRadius, iconCenter;

/// Center of [iconRadius] in the 100-unit box (Flutter [Offset]).
const Offset iconCenter = Offset(50, 50);

Path shapePath(IconShape shape) {
  if (shape.kind == IconShapeKind.circle) {
    return Path()
      ..addOval(Rect.fromCircle(center: iconCenter, radius: shape.radius));
  }
  return Path()..addPolygon(shapePoints(shape), true);
}

/// Greatest distance from [iconCenter] to a point on [shape].
double measuredRadius(IconShape shape) => rules.measuredRadius(shape);

/// Outline points. A circle reports the four compass points of its radius.
List<Offset> shapePoints(IconShape shape) {
  return [
    for (final point in rules.shapePoints(shape)) Offset(point.dx, point.dy),
  ];
}
