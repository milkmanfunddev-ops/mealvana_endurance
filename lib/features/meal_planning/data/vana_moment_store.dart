import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/prefs_provider.dart';

part 'vana_moment_store.g.dart';

/// What today's moments have done, on this device: which rang, which were
/// answered, and where each one's opening sits in the day's conversation.
class VanaMomentDay {
  const VanaMomentDay({
    this.rung = const {},
    this.answered = const {},
    this.starts = const {},
  });

  /// Keys of moments that have rung (vana-moment spec, Cadence).
  final Set<String> rung;

  /// Keys of moments the athlete answered (VM-3).
  final Set<String> answered;

  /// Per moment key, the index of its opening turn in the day's ambient
  /// conversation, once written there (VM-1).
  final Map<String, int> starts;

  VanaMomentDay copyWith({
    Set<String>? rung,
    Set<String>? answered,
    Map<String, int>? starts,
  }) => VanaMomentDay(
    rung: rung ?? this.rung,
    answered: answered ?? this.answered,
    starts: starts ?? this.starts,
  );
}

/// One value per user: `YYYY-MM-DD|<json>`. A value from another day reads as
/// nothing, so a new day starts clean without anything having to clear it.
class VanaMomentStore {
  const VanaMomentStore(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String userId) => 'vana.moments.$userId';

  VanaMomentDay read({required String userId, required String day}) {
    final raw = _prefs.getString(_key(userId));
    if (raw == null) return const VanaMomentDay();
    final bar = raw.indexOf('|');
    if (bar <= 0 || raw.substring(0, bar) != day) return const VanaMomentDay();
    try {
      final json = jsonDecode(raw.substring(bar + 1)) as Map<String, dynamic>;
      return VanaMomentDay(
        rung: {...(json['rung'] as List? ?? const []).cast<String>()},
        answered: {...(json['answered'] as List? ?? const []).cast<String>()},
        starts: {
          for (final e in (json['starts'] as Map? ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        },
      );
    } catch (_) {
      // A value this build cannot read is no record: the worst case is one
      // more ring.
      return const VanaMomentDay();
    }
  }

  Future<void> write({
    required String userId,
    required String day,
    required VanaMomentDay record,
  }) => _prefs.setString(
    _key(userId),
    '$day|${jsonEncode({'rung': record.rung.toList(), 'answered': record.answered.toList(), 'starts': record.starts})}',
  );
}

@riverpod
VanaMomentStore vanaMomentStore(Ref ref) =>
    VanaMomentStore(ref.watch(sharedPreferencesProvider));
