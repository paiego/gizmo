import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizmo/widgets/icon_paths.dart';
import 'package:gizmo/widgets/icon_view.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ink stays inside the centered 72 box and parts join', () {
    for (final body in BodyId.values) {
      for (final top in TopId.values) {
        for (final side in SideId.values) {
          if (top == TopId.none && side == SideId.none) continue;
          for (final hole in HoleId.values) {
            final assembly = Assembly(
              body: body,
              top: top,
              side: side,
              hole: hole,
              color: ColorId.red,
            );
            final path = iconSilhouette(assembly);
            final bounds = path.getBounds();
            expect(
              bounds.left,
              greaterThanOrEqualTo(13.5),
              reason: '$assembly $bounds',
            );
            expect(
              bounds.top,
              greaterThanOrEqualTo(13.5),
              reason: '$assembly $bounds',
            );
            expect(
              bounds.right,
              lessThanOrEqualTo(86.5),
              reason: '$assembly $bounds',
            );
            expect(
              bounds.bottom,
              lessThanOrEqualTo(86.5),
              reason: '$assembly $bounds',
            );
            expect(
              path.contains(const Offset(50, 50)) || hole != HoleId.none,
              isTrue,
            );

            final contours = path.computeMetrics().length;
            final loop = top == TopId.loop;
            final handle = side == SideId.handle;
            final cut = hole != HoleId.none;
            if (!loop && !handle && !cut) {
              expect(contours, 1, reason: '$assembly split into $contours');
            } else if (loop && cut && !handle) {
              expect(contours, greaterThanOrEqualTo(2), reason: '$assembly');
            }
            if (hole == HoleId.round || hole == HoleId.slot) {
              expect(
                path.contains(const Offset(50, 50)),
                isFalse,
                reason: '$assembly hole is filled',
              );
            }
          }
        }
      }
    }
  });

  test('attached parts are at least 14 units on one side', () {
    for (final body in BodyId.values) {
      for (final top in TopId.values) {
        if (top == TopId.none) continue;
        final glyph = topGlyph(body, top)!;
        final bounds = glyph.outline.getBounds();
        expect(
          mathMax(bounds.width, bounds.height),
          greaterThanOrEqualTo(14),
          reason: '$body $top $bounds',
        );
      }
      for (final side in SideId.values) {
        if (side == SideId.none) continue;
        final bounds = sideGlyph(body, side)!.getBounds();
        expect(
          mathMax(bounds.width, bounds.height),
          greaterThanOrEqualTo(14),
          reason: '$body $side $bounds',
        );
      }
    }
  });

  test('a part stays attached to the body', () {
    const samples = [
      (BodyId.disc, TopId.knob, SideId.none),
      (BodyId.slab, TopId.horn, SideId.tab),
      (BodyId.wedge, TopId.none, SideId.wing),
      (BodyId.arch, TopId.knob, SideId.tab),
    ];
    for (final sample in samples) {
      final path = iconSilhouette(
        Assembly(
          body: sample.$1,
          top: sample.$2,
          side: sample.$3,
          hole: HoleId.none,
          color: ColorId.blue,
        ),
      );
      expect(path.contains(const Offset(50, 58)), isTrue, reason: '$sample');
      expect(path.computeMetrics().length, 1, reason: '$sample');
    }
  });

  testWidgets('icons paint on the board', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFFEEEEEE),
          body: Center(
            child: IconView(
              assembly: Assembly(
                body: BodyId.arch,
                top: TopId.loop,
                side: SideId.handle,
                hole: HoleId.slot,
                color: ColorId.amber,
              ),
              size: 220,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(IconView), findsOneWidget);
  });
}

double mathMax(double a, double b) => a > b ? a : b;
