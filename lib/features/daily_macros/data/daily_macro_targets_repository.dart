import 'package:drift/drift.dart';
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

  /// Algorithm version this client expects. Cached rows from older versions
  /// are treated as misses so the next read recalculates with the current
  /// pipeline.
  ///
  /// DEPLOY-COUPLED — flip to 'v6.0.0' IN THE SAME RELEASE that deploys the
  /// ratified daily-macros-dashboard@v1 engine, never before. Expecting a
  /// version the deployed edge function doesn't emit yet makes every cache
  /// read a miss: drop row → recalc → server returns the old version → row
  /// judged stale again → an invalidation loop that strobes every consumer
  /// of dailyMacrosControllerProvider (the dashboard flicker of 2026-08-14).
  static const String _expectedAlgorithmVersion = 'v5.0.0';

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
    if (cachedVersion != _expectedAlgorithmVersion) {
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
      if (cachedVersion != _expectedAlgorithmVersion) {
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
          neat_kcal, tef_kcal, mode, ea, ea_status, algorithm_version, needs_upload,
          created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
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
        targets.algorithmVersion,
        0, // needs_upload = false (just calculated)
        targets.createdAt.millisecondsSinceEpoch,
        targets.updatedAt.millisecondsSinceEpoch,
      ],
    );
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
    );
  }
}
