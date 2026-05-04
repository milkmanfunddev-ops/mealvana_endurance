import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../auth/domain/user_preferences.dart';
import '../data/daily_macro_targets_repository.dart';
import '../domain/daily_macro_targets.dart';

part 'daily_macro_service.g.dart';

/// Surfaces *why* a macro calculation failed. The controller catches this and
/// shows the message on screen instead of the generic empty state.
class DailyMacroCalculationException implements Exception {
  final String reason;
  const DailyMacroCalculationException(this.reason);

  @override
  String toString() => reason;
}

@riverpod
DailyMacroService dailyMacroService(Ref ref) {
  return DailyMacroService(
    repository: ref.read(dailyMacroTargetsRepositoryProvider),
    database: ref.read(appDatabaseProvider),
    supabase: Supabase.instance.client,
  );
}

class DailyMacroService {
  const DailyMacroService({
    required DailyMacroTargetsRepository repository,
    required AppDatabase database,
    required SupabaseClient supabase,
  })  : _repository = repository,
        _database = database,
        _supabase = supabase;

  final DailyMacroTargetsRepository _repository;
  final AppDatabase _database;
  final SupabaseClient _supabase;

  /// Calculate daily macros for a specific date.
  /// Uses cache when available, otherwise calls the edge function.
  Future<DailyMacroTargets?> calculateForDate(
    String userId,
    DateTime date,
    UserProfile profile,
  ) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // 0. Profile completeness — required by the edge function's validateInput.
    // Surface a precise reason so the UI can guide the user to onboarding /
    // preferences instead of dumping them into a generic empty state.
    if (profile.weightPounds <= 0) {
      throw const DailyMacroCalculationException(
        'Your weight is missing. Set it in Settings → Preferences → Profile.',
      );
    }
    if (profile.heightFeet <= 0 && profile.heightInches <= 0) {
      throw const DailyMacroCalculationException(
        'Your height is missing. Set it in Settings → Preferences → Profile.',
      );
    }
    if (profile.age <= 0) {
      throw const DailyMacroCalculationException(
        'Your birthday is missing. Set it in Settings → Preferences → Profile.',
      );
    }

    // 1. Check cache
    final cached = await _repository.getCachedForDate(userId, normalizedDate);
    if (cached != null) return cached;

    // 2. Load activities for target date
    final sessions = await _loadSessionsForDate(userId, normalizedDate);

    // 3. Load multi-day context
    final yesterday = normalizedDate.subtract(const Duration(days: 1));
    final tomorrow = normalizedDate.add(const Duration(days: 1));
    final yesterdayContext = await _loadDayContext(userId, yesterday);
    final tomorrowContext = await _loadDayContext(userId, tomorrow);

    // 4. Calculate weekly hours ratio
    double? weeklyHoursRatio;
    if (profile.typicalWeeklyHours != null && profile.typicalWeeklyHours! > 0) {
      final actualWeeklyHours = await _calculateWeeklyHours(userId, normalizedDate);
      weeklyHoursRatio = actualWeeklyHours / profile.typicalWeeklyHours!;
    }

    // 5. Build input for edge function
    // Convert imperial to metric for the edge function
    final weightKg = profile.weightPounds * 0.453592;
    final heightCm = (profile.heightFeet * 12 + profile.heightInches) * 2.54;

    final input = {
      'user_id': userId,
      'date': normalizedDate.toIso8601String().split('T')[0],
      'sex': profile.gender == Gender.female ? 'female' : 'male',
      'age': profile.age,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'body_fat_pct': profile.bodyFatPct,
      'lifestyle': profile.lifestyle.dbValue,
      'typical_weekly_hours': profile.typicalWeeklyHours,
      'carb_cycle_opt_in': profile.carbCycleOptIn,
      'training_phase': profile.trainingPhase.dbValue,
      'sessions': sessions,
      'yesterday_tss': yesterdayContext['max_tss'],
      'yesterday_hours_since': yesterdayContext['hours_since'],
      'tomorrow_tss': tomorrowContext['max_tss'],
      'tomorrow_duration_hr': tomorrowContext['duration_hr'],
      'tomorrow_is_race': tomorrowContext['is_race'] ?? false,
      'weekly_hours_ratio': weeklyHoursRatio,
      'mode': 'prospective',
      if (profile.weightPoundsUpdatedAt != null)
        'user_weight_updated_at_seconds':
            profile.weightPoundsUpdatedAt!.millisecondsSinceEpoch ~/ 1000,
      if (profile.bodyFatPctUpdatedAt != null)
        'user_body_fat_updated_at_seconds':
            profile.bodyFatPctUpdatedAt!.millisecondsSinceEpoch ~/ 1000,
    };

    // 6. Call edge function
    try {
      final response = await _supabase.functions.invoke(
        'calculate-daily-macros',
        body: input,
      );

      if (response.status != 200) {
        if (kDebugMode) {
          print('calculate-daily-macros failed: ${response.status} ${response.data}');
        }
        // Surface the server-side reason (e.g. "weight_kg must be a positive
        // number <= 300") so the UI can show what's wrong instead of falling
        // through to a generic empty state.
        final data = response.data;
        final reason = data is Map && data['error'] is String
            ? data['error'] as String
            : 'Edge function returned status ${response.status}';
        throw DailyMacroCalculationException(reason);
      }

      final data = response.data as Map<String, dynamic>;

      // 7. Create domain object
      final targets = DailyMacroTargets.fromEdgeFunctionResponse(
        id: const Uuid().v4(),
        userId: userId,
        targetDate: normalizedDate,
        json: data,
      );

      // 8. Save to cache (local + remote)
      await _repository.saveToLocal(targets);
      // Fire and forget remote save
      _repository.saveToRemote(targets);

      return targets;
    } on DailyMacroCalculationException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('Error calling calculate-daily-macros: $e');
      }
      throw DailyMacroCalculationException(e.toString());
    }
  }

  /// Get weekly overview (7 days centered on the given date's week)
  Future<List<DailyMacroTargets?>> getWeekOverview(
    String userId,
    DateTime date,
    UserProfile profile,
  ) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    // Start of week (Sunday) — matches calendar_week_view_kyle.dart
    final startOfWeek = normalizedDate.subtract(Duration(days: normalizedDate.weekday % 7));

    final results = <DailyMacroTargets?>[];
    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final cached = await _repository.getCachedForDate(userId, day);
      results.add(cached);
    }
    return results;
  }

  /// Calculate all 7 days of the week in a single edge function call.
  /// Cached days are skipped; only uncached days are sent in the payload.
  Future<List<DailyMacroTargets?>> calculateWeek(
    String userId,
    DateTime anyDateInWeek,
    UserProfile profile,
  ) async {
    final normalized = DateTime(anyDateInWeek.year, anyDateInWeek.month, anyDateInWeek.day);
    final startOfWeek = normalized.subtract(Duration(days: normalized.weekday % 7));

    // 1. Check cache for all 7 days
    final cached = <int, DailyMacroTargets>{};
    final uncachedIndices = <int>[];
    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final c = await _repository.getCachedForDate(userId, day);
      if (c != null) {
        cached[i] = c;
      } else {
        uncachedIndices.add(i);
      }
    }

    // All cached → return immediately
    if (uncachedIndices.isEmpty) {
      return List.generate(7, (i) => cached[i]);
    }

    // 2. Build day inputs for uncached days
    final dayInputs = <Map<String, dynamic>>[];
    final dayIndexMap = <int, int>{}; // dayInputs index → week index

    for (final idx in uncachedIndices) {
      final day = startOfWeek.add(Duration(days: idx));
      final sessions = await _loadSessionsForDate(userId, day);
      final yesterday = day.subtract(const Duration(days: 1));
      final tomorrow = day.add(const Duration(days: 1));
      final yesterdayCtx = await _loadDayContext(userId, yesterday);
      final tomorrowCtx = await _loadDayContext(userId, tomorrow);

      double? weeklyHoursRatio;
      if (profile.typicalWeeklyHours != null && profile.typicalWeeklyHours! > 0) {
        final actual = await _calculateWeeklyHours(userId, day);
        weeklyHoursRatio = actual / profile.typicalWeeklyHours!;
      }

      dayIndexMap[dayInputs.length] = idx;
      dayInputs.add({
        'sessions': sessions,
        'yesterday_tss': yesterdayCtx['max_tss'],
        'yesterday_hours_since': yesterdayCtx['hours_since'],
        'tomorrow_tss': tomorrowCtx['max_tss'],
        'tomorrow_duration_hr': tomorrowCtx['duration_hr'],
        'tomorrow_is_race': tomorrowCtx['is_race'] ?? false,
        'weekly_hours_ratio': weeklyHoursRatio,
      });
    }

    // 3. Single edge function call
    final weightKg = profile.weightPounds * 0.453592;
    final heightCm = (profile.heightFeet * 12 + profile.heightInches) * 2.54;

    final payload = {
      'user_id': userId,
      'date': startOfWeek.toIso8601String().split('T')[0],
      'scope': 'week',
      'sex': profile.gender == Gender.female ? 'female' : 'male',
      'age': profile.age,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'body_fat_pct': profile.bodyFatPct,
      'lifestyle': profile.lifestyle.dbValue,
      'typical_weekly_hours': profile.typicalWeeklyHours,
      'carb_cycle_opt_in': profile.carbCycleOptIn,
      'training_phase': profile.trainingPhase.dbValue,
      'mode': 'prospective',
      'days': dayInputs,
      if (profile.weightPoundsUpdatedAt != null)
        'user_weight_updated_at_seconds':
            profile.weightPoundsUpdatedAt!.millisecondsSinceEpoch ~/ 1000,
      if (profile.bodyFatPctUpdatedAt != null)
        'user_body_fat_updated_at_seconds':
            profile.bodyFatPctUpdatedAt!.millisecondsSinceEpoch ~/ 1000,
    };

    try {
      final response = await _supabase.functions.invoke(
        'calculate-daily-macros',
        body: payload,
      );

      if (response.status != 200) {
        if (kDebugMode) {
          print('calculate-daily-macros (week) failed: ${response.status} ${response.data}');
        }
        return List.generate(7, (i) => cached[i]);
      }

      final data = response.data as Map<String, dynamic>;
      final dayResults = (data['days'] as List).cast<Map<String, dynamic>>();

      // 4. Parse results, save to cache, merge with cached entries
      for (int j = 0; j < dayResults.length; j++) {
        final weekIdx = dayIndexMap[j]!;
        final day = startOfWeek.add(Duration(days: weekIdx));

        final targets = DailyMacroTargets.fromEdgeFunctionResponse(
          id: const Uuid().v4(),
          userId: userId,
          targetDate: day,
          json: dayResults[j],
        );

        await _repository.saveToLocal(targets);
        _repository.saveToRemote(targets); // fire and forget
        cached[weekIdx] = targets;
      }

      return List.generate(7, (i) => cached[i]);
    } catch (e) {
      if (kDebugMode) {
        print('Error calling calculate-daily-macros (week): $e');
      }
      return List.generate(7, (i) => cached[i]);
    }
  }

  /// Load sessions for a date in the format expected by the edge function
  Future<List<Map<String, dynamic>>> _loadSessionsForDate(
    String userId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final results = await _database.customSelect(
      '''SELECT * FROM activities
         WHERE user_id = ? AND scheduled_date_time >= ? AND scheduled_date_time < ?
         AND deleted_at IS NULL
         ORDER BY scheduled_date_time ASC''',
      variables: [
        Variable.withString(userId),
        Variable.withDateTime(startOfDay),
        Variable.withDateTime(endOfDay),
      ],
    ).get();

    return results.map((row) {
      final durationMinutes = row.readNullable<int>('duration_minutes') ?? 60;
      final durationHr = durationMinutes / 60.0;

      // Convert intensity distribution percentages to 0-1 fractions
      final z1z2 = (row.readNullable<int>('intensity_z1_z2_pct') ?? 70) / 100.0;
      final z3z4 = (row.readNullable<int>('intensity_z3_z4_pct') ?? 20) / 100.0;
      final z5 = (row.readNullable<int>('intensity_z5_pct') ?? 10) / 100.0;

      // Map activity type
      final activityType = row.read<String>('activity_type');
      String sport;
      switch (activityType) {
        case 'cycling':
          sport = 'cycling';
          break;
        case 'swimming':
          sport = 'swimming';
          break;
        case 'strength':
          sport = 'strength';
          break;
        default:
          sport = 'running';
      }

      return {
        'sport': sport,
        'duration_hr': durationHr,
        'pct_conversational': z1z2,
        'pct_tempo': z3z4,
        'pct_allout': z5,
        'tss': row.readNullable<double>('tss'),
        // Server uses this to look up Garmin completion data for resolution.
        'activity_id': row.read<String>('id'),
      };
    }).toList();
  }

  /// Load context info for a day (yesterday/tomorrow)
  Future<Map<String, dynamic>> _loadDayContext(
    String userId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final results = await _database.customSelect(
      '''SELECT tss, duration_minutes, intensity_level, scheduled_date_time
         FROM activities
         WHERE user_id = ? AND scheduled_date_time >= ? AND scheduled_date_time < ?
         AND deleted_at IS NULL''',
      variables: [
        Variable.withString(userId),
        Variable.withDateTime(startOfDay),
        Variable.withDateTime(endOfDay),
      ],
    ).get();

    if (results.isEmpty) {
      return {'max_tss': null, 'hours_since': null, 'duration_hr': null, 'is_race': false};
    }

    double? maxTss;
    double totalDurationHr = 0;
    bool isRace = false;

    for (final row in results) {
      final tss = row.readNullable<double>('tss');
      if (tss != null && (maxTss == null || tss > maxTss)) {
        maxTss = tss;
      }
      final durationMin = row.readNullable<int>('duration_minutes') ?? 0;
      totalDurationHr += durationMin / 60.0;

      final intensity = row.readNullable<String>('intensity_level');
      if (intensity == 'race') isRace = true;
    }

    // Calculate hours since the activity (for yesterday context)
    double? hoursSince;
    if (results.isNotEmpty) {
      // Drift stores DateTimeColumn as epoch seconds
      final lastActivityTime = DateTime.fromMillisecondsSinceEpoch(
        results.last.read<int>('scheduled_date_time') * 1000,
      );
      hoursSince = DateTime.now().difference(lastActivityTime).inMinutes / 60.0;
    }

    return {
      'max_tss': maxTss,
      'hours_since': hoursSince,
      'duration_hr': totalDurationHr,
      'is_race': isRace,
    };
  }

  /// Calculate total training hours for the current week
  Future<double> _calculateWeeklyHours(String userId, DateTime date) async {
    final weekday = date.weekday;
    final startOfWeek = DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final results = await _database.customSelect(
      '''SELECT COALESCE(SUM(duration_minutes), 0) as total_minutes
         FROM activities
         WHERE user_id = ? AND scheduled_date_time >= ? AND scheduled_date_time < ?
         AND deleted_at IS NULL''',
      variables: [
        Variable.withString(userId),
        Variable.withDateTime(startOfWeek),
        Variable.withDateTime(endOfWeek),
      ],
    ).get();

    if (results.isEmpty) return 0;
    final totalMinutes = results.first.read<int>('total_minutes');
    return totalMinutes / 60.0;
  }
}
