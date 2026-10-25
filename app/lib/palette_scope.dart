import 'package:flutter/widgets.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

class PaletteScope extends InheritedWidget {
  const PaletteScope({super.key, required this.palette, required super.child});

  final IconPalette palette;

  static IconPalette? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PaletteScope>()?.palette;
  }

  @override
  bool updateShouldNotify(PaletteScope oldWidget) =>
      palette != oldWidget.palette;
}
