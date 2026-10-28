import 'package:flutter/material.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

const boardColor = Color(0xFFEEEEEE);
const inkColor = Color(0xFF161616);
const mutedColor = Color(0xFF5E5E5E);
const paperColor = Color(0xFFFFFFFF);

/// Colors and the icon palette for the whole app.
///
/// Screens read this from the theme. Icon colors and page chrome move together.
class GizmoLook extends ThemeExtension<GizmoLook> {
  const GizmoLook({
    required this.id,
    required this.label,
    required this.board,
    required this.ink,
    required this.muted,
    required this.paper,
    required this.line,
    required this.icons,
  });

  final String id;
  final String label;
  final Color board;
  final Color ink;
  final Color muted;
  final Color paper;
  final Color line;
  final IconPalette icons;

  static GizmoLook of(BuildContext context) {
    return Theme.of(context).extension<GizmoLook>() ?? warmLook;
  }

  @override
  GizmoLook copyWith({
    String? id,
    String? label,
    Color? board,
    Color? ink,
    Color? muted,
    Color? paper,
    Color? line,
    IconPalette? icons,
  }) {
    return GizmoLook(
      id: id ?? this.id,
      label: label ?? this.label,
      board: board ?? this.board,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      paper: paper ?? this.paper,
      line: line ?? this.line,
      icons: icons ?? this.icons,
    );
  }

  @override
  GizmoLook lerp(GizmoLook? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

const warmLook = GizmoLook(
  id: 'warm',
  label: 'Warm',
  board: boardColor,
  ink: inkColor,
  muted: mutedColor,
  paper: paperColor,
  line: Color(0xFFD5D5D5),
  icons: warmPalette,
);

const coldLook = GizmoLook(
  id: 'cold',
  label: 'Cold',
  board: Color(0xFFE6EEF2),
  ink: Color(0xFF102028),
  muted: Color(0xFF4A6270),
  paper: Color(0xFFF7FBFC),
  line: Color(0xFFC5D5DE),
  icons: coldPalette,
);

const forestLook = GizmoLook(
  id: 'forest',
  label: 'Forest',
  board: Color(0xFFE7E4D8),
  ink: Color(0xFF1C2416),
  muted: Color(0xFF5C6552),
  paper: Color(0xFFF6F4EC),
  line: Color(0xFFD0CBBA),
  icons: forestPalette,
);

const inkLook = GizmoLook(
  id: 'ink',
  label: 'Ink',
  board: Color(0xFF161616),
  ink: Color(0xFFF4F1EA),
  muted: Color(0xFFB7B1A6),
  paper: Color(0xFF242424),
  line: Color(0xFF3A3A3A),
  icons: inkPalette,
);

const gizmoLooks = <GizmoLook>[warmLook, coldLook, forestLook, inkLook];

GizmoLook lookById(String? id) {
  for (final look in gizmoLooks) {
    if (look.id == id) return look;
  }
  return warmLook;
}

ThemeData buildGizmoTheme([GizmoLook look = warmLook]) {
  const family = 'Fraunces';
  final dark = look.board.computeLuminance() < 0.4;
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: family,
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: look.board,
    colorScheme: ColorScheme.fromSeed(
      seedColor: look.ink,
      brightness: dark ? Brightness.dark : Brightness.light,
      surface: look.board,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: look.board,
    textTheme: base.textTheme.apply(
      fontFamily: family,
      bodyColor: look.ink,
      displayColor: look.ink,
    ),
    primaryTextTheme: base.primaryTextTheme.apply(
      fontFamily: family,
      bodyColor: look.ink,
      displayColor: look.ink,
    ),
    splashColor: look.ink.withValues(alpha: 0.08),
    highlightColor: look.ink.withValues(alpha: 0.04),
    extensions: [look],
  );
}
