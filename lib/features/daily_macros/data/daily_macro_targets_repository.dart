import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../domain/daily_macro_targets.dart';
import '../domain/enums.dart';

part 'daily_macro_targets_repository.g.dart';

@riverpod
DailyMacroTargetsRepository dailyMacroTargetsRepository(Ref ref) {
  return DailyMacroTargetsRepository(
    database: ref.read(appDatabaseProvider),
    supabase: Supabase.instance.client,
  );
}

class DailyMacroTargetsRepository {
  const DailyMacroTargetsRepository({
    required AppDatabase database,
    required SupabaseClient supabase,
  })  : _database = database,
        _supabase = supabase;

  final AppDatabase _database;
  final SupabaseClient _supabase;

  /// Get cached macro targets for a specific date
  Future<DailyMacroTargets?> getCachedForDate(String userId, DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    final results = await _database.customSelect(
      'SELECT * FROM daily_macro_targets WHERE user_id = ? AND target_date = ? LIMIT 1',
      variables: [
        Variable.withString(userId),
        Variable.withInt(normalizedDate.millisecondsSinceEpoch),
      ],
    ).get();

    if (results.isEmpty) return null;

    final row = results.first;
    return _mapRowToDomain(row);
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
      await _supabase.from('daily_macro_targets').upsert(
        targets.toJson(),
        onConflict: 'user_id,target_date',
      );
    } catch (e) {
      // Don't rethrow - remote save failures shouldn't block the UI
    }
  }

  /// Get macro targets for a week range
  Future<List<DailyMacroTargets>> getWeekRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day);
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);

    final results = await _database.customSelect(
      '''SELECT * FROM daily_macro_targets
         WHERE user_id = ? AND target_date >= ? AND target_date <= ?
         ORDER BY target_date ASC''',
      variables: [
        Variable.withString(userId),
        Variable.withInt(normalizedStart.millisecondsSinceEpoch),
        Variable.withInt(normalizedEnd.millisecondsSinceEpoch),
      ],
    ).get();

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

  /// Invalidate all cached records for a user.
  /// Called when activities change (create/update/delete/import) since
  /// adjacent-day context (yesterday TSS, tomorrow load) means any activity
  /// change can affect multiple days' macro calculations.
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
      targetDate: DateTime.fromMillisecondsSinceEpoch(row.read<int>('target_date')),
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
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('updated_at')),
    );
  }
}
