import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../database/app_database.dart';
import '../../../database/database_provider.dart';
import '../../../utils/sync_type_converters.dart';
import '../../report/report.dart';
import 'activity_sync_handler.dart';
import 'event_sync_handler.dart';
import 'carb_loading_sync_handler.dart';
import 'user_sync_handler.dart';

part 'coach_sync_handler.g.dart';

@Riverpod(keepAlive: true)
CoachSyncHandler coachSyncHandler(Ref ref) {
  return CoachSyncHandler(
    database: ref.read(appDatabaseProvider),
    supabase: Supabase.instance.client,
    activitySyncHandler: ref.read(activitySyncHandlerProvider),
    eventSyncHandler: ref.read(eventSyncHandlerProvider),
    carbLoadingSyncHandler: ref.read(carbLoadingSyncHandlerProvider),
    userSyncHandler: ref.read(userSyncHandlerProvider),
    report: ref.read(reportProvider),
  );
}

/// Handles sync operations for coach-related entities.
/// Includes coaches, relationships, messages, and athlete data syncing.
class CoachSyncHandler {
  const CoachSyncHandler({
    required AppDatabase database,
    required SupabaseClient supabase,
    required ActivitySyncHandler activitySyncHandler,
    required EventSyncHandler eventSyncHandler,
    required CarbLoadingSyncHandler carbLoadingSyncHandler,
    required UserSyncHandler userSyncHandler,
    Report? report,
  }) : _database = database,
       _supabase = supabase,
       _activitySyncHandler = activitySyncHandler,
       _eventSyncHandler = eventSyncHandler,
       _carbLoadingSyncHandler = carbLoadingSyncHandler,
       _userSyncHandler = userSyncHandler,
       _report = report;

  final AppDatabase _database;
  final SupabaseClient _supabase;
  final ActivitySyncHandler _activitySyncHandler;
  final EventSyncHandler _eventSyncHandler;
  final CarbLoadingSyncHandler _carbLoadingSyncHandler;
  final UserSyncHandler _userSyncHandler;
  final Report? _report;

  /// Injected by the provider; tests may pass a `RecordingReport`.
  Report get _r => _report ?? SentryReport.global;

  /// Sync coach messages for a specific activity from Supabase.
  /// Lightweight, focused sync triggered when viewing an activity's feedback.
  Future<void> syncCoachMessagesForActivity(String activityId) async {
    try {
      _r.info('Syncing coach messages for activity $activityId', area: 'sync');

      // Query Supabase directly for messages related to this activity
      final response = await _supabase
          .from('coach_messages')
          .select('*')
          .eq('activity_id', activityId)
          .order('created_at', ascending: false);

      final messages = response as List<dynamic>;

      if (messages.isNotEmpty) {
        await syncCoachMessages(messages);

        _r.info(
          'Successfully synced ${messages.length} messages for activity $activityId',
          area: 'sync',
        );
      } else {
        _r.info('No messages found for activity $activityId', area: 'sync');
      }
    } catch (e) {
      // The caller (activity feedback screen) owns the error.
      _r.breadcrumb(
        'Coach message sync failed for activity',
        category: 'sync',
        data: {'activityId': activityId, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Sync data for a specific athlete (lightweight, on-demand).
  /// Triggered when a coach views athlete details and taps refresh.
  Future<void> syncAthleteData(String athleteUserId) async {
    try {
      _r.info('Syncing data for athlete $athleteUserId', area: 'sync');

      // Query Supabase for athlete's data in parallel (including profile)
      final responses = await Future.wait([
        _supabase
            .from('users')
            .select('*')
            .eq('id', athleteUserId)
            .maybeSingle(),
        _supabase
            .from('events')
            .select('*')
            .eq('user_id', athleteUserId)
            .order('created_at', ascending: false),
        _supabase
            .from('activities')
            .select('*, nutrition_plan_data')
            .eq('user_id', athleteUserId)
            .isFilter('deleted_at', null)
            .isFilter('provider_deleted_at', null)
            .order('scheduled_date_time', ascending: false),
        _supabase
            .from('carb_loading_plans')
            .select('*')
            .eq('user_id', athleteUserId)
            .order('generated_at', ascending: false),
      ]);

      // Save to local database using existing sync methods
      final profileData = responses[0] as Map<String, dynamic>?;
      final eventsData = responses[1] as List<dynamic>;
      final activitiesData = responses[2] as List<dynamic>;
      final carbLoadingData = responses[3] as List<dynamic>;

      // Sync athlete profile first
      if (profileData != null) {
        _r.info(
          'Syncing athlete profile: ${profileData['first_name']} ${profileData['last_name']}',
          area: 'sync',
          data: {
            'athlete_user_id': athleteUserId,
            'has_first_name': profileData['first_name'] != null,
            'has_last_name': profileData['last_name'] != null,
          },
        );
        await _userSyncHandler.saveRemoteUserProfile(
          profileData,
          athleteUserId,
        );
      } else {
        _r.degraded(
          LoggedFault(
            'No profile data found for athlete $athleteUserId in Supabase',
          ),
          area: 'sync',
        );
      }

      // Sync activities BEFORE events because events may reference activities
      // via activity_id foreign key
      if (activitiesData.isNotEmpty) {
        await _activitySyncHandler.syncAthleteActivities(activitiesData);
      }
      if (eventsData.isNotEmpty) {
        await _eventSyncHandler.syncAthleteEvents(eventsData);
      }
      if (carbLoadingData.isNotEmpty) {
        await _carbLoadingSyncHandler.syncAthleteCarbLoadingPlans(
          carbLoadingData,
        );
      }

      _r.info(
        'Successfully synced athlete data: profile=${profileData != null}, '
        '${eventsData.length} events, ${activitiesData.length} activities, '
        '${carbLoadingData.length} carb loading plans',
        area: 'sync',
      );
    } catch (e) {
      _r.breadcrumb(
        'Athlete data sync failed',
        category: 'sync',
        data: {'athleteUserId': athleteUserId, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Sync coach record from edge function response to local database.
  Future<void> syncCoachRecord(Map<String, dynamic> coachData) async {
    try {
      final coachId = coachData['id'] as String?;
      if (coachId == null) {
        _r.degraded(
          const LoggedFault('Coach record missing id, skipping sync'),
          area: 'sync',
        );
        return;
      }

      // Parse and save to local coaches table
      final companion = CoachesTableCompanion.insert(
        id: coachId,
        userId: coachData['user_id'] as String,
        firstName: coachData['first_name'] as String,
        lastName: coachData['last_name'] as String,
        email: coachData['email'] as String,
        bio: Value(coachData['bio'] as String?),
        applicationStatus: Value(
          coachData['application_status'] as String? ?? 'pending',
        ),
        reviewedBy: Value(coachData['reviewed_by'] as String?),
        reviewedAt: Value(
          coachData['reviewed_at'] != null
              ? DateTime.parse(coachData['reviewed_at'] as String)
              : null,
        ),
        rejectionReason: Value(coachData['rejection_reason'] as String?),
        createdAt: Value(
          coachData['created_at'] != null
              ? DateTime.parse(coachData['created_at'] as String)
              : DateTime.now(),
        ),
        updatedAt: Value(
          coachData['updated_at'] != null
              ? DateTime.parse(coachData['updated_at'] as String)
              : DateTime.now(),
        ),
      );

      await _database
          .into(_database.coachesTable)
          .insert(companion, mode: InsertMode.insertOrReplace);

      _r.info(
        'Synced coach record to local DB',
        area: 'sync',
        data: {
          'coach_id': coachId,
          'user_id': coachData['user_id'],
          'status': coachData['application_status'],
        },
      );
    } catch (e, stackTrace) {
      // Don't rethrow - continue with other syncs
      await _r.fault(
        e,
        stackTrace: stackTrace,
        area: 'sync',
        message: 'Failed to sync coach record from edge function',
        tags: {'entity': 'coaches'},
      );
    }
  }

  /// Sync coach-athlete relationships from edge function response.
  Future<void> syncCoachAthleteRelationships(
    List<dynamic> relationships,
  ) async {
    try {
      for (final r in relationships) {
        final data = r as Map<String, dynamic>;
        final id = data['id'] as String?;
        if (id == null) continue;

        final companion = CoachAthleteRelationshipsTableCompanion.insert(
          id: id,
          coachUserId: data['coach_user_id'] as String,
          athleteUserId: data['athlete_user_id'] as String,
          requestedBy: data['requested_by'] as String,
          status: Value(data['status'] as String? ?? 'pending'),
          requestedAt: Value(
            data['requested_at'] != null
                ? DateTime.parse(data['requested_at'] as String)
                : DateTime.now(),
          ),
          acceptedAt: Value(
            data['accepted_at'] != null
                ? DateTime.parse(data['accepted_at'] as String)
                : null,
          ),
          declinedAt: Value(
            data['declined_at'] != null
                ? DateTime.parse(data['declined_at'] as String)
                : null,
          ),
          archivedAt: Value(
            data['archived_at'] != null
                ? DateTime.parse(data['archived_at'] as String)
                : null,
          ),
          createdAt: Value(
            data['created_at'] != null
                ? DateTime.parse(data['created_at'] as String)
                : DateTime.now(),
          ),
          updatedAt: Value(
            data['updated_at'] != null
                ? DateTime.parse(data['updated_at'] as String)
                : DateTime.now(),
          ),
        );

        await _database
            .into(_database.coachAthleteRelationshipsTable)
            .insert(companion, mode: InsertMode.insertOrReplace);
      }

      _r.info(
        'Synced ${relationships.length} coach-athlete relationships',
        area: 'sync',
      );
    } catch (e, stackTrace) {
      // Don't rethrow - continue with other syncs
      await _r.fault(
        e,
        stackTrace: stackTrace,
        area: 'sync',
        message: 'Failed to sync coach-athlete relationships',
        tags: {'entity': 'coach_athlete_relationships'},
        extra: {'count': relationships.length},
      );
    }
  }

  /// Sync coach messages from edge function response.
  Future<void> syncCoachMessages(List<dynamic> messages) async {
    try {
      for (final m in messages) {
        final data = m as Map<String, dynamic>;
        final id = data['id'] as String?;
        if (id == null) continue;

        final companion = CoachMessagesTableCompanion.insert(
          id: id,
          coachUserId: data['coach_user_id'] as String,
          athleteUserId: data['athlete_user_id'] as String,
          senderUserId: data['sender_user_id'] as String,
          messageText: data['message_text'] as String,
          nutritionPlanId: Value(data['nutrition_plan_id'] as String?),
          activityId: Value(data['activity_id'] as String?),
          isRead: Value(SyncTypeConverters.toBool(data['is_read'])),
          createdAt: Value(
            data['created_at'] != null
                ? DateTime.parse(data['created_at'] as String)
                : DateTime.now(),
          ),
          updatedAt: Value(
            data['updated_at'] != null
                ? DateTime.parse(data['updated_at'] as String)
                : DateTime.now(),
          ),
        );

        await _database
            .into(_database.coachMessagesTable)
            .insert(companion, mode: InsertMode.insertOrReplace);
      }

      _r.info('Synced ${messages.length} coach messages', area: 'sync');
    } catch (e, stackTrace) {
      // Don't rethrow - continue with other syncs
      await _r.fault(
        e,
        stackTrace: stackTrace,
        area: 'sync',
        message: 'Failed to sync coach messages',
        tags: {'entity': 'coach_messages'},
        extra: {'count': messages.length},
      );
    }
  }

  /// Sync athlete profiles for coaches (limited fields).
  Future<void> syncAthleteProfiles(List<dynamic> profiles) async {
    try {
      for (final p in profiles) {
        final data = p as Map<String, dynamic>;
        final id = data['id'] as String?;
        if (id == null) continue;

        // Use insertOrReplace to update existing profiles or insert new ones
        // Only sync the fields that coaches need to see
        // Note: Convert body_weight_kg to weightPounds if provided
        double? weightPounds;
        if (data['body_weight_kg'] != null) {
          final kg = (data['body_weight_kg'] as num).toDouble();
          weightPounds = kg * 2.20462; // Convert kg to pounds
        }

        final companion = UserProfilesTableCompanion(
          id: Value(id),
          firstName: Value(data['first_name'] as String?),
          lastName: Value(data['last_name'] as String?),
          senderName: Value(data['sender_name'] as String?),
          weightPounds: Value(weightPounds),
          dietaryPreference: Value(data['dietary_preference'] as String?),
          allergies: Value(data['allergies'] as String? ?? '{}'),
          updatedAt: Value(DateTime.now()),
        );

        await _database
            .into(_database.userProfilesTable)
            .insertOnConflictUpdate(companion);
      }

      _r.info(
        'Synced ${profiles.length} athlete profiles for coach',
        area: 'sync',
      );
    } catch (e, stackTrace) {
      // Don't rethrow - continue with other syncs
      await _r.fault(
        e,
        stackTrace: stackTrace,
        area: 'sync',
        message: 'Failed to sync athlete profiles',
        tags: {'entity': 'users'},
        extra: {'count': profiles.length},
      );
    }
  }

  /// Sync coach profiles for athletes (so athletes can see coach names).
  Future<void> syncCoachProfiles(List<dynamic> profiles) async {
    try {
      for (final p in profiles) {
        final data = p as Map<String, dynamic>;
        final id = data['id'] as String?;
        if (id == null) continue;

        // Only sync display name fields for coaches
        final companion = UserProfilesTableCompanion(
          id: Value(id),
          firstName: Value(data['first_name'] as String?),
          lastName: Value(data['last_name'] as String?),
          senderName: Value(data['sender_name'] as String?),
          updatedAt: Value(DateTime.now()),
        );

        await _database
            .into(_database.userProfilesTable)
            .insertOnConflictUpdate(companion);
      }

      _r.info(
        'Synced ${profiles.length} coach profiles for athlete',
        area: 'sync',
      );
    } catch (e, stackTrace) {
      // Don't rethrow - continue with other syncs
      await _r.fault(
        e,
        stackTrace: stackTrace,
        area: 'sync',
        message: 'Failed to sync coach profiles',
        tags: {'entity': 'users'},
        extra: {'count': profiles.length},
      );
    }
  }
}
