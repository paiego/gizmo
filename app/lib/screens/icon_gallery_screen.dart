import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

import '../theme.dart';
import '../widgets/icon_shapes.dart';
import '../widgets/icon_view.dart';

/// How many distinct icons the gallery shows.
const int galleryCount = 100;

/// Two columns, with about three and a half rows on screen.
const int galleryColumns = 2;
const double galleryVisibleRows = 3.5;
const double galleryGap = 12;
const double galleryPadding = 16;

/// One hundred legal icons that do not paint as the same picture.
final List<Assembly> galleryAssemblies = _pickGallery();

/// Row height that fits [galleryVisibleRows] in [viewportHeight].
double galleryRowExtent(double viewportHeight) {
  final inner = viewportHeight - galleryPadding - galleryGap * 3;
  if (inner <= 0) return 48;
  return inner / galleryVisibleRows;
}

class IconGalleryScreen extends StatelessWidget {
  const IconGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final look = GizmoLook.of(context);
    return Scaffold(
      backgroundColor: look.board,
      appBar: AppBar(
        backgroundColor: look.board,
        foregroundColor: look.ink,
        elevation: 0,
        title: const Text('Icons'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final extent = galleryRowExtent(constraints.maxHeight);
          final cellWidth = (constraints.maxWidth -
                  galleryPadding * 2 -
                  galleryGap * (galleryColumns - 1)) /
              galleryColumns;
          final iconSize = math.max(24.0, math.min(cellWidth, extent) - 20);
          return GridView.builder(
            key: const ValueKey('icon-gallery'),
            padding: const EdgeInsets.all(galleryPadding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: galleryColumns,
              mainAxisSpacing: galleryGap,
              crossAxisSpacing: galleryGap,
              mainAxisExtent: extent,
            ),
            itemCount: galleryAssemblies.length,
            itemBuilder: (context, index) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: look.paper,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: look.line),
                ),
                child: Center(
                  child: IconView(
                    key: ValueKey('gallery-icon-$index'),
                    assembly: galleryAssemblies[index],
                    size: iconSize,
                    palette: look.icons,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

List<Assembly> _pickGallery() {
  final picked = <Assembly>[];
  for (final assembly in _legalAssemblies()) {
    final distinct = picked.every((other) => !samePicture(other, assembly));
    if (!distinct) continue;
    picked.add(assembly);
    if (picked.length == galleryCount) break;
  }
  return picked;
}

Iterable<Assembly> _legalAssemblies() sync* {
  for (final body in BodyId.values) {
    for (final top in TopId.values) {
      for (final side in SideId.values) {
        if (top == TopId.none && side == SideId.none) continue;
        for (final hole in HoleId.values) {
          for (final color in ColorId.values) {
            for (final pulse in PulseId.values) {
              yield Assembly(
                body: body,
                top: top,
                side: side,
                hole: hole,
                color: color,
                pulse: pulse,
              );
            }
          }
        }
      }
    }
  }
}
