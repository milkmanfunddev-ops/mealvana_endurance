import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/core/revisioned_single_flight.dart';
import '../../../shared/services/performance_telemetry.dart';
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

@Riverpod(keepAlive: true)
DailyMacroService dailyMacroService(Ref ref) {
  return DailyMacroService(
    repository: ref.read(dailyMacroTargetsRepositoryProvider),
    database: ref.read(appDatabaseProvider),
    supabase: Supabase.instance.client,
  );
}

class DailyMacroService {
  DailyMacroService({
    required DailyMacroTargetsRepository repository,
    required AppDatabase database,
    required SupabaseClient supabase,
  }) : _repository = repository,
       _database = database,
       _supabase = supabase;

  final DailyMacroTargetsRepository _repository;
  final AppDatabase _database;
  final SupabaseClient _supabase;

  final RevisionedSingleFlight<List<DailyMacroTargets?>> _weekCalculations =
      RevisionedSingleFlight<List<DailyMacroTargets?>>();
  int _activeWeekCalculations = 0;

  String? profileValidationError(UserProfile profile) {
    if (profile.weightPounds <= 0) {
      return 'Your weight is missing. Set it in Settings → Preferences → Profile.';
    }
    if (profile.heightFeet <= 0 && profile.heightInches <= 0) {
      return 'Your height is missing. Set it in Settings → Preferences → Profile.';
    }
    if (profile.age <= 0) {
      return 'Your birthday is missing. Set it in Settings → Preferences → Profile.';
    }
    return null;
  }

  /// Marks the affected weeks as changed. This does not prevent recalculation;
  /// it guarantees a change that arrives during a calculation gets a follow-up
  /// pass instead of being hidden by the in-flight result.
  void markMacroInputsChanged(String userId, Iterable<DateTime> dates) {
    final weekStarts = <DateTime>{for (final date in dates) _startOfWeek(date)};
    for (final weekStart in weekStarts) {
      final key = _weekKey(userId, weekStart);
      _weekCalculations.markChanged(key);
    }
    if (weekStarts.isNotEmpty) {
      PerformanceTelemetry.record(
        'Macro inputs changed',
        category: 'daily_macros',
        data: {'affected_weeks': weekStarts.length},
      );
    }
  }

  /// Calculate daily macros for a specific date.
  /// Uses cache when available, otherwise calls the edge function.
  Future<DailyMacroTargets?> calculateForDate(
    String userId,
    DateTime date,
    UserProfile profile,
  ) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // 0. Profile completeness — required by the edge function's validateInput.
    final validationError = profileValidationError(profile);
    if (validationError != null) {
      throw DailyMacroCalculationException(validationError);
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
      final actualWeeklyHours = await _calculateWeeklyHours(
        userId,
        normalizedDate,
      );
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
          print(
            'calculate-daily-macros failed: ${response.status} ${response.data}',
          );
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
    final startOfWeek = normalizedDate.subtract(
      Duration(days: normalizedDate.weekday % 7),
    );

    // Single batched query for the whole week (avoids the per-day N+1 —
    // Sentry MEALVANA-ENDURANCE-DEV-4C / DEV-49).
    final cachedByDate = await _repository.getCachedForWeek(
      userId,
      startOfWeek,
    );
    return List.generate(7, (i) {
      final day = startOfWeek.add(Duration(days: i));
      final key = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      return cachedByDate[key];
    });
  }

  /// Calculate all 7 days of the week in a single edge function call.
  /// Cached days are skipped; only uncached days are sent in the payload.
  Future<List<DailyMacroTargets?>> calculateWeek(
    String userId,
    DateTime anyDateInWeek,
    UserProfile profile,
  ) {
    final startOfWeek = _startOfWeek(anyDateInWeek);
    final key = _weekKey(userId, startOfWeek);
    Stopwatch? stopwatch;
    return _weekCalculations.run(
      key,
      operation: () => _calculateWeekOnce(userId, startOfWeek, profile),
      beforeRerun: () => _repository.invalidateDates(
        userId,
        List.generate(7, (i) => startOfWeek.add(Duration(days: i))),
      ),
      onJoin: () {
        PerformanceTelemetry.record(
          'Joined in-flight week macro calculation',
          category: 'daily_macros',
          data: {
            'week_start': _dateString(startOfWeek),
            'active_calculations': _activeWeekCalculations,
          },
        );
      },
      onPassStarted: () {
        stopwatch = Stopwatch()..start();
        _activeWeekCalculations++;
        PerformanceTelemetry.record(
          'Week macro calculation started',
          category: 'daily_macros',
          data: {
            'week_start': _dateString(startOfWeek),
            'active_calculations': _activeWeekCalculations,
          },
        );
      },
      onPassFinished: () {
        _activeWeekCalculations--;
        final completedStopwatch = stopwatch;
        completedStopwatch?.stop();
        PerformanceTelemetry.recordDuration(
          'daily_macros.calculate_week',
          completedStopwatch?.elapsed ?? Duration.zero,
          data: {
            'week_start': _dateString(startOfWeek),
            'active_calculations_after': _activeWeekCalculations,
          },
        );
      },
      onRerun: () {
        PerformanceTelemetry.record(
          'Week macro calculation rerunning after activity change',
          category: 'daily_macros',
          data: {'week_start': _dateString(startOfWeek)},
        );
      },
    );
  }

  Future<List<DailyMacroTargets?>> _calculateWeekOnce(
    String userId,
    DateTime startOfWeek,
    UserProfile profile,
  ) async {
    final validationError = profileValidationError(profile);
    if (validationError != null) {
      throw DailyMacroCalculationException(validationError);
    }

    // 1. Check cache for all 7 days — single batched query (avoids the per-day
    //    N+1: Sentry MEALVANA-ENDURANCE-DEV-4C / DEV-49).
    final cachedByDate = await _repository.getCachedForWeek(
      userId,
      startOfWeek,
    );
    final cached = <int, DailyMacroTargets>{};
    final uncachedIndices = <int>[];
    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final key = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      final c = cachedByDate[key];
      if (c != null) {
        cached[i] = c;
      } else {
        uncachedIndices.add(i);
      }
    }

    // All cached → return immediately
    if (uncachedIndices.isEmpty) {
      PerformanceTelemetry.record(
        'Week macro cache hit',
        category: 'daily_macros',
        data: {'week_start': _dateString(startOfWeek), 'cached_days': 7},
      );
      return List.generate(7, (i) => cached[i]);
    }

    PerformanceTelemetry.record(
      'Week macro cache miss',
      category: 'daily_macros',
      data: {
        'week_start': _dateString(startOfWeek),
        'cached_days': cached.length,
        'missing_days': uncachedIndices.length,
      },
    );

    // 2. Load all activity inputs needed for the week in one query, then build
    // each day's payload in memory. Previously this issued up to 28 sequential
    // queries (sessions + adjacent-day context + weekly hours for every day).
    final activityInputs = await _loadWeekActivityInputs(userId, startOfWeek);
    final dayInputs = <Map<String, dynamic>>[];
    final dayIndexMap = <int, int>{}; // dayInputs index → week index

    for (final idx in uncachedIndices) {
      final day = startOfWeek.add(Duration(days: idx));
      final yesterday = day.subtract(const Duration(days: 1));
      final tomorrow = day.add(const Duration(days: 1));
      final yesterdayCtx = activityInputs.contextFor(yesterday);
      final tomorrowCtx = activityInputs.contextFor(tomorrow);

      double? weeklyHoursRatio;
      if (profile.typicalWeeklyHours != null &&
          profile.typicalWeeklyHours! > 0) {
        final actual = activityInputs.weeklyHoursFor(day);
        weeklyHoursRatio = actual / profile.typicalWeeklyHours!;
      }

      dayIndexMap[dayInputs.length] = idx;
      dayInputs.add({
        'sessions': activityInputs.sessionsFor(day),
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
          print(
            'calculate-daily-macros (week) failed: ${response.status} ${response.data}',
          );
        }
        final data = response.data;
        final reason = data is Map && data['error'] is String
            ? data['error'] as String
            : 'Edge function returned status ${response.status}';
        throw DailyMacroCalculationException(reason);
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
    } on DailyMacroCalculationException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('Error calling calculate-daily-macros (week): $e');
      }
      throw DailyMacroCalculationException(e.toString());
    }
  }

  static DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday % 7));
  }

  static String _weekKey(String userId, DateTime weekStart) =>
      '$userId:${weekStart.millisecondsSinceEpoch}';

  static String _dateString(DateTime date) =>
      date.toIso8601String().split('T').first;

  Future<_WeekActivityInputs> _loadWeekActivityInputs(
    String userId,
    DateTime startOfWeek,
  ) async {
    // A Sunday–Saturday display week can touch two Monday-based training
    // weeks. start-6 through start+8 covers both weekly-hours windows plus the
    // yesterday/tomorrow context needed by the edge function.
    final rangeStart = startOfWeek.subtract(const Duration(days: 6));
    final rangeEnd = startOfWeek.add(const Duration(days: 8));
    final stopwatch = Stopwatch()..start();
    final results = await _database
        .customSelect(
          '''SELECT id, activity_type, scheduled_date_time, duration_minutes,
                distance_miles, pace_target_minutes_per_mile,
                cycling_speed_mph, swimming_pace_per_100m_seconds,
                intensity_z1_z2_pct, intensity_z3_z4_pct, intensity_z5_pct,
                tss, intensity_level
         FROM activities
         WHERE user_id = ? AND scheduled_date_time >= ? AND scheduled_date_time < ?
         AND deleted_at IS NULL AND status != 'skipped'
         ORDER BY scheduled_date_time ASC''',
          variables: [
            Variable.withString(userId),
            Variable.withDateTime(rangeStart),
            Variable.withDateTime(rangeEnd),
          ],
        )
        .get();
    stopwatch.stop();
    PerformanceTelemetry.recordDuration(
      'daily_macros.load_week_activity_inputs',
      stopwatch.elapsed,
      data: {'activity_count': results.length},
      threshold: const Duration(milliseconds: 500),
    );
    return _WeekActivityInputs(results);
  }

  /// Load sessions for a date in the format expected by the edge function.
  ///
  /// `status = 'skipped'` rows are excluded from EVERY activity-derived input
  /// (sessions, adjacent-day context, weekly hours): the athlete's "didn't
  /// happen" contributes zero to session demand and fuel windows exactly as
  /// the confirmation ladder's else-rung does, even while planned_time is
  /// still in the future (platform-resolution.md, SKIPPED addition
  /// 2026-08-17). Tombstones (status='deleted') also carry deleted_at, so the
  /// existing filter already drops them. A skip/unskip therefore invalidates
  /// the cached window — see `macro_cache_invalidation.dart`.
  Future<List<Map<String, dynamic>>> _loadSessionsForDate(
    String userId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final results = await _database
        .customSelect(
          '''SELECT id, activity_type, scheduled_date_time, duration_minutes,
                distance_miles, pace_target_minutes_per_mile,
                cycling_speed_mph, swimming_pace_per_100m_seconds,
                intensity_z1_z2_pct, intensity_z3_z4_pct, intensity_z5_pct,
                tss, intensity_level
         FROM activities
         WHERE user_id = ? AND scheduled_date_time >= ? AND scheduled_date_time < ?
         AND deleted_at IS NULL AND status != 'skipped'
         ORDER BY scheduled_date_time ASC''',
          variables: [
            Variable.withString(userId),
            Variable.withDateTime(startOfDay),
            Variable.withDateTime(endOfDay),
          ],
        )
        .get();

    return results.map(_sessionFromActivityRow).toList();
  }

  /// Load context info for a day (yesterday/tomorrow)
  Future<Map<String, dynamic>> _loadDayContext(
    String userId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final results = await _database
        .customSelect(
          '''SELECT tss, duration_minutes, intensity_level, scheduled_date_time
         FROM activities
         WHERE user_id = ? AND scheduled_date_time >= ? AND scheduled_date_time < ?
         AND deleted_at IS NULL AND status != 'skipped' ''',
          variables: [
            Variable.withString(userId),
            Variable.withDateTime(startOfDay),
            Variable.withDateTime(endOfDay),
          ],
        )
        .get();

    return _contextFromActivityRows(results);
  }

  /// Calculate total training hours for the current week
  Future<double> _calculateWeeklyHours(String userId, DateTime date) async {
    final weekday = date.weekday;
    final startOfWeek = DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final results = await _database
        .customSelect(
          '''SELECT COALESCE(SUM(duration_minutes), 0) as total_minutes
         FROM activities
         WHERE user_id = ? AND scheduled_date_time >= ? AND scheduled_date_time < ?
         AND deleted_at IS NULL AND status != 'skipped' ''',
          variables: [
            Variable.withString(userId),
            Variable.withDateTime(startOfWeek),
            Variable.withDateTime(endOfWeek),
          ],
        )
        .get();

    if (results.isEmpty) return 0;
    final totalMinutes = results.first.read<int>('total_minutes');
    return totalMinutes / 60.0;
  }
}

class _WeekActivityInputs {
  _WeekActivityInputs(this._allRows) {
    for (final row in _allRows) {
      final date = _activityDate(row);
      _rowsByDay.putIfAbsent(_dayKey(date), () => []).add(row);
    }
  }

  final List<QueryRow> _allRows;
  final Map<int, List<QueryRow>> _rowsByDay = {};

  List<Map<String, dynamic>> sessionsFor(DateTime date) =>
      (_rowsByDay[_dayKey(date)] ?? const <QueryRow>[])
          .map(_sessionFromActivityRow)
          .toList(growable: false);

  Map<String, dynamic> contextFor(DateTime date) =>
      _contextFromActivityRows(_rowsByDay[_dayKey(date)] ?? const <QueryRow>[]);

  double weeklyHoursFor(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final monday = normalized.subtract(Duration(days: normalized.weekday - 1));
    final end = monday.add(const Duration(days: 7));
    var totalMinutes = 0;
    for (final row in _allRows) {
      final activityDate = _activityDate(row);
      if (!activityDate.isBefore(monday) && activityDate.isBefore(end)) {
        totalMinutes += row.readNullable<int>('duration_minutes') ?? 0;
      }
    }
    return totalMinutes / 60.0;
  }
}

int _dayKey(DateTime date) =>
    DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;

DateTime _activityDate(QueryRow row) => DateTime.fromMillisecondsSinceEpoch(
  row.read<int>('scheduled_date_time') * 1000,
);

Map<String, dynamic> _sessionFromActivityRow(QueryRow row) {
  var durationMinutes = row.readNullable<int>('duration_minutes') ?? 0;
  final activityType = row.read<String>('activity_type');

  if (durationMinutes == 0) {
    final distanceMiles = row.readNullable<double>('distance_miles');
    if (activityType == 'running') {
      final pace = row.readNullable<double>('pace_target_minutes_per_mile');
      if (distanceMiles != null && pace != null && pace > 0) {
        durationMinutes = (distanceMiles * pace).round();
      }
    } else if (activityType == 'cycling') {
      final speed = row.readNullable<double>('cycling_speed_mph');
      if (distanceMiles != null && speed != null && speed > 0) {
        durationMinutes = ((distanceMiles / speed) * 60).round();
      }
    } else if (activityType == 'swimming') {
      final swimPace = row.readNullable<int>('swimming_pace_per_100m_seconds');
      if (distanceMiles != null && swimPace != null && swimPace > 0) {
        final distanceMeters = distanceMiles * 1609.34;
        durationMinutes = ((distanceMeters / 100) * swimPace / 60).round();
      }
    }
    if (durationMinutes == 0) {
      durationMinutes = activityType == 'other' ? 30 : 60;
    }
  }

  final sport = switch (activityType) {
    'cycling' => 'cycling',
    'swimming' => 'swimming',
    'other' => 'strength',
    _ => 'running',
  };

  return {
    'sport': sport,
    'duration_hr': durationMinutes / 60.0,
    'pct_conversational':
        (row.readNullable<int>('intensity_z1_z2_pct') ?? 70) / 100.0,
    'pct_tempo': (row.readNullable<int>('intensity_z3_z4_pct') ?? 20) / 100.0,
    'pct_allout': (row.readNullable<int>('intensity_z5_pct') ?? 10) / 100.0,
    'tss': row.readNullable<double>('tss'),
    'activity_id': row.read<String>('id'),
  };
}

Map<String, dynamic> _contextFromActivityRows(List<QueryRow> rows) {
  if (rows.isEmpty) {
    return {
      'max_tss': null,
      'hours_since': null,
      'duration_hr': null,
      'is_race': false,
    };
  }

  double? maxTss;
  var totalDurationHr = 0.0;
  var isRace = false;
  for (final row in rows) {
    final tss = row.readNullable<double>('tss');
    if (tss != null && (maxTss == null || tss > maxTss)) {
      maxTss = tss;
    }
    totalDurationHr += (row.readNullable<int>('duration_minutes') ?? 0) / 60.0;
    if (row.readNullable<String>('intensity_level') == 'race') {
      isRace = true;
    }
  }

  final lastActivityTime = _activityDate(rows.last);
  final hoursSince =
      DateTime.now().difference(lastActivityTime).inMinutes / 60.0;
  return {
    'max_tss': maxTss,
    'hours_since': hoursSince,
    'duration_hr': totalDurationHr,
    'is_race': isRace,
  };
}
