import '../../../shared/domain/activity_type.dart';

/// Phase-specific configuration for the client-side greedy solver.
///
/// Controls the maximum number of foods and servings per food
/// to keep the solver output reasonable for each phase/sport combo.
class SportPhaseConfig {
  const SportPhaseConfig({
    required this.maxFoods,
    required this.maxServingsPerFood,
  });

  final int maxFoods;
  final int maxServingsPerFood;

  /// Get phase config for a given sport and phase.
  static SportPhaseConfig forPhase(String phase, ActivityType activityType) {
    switch (phase) {
      case 'before':
        return const SportPhaseConfig(maxFoods: 3, maxServingsPerFood: 3);
      case 'during':
        return _duringConfig(activityType);
      case 'after':
        return const SportPhaseConfig(maxFoods: 5, maxServingsPerFood: 3);
      default:
        return const SportPhaseConfig(maxFoods: 4, maxServingsPerFood: 3);
    }
  }

  static SportPhaseConfig _duringConfig(ActivityType activityType) {
    switch (activityType) {
      case ActivityType.running:
        return const SportPhaseConfig(maxFoods: 4, maxServingsPerFood: 3);
      case ActivityType.cycling:
        return const SportPhaseConfig(maxFoods: 5, maxServingsPerFood: 3);
      case ActivityType.swimming:
        return const SportPhaseConfig(maxFoods: 2, maxServingsPerFood: 3);
      case ActivityType.brick:
        return const SportPhaseConfig(maxFoods: 6, maxServingsPerFood: 3);
      default:
        return const SportPhaseConfig(maxFoods: 4, maxServingsPerFood: 3);
    }
  }
}
