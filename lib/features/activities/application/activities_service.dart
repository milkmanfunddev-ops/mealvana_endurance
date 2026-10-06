import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/domain/activity_type.dart';
import '../domain/activity.dart' as domain;
import '../domain/brick_metadata.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/report/report.dart';
import '../../../shared/domain/write_consistency.dart';
import '../data/activities_repository.dart';
import '../../coach_mode/data/coach_repository.dart';

part 'activities_service.g.dart';

@riverpod
ActivitiesService activitiesService(Ref ref) {
  return ActivitiesService(
    ref.read(appDatabaseProvider),
    ref.read(reportProvider),
    ref.read(activitiesRepositoryProvider),
    ref.read(coachRepositoryProvider),
  );
}

/// Service for managing calendar activities
/// Handles all activity-related operations including CRUD for running, cycling, and swimming activities
class ActivitiesService {
  final AppDatabase _database;
  final Report _report;
  final ActivitiesRepository _activitiesRepository;
  final CoachRepository _coachRepository;

  ActivitiesService(
    this._database,
    this._report,
    this._activitiesRepository,
    this._coachRepository,
  );

  /// Get activities for a specific date range
  Future<List<domain.Activity>> getActivitiesForDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // CRITICAL FIX: Use case-insensitive comparison for userId
      // Supabase returns lowercase UUIDs, but local user profile may have uppercase
      // Filter out archivedForBrick activities - they are hidden when grouped into a brick
      final query = _database.select(_database.activitiesTable)
        ..where(
          (tbl) =>
              tbl.userId.lower().equals(userId.toLowerCase()) &
              tbl.scheduledDateTime.isBetweenValues(startDate, endDate) &
              tbl.deletedAt.isNull() &
              // Q-INT2: rows soft-hidden by a provider disconnect are
              // excluded from display (they revive on a matching re-sync).
              (tbl.hiddenByDisconnect.isNull() |
                  tbl.hiddenByDisconnect.equals(false)) &
              tbl.status.equals('draft').not() &
              (tbl.status.equals('archivedForBrick') |
                      tbl.status.equals('archived_for_brick'))
                  .not(),
        )
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.scheduledDateTime)]);

      final activities = await query.get();
      final mapped = await _mapActivitiesAsync(activities);
      return _hydrateBrickMetadataForActivities(
        userId: userId,
        activities: mapped,
      );
    } catch (e) {
      _report.fault(
        e,
        area: 'activities',
        message: 'Error getting activities for date range',
      );
      rethrow;
    }
  }

  /// Get activities for a specific week
  Future<List<domain.Activity>> getActivitiesForWeek(
    String userId,
    DateTime weekStart,
  ) async {
    final weekEnd = weekStart.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );
    return getActivitiesForDateRange(userId, weekStart, weekEnd);
  }

  /// Get all activities for a user (no date filter)
  Future<List<domain.Activity>> getAllActivities(String userId) async {
    try {
      // CRITICAL FIX: Use case-insensitive comparison for userId
      // Filter out archivedForBrick activities - they are hidden when grouped into a brick
      final query = _database.select(_database.activitiesTable)
        ..where(
          (tbl) =>
              tbl.userId.lower().equals(userId.toLowerCase()) &
              tbl.deletedAt.isNull() &
              // Q-INT2: rows soft-hidden by a provider disconnect are
              // excluded from display (they revive on a matching re-sync).
              (tbl.hiddenByDisconnect.isNull() |
                  tbl.hiddenByDisconnect.equals(false)) &
              tbl.status.equals('draft').not() &
              (tbl.status.equals('archivedForBrick') |
                      tbl.status.equals('archived_for_brick'))
                  .not(),
        )
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.scheduledDateTime)]);

      final activities = await query.get();
      final mapped = await _mapActivitiesAsync(activities);
      return _hydrateBrickMetadataForActivities(
        userId: userId,
        activities: mapped,
      );
    } catch (e) {
      _report.fault(
        e,
        area: 'activities',
        message: 'Error getting all activities',
      );
      rethrow;
    }
  }

  /// Delete all draft activities for a user.
  /// Called when the activities list screen loads to clean up abandoned drafts.
  Future<int> cleanupDraftActivities(String userId) async {
    try {
      final query = _database.select(_database.activitiesTable)
        ..where(
          (tbl) =>
              tbl.userId.lower().equals(userId.toLowerCase()) &
              tbl.status.equals('draft') &
              tbl.deletedAt.isNull(),
        );

      final drafts = await query.get();
      if (drafts.isEmpty) return 0;

      for (final draft in drafts) {
        await (_database.delete(
          _database.activitiesTable,
        )..where((tbl) => tbl.id.equals(draft.id))).go();
      }

      _report.info(
        'Cleaned up ${drafts.length} draft activities',
        area: 'activities',
      );
      return drafts.length;
    } catch (e) {
      _report.fault(
        e,
        area: 'activities',
        message: 'Error cleaning up draft activities',
      );
      return 0;
    }
  }

  /// Helper to map activities asynchronously yielding to the event loop
  /// This prevents the main thread from freezing during heavy syncs
  Future<List<domain.Activity>> _mapActivitiesAsync(
    List<Activity> activities,
  ) async {
    final result = <domain.Activity>[];
    final stopwatch = Stopwatch()..start();

    for (var i = 0; i < activities.length; i++) {
      // Yield every 5 items OR if we've been processing for more than 16ms (1 frame)
      if (i > 0 && (i % 5 == 0 || stopwatch.elapsedMilliseconds > 16)) {
        await Future.delayed(Duration.zero);
        stopwatch.reset();
      }
      result.add(_activitiesRepository.mapper.fromDriftRow(activities[i]));
    }
    return result;
  }

  /// Fills in `brickMetadata` for bricks whose segments are missing, from
  /// their archived leg rows.
  ///
  /// Ticket 24 (Sentry DEV-88, N+1 on `root /`): this used to run two
  /// queries PER brick (archived legs by `brick_id`, then legacy legs by the
  /// ids in the title), and an orphan brick that recovers nothing repeats
  /// them on every load. The archived and legacy lookups are now one query
  /// each for all the bricks in the list; only the title-match fallback
  /// (bricks whose title names sports, not ids) still queries per brick.
  Future<List<domain.Activity>> _hydrateBrickMetadataForActivities({
    required String userId,
    required List<domain.Activity> activities,
  }) async {
    final needsHydration = [
      for (final activity in activities)
        if (activity.isBrick &&
            (activity.brickMetadata?.segments ?? const []).isEmpty)
          activity,
    ];
    if (needsHydration.isEmpty) return activities;

    final archivedByBrick = await _archivedRowsByBrickId(
      userId: userId,
      brickIds: [for (final brick in needsHydration) brick.id],
    );
    final legacyIdsByBrick = <String, List<String>>{
      for (final brick in needsHydration)
        if (!archivedByBrick.containsKey(brick.id))
          brick.id: _extractLegacySegmentIdsFromBrickTitle(brick.title),
    }..removeWhere((_, ids) => ids.length < 2);
    final legacyRowsById = await _legacyRowsById(
      userId: userId,
      segmentIds: {for (final ids in legacyIdsByBrick.values) ...ids},
    );

    final hydrated = <domain.Activity>[];

    for (final activity in activities) {
      if (!activity.isBrick) {
        hydrated.add(activity);
        continue;
      }

      final segments = activity.brickMetadata?.segments ?? const [];
      if (segments.isNotEmpty) {
        hydrated.add(activity);
        continue;
      }

      var segmentRows = archivedByBrick[activity.id] ?? const <Activity>[];
      if (segmentRows.isEmpty) {
        segmentRows = _orderLegacyBrickSegmentRows(
          brick: activity,
          segmentIds: legacyIdsByBrick[activity.id] ?? const [],
          rowsById: legacyRowsById,
        );
      }
      if (segmentRows.isEmpty) {
        segmentRows = await _findTitleMatchedArchivedRows(
          userId: userId,
          brick: activity,
        );
      }

      if (segmentRows.isEmpty) {
        _report.debug(
          'Orphan brick activity has no segment data; keeping visible',
          area: 'activities',
          data: {'brickId': activity.id, 'title': activity.title},
        );
        hydrated.add(activity);
        continue;
      }

      await _linkSegmentRowsToBrickIfNeeded(
        brickId: activity.id,
        segmentRows: segmentRows,
      );

      final reconstructed = _buildBrickMetadataFromActivityRows(segmentRows);
      final patched = activity.copyWith(brickMetadata: reconstructed);
      hydrated.add(patched);

      await _persistReconstructedBrickMetadata(
        brickId: activity.id,
        metadata: reconstructed,
      );
    }

    return hydrated;
  }

  /// Archived leg rows for every brick in [brickIds], in one query, grouped
  /// by brick and ordered by `scheduled_date_time`. A brick with no archived
  /// legs is absent from the map.
  Future<Map<String, List<Activity>>> _archivedRowsByBrickId({
    required String userId,
    required List<String> brickIds,
  }) async {
    final rows =
        await (_database.select(_database.activitiesTable)
              ..where(
                (tbl) =>
                    tbl.userId.lower().equals(userId.toLowerCase()) &
                    tbl.brickId.isIn(brickIds) &
                    tbl.deletedAt.isNull() &
                    (tbl.status.equals('archivedForBrick') |
                        tbl.status.equals('archived_for_brick')),
              )
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.scheduledDateTime)]))
            .get();

    final byBrick = <String, List<Activity>>{};
    for (final row in rows) {
      byBrick.putIfAbsent(row.brickId!, () => []).add(row);
    }
    return byBrick;
  }

  /// Leg rows of legacy bricks (whose title holds their legs' ids) for every
  /// id in [segmentIds], in one query, keyed by lower-cased id.
  Future<Map<String, Activity>> _legacyRowsById({
    required String userId,
    required Set<String> segmentIds,
  }) async {
    if (segmentIds.isEmpty) return const {};
    final rows =
        await (_database.select(_database.activitiesTable)..where(
              (tbl) =>
                  tbl.userId.lower().equals(userId.toLowerCase()) &
                  tbl.id.isIn(segmentIds) &
                  tbl.activityType.equals('brick').not() &
                  tbl.deletedAt.isNull(),
            ))
            .get();
    return {for (final row in rows) row.id.toLowerCase(): row};
  }

  List<Activity> _orderLegacyBrickSegmentRows({
    required domain.Activity brick,
    required List<String> segmentIds,
    required Map<String, Activity> rowsById,
  }) {
    if (segmentIds.length < 2) {
      return const [];
    }

    final orderedRows = <Activity>[];
    for (final segmentId in segmentIds) {
      final match = rowsById[segmentId.toLowerCase()];
      if (match != null) {
        orderedRows.add(match);
      }
    }

    if (orderedRows.length < 2) {
      return const [];
    }

    _report.debug(
      'Recovered brick metadata from legacy title IDs',
      area: 'activities',
      data: {
        'brickId': brick.id,
        'segmentIds': segmentIds,
        'recoveredCount': orderedRows.length,
      },
    );
    return orderedRows;
  }

  Future<List<Activity>> _findTitleMatchedArchivedRows({
    required String userId,
    required domain.Activity brick,
  }) async {
    final sports = _extractSportsFromBrickTitle(brick.title);
    if (sports.length < 2) {
      return const [];
    }

    final from = brick.scheduledDateTime.subtract(const Duration(minutes: 1));
    final to = brick.scheduledDateTime.add(const Duration(minutes: 1));

    final candidateRows =
        await (_database.select(_database.activitiesTable)
              ..where(
                (tbl) =>
                    tbl.userId.lower().equals(userId.toLowerCase()) &
                    tbl.activityType.isIn(sports) &
                    tbl.scheduledDateTime.isBetweenValues(from, to) &
                    tbl.deletedAt.isNull() &
                    tbl.brickId.isNull() &
                    (tbl.status.equals('archivedForBrick') |
                        tbl.status.equals('archived_for_brick')),
              )
              ..orderBy([
                (tbl) => OrderingTerm.asc(tbl.scheduledDateTime),
                (tbl) => OrderingTerm.asc(tbl.updatedAt),
              ]))
            .get();

    if (candidateRows.length < sports.length) {
      return const [];
    }

    final usedIds = <String>{};
    final ordered = <Activity>[];

    for (final sport in sports) {
      Activity? match;
      for (final row in candidateRows) {
        if (usedIds.contains(row.id)) continue;
        if (row.activityType == sport) {
          match = row;
          break;
        }
      }

      if (match == null) {
        return const [];
      }

      usedIds.add(match.id);
      ordered.add(match);
    }

    _report.debug(
      'Recovered brick metadata from archived rows missing brick_id',
      area: 'activities',
      data: {
        'brickId': brick.id,
        'sports': sports,
        'segmentIds': ordered.map((row) => row.id).toList(),
      },
    );

    return ordered;
  }

  List<String> _extractSportsFromBrickTitle(String title) {
    final stripped = title.trim().replaceFirst(
      RegExp(r'\s+BRICK$', caseSensitive: false),
      '',
    );
    final tokens = stripped
        .split('/')
        .map((part) => part.trim().toUpperCase())
        .where((part) => part.isNotEmpty)
        .toList();

    if (tokens.length < 2 || tokens.length > 3) {
      return const [];
    }

    const map = <String, String>{
      'SWIM': 'swimming',
      'SWIMMING': 'swimming',
      'BIKE': 'cycling',
      'CYCLING': 'cycling',
      'RIDE': 'cycling',
      'RUN': 'running',
      'RUNNING': 'running',
    };

    final sports = <String>[];
    for (final token in tokens) {
      final sport = map[token];
      if (sport == null) {
        return const [];
      }
      sports.add(sport);
    }

    return sports;
  }

  Future<void> _linkSegmentRowsToBrickIfNeeded({
    required String brickId,
    required List<Activity> segmentRows,
  }) async {
    final rowsNeedingLink = segmentRows.where((row) => row.brickId != brickId);
    if (rowsNeedingLink.isEmpty) {
      return;
    }

    final now = DateTime.now();
    for (final row in rowsNeedingLink) {
      try {
        await (_database.update(
          _database.activitiesTable,
        )..where((tbl) => tbl.id.equals(row.id))).write(
          ActivitiesTableCompanion(
            brickId: Value(brickId),
            needsUpload: const Value(true),
            localUpdatedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      } catch (e) {
        _report.degraded(
          e,
          area: 'activities',
          message: 'Failed to relink segment row to brick',
          extra: {'brickId': brickId, 'segmentId': row.id},
        );
      }
    }
  }

  List<String> _extractLegacySegmentIdsFromBrickTitle(String title) {
    final stripped = title.trim().replaceFirst(
      RegExp(r'\s+BRICK$', caseSensitive: false),
      '',
    );
    final parts = stripped
        .split('/')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length < 2 || parts.length > 3) {
      return const [];
    }

    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    if (parts.any((part) => !uuidPattern.hasMatch(part))) {
      return const [];
    }
    return parts;
  }

  Future<void> _persistReconstructedBrickMetadata({
    required String brickId,
    required BrickMetadata metadata,
  }) async {
    try {
      final now = DateTime.now();
      await (_database.update(
        _database.activitiesTable,
      )..where((tbl) => tbl.id.equals(brickId))).write(
        ActivitiesTableCompanion(
          brickMetadata: Value(jsonEncode(metadata.toJson())),
          needsUpload: const Value(true),
          localUpdatedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    } catch (e) {
      _report.degraded(
        e,
        area: 'activities',
        message: 'Failed to persist reconstructed brick metadata',
        extra: {'brickId': brickId},
      );
    }
  }

  BrickMetadata _buildBrickMetadataFromActivityRows(
    List<Activity> activityRows,
  ) {
    final segments = <BrickSegment>[];
    var totalDurationMinutes = 0;

    for (var i = 0; i < activityRows.length; i++) {
      final row = activityRows[i];
      final durationMinutes = row.durationMinutes ?? 0;
      totalDurationMinutes += durationMinutes;

      final sport = row.activityType;
      final isSwim = sport == 'swimming';
      final isRunOrBike = sport == 'running' || sport == 'cycling';

      segments.add(
        BrickSegment(
          sport: sport,
          order: i + 1,
          durationMinutes: durationMinutes,
          intensity: row.intensityLevel ?? 'moderate',
          distanceMeters: isSwim && row.distanceMiles != null
              ? row.distanceMiles! * 1609.34
              : null,
          pacePer100mSeconds: row.swimmingPacePer100mSeconds,
          poolOrOpenWater: row.swimmingPoolOrOpenWater,
          waterTempC: row.swimmingWaterTempC,
          distanceMiles: isRunOrBike ? row.distanceMiles : null,
          speedMph: row.cyclingSpeedMph,
          terrain: row.cyclingTerrain,
          indoorOutdoor: row.cyclingIndoorOutdoor,
          elevationGainFt: row.cyclingElevationGainFt,
          paceMinutesPerMile: row.paceTargetMinutesPerMile,
        ),
      );
    }

    return BrickMetadata(
      segmentOrder: activityRows.map((row) => row.activityType).toList(),
      segments: segments,
      originalActivityIds: activityRows.map((row) => row.id).toList(),
      createdFromExisting: true,
      totalDurationMinutes: totalDurationMinutes,
    );
  }

  /// Get a specific activity by ID
  Future<domain.Activity?> getActivityById(
    String userId,
    String activityId,
  ) async {
    try {
      _report.info(
        'Fetching activity by ID',
        area: 'activities',
        data: {'userId': userId, 'activityId': activityId},
      );

      // CRITICAL FIX: Use case-insensitive comparison for userId
      final query = _database.select(_database.activitiesTable)
        ..where(
          (tbl) =>
              tbl.userId.lower().equals(userId.toLowerCase()) &
              tbl.id.equals(activityId) &
              tbl.deletedAt.isNull(),
        );

      final activity = await query.getSingleOrNull();

      if (activity == null) {
        _report.degraded(
          LoggedFault('Activity not found in database'),
          area: 'activities',
          extra: {
            'userId': userId,
            'activityId': activityId,
            'searchedWithDeletedAtNull': true,
          },
        );
        return null;
      }

      _report.info(
        'Activity found successfully',
        area: 'activities',
        data: {
          'activityId': activity.id,
          'title': activity.title,
          'hasNutritionPlan': activity.nutritionPlanData != null,
        },
      );

      final mapped = _activitiesRepository.mapper.fromDriftRow(activity);
      final hydrated = await _hydrateBrickMetadataForActivities(
        userId: userId,
        activities: [mapped],
      );
      return hydrated.isEmpty ? null : hydrated.first;
    } catch (e) {
      _report.fault(
        e,
        area: 'activities',
        message: 'Error getting activity by ID',
        extra: {'userId': userId, 'activityId': activityId},
      );
      rethrow;
    }
  }

  /// Create a new running activity
  /// If [forUserId] is provided and different from [userId], validates coach-athlete relationship
  Future<domain.Activity> createActivity({
    required String deviceId,
    required String userId,
    String?
    forUserId, // NEW: If provided, create activity for this user (coach creating for athlete)
    required ActivityType activityType,
    required String title,
    required DateTime scheduledDateTime,
    double? distanceMiles,
    int? durationMinutes,
    double? paceTargetMinutesPerMile,
    domain.IntensityLevel? intensityLevel,
    String? notes,
    // Cycling-specific parameters
    double? cyclingSpeedMph,
    String? cyclingTerrain,
    String? cyclingIndoorOutdoor,
    int? cyclingElevationGainFt,
    String? cyclingSessionGoal,
    // Swimming-specific parameters
    int? swimmingPacePer100mSeconds,
    String? swimmingPoolOrOpenWater,
    double? swimmingWaterTempC,
    // Shared parameters
    String? intensityTarget,
    int? timeBeforeMinutes,
    // Nutrition plan data (embedded JSON)
    Map<String, dynamic>? nutritionPlanData,
    // Brick-specific parameters
    BrickMetadata? brickMetadata,
    String? brickId,
    WriteConsistency? consistency,
    domain.ActivityStatus status = domain.ActivityStatus.planned,
  }) async {
    try {
      // Determine the owner of the activity
      final ownerId = forUserId ?? userId;
      final resolvedConsistency =
          consistency ??
          WriteConsistencyResolver.forActorAndOwner(
            actorUserId: userId,
            ownerUserId: ownerId,
          );

      // Validate coach-athlete relationship if creating for someone else
      if (forUserId != null && forUserId != userId) {
        final hasActiveRelationship = await _coachRepository
            .isActiveCoachAthleteRelationship(
              coachUserId: userId,
              athleteUserId: forUserId,
            );

        if (!hasActiveRelationship) {
          _report.fault(
            LoggedFault('Coach does not have active relationship with athlete'),
            area: 'activities',
            extra: {'coachUserId': userId, 'athleteUserId': forUserId},
          );
          throw Exception(
            'Not authorized to create activities for this athlete',
          );
        }
      }

      final now = DateTime.now();
      final activity = domain.Activity(
        id: '', // Empty string - will be auto-generated by database
        userId: ownerId, // Use ownerId (athlete if coach is creating for them)
        activityType: activityType,
        title: title,
        scheduledDateTime: scheduledDateTime,
        status: status,
        distanceMiles: distanceMiles,
        durationMinutes: durationMinutes,
        paceTargetMinutesPerMile: paceTargetMinutesPerMile,
        intensityLevel: intensityLevel,
        notes: notes,
        // Cycling-specific fields
        cyclingSpeedMph: cyclingSpeedMph,
        cyclingTerrain: cyclingTerrain,
        cyclingIndoorOutdoor: cyclingIndoorOutdoor,
        cyclingElevationGainFt: cyclingElevationGainFt,
        cyclingSessionGoal: cyclingSessionGoal,
        // Swimming-specific fields
        swimmingPacePer100mSeconds: swimmingPacePer100mSeconds,
        swimmingPoolOrOpenWater: swimmingPoolOrOpenWater,
        swimmingWaterTempC: swimmingWaterTempC,
        // Shared fields
        intensityTarget: intensityTarget,
        timeBeforeMinutes: timeBeforeMinutes,
        // Nutrition plan data (embedded JSON)
        nutritionPlanData: nutritionPlanData,
        // Brick-specific fields
        brickMetadata: brickMetadata,
        brickId: brickId,
        createdAt: now,
        updatedAt: now,
      );

      _report.info(
        'Resolved write consistency',
        area: 'activities',
        data: {
          'entity': 'activity',
          'operation': 'create',
          'actorUserId': userId,
          'ownerUserId': ownerId,
          'consistencyMode': resolvedConsistency.value,
        },
      );

      return await _activitiesRepository.createActivity(
        deviceId: deviceId,
        activity: activity,
        requireRemoteAck:
            resolvedConsistency == WriteConsistency.remoteAckRequired,
      );
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'activities',
        message: 'Error creating activity',
      );
      rethrow;
    }
  }

  /// Create a new cycling activity (convenience method)
  Future<domain.Activity> createCyclingActivity({
    required String deviceId,
    required String userId,
    String?
    forUserId, // NEW: If provided, create activity for this user (coach creating for athlete)
    required String title,
    required DateTime scheduledDateTime,
    required double distanceMiles,
    required int durationMinutes,
    required double cyclingSpeedMph,
    String? cyclingTerrain,
    String? cyclingIndoorOutdoor,
    int? cyclingElevationGainFt,
    String? cyclingSessionGoal,
    String? intensityTarget,
    int? timeBeforeMinutes,
    String? notes,
    WriteConsistency? consistency,
  }) async {
    return createActivity(
      deviceId: deviceId,
      userId: userId,
      forUserId: forUserId,
      activityType: ActivityType.cycling,
      title: title,
      scheduledDateTime: scheduledDateTime,
      distanceMiles: distanceMiles,
      durationMinutes: durationMinutes,
      cyclingSpeedMph: cyclingSpeedMph,
      cyclingTerrain: cyclingTerrain,
      cyclingIndoorOutdoor: cyclingIndoorOutdoor,
      cyclingElevationGainFt: cyclingElevationGainFt,
      cyclingSessionGoal: cyclingSessionGoal,
      intensityTarget: intensityTarget,
      timeBeforeMinutes: timeBeforeMinutes,
      notes: notes,
      consistency: consistency,
    );
  }

  /// Create a new swimming activity (convenience method)
  Future<domain.Activity> createSwimmingActivity({
    required String deviceId,
    required String userId,
    String?
    forUserId, // NEW: If provided, create activity for this user (coach creating for athlete)
    required String title,
    required DateTime scheduledDateTime,
    required double distanceMiles,
    required int durationMinutes,
    required int swimmingPacePer100mSeconds,
    String? swimmingPoolOrOpenWater,
    double? swimmingWaterTempC,
    String? intensityTarget,
    int? timeBeforeMinutes,
    String? notes,
    WriteConsistency? consistency,
  }) async {
    return createActivity(
      deviceId: deviceId,
      userId: userId,
      forUserId: forUserId,
      activityType: ActivityType.swimming,
      title: title,
      scheduledDateTime: scheduledDateTime,
      distanceMiles: distanceMiles,
      durationMinutes: durationMinutes,
      swimmingPacePer100mSeconds: swimmingPacePer100mSeconds,
      swimmingPoolOrOpenWater: swimmingPoolOrOpenWater,
      swimmingWaterTempC: swimmingWaterTempC,
      intensityTarget: intensityTarget,
      timeBeforeMinutes: timeBeforeMinutes,
      notes: notes,
      consistency: consistency,
    );
  }

  /// Create a brick workout from existing activities (convenience method)
  /// Delegates to the repository's createBrickFromActivities method which:
  /// 1. Creates a new brick activity with BrickMetadata
  /// 2. Archives the original activities
  /// 3. Links them together via brick_id
  Future<domain.Activity> createBrickActivity({
    required List<domain.Activity> activities,
    required List<String> segmentOrder,
  }) async {
    try {
      if (activities.length < 2 || activities.length > 3) {
        throw ArgumentError('Brick must have 2-3 activities');
      }

      if (segmentOrder.length != activities.length) {
        throw ArgumentError('Segment order must match activities length');
      }

      _report.info(
        'Creating brick activity from existing activities',
        area: 'activities',
        data: {
          'activityCount': activities.length,
          'segmentOrder': segmentOrder,
          'activityIds': activities.map((a) => a.id).toList(),
        },
      );

      return await _activitiesRepository.createBrickFromActivities(
        activities: activities,
        segmentOrder: segmentOrder,
      );
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'activities',
        message: 'Error creating brick activity',
      );
      rethrow;
    }
  }

  /// Update an existing activity
  /// If [currentUserId] is provided and different from activity.userId, validates coach-athlete relationship
  Future<domain.Activity> updateActivity({
    required String deviceId,
    required domain.Activity activity,
    String?
    currentUserId, // NEW: Current user ID (for validation if coach is editing athlete's activity)
    WriteConsistency? consistency,
  }) async {
    try {
      final actorUserId = currentUserId ?? activity.userId;
      final resolvedConsistency =
          consistency ??
          WriteConsistencyResolver.forActorAndOwner(
            actorUserId: actorUserId,
            ownerUserId: activity.userId,
          );

      // Validate coach-athlete relationship if editing for someone else
      if (currentUserId != null && currentUserId != activity.userId) {
        final hasActiveRelationship = await _coachRepository
            .isActiveCoachAthleteRelationship(
              coachUserId: currentUserId,
              athleteUserId: activity.userId,
            );

        if (!hasActiveRelationship) {
          _report.fault(
            LoggedFault('Coach does not have active relationship with athlete'),
            area: 'activities',
            extra: {
              'coachUserId': currentUserId,
              'athleteUserId': activity.userId,
            },
          );
          throw Exception(
            'Not authorized to update activities for this athlete',
          );
        }
      }

      _report.info(
        'Resolved write consistency',
        area: 'activities',
        data: {
          'entity': 'activity',
          'operation': 'update',
          'actorUserId': actorUserId,
          'ownerUserId': activity.userId,
          'consistencyMode': resolvedConsistency.value,
          'activityId': activity.id,
        },
      );

      return await _activitiesRepository.updateActivity(
        deviceId: deviceId,
        activity: activity.copyWith(updatedAt: DateTime.now()),
        requireRemoteAck:
            resolvedConsistency == WriteConsistency.remoteAckRequired,
      );
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'activities',
        message: 'Error updating activity',
      );
      rethrow;
    }
  }

  /// Delete an activity (soft delete)
  /// If [currentUserId] is provided, validates coach-athlete relationship for cross-user deletion
  Future<void> deleteActivity({
    required String deviceId,
    required String activityId,
    String?
    currentUserId, // NEW: Current user ID (for validation if coach is deleting athlete's activity)
    String? activityOwnerId, // NEW: Activity owner ID (for validation)
    WriteConsistency? consistency,
  }) async {
    try {
      final actorUserId = currentUserId ?? deviceId;
      final ownerUserId = activityOwnerId ?? actorUserId;
      final resolvedConsistency =
          consistency ??
          WriteConsistencyResolver.forActorAndOwner(
            actorUserId: actorUserId,
            ownerUserId: ownerUserId,
          );

      // Validate coach-athlete relationship if deleting for someone else
      if (currentUserId != null &&
          activityOwnerId != null &&
          currentUserId != activityOwnerId) {
        final hasActiveRelationship = await _coachRepository
            .isActiveCoachAthleteRelationship(
              coachUserId: currentUserId,
              athleteUserId: activityOwnerId,
            );

        if (!hasActiveRelationship) {
          _report.fault(
            LoggedFault('Coach does not have active relationship with athlete'),
            area: 'activities',
            extra: {
              'coachUserId': currentUserId,
              'athleteUserId': activityOwnerId,
            },
          );
          throw Exception(
            'Not authorized to delete activities for this athlete',
          );
        }
      }

      _report.info(
        'Resolved write consistency',
        area: 'activities',
        data: {
          'entity': 'activity',
          'operation': 'delete',
          'actorUserId': actorUserId,
          'ownerUserId': ownerUserId,
          'consistencyMode': resolvedConsistency.value,
          'activityId': activityId,
        },
      );

      await _activitiesRepository.deleteActivity(
        deviceId: deviceId,
        activityId: activityId,
        requireRemoteAck:
            resolvedConsistency == WriteConsistency.remoteAckRequired,
        remoteUserId: ownerUserId,
      );
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'activities',
        message: 'Error deleting activity',
      );
      rethrow;
    }
  }

  /// Mark a workout done (dashboard G1): actual_time = now, status
  /// completed. planned_time is never touched by any gesture.
  Future<void> markWorkoutDone({required String activityId}) async {
    await _activitiesRepository.markWorkoutDone(activityId: activityId);
  }

  /// Mark a workout not-done (dashboard G2): actual_time cleared to null,
  /// status back to planned.
  Future<void> markWorkoutUndone({required String activityId}) async {
    await _activitiesRepository.markWorkoutUndone(activityId: activityId);
  }

  /// Skip a workout (dashboard G5, v2): status = 'skipped', actual_time
  /// cleared, planned_time untouched. Never a delete.
  Future<void> skipWorkout({required String activityId}) async {
    await _activitiesRepository.skipWorkout(activityId: activityId);
  }

  /// Unskip a workout (dashboard G5, v2): status back to planned.
  Future<void> unskipWorkout({required String activityId}) async {
    await _activitiesRepository.unskipWorkout(activityId: activityId);
  }
}
