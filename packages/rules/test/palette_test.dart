import 'dart:math' as math;

import 'package:gizmo_rules/gizmo_rules.dart';
import 'package:test/test.dart';

void main() {
  test('warm is the original ring and the default', () {
    expect(iconPalettes.first, warmPalette);
    expect(warmPalette.values, colorValue);
    expect(warmPalette.values, {
      ColorId.red: 0xFFE53935,
      ColorId.orange: 0xFFFB8C00,
      ColorId.amber: 0xFFF9A825,
      ColorId.green: 0xFF43A047,
      ColorId.teal: 0xFF00897B,
      ColorId.blue: 0xFF1E88E5,
      ColorId.purple: 0xFF8E24AA,
      ColorId.pink: 0xFFD81B60,
    });
    expect(paletteById(null), warmPalette);
    expect(paletteById('missing'), warmPalette);
    expect(paletteById('warm'), warmPalette);
  });

  test('each palette keeps eight opaque slots', () {
    expect(iconPalettes.map((palette) => palette.id).toSet(), hasLength(4));
    for (final palette in iconPalettes) {
      expect(palette.values.keys.toSet(), ColorId.values.toSet());
      expect(palette.values.values.toSet(), hasLength(8));
      for (final argb in palette.values.values) {
        expect(argb & 0xFF000000, 0xFF000000, reason: palette.id);
      }
    }
  });

  test('cold, forest, and ink stay readable and distinct', () {
    final board = _luminance(0xFFEEEEEE);
    for (final palette in [coldPalette, forestPalette, inkPalette]) {
      for (final color in ColorId.values) {
        expect(palette.values[color], isNot(colorValue[color]));
        final contrast = _contrast(_luminance(palette.values[color]!), board);
        expect(contrast, greaterThanOrEqualTo(3), reason: palette.id);
      }
    }

    for (final argb in coldPalette.values.values) {
      final hue = _hue(argb);
      expect(hue, inInclusiveRange(160, 325), reason: hue.toString());
    }

    final forestHues = forestPalette.values.values.map(_hue).toList();
    expect(forestHues.where((hue) => hue >= 10 && hue <= 60), hasLength(3));
    expect(
      forestHues.where((hue) => hue >= 70 && hue <= 180),
      hasLength(greaterThanOrEqualTo(4)),
    );

    final inkHues = inkPalette.values.values.map(_hue).toList();
    expect(inkHues.where((hue) => hue <= 40 || hue >= 340), isNotEmpty);
    expect(inkHues.where((hue) => hue >= 80 && hue <= 160), isNotEmpty);
    expect(inkHues.where((hue) => hue >= 200 && hue <= 280), isNotEmpty);
  });
}

double _contrast(double foreground, double background) {
  final lighter = math.max(foreground, background);
  final darker = math.min(foreground, background);
  return (lighter + 0.05) / (darker + 0.05);
}

double _luminance(int argb) {
  double channel(int value) {
    final c = value / 255;
    return c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = channel((argb >> 16) & 0xFF);
  final g = channel((argb >> 8) & 0xFF);
  final b = channel(argb & 0xFF);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _hue(int argb) {
  final r = ((argb >> 16) & 0xFF) / 255;
  final g = ((argb >> 8) & 0xFF) / 255;
  final b = (argb & 0xFF) / 255;
  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  final d = maxC - minC;
  if (d == 0) return 0;
  late final double sector;
  if (maxC == r) {
    sector = ((g - b) / d) % 6;
  } else if (maxC == g) {
    sector = (b - r) / d + 2;
  } else {
    sector = (r - g) / d + 4;
  }
  final hue = sector * 60;
  return hue < 0 ? hue + 360 : hue;
}
