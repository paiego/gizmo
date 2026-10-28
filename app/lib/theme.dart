import 'package:flutter/material.dart';

const boardColor = Color(0xFFEEEEEE);
const inkColor = Color(0xFF161616);
const mutedColor = Color(0xFF5E5E5E);
const paperColor = Color(0xFFFFFFFF);

ThemeData buildGizmoTheme() {
  const family = 'Fraunces';
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: family,
    scaffoldBackgroundColor: boardColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: inkColor,
      brightness: Brightness.light,
      surface: boardColor,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: family,
      bodyColor: inkColor,
      displayColor: inkColor,
    ),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: family),
    splashColor: const Color(0x14161616),
    highlightColor: const Color(0x0A161616),
  );
}
