/// The onboarding draft survives a pending signup's trip through
/// SharedPreferences (develop-2026-10 ticket 42, 30-007): every answer
/// round-trips, and a record from another build restores what it can
/// instead of throwing.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_draft.dart';

const _full = OnboardingDraft(
  sports: {OnboardingSport.running, OnboardingSport.triathlon},
  goals: {OnboardingGoal.performance, OnboardingGoal.eatHealthier},
  pitfalls: {OnboardingPitfall.gutIssues, OnboardingPitfall.noTime},
  firstName: 'Ada',
  lastName: 'Runner',
  email: 'draft@example.com',
  gender: Gender.female,
  birthYear: 1990,
  useMetricUnits: true,
  heightFeet: 5,
  heightInches: 7,
  weightPounds: 141.5,
  gutTraining: GutTraining.high,
  sweatRate: SweatRateCat.heavy,
  planEdits: OnboardingPlanEdits(
    longRunCarbGph: 75,
    fluidMlPerHr: 650.5,
    sodiumMgPerHr: 800,
  ),
  connectedProvider: 'garmin',
  declinedTrainingApps: true,
  tridotNotifyRequested: true,
  sweatTestInterest: true,
);

/// What SharedPreferences hands back: the JSON string, decoded.
Map<String, dynamic> _throughPrefs(OnboardingDraft draft) =>
    jsonDecode(jsonEncode(draft.toJson())) as Map<String, dynamic>;

void main() {
  test('a full draft round-trips through its stored JSON', () {
    final back = OnboardingDraft.fromJson(_throughPrefs(_full));

    expect(back.sports, _full.sports);
    expect(back.goals, _full.goals);
    expect(back.pitfalls, _full.pitfalls);
    expect(back.firstName, 'Ada');
    expect(back.lastName, 'Runner');
    expect(back.email, 'draft@example.com');
    expect(back.gender, Gender.female);
    expect(back.birthYear, 1990);
    expect(back.useMetricUnits, isTrue);
    expect(back.heightFeet, 5);
    expect(back.heightInches, 7);
    expect(back.weightPounds, 141.5);
    expect(back.gutTraining, GutTraining.high);
    expect(back.sweatRate, SweatRateCat.heavy);
    expect(back.planEdits.longRunCarbGph, 75);
    expect(back.planEdits.longRideCarbGph, isNull);
    expect(back.planEdits.fluidMlPerHr, 650.5);
    expect(back.planEdits.sodiumMgPerHr, 800);
    expect(back.connectedProvider, 'garmin');
    expect(back.declinedTrainingApps, isTrue);
    expect(back.tridotNotifyRequested, isTrue);
    expect(back.sweatTestInterest, isTrue);
  });

  test('sets are stored as their dbValue lists', () {
    final json = _full.toJson();
    expect(json['goals'], containsAll(['performance', 'eat_healthier']));
    expect(json['pitfalls'], containsAll(['gut_issues', 'no_time']));
  });

  test('an unknown enum value is dropped, not thrown', () {
    final json = _throughPrefs(_full)
      ..['sports'] = ['running', 'rowing']
      ..['goals'] = ['performance', 'win_the_lottery']
      ..['gender'] = 'unspecified'
      ..['gut_training'] = 'extreme'
      ..['sweat_rate'] = 42;

    final back = OnboardingDraft.fromJson(json);

    expect(back.sports, {OnboardingSport.running});
    expect(back.goals, {OnboardingGoal.performance});
    expect(back.gender, isNull);
    expect(back.gutTraining, GutTraining.moderate);
    expect(back.sweatRate, SweatRateCat.medium);
    // The rest is still there.
    expect(back.birthYear, 1990);
    expect(back.weightPounds, 141.5);
  });

  test('a wrongly typed field keeps its default; nothing throws', () {
    final back = OnboardingDraft.fromJson({
      'sports': 'running',
      'birth_year': '1990',
      'weight_pounds': 'heavy',
      'use_metric_units': 'yes',
      'plan_edits': [1, 2],
    });

    expect(back.sports, isEmpty);
    expect(back.birthYear, isNull);
    expect(back.weightPounds, isNull);
    expect(back.useMetricUnits, isFalse);
    expect(back.planEdits.hasAnyEdit, isFalse);
    expect(OnboardingDraft.fromJson(null).sports, isEmpty);
  });
}
