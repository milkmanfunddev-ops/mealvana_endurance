import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../shared/database/app_database.dart' hide Activity;
import '../../../shared/services/preferences_service.dart';
import '../../activities/domain/activity.dart';
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
  }) : _apiClient = apiClient,
       _oauthService = oauthService,
       _preferencesService = preferencesService,
       _db = database;

  final TrainingPeaksApiClient _apiClient;
  final TrainingPeaksOAuthService _oauthService;
  final PreferencesService _preferencesService;
  final AppDatabase _db;

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
  Future<void> pushPlanToWorkout({
    required String userId,
    required Activity activity,
    required NutritionPlan plan,
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

    // Build the formatted block
    final block = TpWritebackFormatter.formatPlanBlock(
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

      // Record success in Drift
      await _upsertWritebackEntry(
        userId: userId,
        activityId: activity.id,
        tpWorkoutId: workoutIdStr,
        planHash: hash,
        status: 'active',
      );

      if (kDebugMode) {
        print('✅ TP Write-back: pushed plan to workout $workoutIdStr');
      }
    } on TokenExpiredException {
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

      if (kDebugMode) {
        print(
          '✅ TP Feedback: pushed rating $rating/5 to workout $workoutIdStr',
        );
      }
    } on TokenExpiredException {
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
