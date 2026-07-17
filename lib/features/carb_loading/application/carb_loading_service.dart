import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/domain/write_consistency.dart';
import '../data/carb_loading_repository.dart';
import '../../coach_mode/data/coach_repository.dart';
import '../../events/data/events_repository.dart';

part 'carb_loading_service.g.dart';

@riverpod
CarbLoadingService carbLoadingService(Ref ref) {
  return CarbLoadingService(
    ref.read(appDatabaseProvider),
    ref.read(appLoggerProvider),
    ref.read(carbLoadingRepositoryProvider),
    ref.read(coachRepositoryProvider),
    ref.read(eventsRepositoryProvider),
  );
}

/// Service for managing carb loading plans and days
/// Handles creation, deletion, and updates of carb loading protocols
class CarbLoadingService {
  final AppDatabase _database;
  final AppLogger _logger;
  final CarbLoadingRepository _carbLoadingRepository;
  final CoachRepository _coachRepository;
  final EventsRepository _eventsRepository;

  CarbLoadingService(
    this._database,
    this._logger,
    this._carbLoadingRepository,
    this._coachRepository,
    this._eventsRepository,
  );

  /// Create a carb loading plan for an event
  /// This generates day records for each carb loading day based on the protocol
  /// If [forUserId] is provided and different from [userId], validates coach-athlete relationship
  Future<void> createCarbLoadingPlan({
    required String deviceId,
    required String userId,
    String?
    forUserId, // NEW: If provided, create plan for this user (coach creating for athlete)
    String? eventId,
    required int protocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
    WriteConsistency? consistency,
  }) async {
    try {
      // Determine the owner of the plan
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
          _logger.error(
            'Coach does not have active relationship with athlete',
            context: 'CARB_LOADING_SERVICE',
            data: {'coachUserId': userId, 'athleteUserId': forUserId},
          );
          throw Exception(
            'Not authorized to create carb loading plans for this athlete',
          );
        }
      }

      // Make create idempotent: remove any plan(s) already attached to this
      // event first. Without this, a stale `event.hasCarbLoading` flag or a
      // double-fired protocol selection routes through the no-guard create path
      // twice and leaves TWO plans for one event — which then made every
      // getCarbLoadingPlan read throw 'Too many elements' and killed the whole
      // event (no days, no calendar dots). getCarbLoadingPlan self-heals
      // existing duplicates; this stops new ones being born.
      if (eventId != null) {
        final existing = await getCarbLoadingPlan(eventId);
        if (existing != null) {
          _logger.info(
            'Replacing existing carb loading plan ${existing.id} for event '
            '$eventId before creating the new one',
            context: 'CARB_LOADING_SERVICE',
            data: {'eventId': eventId, 'existingPlanId': existing.id},
          );
          await _carbLoadingRepository.deleteCarbLoadingPlan(
            deviceId: deviceId,
            planId: existing.id,
            requireRemoteAck:
                resolvedConsistency == WriteConsistency.remoteAckRequired,
          );
        }
      }

      // Repository creates the plan AND its per-day rows locally in Drift
      // (offline-first, needs_upload=true) — not via an edge function, despite
      // what an older comment here claimed. So the days exist on-device the
      // moment this returns; the calendar/dashboard read them from Drift.
      await _carbLoadingRepository.createCarbLoadingPlan(
        deviceId: deviceId,
        userId: ownerId, // Use ownerId (athlete if coach is creating for them)
        eventId: eventId,
        protocolDays: protocolDays,
        raceDate: raceDate,
        bodyWeightPounds: bodyWeightPounds,
        requireRemoteAck:
            resolvedConsistency == WriteConsistency.remoteAckRequired,
      );

      _logger.info(
        'Resolved write consistency',
        context: 'CARB_LOADING_SERVICE',
        data: {
          'entity': 'carb_loading_plan',
          'operation': 'create',
          'actorUserId': userId,
          'ownerUserId': ownerId,
          'consistencyMode': resolvedConsistency.value,
          'eventId': eventId,
        },
      );

      // Update event with carb loading info (only if eventId is provided)
      if (eventId != null) {
        final startDate = raceDate.subtract(Duration(days: protocolDays));
        await (_database.update(
          _database.eventsTable,
        )..where((tbl) => tbl.id.equals(eventId))).write(
          EventsTableCompanion(
            hasCarbLoading: const Value(true),
            carbLoadingDays: Value(protocolDays),
            carbLoadingStartDate: Value(startDate),
            updatedAt: Value(DateTime.now()),
            needsUpload: const Value(true),
            localUpdatedAt: Value(DateTime.now()),
          ),
        );

        // Upload the updated event to Supabase so athlete can see hasCarbLoading=true
        try {
          await _eventsRepository.uploadDirtyRecords(ownerId);
        } catch (e) {
          _logger.warning(
            'Failed to upload event after carb loading update; will retry on next sync',
            context: 'CARB_LOADING_SERVICE',
            error: e,
          );
        }
      }
    } catch (e) {
      _logger.error('Error creating carb loading plan', error: e);
      rethrow;
    }
  }

  /// Delete carb loading plan and associated day records
  /// If [currentUserId] is provided, validates coach-athlete relationship for cross-user deletion
  Future<void> deleteCarbLoadingPlan({
    required String deviceId,
    required String eventId,
    String?
    currentUserId, // NEW: Current user ID (for validation if coach is deleting athlete's plan)
    String? planOwnerId, // NEW: Plan owner ID (for validation)
    WriteConsistency? consistency,
  }) async {
    try {
      final actorUserId = currentUserId ?? deviceId;
      final ownerUserId = planOwnerId ?? actorUserId;
      final resolvedConsistency =
          consistency ??
          WriteConsistencyResolver.forActorAndOwner(
            actorUserId: actorUserId,
            ownerUserId: ownerUserId,
          );

      // Validate coach-athlete relationship if deleting for someone else
      if (currentUserId != null &&
          planOwnerId != null &&
          currentUserId != planOwnerId) {
        final hasActiveRelationship = await _coachRepository
            .isActiveCoachAthleteRelationship(
              coachUserId: currentUserId,
              athleteUserId: planOwnerId,
            );

        if (!hasActiveRelationship) {
          _logger.error(
            'Coach does not have active relationship with athlete',
            context: 'CARB_LOADING_SERVICE',
            data: {'coachUserId': currentUserId, 'athleteUserId': planOwnerId},
          );
          throw Exception(
            'Not authorized to delete carb loading plans for this athlete',
          );
        }
      }

      _logger.info(
        'Resolved write consistency',
        context: 'CARB_LOADING_SERVICE',
        data: {
          'entity': 'carb_loading_plan',
          'operation': 'delete',
          'actorUserId': actorUserId,
          'ownerUserId': ownerUserId,
          'consistencyMode': resolvedConsistency.value,
          'eventId': eventId,
        },
      );

      // First, look up the plan by eventId to get the actual planId
      final plan = await getCarbLoadingPlan(eventId);

      if (plan != null) {
        // Delete the plan using the actual plan ID
        await _carbLoadingRepository.deleteCarbLoadingPlan(
          deviceId: deviceId,
          planId: plan.id,
          requireRemoteAck:
              resolvedConsistency == WriteConsistency.remoteAckRequired,
        );
        _logger.info('Deleted carb loading plan ${plan.id} for event $eventId');
      } else {
        _logger.warning(
          'No carb loading plan found for event $eventId - nothing to delete',
        );
      }

      // Update event to clear carb loading flags (even if plan wasn't found)
      await (_database.update(
        _database.eventsTable,
      )..where((tbl) => tbl.id.equals(eventId))).write(
        EventsTableCompanion(
          hasCarbLoading: const Value(false),
          carbLoadingDays: const Value(null),
          carbLoadingStartDate: const Value(null),
          updatedAt: Value(DateTime.now()),
          needsUpload: const Value(true),
          localUpdatedAt: Value(DateTime.now()),
        ),
      );

      // Upload the updated event to Supabase so athlete sees hasCarbLoading=false
      try {
        await _eventsRepository.uploadDirtyRecords(ownerUserId);
      } catch (e) {
        _logger.warning(
          'Failed to upload event after carb loading deletion; will retry on next sync',
          context: 'CARB_LOADING_SERVICE',
          error: e,
        );
      }
    } catch (e) {
      _logger.error('Error deleting carb loading plan', error: e);
      rethrow;
    }
  }

  /// Delete a single carb loading day and its associated meals
  Future<void> deleteCarbLoadingDay(String carbLoadingDayId) async {
    try {
      _logger.info(
        'Resolved write consistency',
        context: 'CARB_LOADING_SERVICE',
        data: {
          'entity': 'carb_loading_day',
          'operation': 'delete',
          'consistencyMode': WriteConsistency.offlineFirst.value,
          'carbLoadingDayId': carbLoadingDayId,
        },
      );

      // Delete all meals for this day
      await (_database.delete(
        _database.carbLoadingDayMealsTable,
      )..where((tbl) => tbl.carbLoadingDayId.equals(carbLoadingDayId))).go();

      // Delete the carb loading day
      await (_database.delete(
        _database.carbLoadingDaysTable,
      )..where((tbl) => tbl.id.equals(carbLoadingDayId))).go();
    } catch (e) {
      _logger.error('Error deleting carb loading day', error: e);
      rethrow;
    }
  }

  /// Update a single carb loading day.
  /// If [currentUserId] differs from the day owner, coach-athlete relationship is validated.
  Future<CarbLoadingDay> updateCarbLoadingDay({
    required String deviceId,
    required String carbLoadingDayId,
    required Map<String, dynamic> updates,
    String? currentUserId,
    String? dayOwnerId,
    WriteConsistency? consistency,
  }) async {
    try {
      final actorUserId = currentUserId ?? deviceId;
      final ownerUserId =
          dayOwnerId ??
          await _carbLoadingRepository.getCarbLoadingDayOwnerUserId(
            carbLoadingDayId,
          ) ??
          actorUserId;
      final resolvedConsistency =
          consistency ??
          WriteConsistencyResolver.forActorAndOwner(
            actorUserId: actorUserId,
            ownerUserId: ownerUserId,
          );

      if (actorUserId != ownerUserId) {
        final hasActiveRelationship = await _coachRepository
            .isActiveCoachAthleteRelationship(
              coachUserId: actorUserId,
              athleteUserId: ownerUserId,
            );

        if (!hasActiveRelationship) {
          _logger.error(
            'Coach does not have active relationship with athlete',
            context: 'CARB_LOADING_SERVICE',
            data: {'coachUserId': actorUserId, 'athleteUserId': ownerUserId},
          );
          throw Exception(
            'Not authorized to update carb loading days for this athlete',
          );
        }
      }

      _logger.info(
        'Resolved write consistency',
        context: 'CARB_LOADING_SERVICE',
        data: {
          'entity': 'carb_loading_day',
          'operation': 'update',
          'actorUserId': actorUserId,
          'ownerUserId': ownerUserId,
          'consistencyMode': resolvedConsistency.value,
          'carbLoadingDayId': carbLoadingDayId,
        },
      );

      return await _carbLoadingRepository.updateCarbLoadingDay(
        deviceId: deviceId,
        carbLoadingDayId: carbLoadingDayId,
        updates: updates,
        requireRemoteAck:
            resolvedConsistency == WriteConsistency.remoteAckRequired,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error updating carb loading day',
        context: 'CARB_LOADING_SERVICE',
        error: e,
        stackTrace: stackTrace,
        data: {'carbLoadingDayId': carbLoadingDayId},
      );
      rethrow;
    }
  }

  /// Update carb loading protocol (delete old plan and create new one)
  /// If [forUserId] is provided, creates plan for this user (coach updating athlete's plan)
  Future<void> updateCarbLoadingProtocol({
    required String deviceId,
    required String userId,
    String?
    forUserId, // NEW: If provided, update plan for this user (coach updating athlete's plan)
    required String eventId,
    required int newProtocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
    WriteConsistency? consistency,
  }) async {
    try {
      // Determine the owner
      final ownerId = forUserId ?? userId;
      final resolvedConsistency =
          consistency ??
          WriteConsistencyResolver.forActorAndOwner(
            actorUserId: userId,
            ownerUserId: ownerId,
          );

      _logger.info(
        'Resolved write consistency',
        context: 'CARB_LOADING_SERVICE',
        data: {
          'entity': 'carb_loading_plan',
          'operation': 'update_protocol',
          'actorUserId': userId,
          'ownerUserId': ownerId,
          'consistencyMode': resolvedConsistency.value,
          'eventId': eventId,
        },
      );

      // Delete existing plan (validation happens in deleteCarbLoadingPlan)
      await deleteCarbLoadingPlan(
        deviceId: deviceId,
        eventId: eventId,
        currentUserId: userId,
        planOwnerId: ownerId,
        consistency: resolvedConsistency,
      );

      // Create new plan (validation happens in createCarbLoadingPlan)
      await createCarbLoadingPlan(
        deviceId: deviceId,
        userId: userId,
        forUserId: forUserId,
        eventId: eventId,
        protocolDays: newProtocolDays,
        raceDate: raceDate,
        bodyWeightPounds: bodyWeightPounds,
        consistency: resolvedConsistency,
      );
    } catch (e) {
      _logger.error('Error updating carb loading protocol', error: e);
      rethrow;
    }
  }

  /// Get carb loading plan for an event.
  ///
  /// Tolerates — and self-heals — duplicate plans for one event. A race between
  /// two concurrent protocol selections (the button double-fired; see the
  /// create/update paths) could insert more than one plan, and this used to
  /// call `getSingleOrNull()`, which THROWS `Bad state: Too many elements` on
  /// >1 row. That crash then cascaded through delete/update and left the whole
  /// event dead: no carb loading days rendered, no calendar dots, nothing.
  ///
  /// Now: return the newest plan and delete the older duplicates so the event
  /// converges back to a single plan on the next read.
  Future<CarbLoadingPlan?> getCarbLoadingPlan(String eventId) async {
    try {
      final plans =
          await (_database.select(_database.carbLoadingPlansTable)
                ..where((tbl) => tbl.eventId.equals(eventId))
                ..orderBy([(tbl) => OrderingTerm.desc(tbl.generatedAt)]))
              .get();

      if (plans.isEmpty) return null;
      final keep = plans.first;

      if (plans.length > 1) {
        _logger.warning(
          'Found ${plans.length} carb loading plans for event $eventId — '
          'keeping the newest (${keep.id}) and removing the duplicates',
          context: 'CARB_LOADING_SERVICE',
          data: {'eventId': eventId, 'keptPlanId': keep.id},
        );
        for (final dup in plans.skip(1)) {
          // Local cleanup only. Delete each duplicate's days + meals first so no
          // orphan rows remain, then the plan row itself. Best-effort: a failed
          // cleanup must not turn a read back into the crash it just replaced.
          try {
            final dupDays =
                await (_database.select(_database.carbLoadingDaysTable)
                      ..where((t) => t.carbLoadingPlanId.equals(dup.id)))
                    .get();
            for (final day in dupDays) {
              await (_database.delete(_database.carbLoadingDayMealsTable)
                    ..where((t) => t.carbLoadingDayId.equals(day.id)))
                  .go();
            }
            await (_database.delete(_database.carbLoadingDaysTable)
                  ..where((t) => t.carbLoadingPlanId.equals(dup.id)))
                .go();
            await (_database.delete(_database.carbLoadingPlansTable)
                  ..where((t) => t.id.equals(dup.id)))
                .go();
          } catch (e) {
            _logger.warning(
              'Failed to clean up duplicate carb loading plan ${dup.id}',
              context: 'CARB_LOADING_SERVICE',
              error: e,
            );
          }
        }
      }

      return keep;
    } catch (e) {
      _logger.error(
        'Error getting carb loading plan for event: $eventId',
        error: e,
      );
      rethrow;
    }
  }

  /// Get carb loading days for a plan
  Future<List<CarbLoadingDay>> getCarbLoadingDays(String planId) async {
    try {
      final query = _database.select(_database.carbLoadingDaysTable)
        ..where((tbl) => tbl.carbLoadingPlanId.equals(planId))
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.dayNumber)]);

      return await query.get();
    } catch (e) {
      _logger.error(
        'Error getting carb loading days for plan: $planId',
        error: e,
      );
      rethrow;
    }
  }

  /// Get all carb loading days for a date range, scoped to a specific user
  ///
  /// IMPORTANT: This method joins through carb_loading_plans to ensure
  /// only days belonging to the specified user are returned.
  Future<List<CarbLoadingDay>> getCarbLoadingDaysForRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Join carb_loading_days with carb_loading_plans to filter by user_id
      final query =
          _database.select(_database.carbLoadingDaysTable).join([
              innerJoin(
                _database.carbLoadingPlansTable,
                _database.carbLoadingPlansTable.id.equalsExp(
                  _database.carbLoadingDaysTable.carbLoadingPlanId,
                ),
              ),
            ])
            ..where(
              _database.carbLoadingPlansTable.userId.equals(userId) &
                  _database.carbLoadingDaysTable.planDate.isBiggerOrEqualValue(
                    startDate,
                  ) &
                  _database.carbLoadingDaysTable.planDate.isSmallerOrEqualValue(
                    endDate,
                  ),
            )
            ..orderBy([
              OrderingTerm.asc(_database.carbLoadingDaysTable.planDate),
            ]);

      final results = await query.get();
      return results
          .map((row) => row.readTable(_database.carbLoadingDaysTable))
          .toList();
    } catch (e) {
      _logger.error('Error getting carb loading days for range', error: e);
      rethrow;
    }
  }

  /// Get the carb protocol (g/kg) for a specific day (helper method)
  double getCarbProtocolForDay({
    required int protocolDays,
    required int daysBeforeRace,
  }) {
    if (protocolDays == 2) {
      // 2-day protocol
      if (daysBeforeRace == 2) {
        // Day -2: 9g/kg
        return 9.0;
      } else {
        // Day -1: 11g/kg
        return 11.0;
      }
    } else if (protocolDays == 3) {
      // 3-day protocol
      if (daysBeforeRace == 3 || daysBeforeRace == 2) {
        // Day -3 and -2: 8g/kg
        return 8.0;
      } else {
        // Day -1: 10g/kg
        return 10.0;
      }
    }

    // Default fallback
    return 8.0;
  }
}
