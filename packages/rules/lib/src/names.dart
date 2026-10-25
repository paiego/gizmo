/// A player name after the identity rules have been applied.
class PlayerName {
  const PlayerName({required this.display, required this.key});

  /// Spelling with the ends trimmed and internal whitespace collapsed.
  final String display;

  /// Unicode lowercase of [display]. This is the identity key.
  final String key;

  @override
  bool operator ==(Object other) =>
      other is PlayerName && other.display == display && other.key == key;

  @override
  int get hashCode => Object.hash(display, key);

  @override
  String toString() => display;
}

/// Trims the ends, collapses internal whitespace, and checks the name rules.
///
/// Returns null when the result is empty, longer than 20 characters, or
/// contains anything other than letters, digits, and spaces.
PlayerName? parsePlayerName(String raw) {
  final display = raw.trim().replaceAll(RegExp(r'\s+', unicode: true), ' ');
  if (display.isEmpty || display.length > 20) return null;
  if (!RegExp(r'^[\p{L}\p{Nd} ]+$', unicode: true).hasMatch(display)) {
    return null;
  }
  return PlayerName(display: display, key: display.toLowerCase());
}
