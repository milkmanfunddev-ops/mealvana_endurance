import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/activity.dart';
import '../../domain/brick_exceptions.dart';
import '../../application/activities_service.dart';
import '../../data/activities_repository.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/services/schema_recovery_service.dart';

part 'brick_actions_controller.g.dart';

/// Controller for handling brick workout actions (create, ungroup, remove segments)
///
/// This controller manages the business logic for:
/// - Creating brick workouts from selected activities
/// - Ungrouping brick workouts back to standalone activities
/// - Removing segments from existing brick workouts
///
/// Follows Andrea Bizzotto's Riverpod AsyncNotifier pattern.
/// All business logic is in the controller, NOT in UI screens.
@riverpod
class BrickActionsController extends _$BrickActionsController {
  ActivitiesService get _service => ref.read(activitiesServiceProvider);
  ActivitiesRepository get _repository => ref.read(activitiesRepositoryProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);
  SchemaRecoveryService get _schemaRecovery => ref.read(schemaRecoveryServiceProvider);

  @override
  FutureOr<void> build() {
    // No persistent state needed - this is an action controller
    // Return empty value for void AsyncNotifier
  }

  /// Create a brick workout from selected activities
  ///
  /// Parameters:
  /// - activities: List of 2-3 activities to combine (already validated)
  /// - segmentOrder: List of activity IDs defining segment order
  ///
  /// Returns the created brick activity
  ///
  /// Side effects:
  /// - Creates brick activity with brick_metadata
  /// - Archives original activities with status='archived_for_brick'
  /// - Sets needs_upload=true for offline-first sync
  ///
  /// Throws:
  /// - BrickValidationException if validation fails
  /// - BrickCreationException if creation fails
  Future<Activity> createBrickFromSelection({
    required List<Activity> activities,
    required List<String> segmentOrder,
  }) async {
    _logger.info(
      'Creating brick from selected activities',
      context: 'BRICK_ACTIONS_CONTROLLER',
      data: {
        'activityCount': activities.length,
        'segmentOrder': segmentOrder,
        'activityIds': activities.map((a) => a.id).toList(),
        'sportTypes': activities.map((a) => a.activityType.name).toList(),
      },
    );

    // Validate segment order matches activities
    if (segmentOrder.length != activities.length) {
      throw BrickValidationException.invalidSegmentOrder();
    }

    try {
      // Use schema recovery wrapper - automatically handles schema errors
      // by reinitializing database and retrying (user just sees loading spinner)
      final brickActivity = await _schemaRecovery.withSchemaRecovery(
        operation: () => _service.createBrickActivity(
          activities: activities,
          segmentOrder: segmentOrder,
        ),
        onRetryNeeded: () async {
          // Invalidate dependent providers so they use the new database
          ref.invalidate(activitiesRepositoryProvider);
          ref.invalidate(activitiesServiceProvider);
          // Retry the operation with fresh providers
          return ref.read(activitiesServiceProvider).createBrickActivity(
            activities: activities,
            segmentOrder: segmentOrder,
          );
        },
        context: 'BRICK_ACTIONS_CONTROLLER.createBrickFromSelection',
      );

      _logger.info(
        'Successfully created brick activity',
        context: 'BRICK_ACTIONS_CONTROLLER',
        data: {
          'brickId': brickActivity.id,
          'brickType': brickActivity.activityType.name,
        },
      );

      return brickActivity;
    } on BrickValidationException {
      // Re-throw validation exceptions as-is
      rethrow;
    } catch (e, stackTrace) {
      _logger.error(
        'Error creating brick from selection',
        context: 'BRICK_ACTIONS_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
        data: {
          'activityIds': activities.map((a) => a.id).toList(),
        },
      );

      // Wrap unknown errors in BrickCreationException
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        throw BrickCreationException.networkError(e);
      } else if (e.toString().contains('database') || e.toString().contains('drift')) {
        throw BrickCreationException.databaseError(e);
      } else {
        throw BrickCreationException.unknown(e);
      }
    }
  }

  /// Ungroup a brick workout back to standalone activities
  ///
  /// Parameters:
  /// - brickId: ID of the brick activity to ungroup
  ///
  /// Side effects:
  /// - Restores archived activities to status='planned'
  /// - Clears brick_id from restored activities
  /// - Soft deletes the brick activity (deleted_at = now)
  /// - Sets needs_upload=true for offline-first sync
  ///
  /// Throws:
  /// - BrickUngroupException if ungroup fails
  Future<void> ungroupBrick(String brickId) async {
    try {
      _logger.info(
        'Ungrouping brick activity',
        context: 'BRICK_ACTIONS_CONTROLLER',
        data: {'brickId': brickId},
      );

      // Call repository to ungroup brick
      await _repository.ungroupBrick(brickId);

      _logger.info(
        'Successfully ungrouped brick activity',
        context: 'BRICK_ACTIONS_CONTROLLER',
        data: {'brickId': brickId},
      );
    } on StateError catch (e, stackTrace) {
      // Brick not found in database
      _logger.error(
        'Brick not found when attempting to ungroup',
        context: 'BRICK_ACTIONS_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
        data: {'brickId': brickId},
      );
      throw BrickUngroupException.brickNotFound(brickId);
    } catch (e, stackTrace) {
      _logger.error(
        'Error ungrouping brick',
        context: 'BRICK_ACTIONS_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
        data: {'brickId': brickId},
      );

      // Wrap unknown errors in BrickUngroupException
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        throw BrickUngroupException.networkError(e);
      } else {
        throw BrickUngroupException.databaseError(e);
      }
    }
  }

  /// Remove a segment from a brick workout
  ///
  /// If 2+ segments remain after removal:
  /// - Updates brick metadata to remove the segment
  /// - Soft deletes the original activity for that segment
  ///
  /// If only 1 segment would remain:
  /// - Returns false to indicate ungrouping dialog should be shown
  /// - UI should call ungroupBrick() after user confirmation
  ///
  /// Parameters:
  /// - brickId: ID of the brick activity
  /// - segmentIndex: 0-based index of segment to remove
  ///
  /// Returns true if segment was removed successfully, false if ungrouping needed
  ///
  /// Note: This method is planned for Phase 3.4 but not yet implemented.
  /// For now, we'll throw UnimplementedError with clear message.
  Future<bool> removeSegmentFromBrick({
    required String brickId,
    required int segmentIndex,
  }) async {
    _logger.info(
      'Removing segment from brick',
      context: 'BRICK_ACTIONS_CONTROLLER',
      data: {
        'brickId': brickId,
        'segmentIndex': segmentIndex,
      },
    );

    throw UnimplementedError(
      'Remove segment feature is planned for Phase 3.4 but not yet implemented. '
      'For now, use ungroup to remove all segments.',
    );

    // TODO: Implement remove segment logic
    // 1. Get brick activity
    // 2. Count segments in brick_metadata
    // 3. If 3 segments: Update brick_metadata, remove segment, update totals
    // 4. If 2 segments: Return false (show ungroup dialog)
    // 5. Mark needs_upload=true for sync
  }
}
