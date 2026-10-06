import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../../shared/database/app_database.dart' hide Activity;
import '../../../shared/services/preferences_service.dart';
import '../../../shared/services/report/report.dart';
import '../../activities/domain/activity.dart';
import '../../nutrition_plan/domain/fuel_log_data.dart';
import '../../nutrition_plan/domain/nutrition_plan.dart';
import '../data/training_peaks_api_client.dart';
import '../domain/integration_exceptions.dart';
import 'tp_writeback_formatter.dart';
import 'training_peaks_oauth_service.dart';

/// Orchestrates pushing/removing nutrition plan summaries to/from TP workout
/// descriptions. All public methods are safe to call fire-and-forget — they
/// catch all exceptions, report them through [Report], and never throw.
class TpWritebackService {
  TpWritebackService({
    required TrainingPeaksApiClient apiClient,
    required TrainingPeaksOAuthService oauthService,
    required PreferencesService preferencesService,
    required AppDatabase database,
    SupabaseClient? supabase,
    Report? report,
    DateTime Function()? clock,
  }) : _apiClient = apiClient,
       _oauthService = oauthService,
       _preferencesService = preferencesService,
       _db = database,
       _supabase = supabase,
       _report = report,
       _clock = clock ?? DateTime.now;

  final TrainingPeaksApiClient _apiClient;
  final TrainingPeaksOAuthService _oauthService;
  final PreferencesService _preferencesService;
  final AppDatabase _db;
  final Report? _report;
  final DateTime Function() _clock;

  Report get _r => _report ?? SentryReport.global;

  static const _area = 'training_peaks';

  /// TrainingPeaks refuses a `PUT /v2/workouts/plan/{id}` with a 400 once the
  /// workout's `WorkoutDay` is more than 7 days in the past or more than a
  /// year ahead (docs/integration/api-exploration/training-peaks/writeback.md
  /// § Constraints). Prod MEALVANA-ENDURANCE-CY (a plan saved 14 days after
  /// its workout day) and C7 (the disconnect strip walking months-old
  /// workouts) were this refusal.
  static const tpEditWindowPastDays = 7;
  static const tpEditWindowFutureDays = 365;

  /// Whether TP will accept a plan write for [workout], judged from the
  /// `WorkoutDay` the GET returned (a naive local date; the time is ignored).
  /// An unreadable `WorkoutDay` counts as inside: TP decides, and a refusal
  /// is reported with its body.
  @visibleForTesting
  static bool isWithinTpEditWindow(
    Map<String, dynamic> workout, {
    required DateTime now,
  }) {
    final raw = workout['WorkoutDay'];
    final parsed = raw is String ? DateTime.tryParse(raw) : null;
    if (parsed == null) return true;
    final day = DateTime.utc(parsed.year, parsed.month, parsed.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    final daysPast = today.difference(day).inDays;
    return daysPast <= tpEditWindowPastDays &&
        -daysPast <= tpEditWindowFutureDays;
  }

  /// Checks the edit window before a PUT. Outside it, records the skip (D9)
  /// and returns false; the caller leaves the workout untouched.
  Future<bool> _insideEditWindow(
    Map<String, dynamic> workout,
    String workoutId, {
    required String op,
  }) async {
    if (isWithinTpEditWindow(workout, now: _clock())) return true;
    await _r.note(
      'TP write-back skipped: workout outside TP edit window',
      area: _area,
      data: {
        'workoutId': workoutId,
        'workoutDay': workout['WorkoutDay'],
        'op': op,
      },
    );
    return false;
  }

  /// Server-side ledger custodian (TP-5/Q-INT16 as amended 2026-09-11):
  /// NO push happens without its ledger row. Nullable only for legacy
  /// construction paths; a null client means pushes are REFUSED.
  final SupabaseClient? _supabase;

  /// TP-5: open the per-push ledger row (status 'attempt'). Returns the row
  /// id, or null when the ledger is unreachable — in which case the caller
  /// MUST skip the push (the ledger is a precondition, not a side effect).
  Future<String?> _openLedgerRow({
    required String userId,
    required String? activityId,
    required String tpWorkoutId,
    String? planHash,
    required String blockKind,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      await _r.note(
        'TP write-back refused: no ledger client (TP-5)',
        area: _area,
        data: {'blockKind': blockKind},
      );
      return null;
    }
    try {
      final row = await supabase
          .from('tp_writeback_ledger')
          .insert({
            'user_id': userId,
            'activity_id': activityId,
            'tp_workout_id': tpWorkoutId,
            'plan_hash': planHash,
            'block_kind': blockKind,
            'status': 'attempt',
          })
          .select('id')
          .single();
      return row['id'] as String?;
    } catch (e, st) {
      // No ledger row means no push (TP-5): the athlete's plan never reaches
      // TP and nothing else would say so.
      await _r.fault(
        e,
        stackTrace: st,
        area: _area,
        message: 'TP write-back: ledger row open failed; push refused',
      );
      return null;
    }
  }

  Future<void> _closeLedgerRow(
    String ledgerId, {
    required bool success,
    String? error,
  }) async {
    final supabase = _supabase;
    if (supabase == null) return;
    try {
      await supabase
          .from('tp_writeback_ledger')
          .update({'status': success ? 'success' : 'failure', 'error': error})
          .eq('id', ledgerId);
    } catch (e, st) {
      await _r.fault(
        e,
        stackTrace: st,
        area: _area,
        message: 'TP write-back: ledger row close failed; row left as attempt',
      );
    }
  }

  /// Tracks workout IDs currently being written to prevent duplicate calls.
  final Set<String> _inFlightWorkouts = {};

  /// Report TP's profile premium status — INFORMATIONAL ONLY.
  ///
  /// A1 (ruled 2026-09-20): no behavior keys on the IsPremium flag. The flag
  /// is a connect-time snapshot, proven false-negative on premium-featured
  /// trials — so this method no longer touches the block state. Eligibility
  /// is decided by TP's ACTUAL write-back responses alone: a 403 on a push
  /// blocks (see _handleApiException), a successful push unblocks.
  ///
  /// Returns the profile's reported status for display, or `null` when it
  /// could not be read.
  Future<bool?> refreshPremiumEligibility({required String userId}) async {
    return _getPremiumStatus(userId);
  }

  /// Push the nutrition plan summary to the TP workout description.
  /// Safe to call fire-and-forget — never throws.
  ///
  /// When [fuelLog] is supplied (fuel-log completion), the SAME
  /// `[Mealvana Fuel Plan]` block is re-rendered in its logged state —
  /// `planned · consumed` per phase — and replaces the plan-time block
  /// in-place (RULED Xuan, 2026-09-10, option A single-block). block_kind
  /// stays 'plan'; the differing hash is what lets the re-push through the
  /// unchanged-plan guard.
  Future<void> pushPlanToWorkout({
    required String userId,
    required Activity activity,
    required NutritionPlan plan,
    FuelLogData? fuelLog,
  }) async {
    try {
      // Guard 1: Is write-back enabled?
      if (!_preferencesService.tpWritebackEnabled) return;

      // Guard 2: Is this activity from TrainingPeaks?
      if (activity.syncedFromProvider != 'training_peaks') return;

      // Guard 3: Does it have a TP workout ID?
      final workoutIdStr = activity.providerWorkoutId;
      if (workoutIdStr == null || workoutIdStr.isEmpty) return;

      // Guard 4: Is write-back blocked due to 403?
      if (_preferencesService.tpWritebackPremiumBlocked) return;

      // Guard 5: Concurrency — skip if already in flight for this workout
      if (!_inFlightWorkouts.add(workoutIdStr)) {
        _r.debug(
          'TP write-back skipped: push already in flight',
          area: _area,
          data: {'workoutId': workoutIdStr},
        );
        return;
      }

      try {
        await _doPush(
          userId: userId,
          workoutIdStr: workoutIdStr,
          activity: activity,
          plan: plan,
          fuelLog: fuelLog,
        );
      } finally {
        _inFlightWorkouts.remove(workoutIdStr);
      }
    } catch (e, st) {
      await _r.fault(
        e,
        stackTrace: st,
        area: _area,
        message: 'TP write-back: pushPlanToWorkout failed',
      );
    }
  }

  /// Core push logic, separated so we can retry on token expiry.
  Future<void> _doPush({
    required String userId,
    required String workoutIdStr,
    required Activity activity,
    required NutritionPlan plan,
    FuelLogData? fuelLog,
    bool isRetry = false,
  }) async {
    // Get a valid access token (refreshes if close to expiry)
    final accessToken = await _oauthService.getValidAccessToken(userId);
    if (accessToken == null) {
      await _r.note(
        'TP write-back skipped: no valid access token',
        area: _area,
        data: {'workoutId': workoutIdStr},
      );
      return;
    }

    // Build the formatted block — logged (planned · consumed) form once the
    // athlete has logged fuel for this plan, otherwise the plan-time form.
    final block = fuelLog != null
        ? TpWritebackFormatter.formatLoggedPlanBlock(
            plan,
            fuelLog,
            durationMinutes: activity.durationMinutes,
          )
        : TpWritebackFormatter.formatPlanBlock(
            plan,
            durationMinutes: activity.durationMinutes,
          );
    final hash = TpWritebackFormatter.computeHash(block);

    // Guard: Has the plan actually changed?
    final existing = await _getWritebackEntry(userId, workoutIdStr);
    if (existing != null && existing.planHash == hash) {
      _r.debug('TP write-back skipped: plan hash unchanged', area: _area);
      return;
    }

    _r.debug(
      'TP write-back: pushing plan block',
      area: _area,
      data: {'workoutId': workoutIdStr, 'retry': isRetry},
    );

    // TP-5/Q-INT16: no push without a ledger row.
    final ledgerId = await _openLedgerRow(
      userId: userId,
      activityId: activity.id,
      tpWorkoutId: workoutIdStr,
      planHash: hash,
      blockKind: 'plan',
    );
    if (ledgerId == null) return;

    try {
      // GET → merge → PUT
      final workout = await _apiClient.getWorkoutById(
        accessToken,
        workoutIdStr,
        includeDescription: true,
      );
      if (!await _insideEditWindow(workout, workoutIdStr, op: 'plan')) {
        await _closeLedgerRow(
          ledgerId,
          success: false,
          error: 'outside_edit_window',
        );
        return;
      }
      final existingDesc = workout['Description'] as String? ?? '';
      final updatedDesc = TpWritebackFormatter.mergeBlockIntoDescription(
        existingDesc,
        block,
      );

      final updatedWorkout = Map<String, dynamic>.from(workout);
      updatedWorkout['Description'] = updatedDesc;

      await _apiClient.updatePlannedWorkout(
        accessToken,
        workoutId: workoutIdStr,
        workoutData: updatedWorkout,
      );

      // Record success in Drift + close the server ledger row.
      await _upsertWritebackEntry(
        userId: userId,
        activityId: activity.id,
        tpWorkoutId: workoutIdStr,
        planHash: hash,
        status: 'active',
      );
      await _closeLedgerRow(ledgerId, success: true);

      await onPushSucceeded();

      _r.debug(
        'TP write-back: plan block pushed',
        area: _area,
        data: {'workoutId': workoutIdStr},
      );
    } on TokenExpiredException catch (e, st) {
      await _closeLedgerRow(
        ledgerId,
        success: false,
        error: 'token_expired${isRetry ? '_after_refresh' : ''}',
      );
      if (!isRetry) {
        await _r.note(
          'TP write-back: 401; forcing token refresh and retrying',
          area: _area,
          data: {'workoutId': workoutIdStr},
        );
        // Force refresh bypasses the local expiry check
        final freshToken = await _oauthService.forceRefreshToken(userId);
        if (freshToken == null) {
          // The refresh failure itself was reported by the OAuth service.
          await _r.note(
            'TP write-back: force refresh failed; push abandoned',
            area: _area,
            data: {'workoutId': workoutIdStr},
          );
          return;
        }
        await _doPush(
          userId: userId,
          workoutIdStr: workoutIdStr,
          activity: activity,
          plan: plan,
          fuelLog: fuelLog,
          isRetry: true,
        );
      } else {
        // A fresh token was still refused: the account, not the token.
        await _r.degraded(
          e,
          stackTrace: st,
          area: _area,
          message:
              'TP write-back: token still expired after refresh; push abandoned',
          extra: {'workoutId': workoutIdStr},
        );
      }
    } on IntegrationApiException catch (e) {
      await _closeLedgerRow(
        ledgerId,
        success: false,
        error: 'api_${e.statusCode}',
      );
      await handleApiException(e, userId, workoutIdStr);
    }
  }

  /// Push completion feedback to the TP workout description.
  /// Appends a [Mealvana Feedback] block with rating and notes.
  /// Safe to call fire-and-forget — never throws.
  Future<void> pushCompletionFeedback({
    required String userId,
    required Activity activity,
    required int rating,
    String? notes,
  }) async {
    try {
      if (!_preferencesService.tpWritebackEnabled) return;
      if (activity.syncedFromProvider != 'training_peaks') return;

      final workoutIdStr = activity.providerWorkoutId;
      if (workoutIdStr == null || workoutIdStr.isEmpty) return;
      if (_preferencesService.tpWritebackPremiumBlocked) return;

      if (!_inFlightWorkouts.add('fb_$workoutIdStr')) return;

      try {
        await _doPushFeedback(
          userId: userId,
          workoutIdStr: workoutIdStr,
          rating: rating,
          notes: notes,
        );
      } finally {
        _inFlightWorkouts.remove('fb_$workoutIdStr');
      }
    } catch (e, st) {
      await _r.fault(
        e,
        stackTrace: st,
        area: _area,
        message: 'TP write-back: pushCompletionFeedback failed',
      );
    }
  }

  Future<void> _doPushFeedback({
    required String userId,
    required String workoutIdStr,
    required int rating,
    String? notes,
    bool isRetry = false,
  }) async {
    final accessToken = await _oauthService.getValidAccessToken(userId);
    if (accessToken == null) return;

    final block = TpWritebackFormatter.formatFeedbackBlock(
      rating: rating,
      notes: notes,
    );

    _r.debug(
      'TP write-back: pushing feedback block',
      area: _area,
      data: {'workoutId': workoutIdStr, 'retry': isRetry},
    );

    // TP-5/Q-INT16: no push without a ledger row (feedback included).
    final ledgerId = await _openLedgerRow(
      userId: userId,
      activityId: null,
      tpWorkoutId: workoutIdStr,
      blockKind: 'feedback',
    );
    if (ledgerId == null) return;

    try {
      final workout = await _apiClient.getWorkoutById(
        accessToken,
        workoutIdStr,
        includeDescription: true,
      );
      if (!await _insideEditWindow(workout, workoutIdStr, op: 'feedback')) {
        await _closeLedgerRow(
          ledgerId,
          success: false,
          error: 'outside_edit_window',
        );
        return;
      }
      final existingDesc = workout['Description'] as String? ?? '';
      final updatedDesc = TpWritebackFormatter.mergeFeedbackIntoDescription(
        existingDesc,
        block,
      );

      final updatedWorkout = Map<String, dynamic>.from(workout);
      updatedWorkout['Description'] = updatedDesc;

      await _apiClient.updatePlannedWorkout(
        accessToken,
        workoutId: workoutIdStr,
        workoutData: updatedWorkout,
      );

      await _closeLedgerRow(ledgerId, success: true);
      _r.debug(
        'TP write-back: feedback block pushed',
        area: _area,
        data: {'workoutId': workoutIdStr, 'rating': rating},
      );
    } on TokenExpiredException {
      await _closeLedgerRow(ledgerId, success: false, error: 'token_expired');
      await _r.note(
        'TP feedback write-back: 401; ${isRetry ? 'abandoned after refresh' : 'forcing token refresh and retrying'}',
        area: _area,
        data: {'workoutId': workoutIdStr},
      );
      if (!isRetry) {
        final freshToken = await _oauthService.forceRefreshToken(userId);
        if (freshToken == null) return;
        await _doPushFeedback(
          userId: userId,
          workoutIdStr: workoutIdStr,
          rating: rating,
          notes: notes,
          isRetry: true,
        );
      }
    } on IntegrationApiException catch (e) {
      await _closeLedgerRow(
        ledgerId,
        success: false,
        error: 'api_${e.statusCode}',
      );
      await handleApiException(e, userId, workoutIdStr);
    }
  }

  /// Remove the Mealvana block from the TP workout description.
  /// Safe to call fire-and-forget — never throws.
  Future<void> removePlanFromWorkout({
    required String userId,
    required Activity activity,
  }) async {
    try {
      if (activity.syncedFromProvider != 'training_peaks') return;

      final workoutIdStr = activity.providerWorkoutId;
      if (workoutIdStr == null || workoutIdStr.isEmpty) return;

      // Check if we ever pushed to this workout
      final existing = await _getWritebackEntry(userId, workoutIdStr);
      if (existing == null) return;

      final accessToken = await _oauthService.getValidAccessToken(userId);
      if (accessToken == null) return;

      try {
        final workout = await _apiClient.getWorkoutById(
          accessToken,
          workoutIdStr,
          includeDescription: true,
        );
        final existingDesc = workout['Description'] as String? ?? '';
        final strippedDesc = TpWritebackFormatter.stripBlockFromDescription(
          existingDesc,
        );

        if (strippedDesc != existingDesc &&
            await _insideEditWindow(workout, workoutIdStr, op: 'remove')) {
          final updatedWorkout = Map<String, dynamic>.from(workout);
          updatedWorkout['Description'] = strippedDesc;

          await _apiClient.updatePlannedWorkout(
            accessToken,
            workoutId: workoutIdStr,
            workoutData: updatedWorkout,
          );
        }

        // Remove tracking entry
        await _deleteWritebackEntry(userId, workoutIdStr);

        _r.debug(
          'TP write-back: plan block removed',
          area: _area,
          data: {'workoutId': workoutIdStr},
        );
      } on TokenExpiredException {
        // Try once more with force-refreshed token
        await _r.note(
          'TP write-back removal: 401; forcing token refresh and retrying',
          area: _area,
          data: {'workoutId': workoutIdStr},
        );
        final freshToken = await _oauthService.forceRefreshToken(userId);
        if (freshToken == null) return;

        final workout = await _apiClient.getWorkoutById(
          freshToken,
          workoutIdStr,
          includeDescription: true,
        );
        final existingDesc = workout['Description'] as String? ?? '';
        final strippedDesc = TpWritebackFormatter.stripBlockFromDescription(
          existingDesc,
        );

        if (strippedDesc != existingDesc &&
            await _insideEditWindow(workout, workoutIdStr, op: 'remove')) {
          final updatedWorkout = Map<String, dynamic>.from(workout);
          updatedWorkout['Description'] = strippedDesc;
          await _apiClient.updatePlannedWorkout(
            freshToken,
            workoutId: workoutIdStr,
            workoutData: updatedWorkout,
          );
        }
        await _deleteWritebackEntry(userId, workoutIdStr);
      }
    } on IntegrationApiException catch (e) {
      await handleApiException(e, userId, activity.providerWorkoutId);
    } catch (e, st) {
      await _r.fault(
        e,
        stackTrace: st,
        area: _area,
        message: 'TP write-back: removePlanFromWorkout failed',
      );
    }
  }

  /// Q-INT16/Q-INT2: disconnect tail — strip every [Mealvana Fuel Plan]
  /// block we ever pushed (best effort; the athlete may have revoked API
  /// access already), purge the LOCAL log, and purge the SERVER ledger.
  /// Called BEFORE the OAuth tokens are cleared, since the strip needs them.
  /// Safe to call fire-and-forget — never throws.
  Future<void> handleDisconnect({required String userId}) async {
    try {
      // Best-effort block strip for every workout we logged a push for.
      final entries = await (_db.select(
        _db.tpWritebackTable,
      )..where((t) => t.userId.equals(userId))).get();
      final accessToken = await _oauthService.getValidAccessToken(userId);
      if (accessToken != null) {
        for (final entry in entries) {
          try {
            final workoutIdStr = entry.tpWorkoutId.toString();
            final workout = await _apiClient.getWorkoutById(
              accessToken,
              workoutIdStr,
              includeDescription: true,
            );
            final existingDesc = workout['Description'] as String? ?? '';
            var strippedDesc = TpWritebackFormatter.stripBlockFromDescription(
              existingDesc,
            );
            strippedDesc = TpWritebackFormatter.stripFeedbackFromDescription(
              strippedDesc,
            );
            if (strippedDesc != existingDesc &&
                await _insideEditWindow(
                  workout,
                  workoutIdStr,
                  op: 'disconnect',
                )) {
              final updatedWorkout = Map<String, dynamic>.from(workout);
              updatedWorkout['Description'] = strippedDesc;
              await _apiClient.updatePlannedWorkout(
                accessToken,
                workoutId: workoutIdStr,
                workoutData: updatedWorkout,
              );
            }
          } catch (e, st) {
            // Per-workout best effort — keep stripping the rest. The athlete
            // may already have revoked API access, so this is expected-bad.
            await _r.degraded(
              e,
              stackTrace: st,
              area: _area,
              message: 'TP write-back: disconnect strip failed for one workout',
              extra: {
                'workoutId': entry.tpWorkoutId.toString(),
                if (e is IntegrationApiException) ...e.reportExtra,
              },
            );
          }
        }
      }

      // Purge the local log.
      await (_db.delete(
        _db.tpWritebackTable,
      )..where((t) => t.userId.equals(userId))).go();

      // Purge the server ledger (Q-INT16: disconnect purges the ledger).
      final supabase = _supabase;
      if (supabase != null) {
        try {
          await supabase
              .from('tp_writeback_ledger')
              .delete()
              .eq('user_id', userId);
        } catch (e, st) {
          await _r.fault(
            e,
            stackTrace: st,
            area: _area,
            message: 'TP write-back: server ledger purge on disconnect failed',
          );
        }
      }
    } catch (e, st) {
      await _r.fault(
        e,
        stackTrace: st,
        area: _area,
        message: 'TP write-back: handleDisconnect failed',
      );
    }
  }

  /// A1: a successful push IS the eligibility evidence — clear any block a
  /// past 403 armed (the response, never the profile flag, decides).
  @visibleForTesting
  Future<void> onPushSucceeded() async {
    if (_preferencesService.tpWritebackPremiumBlocked) {
      await _preferencesService.setTpWritebackPremiumBlocked(false);
    }
  }

  // ─── Error handling ───

  @visibleForTesting
  Future<void> handleApiException(
    IntegrationApiException e,
    String userId,
    String? workoutId,
  ) async {
    final status = e.statusCode;

    if (status == 403) {
      // A1 (ruled 2026-09-20): the write-back RESPONSE is the evidence — a
      // 403 on an actual push attempt means TP refused this account's
      // write-back, full stop. The IsPremium profile flag is never
      // consulted (connect-time snapshot, false-negative on trials). The
      // block clears the same way it was set: by a later successful push.
      await _preferencesService.setTpWritebackPremiumBlocked(true);
      await _r.degraded(
        e,
        area: _area,
        message:
            'TP write-back: 403; TP refused the push, future attempts blocked',
        extra: {'workoutId': workoutId, ...e.reportExtra},
      );
    } else if (status == 404) {
      // Workout deleted from TP — clean up tracking
      if (workoutId != null) {
        await _deleteWritebackEntry(userId, workoutId);
      }
      await _r.note(
        'TP write-back: 404; workout deleted from TP, tracking entry removed',
        area: _area,
        data: {'workoutId': workoutId},
      );
    } else {
      await _r.degraded(
        e,
        stackTrace: StackTrace.current,
        area: _area,
        message: 'TP write-back: push rejected by TP API',
        extra: {'workoutId': workoutId, ...e.reportExtra},
      );
    }
  }

  /// Returns:
  /// - true: athlete profile confirms premium
  /// - false: athlete profile confirms non-premium
  /// - null: unable to verify
  Future<bool?> _getPremiumStatus(String userId) async {
    try {
      final token = await _oauthService.getValidAccessToken(userId);
      if (token == null) return null;
      final profile = await _apiClient.getAthleteProfile(token);
      return profile.isPremium;
    } catch (e) {
      // Informational only (A1): the caller shows "unknown".
      await _r.note(
        'TP premium status unreadable',
        area: _area,
        data: {'error': e.toString()},
      );
      return null;
    }
  }

  // ─── Drift helpers ───

  Future<TpWritebackEntry?> _getWritebackEntry(
    String userId,
    String tpWorkoutId,
  ) async {
    final table = _db.tpWritebackTable;
    final query = _db.select(table)
      ..where(
        (t) =>
            t.userId.equals(userId) &
            t.tpWorkoutId.equals(int.tryParse(tpWorkoutId) ?? 0),
      );
    return query.getSingleOrNull();
  }

  Future<void> _upsertWritebackEntry({
    required String userId,
    required String activityId,
    required String tpWorkoutId,
    required String planHash,
    required String status,
    String? lastError,
  }) async {
    final tpId = int.tryParse(tpWorkoutId) ?? 0;
    final existing = await _getWritebackEntry(userId, tpWorkoutId);

    if (existing != null) {
      final table = _db.tpWritebackTable;
      ((_db.update(table))..where((t) => t.id.equals(existing.id))).write(
        TpWritebackTableCompanion(
          planHash: Value(planHash),
          pushedAt: Value(DateTime.now()),
          status: Value(status),
          lastError: Value(lastError),
        ),
      );
    } else {
      await _db
          .into(_db.tpWritebackTable)
          .insert(
            TpWritebackTableCompanion(
              userId: Value(userId),
              activityId: Value(activityId),
              tpWorkoutId: Value(tpId),
              planHash: Value(planHash),
              pushedAt: Value(DateTime.now()),
              status: Value(status),
              lastError: Value(lastError),
            ),
          );
    }
  }

  Future<void> _deleteWritebackEntry(String userId, String tpWorkoutId) async {
    final table = _db.tpWritebackTable;
    (_db.delete(table)..where(
          (t) =>
              t.userId.equals(userId) &
              t.tpWorkoutId.equals(int.tryParse(tpWorkoutId) ?? 0),
        ))
        .go();
  }
}
