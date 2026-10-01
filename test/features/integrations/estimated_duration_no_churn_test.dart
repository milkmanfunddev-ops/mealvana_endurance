import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/integrations/application/change_detection_service.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

/// Regression: a P3-estimated duration must not masquerade as a provider-side
/// change on every later sync.
///
/// WHAT WENT WRONG. P3 fills a NULL duration from usual pace and marks the row
/// `duration_source='estimated'`. `_hasMinorChanges` compared durations
/// directly, so local 140 vs remote null read as a change FOREVER: every sync
/// reclassified the row as a minor update, the provider merge nulled the
/// duration again (it is provider-owned), the importer re-estimated the same
/// number, and the row was written and re-uploaded for nothing.
///
/// These tests assert the churn signature DEAD rather than inferring it: two
/// consecutive detection passes over the same estimated row, with the second
/// asserted unchanged.
void main() {
  final service = ChangeDetectionService();
  final day = DateTime(2026, 10, 2, 6, 0);

  Activity row({
    required String id,
    int? durationMinutes,
    String? durationSource,
    double distanceMiles = 14.0,
    String title = '14 mi Long Run',
  }) => Activity(
    id: id,
    userId: 'athlete-1',
    activityType: ActivityType.running,
    title: title,
    status: ActivityStatus.planned,
    scheduledDateTime: day,
    distanceMiles: distanceMiles,
    durationMinutes: durationMinutes,
    durationSource: durationSource,
    syncedFromProvider: 'final_surge',
    providerWorkoutId: 'fs-9e42899e',
    createdAt: day,
    updatedAt: day,
  );

  /// The provider keeps sending the same distance-only plan.
  final remote = row(id: '');

  test('an unchanged distance-only row is unchanged (the original gap)', () {
    final result = service.detectChanges(
      localActivities: [row(id: 'local-1')],
      remoteWorkouts: [remote],
      provider: 'final_surge',
    );

    // This is WHY the sweep-side estimate exists: no repository call is made
    // here at all, so the import seam can never reach this row.
    expect(result.unchangedCount, 1);
    expect(result.updatedActivities, isEmpty);
    expect(result.newActivities, isEmpty);
  });

  test('two consecutive passes over an estimated row: both unchanged', () {
    // Pass 1 — the row has just been estimated by the sweep.
    var local = row(
      id: 'local-2',
      durationMinutes: 140,
      durationSource: 'estimated',
    );

    final first = service.detectChanges(
      localActivities: [local],
      remoteWorkouts: [remote],
      provider: 'final_surge',
    );
    expect(
      first.updatedActivities,
      isEmpty,
      reason: 'our own estimate is not a provider change',
    );
    expect(first.unchangedCount, 1);

    // Nothing was written, so the row entering pass 2 is the same row. (Had it
    // been classified as updated, the merge would have nulled the duration and
    // the importer would have re-estimated it — the churn cycle.)
    final second = service.detectChanges(
      localActivities: [local],
      remoteWorkouts: [remote],
      provider: 'final_surge',
    );
    expect(second.updatedActivities, isEmpty, reason: 'and still not, forever');
    expect(second.unchangedCount, 1);
  });

  test('a REAL provider duration arriving later still wins', () {
    final local = row(
      id: 'local-3',
      durationMinutes: 140,
      durationSource: 'estimated',
    );
    // The coach finally entered a time.
    final remoteWithDuration = row(id: '', durationMinutes: 88);

    final result = service.detectChanges(
      localActivities: [local],
      remoteWorkouts: [remoteWithDuration],
      provider: 'final_surge',
    );

    expect(
      result.updatedActivities,
      hasLength(1),
      reason: 'the guard must not swallow a genuine provider duration',
    );
    expect(result.updatedActivities.single.newDurationMinutes, 88);
    expect(result.unchangedCount, 0);
  });

  test('an authoritative local duration is still compared normally', () {
    // durationSource null means provider- or athlete-supplied. A provider that
    // drops the duration IS a change for such a row — the guard is scoped to
    // rows we estimated, not to every null-vs-value pair.
    final result = service.detectChanges(
      localActivities: [row(id: 'local-4', durationMinutes: 95)],
      remoteWorkouts: [remote],
      provider: 'final_surge',
    );

    expect(result.updatedActivities, hasLength(1));
    expect(result.unchangedCount, 0);
  });

  test('a title change on an estimated row is still a change', () {
    final result = service.detectChanges(
      localActivities: [
        row(id: 'local-5', durationMinutes: 140, durationSource: 'estimated'),
      ],
      remoteWorkouts: [row(id: '', title: '16 mi Long Run')],
      provider: 'final_surge',
    );

    expect(
      result.updatedActivities,
      hasLength(1),
      reason: 'the guard narrows ONE comparison, it does not disable detection',
    );
  });
}
