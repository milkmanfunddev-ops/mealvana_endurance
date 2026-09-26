import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The last education rows the server answered, kept on the device so Learn
/// offline shows the lessons from the last load instead of claiming there
/// are none (testing-wave 117-008). A read cache of server content, not
/// athlete data: written only after a good fetch, read only when a fetch
/// fails, per device.
class EducationCache {
  const EducationCache(this._prefs);

  final SharedPreferences _prefs;

  static const String key = 'education.published_rows';

  /// The cached rows as the server sent them, or null when nothing was ever
  /// loaded here (or the stored value is unreadable).
  List<Map<String, dynamic>>? read() {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<void> write(List<dynamic> rows) =>
      _prefs.setString(key, jsonEncode(rows));
}
