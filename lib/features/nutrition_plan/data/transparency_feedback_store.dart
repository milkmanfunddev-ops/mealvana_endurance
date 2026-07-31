import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/app_external_deps.dart';

/// Per-user thumbs-up/thumbs-down votes for transparency Q&A and calc-card
/// "Does this make sense?" footers. Stored locally in SharedPreferences as a
/// single JSON-encoded `Map<String, String>` keyed by a stable feedback key
/// (see [feedbackKey]). Vote values are `'up'` or `'down'`; absence of a key
/// means no vote.
class TransparencyFeedbackStore extends Notifier<Map<String, String>> {
  static const String _prefsKey = 'transparency_qa_feedback_v1';

  /// Build a stable key for a single feedback target.
  /// `kind` distinguishes the calc-card "Does this make sense?" thumb
  /// (`'calc'`) from per-question Full Story thumbs (`'qa'`).
  static String feedbackKey({
    required String kind,
    required String nutrient,
    required String phase,
    String? question,
  }) {
    final q = question ?? '';
    return '$kind|$nutrient|$phase|$q';
  }

  @override
  Map<String, String> build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = json.decode(raw);
      if (decoded is Map) {
        return {
          for (final entry in decoded.entries)
            entry.key.toString(): entry.value.toString(),
        };
      }
    } catch (_) {
      // Corrupt payload — drop it on the floor and start fresh.
    }
    return const {};
  }

  /// Returns the current vote (`'up'` / `'down'`) or null if none.
  String? voteFor(String key) => state[key];

  /// Toggle a vote: tapping the same direction clears, tapping the opposite
  /// switches.
  Future<void> toggle({required String key, required String vote}) async {
    final current = state[key];
    final next = Map<String, String>.from(state);
    if (current == vote) {
      next.remove(key);
    } else {
      next[key] = vote;
    }
    state = next;
    await _persist(next);
  }

  Future<void> _persist(Map<String, String> map) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (map.isEmpty) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, json.encode(map));
    }
  }
}

/// Provider for the transparency feedback store. Loads from SharedPreferences
/// on first read; subsequent reads use the in-memory state.
final transparencyFeedbackStoreProvider =
    NotifierProvider<TransparencyFeedbackStore, Map<String, String>>(
      TransparencyFeedbackStore.new,
    );
