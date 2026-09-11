/// What the launcher's moment reads (vana-moment spec): today's activities
/// and meal logs, seeded, so a test that mounts the Vana host decides whether
/// Vana has anything to say and touches no database.
library;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/presentation/providers/activities_controller.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_moment_controller.dart';

class _SeededActivities extends ActivitiesController {
  _SeededActivities(this._activities);

  final List<Activity> _activities;

  @override
  Future<List<Activity>> build() async => _activities;
}

/// Overrides for the moment's inputs. With the defaults nothing is raised.
List<Override> vanaMomentInputs({
  List<Activity> activities = const [],
  Stream<List<MealLog>> Function()? logs,
  bool reducedMotion = false,
}) => [
  activitiesControllerProvider.overrideWith(
    () => _SeededActivities(activities),
  ),
  mealLogsForDateProvider.overrideWith(
    (ref, date) => logs?.call() ?? Stream.value(const <MealLog>[]),
  ),
  vanaReducedMotionProvider.overrideWithValue(reducedMotion),
];
