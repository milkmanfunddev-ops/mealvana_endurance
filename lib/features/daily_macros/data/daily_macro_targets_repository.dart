import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../domain/daily_macro_targets.dart';
import '../domain/enums.dart';

part 'daily_macro_targets_repository.g.dart';

@riverpod
DailyMacroTargetsRepository dailyMacroTargetsRepository(Ref ref) {
  return DailyMacroTargetsRepository(
    database: ref.read(appDatabaseProvider),
    supabase: Supabase.instance.client,
    sentry: ref.read(sentryReporterProvider),
  );
}

class DailyMacroTargetsRepository {
  DailyMacroTargetsRepository({
    required AppDatabase database,
    required SupabaseClient supabase,
    SentryReporter sentry = const NoopSentryReporter(),
  }) : _database = database,
       _supabase = supabase,
       _sentry = sentry;

  final AppDatabase _database;
  final SupabaseClient _supabase;
  final SentryReporter _sentry;
  bool _reportedRemoteSaveFailureThisSession = false;

  /// The engine version a cached day must carry to be served. Rows with an
  /// OLDER `algorithm_version` are treated as misses so the next read
  /// recalculates with the current pipeline; rows with a NEWER one are
  /// accepted as-is.
  ///
  /// Why "older", not "different" (2026-08-19, Phase C of
  /// daily-macros-dashboard@v3 — Lee/Xuan ruling): an equality gate made the
  /// engine deploy and the app release inseparable. Deploy a newer engine
  /// first and every installed build read a day → judged it stale (v6 ≠ v5)
  /// → recalculated → got v6 again → still stale — an invalidation loop that
  /// strobed every consumer of dailyMacrosControllerProvider (the
  /// 2026-08-14 dashboard flicker). Accepting newer rows lets the engine move
  /// ahead of the client; raising this floor later invalidates the leftover
  /// old rows exactly once. The schema-change resync (app_config
  /// current_schema_version / VersionCheckService) stays the only forced
  /// wipe. Today's pre-v6 installs are served by the frozen legacy function
  /// `calculate-daily-macros`; this build calls `calculate-daily-macros-v6`.
  static const String _minAlgorithmVersion = 'v6.0.0';

  /// Semantic-ish compare of `vN.N.N` strings; anything unparsable is treated
  /// as older than everything (→ recalculated once).
  static bool _isOlderThan(String cached, String floor) {
    List<int> parse(String v) => v
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('.')
        .map((p) => int.tryParse(p) ?? -1)
        .toList();
    final a = parse(cached);
    final b = parse(floor);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x < 0) return true;
      if (x != y) return x < y;
    }
    return false;
  }

  /// Whether a cached row's engine version is stale (older than the floor).
  @visibleForTesting
  static bool isStaleAlgorithmVersion(String cachedVersion) =>
      _isOlderThan(cachedVersion, _minAlgorithmVersion);

  /// Get cached macro targets for a specific date
  Future<DailyMacroTargets?> getCachedForDate(
    String userId,
    DateTime date,
  ) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    final results = await _database
        .customSelect(
          'SELECT * FROM daily_macro_targets WHERE user_id = ? AND target_date = ? LIMIT 1',
          variables: [
            Variable.withString(userId),
            Variable.withInt(normalizedDate.millisecondsSinceEpoch),
          ],
        )
        .get();

    if (results.isEmpty) return null;

    final row = results.first;
    final cachedVersion = row.read<String>('algorithm_version');
    if (isStaleAlgorithmVersion(cachedVersion)) {
      // Stale cache — drop it so the caller recalculates fresh.
      await invalidateForDate(userId, normalizedDate);
      return null;
    }
    return _mapRowToDomain(row);
  }

  /// Batched variant of [getCachedForDate] for the 7-day window starting at
  /// [startOfWeek].
  ///
  /// Fetches the whole week in ONE query instead of one-per-day, eliminating
  /// the week-overview N+1 (Sentry MEALVANA-ENDURANCE-DEV-4C / DEV-49). Applies
  /// the same algorithm-version staleness check as [getCachedForDate], dropping
  /// stale rows so the caller recalculates them.
  ///
  /// Returns a map keyed by the row's normalized `target_date`
  /// (millisecondsSinceEpoch) for O(1) per-day lookup.
  Future<Map<int, DailyMacroTargets>> getCachedForWeek(
    String userId,
    DateTime startOfWeek,
  ) async {
    final normalizedStart = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );
    final normalizedEnd = normalizedStart.add(const Duration(days: 6));

    final results = await _database
        .customSelect(
          '''SELECT * FROM daily_macro_targets
         WHERE user_id = ? AND target_date >= ? AND target_date <= ?''',
          variables: [
            Variable.withString(userId),
            Variable.withInt(normalizedStart.millisecondsSinceEpoch),
            Variable.withInt(normalizedEnd.millisecondsSinceEpoch),
          ],
        )
        .get();

    final map = <int, DailyMacroTargets>{};
    final staleDates = <DateTime>[];
    for (final row in results) {
      final targetMillis = row.read<int>('target_date');
      final cachedVersion = row.read<String>('algorithm_version');
      if (isStaleAlgorithmVersion(cachedVersion)) {
        staleDates.add(DateTime.fromMillisecondsSinceEpoch(targetMillis));
        continue;
      }
      map[targetMillis] = _mapRowToDomain(row);
    }

    // Drop stale-version rows so the next calc refreshes them (mirrors the
    // single-date path in getCachedForDate).
    for (final date in staleDates) {
      await invalidateForDate(userId, date);
    }

    return map;
  }

  /// Save macro targets to local Drift database
  Future<void> saveToLocal(DailyMacroTargets targets) async {
    final normalizedDate = DateTime(
      targets.targetDate.year,
      targets.targetDate.month,
      targets.targetDate.day,
    );

    await _database.customStatement(
      '''INSERT OR REPLACE INTO daily_macro_targets
         (id, user_id, target_date, carb_g, prot_g, fat_g, tdee, rmr, session_kcal,
          neat_kcal, tef_kcal, mode, ea, ea_status, calculation_input,
          algorithm_version, needs_upload, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        targets.id,
        targets.userId,
        normalizedDate.millisecondsSinceEpoch,
        targets.carbG,
        targets.protG,
        targets.fatG,
        targets.tdee,
        targets.rmr,
        targets.sessionKcal,
        targets.neatKcal,
        targets.tefKcal,
        targets.mode,
        targets.ea,
        targets.eaStatus?.dbValue,
        _encodeCalculationInput(targets),
        targets.algorithmVersion,
        0, // needs_upload = false (just calculated)
        targets.createdAt.millisecondsSinceEpoch,
        targets.updatedAt.millisecondsSinceEpoch,
      ],
    );
  }

  /// The engine inputs the domain model carries but the scalar columns don't.
  ///
  /// Bug 2026-08-20-dashboard-weight-fallback-70kg: this column was never
  /// written by the local save path, so every cached read handed the display
  /// layer `weightKg == null` and the assembler priced EVERY athlete's
  /// formula-rung sessions at a silent 70 kg. F4 session cost is exactly
  /// linear in body weight (docs/ssot — invariant I6), so a wrong weight is a
  /// wrong number on every surface. Persist EVERY calculation_input field the
  /// domain models (`sources` and `delta` are documented fresh-calculation
  /// transients and intentionally not cached); the I7 seam round-trip test
  /// (test/features/daily_macros/daily_macro_targets_roundtrip_test.dart)
  /// fails if a field is added to the domain but dropped here or in
  /// [_mapRowToDomain].
  static String _encodeCalculationInput(DailyMacroTargets targets) {
    return jsonEncode({
      if (targets.weightKg != null) 'weight_kg': targets.weightKg,
      if (targets.bodyFatPct != null) 'body_fat_pct': targets.bodyFatPct,
      'energy_basis': targets.energyBasis,
    });
  }

  /// Parse the `calculation_input` JSON of a cached row. Legacy rows (written
  /// before the column was populated) and corrupt payloads read as absent —
  /// the domain's own defaults then apply, and the display layer must treat a
  /// missing weight as missing, never as a stand-in constant.
  static Map<String, dynamic>? _decodeCalculationInput(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  /// Save macro targets to Supabase
  Future<void> saveToRemote(DailyMacroTargets targets) async {
    try {
      await _supabase
          .from('daily_macro_targets')
          .upsert(targets.toJson(), onConflict: 'user_id,target_date');
    } catch (e) {
      // Don't rethrow - remote save failures shouldn't block the UI. Do make
      // them visible: RLS/user-id mismatches previously disappeared here and
      // made remote cache health impossible to diagnose.
      _sentry.addBreadcrumb(
        message: 'Daily macro remote save failed',
        category: 'daily_macros.remote_cache',
        level: SentryLevel.warning,
        data: {'error_type': e.runtimeType.toString()},
      );
      if (!_reportedRemoteSaveFailureThisSession) {
        _reportedRemoteSaveFailureThisSession = true;
        await _sentry.captureMessage(
          'Daily macro remote save failed',
          level: SentryLevel.warning,
          tags: {
            'component': 'daily_macros',
            'operation': 'remote_cache_save',
            'error_type': e.runtimeType.toString(),
          },
        );
      }
    }
  }

  /// Get macro targets for a week range
  Future<List<DailyMacroTargets>> getWeekRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);

    final results = await _database
        .customSelect(
          '''SELECT * FROM daily_macro_targets
         WHERE user_id = ? AND target_date >= ? AND target_date <= ?
         ORDER BY target_date ASC''',
          variables: [
            Variable.withString(userId),
            Variable.withInt(normalizedStart.millisecondsSinceEpoch),
            Variable.withInt(normalizedEnd.millisecondsSinceEpoch),
          ],
        )
        .get();

    return results.map(_mapRowToDomain).toList();
  }

  /// Invalidate cached record for a specific date
  Future<void> invalidateForDate(String userId, DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    await _database.customStatement(
      'DELETE FROM daily_macro_targets WHERE user_id = ? AND target_date = ?',
      [userId, normalizedDate.millisecondsSinceEpoch],
    );
  }

  /// Invalidate the cached records for a specific set of days, in one statement.
  ///
  /// This is the scoped alternative to [invalidateAllForUser]: an activity edit
  /// only staleness-affects a bounded window of days (see
  /// `macroDatesToInvalidate` in `domain/macro_cache_invalidation.dart`), so
  /// there's no reason to discard the user's whole cache. No-op on an empty set.
  Future<void> invalidateDates(String userId, Iterable<DateTime> dates) async {
    // Normalize to midnight — rows are keyed by midnight, and a caller may hand
    // us a timestamped date (or one nudged off midnight by a DST shift).
    final epochDays = <int>{
      for (final d in dates)
        DateTime(d.year, d.month, d.day).millisecondsSinceEpoch,
    };
    if (epochDays.isEmpty) return;

    // Chunk the IN list rather than binding one variable per day. Defensive, not
    // a fix for an observed crash: the sqlite3 we bundle allows 32766 variables,
    // and even a multi-year provider import lands well under that. But the
    // SQLite-guaranteed floor is 999, so a build change (system sqlite, another
    // platform) could start throwing here — and a throw means invalidation is
    // skipped and the user silently reads STALE macros, which is the worst way
    // for this to fail. Cheap insurance against that.
    const chunkSize = 400;
    final days = epochDays.toList(growable: false);
    for (var start = 0; start < days.length; start += chunkSize) {
      final chunk = days.sublist(
        start,
        (start + chunkSize).clamp(0, days.length),
      );
      final placeholders = List.filled(chunk.length, '?').join(', ');
      await _database.customStatement(
        'DELETE FROM daily_macro_targets '
        'WHERE user_id = ? AND target_date IN ($placeholders)',
        [userId, ...chunk],
      );
    }
  }

  /// Invalidate every cached day from [fromDate] (inclusive) forward — today
  /// and all future cached days — leaving earlier days untouched.
  ///
  /// This is the Q-016 window (platform-resolution.md, "Manual profile
  /// edits — which cached days recalculate", RULED 2026-08-17): a MANUAL
  /// write to an engine input recalculates today + future; past days are
  /// the historical record of what the athlete was told to eat and are
  /// never touched. Prefer this over [invalidateAllForUser] for any
  /// profile-driven invalidation.
  Future<void> invalidateFromDate(String userId, DateTime fromDate) async {
    final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
    await _database.customStatement(
      'DELETE FROM daily_macro_targets '
      'WHERE user_id = ? AND target_date >= ?',
      [userId, from.millisecondsSinceEpoch],
    );
  }

  /// Invalidate ALL cached records for a user — every date, for all time.
  ///
  /// Blunt instrument, kept as an escape hatch (e.g. an algorithm-version bump
  /// or a corrupted cache). Do NOT use it for ordinary activity edits: prefer
  /// [invalidateDates] with `macroDatesToInvalidate`, which drops only the days
  /// whose inputs actually moved. Wiping everything means every date the user
  /// later opens is a cache miss — an edge-function round trip each, and no
  /// macros at all while offline.
  Future<void> invalidateAllForUser(String userId) async {
    await _database.customStatement(
      'DELETE FROM daily_macro_targets WHERE user_id = ?',
      [userId],
    );
  }

  DailyMacroTargets _mapRowToDomain(QueryRow row) {
    // Bug 2026-08-20-dashboard-weight-fallback-70kg: the read path must map
    // every calculation_input field the domain carries (weight_kg,
    // body_fat_pct, energy_basis) — this mapper previously dropped all of
    // them, which is how the dashboard lost the athlete's weight on every
    // locally-cached day.
    final input = _decodeCalculationInput(
      row.readNullable<String>('calculation_input'),
    );
    return DailyMacroTargets(
      id: row.read<String>('id'),
      userId: row.read<String>('user_id'),
      targetDate: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('target_date'),
      ),
      carbG: row.read<double>('carb_g'),
      protG: row.read<double>('prot_g'),
      fatG: row.read<double>('fat_g'),
      tdee: row.read<double>('tdee'),
      rmr: row.read<double>('rmr'),
      sessionKcal: row.read<double>('session_kcal'),
      neatKcal: row.readNullable<double>('neat_kcal'),
      tefKcal: row.readNullable<double>('tef_kcal'),
      mode: row.read<String>('mode'),
      ea: row.readNullable<double>('ea'),
      eaStatus: EaStatus.fromDbValue(row.readNullable<String>('ea_status')),
      algorithmVersion: row.read<String>('algorithm_version'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('created_at'),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('updated_at'),
      ),
      weightKg: (input?['weight_kg'] as num?)?.toDouble(),
      bodyFatPct: (input?['body_fat_pct'] as num?)?.toDouble(),
      // Q-009: pre_override days suppress surplus copy; a cached read that
      // forgot this basis would lie a day after the EA gate raised the plan.
      energyBasis: input?['energy_basis'] as String? ?? 'as_computed',
    );
  }
}
