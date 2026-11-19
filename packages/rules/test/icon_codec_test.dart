import 'dart:math';

import 'package:gizmo_rules/gizmo_rules.dart';
import 'package:test/test.dart';

void main() {
  group('assembly codec', () {
    test('encode decode round-trip', () {
      const assembly = Assembly(
        body: BodyId.wedge,
        top: TopId.horn,
        side: SideId.wing,
        hole: HoleId.slot,
        color: ColorId.teal,
        pulse: PulseId.rim,
      );
      final vector = encodeAssembly(assembly);
      expect(vector.first, iconCodecVersion);
      expect(decodeAssembly(vector), assembly);
    });
  });

  group('icon snapshot codec', () {
    test('encode decode round-trip', () {
      final rng = Random(42);
      Assembly? picked;
      for (final assembly in legalAssemblies()) {
        if (rng.nextBool()) {
          picked = assembly;
          break;
        }
      }
      picked ??= Assembly(
        body: BodyId.disc,
        top: TopId.knob,
        side: SideId.tab,
        hole: HoleId.round,
        color: ColorId.purple,
        pulse: PulseId.core,
      );
      final snapshot = materializeIcon(picked);
      final vector = encodeIconSnapshot(snapshot);
      expect(decodeIconSnapshot(vector), snapshot);
    });
  });

  group('materialize compare', () {
    test('decode assembly materializes to same picture', () {
      for (final assembly in legalAssemblies().take(80)) {
        final snapshot = materializeIcon(assembly);
        final fromAssembly = materializeIcon(decodeAssembly(encodeAssembly(assembly)));
        expect(fromAssembly, snapshot);
        final fromSnapshot = decodeIconSnapshot(encodeIconSnapshot(snapshot));
        expect(fromSnapshot, snapshot);
      }
    });

    test('high-similarity decoy round-trip snapshot equality', () {
      final round = buildRound(
        level: 7,
        random: Random(7),
        decoySimilarity: 1,
        levelBasedProximity: false,
      );
      for (final choice in round.choices) {
        expect(
          decodeIconSnapshot(encodeIconSnapshot(choice.appearance)),
          choice.appearance,
        );
        expect(decodeAssembly(encodeAssembly(choice.assembly)), choice.assembly);
      }
      expect(
        decodeIconSnapshot(encodeIconSnapshot(round.baseline)),
        round.baseline,
      );
    });
  });
}