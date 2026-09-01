import 'package:flutter/foundation.dart';

import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../activities/data/activities_repository.dart';
import '../../activities/domain/activity.dart';
import '../data/integrations_repository.dart';
import '../data/runna_ics_client.dart';
import '../domain/integration_exceptions.dart';
import 'change_detection_service.dart';
import 'runna_ics_parser.dart';
import 'runna_transformer.dart';
import 'synced_workout_analytics.dart';

/// Syncs planned workouts from a Runna calendar-subscription (.ics) feed
/// into the local activities table.
///
/// Mirrors the FinalSurge / V.O2 sync pattern, but simpler: there is no
/// OAuth or token refresh. The feed URL (which embeds Runna's access token)
/// is stored in the integration row's `accessToken` field — the closest
/// existing slot for a bearer credential, and it keeps the URL backed up to
/// Supabase alongside every other provider secret. Documented here and at
/// the row-creation site (ConnectTrainingController.connectRunna).
///
/// Reconciliation rules specific to a rolling ICS feed:
/// - Incoming events are deduped by UID (confirmed stable across re-fetches).
/// - UID-churn fallback: plan regeneration in Runna MAY reissue UIDs. When an
///   incoming UID is unknown but a local planned Runna activity exists on the
///   same day with the same normalized title, we adopt the new UID onto that
///   activity instead of inserting a duplicate.
/// - Rolling-window deletion: the feed is a moving window (~2 weeks forward
///   for Premium calendar sync; past events roll off). A local FUTURE planned
///   activity is soft-deleted only when its date falls INSIDE the observed
///   feed window (>= min event date && <= max event date) and its UID is
///   absent. Absence outside the window just means the window moved — never
///   treated as deletion. Past/completed activities and rows already marked
///   providerDeletedAt are never touched (the ChangeDetectionService guard
///   from the provider re-delete churn fix also applies).
class RunnaSyncService {
  RunnaSyncService({
    required RunnaIcsClient icsClient,
    required RunnaIcsParser parser,
    required IntegrationsRepository integrationsRepository,
    required ActivitiesRepository activitiesRepository,
    required RunnaTransformer transformer,
    required ChangeDetectionService changeDetectionService,
    AnalyticsTracker? analytics,
  }) : _icsClient = icsClient,
       _parser = parser,
       _integrationsRepository = integrationsRepository,
       _activitiesRepository = activitiesRepository,
       _transformer = transformer,
       _changeDetectionService = changeDetectionService,
       _analytics = analytics;

  final RunnaIcsClient _icsClient;
  final RunnaIcsParser _parser;
  final IntegrationsRepository _integrationsRepository;
  final ActivitiesRepository _activitiesRepository;
  final RunnaTransformer _transformer;
  final ChangeDetectionService _changeDetectionService;
  final AnalyticsTracker? _analytics;

  static const _provider = 'runna';

  void _trackSyncedWorkoutPlanned(Activity activity) =>
      trackSyncedWorkoutPlanned(_analytics, activity, provider: _provider);

  /// Short stable fingerprint of the feed URL (FNV-1a 32-bit, hex). Used as
  /// the `providerAthleteId` for the integration row — Runna's feed carries
  /// no athlete identity, and the column is required text.
  static String stableFeedFingerprint(String url) {
    var hash = 0x811C9DC5;
    for (final unit in url.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Validate a feed URL by actually fetching and parsing it. Shape checks on
  /// the URL are deliberately permissive — "returns parseable ICS" is the
  /// real test. Throws the same typed errors as [RunnaIcsClient.fetchIcs].
  Future<RunnaFeedProbe> probeFeed(String feedUrl) async {
    final icsText = await _icsClient.fetchIcs(feedUrl);
    final parsed = _parser.parse(icsText);
    return RunnaFeedProbe(eventCount: parsed.events.length);
  }

  /// Sync workouts from the stored Runna feed.
  Future<RunnaSyncResult> syncWorkouts(String userId) async {
    final integration = await _integrationsRepository.getIntegration(
      userId,
      _provider,
    );
    if (integration == null || !integration.isActive) {
      return RunnaSyncResult.notConnected();
    }

    if (kDebugMode) {
      print('🔄 [runna] Starting sync for user $userId');
    }

    try {
      // The feed URL lives in accessToken (see class docs).
      final icsText = await _icsClient.fetchIcs(integration.accessToken);
      final parsed = _parser.parse(icsText);

      // Dedupe incoming events by UID.
      final seenUids = <String>{};
      final events = <RunnaIcsEvent>[];
      var filteredCount = parsed.skippedTotal;
      for (final event in parsed.events) {
        if (seenUids.add(event.uid)) {
          events.add(event);
        } else {
          filteredCount++;
        }
      }

      if (kDebugMode) {
        print(
          '   [runna] Parsed ${events.length} events '
          '(malformed: ${parsed.skippedMalformed}, '
          'cancelled: ${parsed.skippedCancelled}, '
          'recurring: ${parsed.skippedRecurring})',
        );
      }

      // Transform. Nulls are non-running sessions (strength/mobility/...)
      // deliberately skipped in MVP.
      final remoteActivities = <Activity>[];
      for (final event in events) {
        final result = _transformer.transform(event, userId);
        if (result == null) {
          filteredCount++;
          continue;
        }
        remoteActivities.add(result.activity);
      }

      // Clean any duplicates left behind by previous buggy syncs.
      await _activitiesRepository.cleanupDuplicateProviderActivities(
        userId: userId,
        provider: _provider,
      );

      final localActivities = await _activitiesRepository
          .getActivitiesByUserAndProvider(userId, _provider);

      // ------------------------------------------------------------------
      // UID-churn adoption: remap local UIDs before change detection so a
      // regenerated plan updates existing rows instead of duplicating them.
      // ------------------------------------------------------------------
      final adoption = _resolveUidAdoptions(
        localActivities: localActivities,
        remoteActivities: remoteActivities,
      );

      final changes = _changeDetectionService.detectChanges(
        localActivities: adoption.adjustedLocals,
        remoteWorkouts: remoteActivities,
        provider: _provider,
      );

      for (final activity in changes.newActivities) {
        await _activitiesRepository.insertActivity(activity);
        _trackSyncedWorkoutPlanned(activity);
      }

      var updatedCount = 0;
      for (final change in changes.updatedActivities) {
        final updated = change.updatedActivity.copyWith(
          id: change.activityId,
          needsNutritionRefresh: change.scheduleChanged,
          lastSyncedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _activitiesRepository.updateActivityFromProvider(updated);
        updatedCount++;
      }

      // Adopted pairs whose content is otherwise unchanged still need the new
      // UID persisted, or the next sync repeats the fingerprint match.
      final updatedIds = changes.updatedActivities
          .map((c) => c.activityId)
          .toSet();
      final remoteByUid = <String, Activity>{
        for (final a in remoteActivities)
          if (a.providerWorkoutId != null) a.providerWorkoutId!: a,
      };
      for (final entry in adoption.adoptedLocalIdByUid.entries) {
        if (updatedIds.contains(entry.value)) continue;
        final remote = remoteByUid[entry.key];
        if (remote == null) continue;
        await _activitiesRepository.updateActivityFromProvider(
          remote.copyWith(
            id: entry.value,
            lastSyncedAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        updatedCount++;
      }

      // ------------------------------------------------------------------
      // Rolling-window deletion filter (see class docs).
      // ------------------------------------------------------------------
      final deletedCount = await _applyWindowedDeletions(
        deletedActivityIds: changes.deletedActivityIds,
        localActivities: localActivities,
        remoteActivities: remoteActivities,
      );

      await _integrationsRepository.updateSyncStatus(
        userId,
        _provider,
        status: 'success',
      );

      if (kDebugMode) {
        print(
          '✅ [runna] Sync complete — '
          'new: ${changes.newActivities.length}, '
          'updated: $updatedCount, '
          'deleted: $deletedCount, '
          'filtered: $filteredCount',
        );
      }

      return RunnaSyncResult(
        success: true,
        newWorkouts: changes.newActivities.length,
        updated: updatedCount,
        deleted: deletedCount,
        skipped: changes.unchangedCount,
        filtered: filteredCount,
        activities: changes.newActivities,
      );
    } on NetworkException catch (e) {
      // Transient — don't stamp an error status, the user can just retry.
      if (kDebugMode) {
        print('❌ [runna] Sync failed (network): $e');
      }
      return RunnaSyncResult.networkError(e.message);
    } on IntegrationApiException catch (e) {
      await _integrationsRepository.updateSyncStatus(
        userId,
        _provider,
        status: 'error',
        error: e.message,
      );
      return RunnaSyncResult.error(e.message);
    } catch (e) {
      await _integrationsRepository.updateSyncStatus(
        userId,
        _provider,
        status: 'error',
        error: e.toString(),
      );
      if (kDebugMode) {
        print('❌ [runna] Sync failed: $e');
      }
      return RunnaSyncResult.error(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Same-day + normalized-title fingerprint used for UID-churn adoption.
  String _dayTitleFingerprint(Activity activity) {
    final d = activity.scheduledDateTime;
    return '${d.year}-${d.month}-${d.day}|${activity.title.trim().toLowerCase()}';
  }

  /// Match incoming events with unknown UIDs to local planned Runna
  /// activities on the same day with the same normalized title, and rewrite
  /// the local list so ChangeDetectionService pairs them by the NEW UID.
  _UidAdoptionResult _resolveUidAdoptions({
    required List<Activity> localActivities,
    required List<Activity> remoteActivities,
  }) {
    final localUids = <String>{
      for (final a in localActivities)
        if (a.providerWorkoutId != null) a.providerWorkoutId!,
    };
    final remoteUids = <String>{
      for (final a in remoteActivities)
        if (a.providerWorkoutId != null) a.providerWorkoutId!,
    };

    // Locals eligible for adoption: planned, not provider-deleted, and their
    // current UID no longer appears in the feed (otherwise they pair with
    // their own remote event).
    final adoptableByFingerprint = <String, Activity>{};
    for (final local in localActivities) {
      if (local.providerDeletedAt != null) continue;
      if (local.status != ActivityStatus.planned) continue;
      final uid = local.providerWorkoutId;
      if (uid != null && remoteUids.contains(uid)) continue;
      adoptableByFingerprint.putIfAbsent(
        _dayTitleFingerprint(local),
        () => local,
      );
    }

    final adoptedLocalIdByUid = <String, String>{};
    final newUidByLocalId = <String, String>{};
    for (final remote in remoteActivities) {
      final uid = remote.providerWorkoutId;
      if (uid == null || localUids.contains(uid)) continue;
      final match = adoptableByFingerprint.remove(_dayTitleFingerprint(remote));
      if (match != null) {
        adoptedLocalIdByUid[uid] = match.id;
        newUidByLocalId[match.id] = uid;
        if (kDebugMode) {
          print(
            '   🔗 [runna] UID adoption: "${match.title}" '
            '(${match.providerWorkoutId} → $uid)',
          );
        }
      }
    }

    final adjustedLocals = <Activity>[
      for (final local in localActivities)
        newUidByLocalId.containsKey(local.id)
            ? local.copyWith(providerWorkoutId: newUidByLocalId[local.id])
            : local,
    ];

    return _UidAdoptionResult(
      adjustedLocals: adjustedLocals,
      adoptedLocalIdByUid: adoptedLocalIdByUid,
    );
  }

  /// Apply the rolling-window deletion rule to the change-detection output.
  /// Returns the number of activities actually soft-deleted.
  Future<int> _applyWindowedDeletions({
    required List<String> deletedActivityIds,
    required List<Activity> localActivities,
    required List<Activity> remoteActivities,
  }) async {
    if (deletedActivityIds.isEmpty) return 0;

    // The observed feed window: min..max event date (date-only). An empty
    // feed gives us no window, so we delete nothing — never mass-delete on a
    // feed hiccup.
    DateTime? windowStart;
    DateTime? windowEnd;
    for (final remote in remoteActivities) {
      final day = _dateOnly(remote.scheduledDateTime);
      if (windowStart == null || day.isBefore(windowStart)) windowStart = day;
      if (windowEnd == null || day.isAfter(windowEnd)) windowEnd = day;
    }
    if (windowStart == null || windowEnd == null) return 0;

    final localById = {for (final a in localActivities) a.id: a};
    final now = DateTime.now();
    var deleted = 0;

    for (final activityId in deletedActivityIds) {
      final local = localById[activityId];
      if (local == null) continue;
      // Never touch completed (or otherwise non-planned) activities.
      if (local.status != ActivityStatus.planned) continue;
      // Never touch past activities — rolling feeds drop past events, so
      // absence of a past event is not deletion.
      if (!local.scheduledDateTime.isAfter(now)) continue;
      // Only delete inside the observed window; outside it, absence just
      // means the window moved.
      final day = _dateOnly(local.scheduledDateTime);
      if (day.isBefore(windowStart) || day.isAfter(windowEnd)) continue;

      await _activitiesRepository.softDeleteFromProvider(activityId);
      deleted++;
    }
    return deleted;
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}

class _UidAdoptionResult {
  const _UidAdoptionResult({
    required this.adjustedLocals,
    required this.adoptedLocalIdByUid,
  });

  final List<Activity> adjustedLocals;

  /// Remote UID → local activity id for pairs matched by fingerprint.
  final Map<String, String> adoptedLocalIdByUid;
}

/// Result of a connect-time feed validation fetch.
class RunnaFeedProbe {
  const RunnaFeedProbe({required this.eventCount});

  final int eventCount;
}

/// Result returned to controllers/UI. Mirrors VdotSyncResult, minus the
/// re-auth path (a feed URL never expires the way OAuth tokens do — a dead
/// URL surfaces as an apiError with a copy-a-fresh-link message).
class RunnaSyncResult {
  const RunnaSyncResult({
    required this.success,
    this.error,
    this.errorType = RunnaSyncErrorType.none,
    this.newWorkouts = 0,
    this.updated = 0,
    this.deleted = 0,
    this.skipped = 0,
    this.filtered = 0,
    this.activities = const [],
  });

  factory RunnaSyncResult.notConnected() {
    return const RunnaSyncResult(
      success: false,
      error: 'Runna is not connected',
      errorType: RunnaSyncErrorType.notConnected,
    );
  }

  factory RunnaSyncResult.error(String message) {
    return RunnaSyncResult(
      success: false,
      error: message,
      errorType: RunnaSyncErrorType.apiError,
    );
  }

  factory RunnaSyncResult.networkError(String message) {
    return RunnaSyncResult(
      success: false,
      error: message,
      errorType: RunnaSyncErrorType.network,
    );
  }

  final bool success;
  final String? error;
  final RunnaSyncErrorType errorType;
  final int newWorkouts;
  final int updated;
  final int deleted;
  final int skipped;
  final int filtered;
  final List<Activity> activities;

  bool get hasChanges => (newWorkouts + updated + deleted) > 0;
  bool get isNetworkError => errorType == RunnaSyncErrorType.network;

  String get summary {
    if (!success) {
      if (isNetworkError) return 'No internet connection. Please try again.';
      return error ?? 'Sync failed';
    }
    if (newWorkouts == 0 && skipped == 0) return 'No workouts found';
    if (newWorkouts == 0) return 'All $skipped workouts already synced';
    return '$newWorkouts new workout${newWorkouts == 1 ? '' : 's'} synced';
  }
}

enum RunnaSyncErrorType { none, notConnected, network, apiError }
