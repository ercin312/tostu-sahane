import 'package:shared_preferences/shared_preferences.dart';

/// Mutfak fişi için tercih edilen Windows yazıcı adı.
abstract final class KitchenPrinterSettings {
  static const _key = 'kitchen_printer_name';

  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> save(String? printerName) async {
    final prefs = await SharedPreferences.getInstance();
    if (printerName == null || printerName.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, printerName);
    }
  }
}
