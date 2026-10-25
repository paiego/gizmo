import 'package:shared_preferences/shared_preferences.dart';

class NameStore {
  static const storageKey = 'player_name';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(storageKey);
    if (name == null || name.isEmpty) return null;
    return name;
  }

  Future<void> write(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, name);
  }
}
