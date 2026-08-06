import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/onboarding/application/onboarding_snapshot_service.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  UserProfile profile() => UserProfile(
    id: 'anon-1',
    deviceId: 'device-1',
    authProvider: 'anonymous',
    isAnonymous: true,
    gender: Gender.other,
    birthday: DateTime(1994, 7, 1),
    heightFeet: 5,
    heightInches: 9,
    weightPounds: 140,
    runsWithWaterBottle: false,
    gutTraining: GutTraining.high,
    sweatRate: SweatRateCat.heavy,
    onboardingCompleted: true,
    appVersion: '1.0.0-test',
    createdAt: DateTime(2026, 8, 6),
    updatedAt: DateTime(2026, 8, 6),
  );

  const draft = OnboardingDraft(
    sports: {OnboardingSport.triathlon},
    goals: {OnboardingGoal.performance, OnboardingGoal.understandEating},
    pitfalls: {OnboardingPitfall.gutIssues},
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('write → read round-trips profile and survey', () async {
    final service = OnboardingSnapshotService();
    await service.writeSnapshot(profile: profile(), draft: draft);

    final snapshot = await service.readSnapshot();
    expect(snapshot, isNotNull);
    expect(snapshot!.profile.id, 'anon-1');
    expect(snapshot.profile.isAnonymous, isTrue);
    expect(snapshot.profile.gutTraining, GutTraining.high);
    expect(snapshot.profile.sweatRate, SweatRateCat.heavy);
    expect(snapshot.sports, ['triathlon']);
    expect(snapshot.goals, containsAll(['performance', 'understand_eating']));

    final restoredDraft = snapshot.toSurveyDraft();
    expect(restoredDraft.sports, {OnboardingSport.triathlon});
    expect(restoredDraft.pitfalls, {OnboardingPitfall.gutIssues});
  });

  test('corrupt snapshot is dropped, not thrown', () async {
    SharedPreferences.setMockInitialValues({
      OnboardingSnapshotService.prefsKey: '{not-json',
    });
    final service = OnboardingSnapshotService();
    expect(await service.readSnapshot(), isNull);
    // And the corrupt payload was cleared.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(OnboardingSnapshotService.prefsKey), isNull);
  });

  test('clearSnapshot removes the payload', () async {
    final service = OnboardingSnapshotService();
    await service.writeSnapshot(profile: profile(), draft: draft);
    await service.clearSnapshot();
    expect(await service.readSnapshot(), isNull);
  });

  test('unknown enum strings in a future snapshot are skipped', () async {
    final service = OnboardingSnapshotService();
    await service.writeSnapshot(profile: profile(), draft: draft);
    // Simulate a snapshot written by a newer client with an unknown sport.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(OnboardingSnapshotService.prefsKey)!;
    await prefs.setString(
      OnboardingSnapshotService.prefsKey,
      raw.replaceFirst('"triathlon"', '"pickleball"'),
    );

    final snapshot = await service.readSnapshot();
    expect(snapshot!.toSurveyDraft().sports, isEmpty);
  });
}
