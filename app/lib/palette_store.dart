import 'package:shared_preferences/shared_preferences.dart';

class PaletteStore {
  static const storageKey = 'icon_palette';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(storageKey);
    if (id == null || id.isEmpty) return null;
    return id;
  }

  Future<void> write(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, id);
  }
}
