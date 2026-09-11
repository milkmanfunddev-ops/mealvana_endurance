import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/prefs_provider.dart';

part 'vana_ambient_store.g.dart';

/// Which conversation the Vana sheet is holding today, per person, on this
/// device.
///
/// One value per user, `YYYY-MM-DD|<conversationId>`. A value from another day
/// reads as nothing, so the first sheet of a new day starts a new
/// conversation without anything having to clear the old one.
class VanaAmbientStore {
  const VanaAmbientStore(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String userId) => 'vana.ambient_conversation.$userId';

  /// The conversation held for [day], or null when there is none yet.
  String? read({required String userId, required String day}) {
    final raw = _prefs.getString(_key(userId));
    if (raw == null) return null;
    final bar = raw.indexOf('|');
    if (bar <= 0 || raw.substring(0, bar) != day) return null;
    final id = raw.substring(bar + 1);
    return id.isEmpty ? null : id;
  }

  Future<void> write({
    required String userId,
    required String day,
    required String conversationId,
  }) => _prefs.setString(_key(userId), '$day|$conversationId');
}

@riverpod
VanaAmbientStore vanaAmbientStore(Ref ref) =>
    VanaAmbientStore(ref.watch(sharedPreferencesProvider));
