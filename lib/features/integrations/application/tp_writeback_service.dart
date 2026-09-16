import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../../shared/database/app_database.dart' hide Activity;
import '../../../shared/services/preferences_service.dart';
import '../../activities/domain/activity.dart';
import '../../nutrition_plan/domain/fuel_log_data.dart';
import '../../nutrition_plan/domain/nutrition_plan.dart';
import '../data/training_peaks_api_client.dart';
import '../domain/integration_exceptions.dart';
import 'tp_writeback_formatter.dart';
import 'training_peaks_oauth_service.dart';

/// Orchestrates pushing/removing nutrition plan summaries to/from TP workout
/// descriptions. All public methods are safe to call fire-and-forget — they
/// catch all exceptions, log to Sentry, and never throw.
class TpWritebackService {
  TpWritebackService({
    required TrainingPeaksApiClient apiClient,
    required TrainingPeaksOAuthService oauthService,
    required PreferencesService preferencesService,
    required AppDatabase database,
    SupabaseClient? supabase,
  }) : _apiClient = apiClient,
       _oauthService = oauthService,
       _preferencesService = preferencesService,
       _db = database,
       _supabase = supabase;

  final TrainingPeaksApiClient _apiClient;
  final TrainingPeaksOAuthService _oauthService;
  final PreferencesService _preferencesService;
  final AppDatabase _db;

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
      if (kDebugMode) {
        print('⛔ TP Write-back: no ledger client — push refused (TP-5)');
      }
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
      _logError('openLedgerRow', e, st);
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
      _logError('closeLedgerRow', e, st);
    }
  }

  /// Tracks workout IDs currently being written to prevent duplicate calls.
  final Set<String> _inFlightWorkouts = {};

  /// Re-check TP premium eligibility and reconcile local block state.
  ///
  /// Returns:
  /// - `true` when profile confirms premium (write-back unblocked)
  /// - `false` when profile confirms non-premium (write-back blocked)
  /// - `null` when eligibility could not be verified
  Future<bool?> refreshPremiumEligibility({required String userId}) async {
    final premiumStatus = await _getPremiumStatus(userId);
    if (premiumStatus == true) {
      await _preferencesService.setTpWritebackPremiumBlocked(false);
    } else if (premiumStatus == false) {
      await _preferencesService.setTpWritebackPremiumBlocked(true);
    }
    return premiumStatus;
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
        if (kDebugMode) {
          print(
            '⏭️ TP Write-back: skipped — already in flight for $workoutIdStr',
          );
        }
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
      _logError('pushPlanToWorkout', e, st);
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
      if (kDebugMode) {
        print('⏭️ TP Write-back: skipped — no valid access token');
      }
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
      if (kDebugMode) print('⏭️ TP Write-back: skipped — plan hash unchanged');
      return;
    }

    if (kDebugMode) {
      print(
        '📤 TP Write-back: GET+PUT workout $workoutIdStr${isRetry ? ' (retry)' : ''}',
      );
    }

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

      if (kDebugMode) {
        print('✅ TP Write-back: pushed plan to workout $workoutIdStr');
      }
    } on TokenExpiredException {
      await _closeLedgerRow(
        ledgerId,
        success: false,
        error: 'token_expired${isRetry ? '_after_refresh' : ''}',
      );
      if (!isRetry) {
        if (kDebugMode) {
          print(
            '🔄 TP Write-back: 401 — forcing token refresh and retrying...',
          );
        }
        // Force refresh bypasses the local expiry check
        final freshToken = await _oauthService.forceRefreshToken(userId);
        if (freshToken == null) {
          if (kDebugMode) {
            print('❌ TP Write-back: force refresh failed — giving up');
          }
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
        if (kDebugMode) {
          print(
            '❌ TP Write-back: token still expired after refresh — giving up',
          );
        }
      }
    } on IntegrationApiException catch (e) {
      await _closeLedgerRow(
        ledgerId,
        success: false,
        error: 'api_${e.statusCode}',
      );
      await _handleApiException(e, userId, workoutIdStr);
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
      _logError('pushCompletionFeedback', e, st);
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

    if (kDebugMode) {
      print(
        '📤 TP Feedback: pushing to workout $workoutIdStr${isRetry ? ' (retry)' : ''}',
      );
    }

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
      if (kDebugMode) {
        print(
          '✅ TP Feedback: pushed rating $rating/5 to workout $workoutIdStr',
        );
      }
    } on TokenExpiredException {
      await _closeLedgerRow(ledgerId, success: false, error: 'token_expired');
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
      await _handleApiException(e, userId, workoutIdStr);
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

        if (strippedDesc != existingDesc) {
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

        if (kDebugMode) {
          print('✅ TP Write-back: removed plan from workout $workoutIdStr');
        }
      } on TokenExpiredException {
        // Try once more with force-refreshed token
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

        if (strippedDesc != existingDesc) {
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
      await _handleApiException(e, userId, activity.providerWorkoutId);
    } catch (e, st) {
      _logError('removePlanFromWorkout', e, st);
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
            if (strippedDesc != existingDesc) {
              final updatedWorkout = Map<String, dynamic>.from(workout);
              updatedWorkout['Description'] = strippedDesc;
              await _apiClient.updatePlannedWorkout(
                accessToken,
                workoutId: workoutIdStr,
                workoutData: updatedWorkout,
              );
            }
          } catch (e, st) {
            // Per-workout best effort — keep stripping the rest.
            _logError('handleDisconnect.strip', e, st);
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
          _logError('handleDisconnect.ledger', e, st);
        }
      }
    } catch (e, st) {
      _logError('handleDisconnect', e, st);
    }
  }

  // ─── Error handling ───

  Future<void> _handleApiException(
    IntegrationApiException e,
    String userId,
    String? workoutId,
  ) async {
    final status = e.statusCode;

    if (status == 403) {
      final premiumStatus = await _getPremiumStatus(userId);

      if (premiumStatus == false) {
        // Confirmed basic account — block future attempts.
        await _preferencesService.setTpWritebackPremiumBlocked(true);
        if (kDebugMode) {
          print(
            '⚠️ TP Write-back: 403 — premium required, blocking future attempts',
          );
        }
      } else {
        // Not a premium restriction (or we couldn't verify). Do not hard-block.
        // Also clear stale block if profile confirms premium.
        if (premiumStatus == true &&
            _preferencesService.tpWritebackPremiumBlocked) {
          await _preferencesService.setTpWritebackPremiumBlocked(false);
        }
        if (kDebugMode) {
          print(
            '⚠️ TP Write-back: 403 — not confirmed as premium restriction; leaving toggle enabled',
          );
        }
      }
    } else if (status == 404) {
      // Workout deleted from TP — clean up tracking
      if (workoutId != null) {
        await _deleteWritebackEntry(userId, workoutId);
      }
      if (kDebugMode) {
        print('⚠️ TP Write-back: 404 — workout deleted from TP');
      }
    } else {
      _logError('_handleApiException', e, StackTrace.current);
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
    } catch (_) {
      return null;
    }
  }

  void _logError(String method, Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      print('❌ TP Write-back ($method): $error');
    }
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: Hint.withMap({'method': 'TpWritebackService.$method'}),
    );
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
