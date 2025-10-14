/// Test fixtures for nutrition plan requests
///
/// Canonical request data for different race distances and conditions
library;

import 'users.dart';

/// Standard nutrition plan request scenarios
class NutritionPlanRequestFixtures {
  /// 5K race - short distance, minimal fueling needed
  static Map<String, dynamic> get fiveK => {
        'device_id': UserFixtures.beginner['device_id'],
        'distance_miles': 3.1,
        'pace_minutes_per_mile': 9.0,
        'time_before_run_hours': 1.5,
        'gut_training_level': 'low',
        'temp_f': 65.0,
        'humidity': 55.0,
        'sweat_rate': 'medium',
        'gi_sensitivity': 'low',
        'allow_high_carb_run': false,
      };

  /// 10K race - moderate distance
  static Map<String, dynamic> get tenK => {
        'device_id': UserFixtures.intermediate['device_id'],
        'distance_miles': 6.2,
        'pace_minutes_per_mile': 8.5,
        'time_before_run_hours': 2.0,
        'gut_training_level': 'moderate',
        'temp_f': 68.0,
        'humidity': 60.0,
        'sweat_rate': 'medium',
        'gi_sensitivity': 'low',
        'allow_high_carb_run': true,
      };

  /// Half marathon - requires during-run fueling
  static Map<String, dynamic> get halfMarathon => {
        'device_id': UserFixtures.intermediate['device_id'],
        'distance_miles': 13.1,
        'pace_minutes_per_mile': 8.5,
        'time_before_run_hours': 3.0,
        'gut_training_level': 'moderate',
        'temp_f': 70.0,
        'humidity': 65.0,
        'sweat_rate': 'medium',
        'gi_sensitivity': 'low',
        'allow_high_carb_run': true,
      };

  /// Marathon - full fueling strategy needed
  static Map<String, dynamic> get marathon => {
        'device_id': UserFixtures.advanced['device_id'],
        'distance_miles': 26.2,
        'pace_minutes_per_mile': 7.5,
        'time_before_run_hours': 3.0,
        'gut_training_level': 'high',
        'temp_f': 72.0,
        'humidity': 70.0,
        'sweat_rate': 'high',
        'gi_sensitivity': 'low',
        'allow_high_carb_run': true,
      };

  /// Ultra marathon (50K) - maximum fueling requirements
  static Map<String, dynamic> get ultraMarathon => {
        'device_id': UserFixtures.ultraRunner['device_id'],
        'distance_miles': 31.0,
        'pace_minutes_per_mile': 10.0,
        'time_before_run_hours': 4.0,
        'gut_training_level': 'high',
        'temp_f': 75.0,
        'humidity': 75.0,
        'sweat_rate': 'high',
        'gi_sensitivity': 'moderate',
        'allow_high_carb_run': true,
      };

  /// Hot weather marathon - increased hydration needs
  static Map<String, dynamic> get hotWeatherMarathon => {
        'device_id': UserFixtures.advanced['device_id'],
        'distance_miles': 26.2,
        'pace_minutes_per_mile': 8.0,
        'time_before_run_hours': 3.0,
        'gut_training_level': 'moderate',
        'temp_f': 85.0, // Hot conditions
        'humidity': 80.0, // High humidity
        'sweat_rate': 'high',
        'gi_sensitivity': 'low',
        'allow_high_carb_run': true,
      };

  /// Cold weather marathon - reduced hydration needs
  static Map<String, dynamic> get coldWeatherMarathon => {
        'device_id': UserFixtures.advanced['device_id'],
        'distance_miles': 26.2,
        'pace_minutes_per_mile': 7.5,
        'time_before_run_hours': 3.0,
        'gut_training_level': 'high',
        'temp_f': 40.0, // Cold conditions
        'humidity': 50.0,
        'sweat_rate': 'low',
        'gi_sensitivity': 'low',
        'allow_high_carb_run': true,
      };

  /// Beginner marathon - conservative fueling
  static Map<String, dynamic> get beginnerMarathon => {
        'device_id': UserFixtures.beginner['device_id'],
        'distance_miles': 26.2,
        'pace_minutes_per_mile': 10.0,
        'time_before_run_hours': 3.0,
        'gut_training_level': 'low', // Conservative approach
        'temp_f': 65.0,
        'humidity': 60.0,
        'sweat_rate': 'medium',
        'gi_sensitivity': 'high', // More sensitive GI
        'allow_high_carb_run': false,
      };

  /// Short time window before run - limited pre-run options
  static Map<String, dynamic> get shortPreRunWindow => {
        'device_id': UserFixtures.intermediate['device_id'],
        'distance_miles': 13.1,
        'pace_minutes_per_mile': 8.5,
        'time_before_run_hours': 0.5, // Only 30 minutes!
        'gut_training_level': 'moderate',
        'temp_f': 68.0,
        'humidity': 60.0,
        'sweat_rate': 'medium',
        'gi_sensitivity': 'low',
        'allow_high_carb_run': false,
      };

  /// Heavy athlete - increased carb needs
  static Map<String, dynamic> get heavyAthleteMarathon => {
        'device_id': UserFixtures.heavyAthlete['device_id'],
        'distance_miles': 26.2,
        'pace_minutes_per_mile': 9.0,
        'time_before_run_hours': 3.0,
        'gut_training_level': 'moderate',
        'temp_f': 70.0,
        'humidity': 65.0,
        'sweat_rate': 'high',
        'gi_sensitivity': 'low',
        'allow_high_carb_run': true,
      };

  /// Fast pace marathon - higher intensity needs
  static Map<String, dynamic> get fastPaceMarathon => {
        'device_id': UserFixtures.advanced['device_id'],
        'distance_miles': 26.2,
        'pace_minutes_per_mile': 6.5, // Sub-3:00 marathon pace
        'time_before_run_hours': 3.0,
        'gut_training_level': 'high',
        'temp_f': 68.0,
        'humidity': 60.0,
        'sweat_rate': 'high',
        'gi_sensitivity': 'low',
        'allow_high_carb_run': true,
      };

  /// Get all standard test scenarios
  static List<Map<String, dynamic>> get standardScenarios => [
        fiveK,
        tenK,
        halfMarathon,
        marathon,
        ultraMarathon,
      ];

  /// Get all edge case scenarios
  static List<Map<String, dynamic>> get edgeCases => [
        hotWeatherMarathon,
        coldWeatherMarathon,
        beginnerMarathon,
        shortPreRunWindow,
        heavyAthleteMarathon,
        fastPaceMarathon,
      ];

  /// Get all scenarios (standard + edge cases)
  static List<Map<String, dynamic>> get all => [
        ...standardScenarios,
        ...edgeCases,
      ];
}

/// Algorithmic plan request format (for run-plan edge function)
class AlgorithmicPlanRequestFixtures {
  /// Convert modern AI request to algorithmic format
  static Map<String, dynamic> toAlgorithmicFormat(Map<String, dynamic> aiRequest) {
    final distanceMiles = aiRequest['distance_miles'] as double;
    final paceMinPerMile = aiRequest['pace_minutes_per_mile'] as double;
    final timeBeforeHours = aiRequest['time_before_run_hours'] as double;

    // Calculate duration in minutes
    final durationMin = (distanceMiles * paceMinPerMile).round();

    // Get user weight (would come from profile in real scenario)
    // For test, use default 70kg
    final weightKg = 70.0;

    return {
      'device_id': aiRequest['device_id'],
      'weight_kg': weightKg,
      'duration_min': durationMin,
      'pre_window_min': (timeBeforeHours * 60).round(),
      'gut_training': aiRequest['gut_training_level'],
      'pace_min_per_km': paceMinPerMile / 1.60934, // Convert to km
    };
  }

  /// Marathon algorithmic request
  static Map<String, dynamic> get marathon => {
        'device_id': UserFixtures.advanced['device_id'],
        'weight_kg': 70.0,
        'duration_min': 196, // 26.2 miles at 7.5 min/mile
        'pre_window_min': 180, // 3 hours
        'gut_training': 'high',
        'pace_min_per_km': 4.66, // 7.5 min/mile in min/km
      };

  /// Half marathon algorithmic request
  static Map<String, dynamic> get halfMarathon => {
        'device_id': UserFixtures.intermediate['device_id'],
        'weight_kg': 75.0,
        'duration_min': 111, // 13.1 miles at 8.5 min/mile
        'pre_window_min': 180, // 3 hours
        'gut_training': 'moderate',
        'pace_min_per_km': 5.28, // 8.5 min/mile in min/km
      };
}

/// Expected macro target ranges for validation
class ExpectedMacroTargets {
  /// Marathon expected targets (for advanced runner)
  static Map<String, String> get marathon => {
        'carbs_pre_run_g': '180-240', // 2.5-3.5g/kg for 70kg athlete
        'carbs_during_run_g': '180-240', // 60-90g/hr for ~3 hours
        'carbs_total_g': '360-480',
        'protein_pre_run_g': '10-20',
        'sodium_mg': '1200-1800', // 400-600mg/hr for 3 hours
        'water_ml': '1200-1800', // ~400-600ml/hr
      };

  /// Half marathon expected targets
  static Map<String, String> get halfMarathon => {
        'carbs_pre_run_g': '150-210', // 2-3g/kg for 75kg athlete
        'carbs_during_run_g': '60-90', // 30-60g/hr for ~2 hours
        'carbs_total_g': '210-300',
        'protein_pre_run_g': '10-20',
        'sodium_mg': '600-1200', // 300-600mg/hr for 2 hours
        'water_ml': '800-1200', // ~400-600ml/hr
      };

  /// 10K expected targets (minimal during-run fueling)
  static Map<String, String> get tenK => {
        'carbs_pre_run_g': '140-200', // 2-2.5g/kg
        'carbs_during_run_g': '0-30', // Optional for this distance
        'carbs_total_g': '140-230',
        'protein_pre_run_g': '10-15',
        'sodium_mg': '200-400', // Short duration
        'water_ml': '400-600',
      };
}
