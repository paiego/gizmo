import 'package:gizmo_rules/gizmo_rules.dart';
import 'package:test/test.dart';

void main() {
  test('trims, collapses whitespace, and lowercases the key', () {
    final name = parsePlayerName('  Paul   Smith  ');
    expect(name, isNotNull);
    expect(name!.display, 'Paul Smith');
    expect(name.key, 'paul smith');
  });

  test('Paul and paul are one player', () {
    expect(parsePlayerName('Paul')!.key, parsePlayerName('paul')!.key);
    expect(parsePlayerName('Paul')!.display, 'Paul');
    expect(parsePlayerName('paul')!.display, 'paul');
  });

  test('accepts letters, digits, and a single space', () {
    expect(parsePlayerName('player 1'), isNotNull);
    expect(parsePlayerName('Émile'), isNotNull);
    expect(parsePlayerName('A' * 20), isNotNull);
  });

  test('rejects empty, long, and punctuated names', () {
    expect(parsePlayerName(''), isNull);
    expect(parsePlayerName('   '), isNull);
    expect(parsePlayerName('A' * 21), isNull);
    expect(parsePlayerName('a-b'), isNull);
    expect(parsePlayerName('a_b'), isNull);
    expect(parsePlayerName('Paul!'), isNull);
  });
}
