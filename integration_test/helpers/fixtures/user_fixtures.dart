/// Test user profile fixtures for integration testing
/// Provides a variety of user profiles covering different scenarios
class UserFixtures {
  /// Beginner female runner - new to endurance sports
  static Map<String, dynamic> get beginner => {
        'device_id': 'test-device-beginner',
        'age': 30,
        'weight_pounds': 140.0,
        'gender': 'female',
        'gut_training_level': 'beginner',
        'runs_with_water_bottle': true,
        'onboarding_completed': true,
        'onboarding_completed_at': DateTime.now().toIso8601String(),
      };

  /// Intermediate male runner - moderate experience
  static Map<String, dynamic> get intermediate => {
        'device_id': 'test-device-intermediate',
        'age': 35,
        'weight_pounds': 170.0,
        'gender': 'male',
        'gut_training_level': 'intermediate',
        'runs_with_water_bottle': false,
        'onboarding_completed': true,
        'onboarding_completed_at': DateTime.now().toIso8601String(),
      };

  /// Advanced male runner - experienced with gut training
  static Map<String, dynamic> get advanced => {
        'device_id': 'test-device-advanced',
        'age': 28,
        'weight_pounds': 155.0,
        'gender': 'male',
        'gut_training_level': 'advanced',
        'runs_with_water_bottle': false,
        'onboarding_completed': true,
        'onboarding_completed_at': DateTime.now().toIso8601String(),
      };

  /// Ultra runner - highly experienced female
  static Map<String, dynamic> get ultraRunner => {
        'device_id': 'test-device-ultra',
        'age': 40,
        'weight_pounds': 145.0,
        'gender': 'female',
        'gut_training_level': 'advanced',
        'runs_with_water_bottle': true,
        'onboarding_completed': true,
        'onboarding_completed_at': DateTime.now().toIso8601String(),
      };

  /// Cyclist - multi-sport athlete focused on cycling
  static Map<String, dynamic> get cyclist => {
        'device_id': 'test-device-cyclist',
        'age': 32,
        'weight_pounds': 165.0,
        'gender': 'male',
        'gut_training_level': 'intermediate',
        'runs_with_water_bottle': false,
        'onboarding_completed': true,
        'onboarding_completed_at': DateTime.now().toIso8601String(),
      };

  /// New user who hasn't completed onboarding
  static Map<String, dynamic> get newUser => {
        'device_id': 'test-device-new',
        'age': null,
        'weight_pounds': null,
        'gender': null,
        'gut_training_level': null,
        'runs_with_water_bottle': null,
        'onboarding_completed': false,
        'onboarding_completed_at': null,
      };

  /// Helper to get all complete user profiles
  static List<Map<String, dynamic>> get allCompleteUsers => [
        beginner,
        intermediate,
        advanced,
        ultraRunner,
        cyclist,
      ];

  /// Helper to create a custom user profile
  static Map<String, dynamic> custom({
    String? deviceId,
    int? age,
    double? weightPounds,
    String? gender,
    String? gutTrainingLevel,
    bool? runsWithWaterBottle,
    bool onboardingCompleted = true,
  }) {
    return {
      'device_id': deviceId ?? 'test-device-custom',
      'age': age,
      'weight_pounds': weightPounds,
      'gender': gender,
      'gut_training_level': gutTrainingLevel,
      'runs_with_water_bottle': runsWithWaterBottle,
      'onboarding_completed': onboardingCompleted,
      'onboarding_completed_at':
          onboardingCompleted ? DateTime.now().toIso8601String() : null,
    };
  }
}
