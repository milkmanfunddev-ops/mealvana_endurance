/// Test fixtures for users table (edge function testing)
///
/// Simple Map-based user data for edge function and service tests.
/// Full Drift entity fixtures will be added in Phase 4 (migration testing).
library;

/// User fixtures as Maps for edge function testing
/// These match the format expected by edge functions (snake_case)
class UserFixtures {
  /// Beginner runner - low gut training, conservative settings
  static Map<String, dynamic> get beginner => {
        'device_id': 'test-device-beginner',
        'gender': 'female',
        'birthday': '1995-05-15', // 30 years old
        'height_feet': 5,
        'height_inches': 6,
        'weight_pounds': 140.0,
        'runs_with_water_bottle': true,
        'gut_training_level': 'low',
        'onboarding_completed': true,
        'app_version': '1.6.0',
      };

  /// Intermediate runner - moderate gut training
  static Map<String, dynamic> get intermediate => {
        'device_id': 'test-device-intermediate',
        'gender': 'male',
        'birthday': '1988-08-20', // 37 years old
        'height_feet': 5,
        'height_inches': 10,
        'weight_pounds': 165.0,
        'runs_with_water_bottle': true,
        'gut_training_level': 'moderate',
        'onboarding_completed': true,
        'app_version': '1.6.0',
      };

  /// Advanced/elite runner - high gut training
  static Map<String, dynamic> get advanced => {
        'device_id': 'test-device-advanced',
        'gender': 'male',
        'birthday': '1990-03-10', // 35 years old
        'height_feet': 6,
        'height_inches': 0,
        'weight_pounds': 155.0,
        'runs_with_water_bottle': false, // Relies on aid stations
        'gut_training_level': 'high',
        'onboarding_completed': true,
        'app_version': '1.6.0',
      };

  /// Heavier athlete - tests carb calculations for larger body weight
  static Map<String, dynamic> get heavyAthlete => {
        'device_id': 'test-device-heavy',
        'gender': 'male',
        'birthday': '1985-11-05', // 40 years old
        'height_feet': 6,
        'height_inches': 2,
        'weight_pounds': 210.0,
        'runs_with_water_bottle': true,
        'gut_training_level': 'moderate',
        'onboarding_completed': true,
        'app_version': '1.6.0',
      };

  /// Lightweight athlete - tests minimum carb requirements
  static Map<String, dynamic> get lightAthlete => {
        'device_id': 'test-device-light',
        'gender': 'female',
        'birthday': '1998-07-22', // 27 years old
        'height_feet': 5,
        'height_inches': 2,
        'weight_pounds': 110.0,
        'runs_with_water_bottle': true,
        'gut_training_level': 'low',
        'onboarding_completed': true,
        'app_version': '1.6.0',
      };

  /// Ultra runner - high volume training
  static Map<String, dynamic> get ultraRunner => {
        'device_id': 'test-device-ultra',
        'gender': 'other',
        'birthday': '1987-04-18', // 38 years old
        'height_feet': 5,
        'height_inches': 9,
        'weight_pounds': 150.0,
        'runs_with_water_bottle': true,
        'gut_training_level': 'high',
        'onboarding_completed': true,
        'app_version': '1.6.0',
      };

  /// New user - incomplete onboarding
  static Map<String, dynamic> get newUser => {
        'device_id': 'test-device-new',
        'gender': 'female',
        'birthday': '1992-12-01', // 33 years old
        'height_feet': 5,
        'height_inches': 5,
        'weight_pounds': 135.0,
        'runs_with_water_bottle': true,
        'gut_training_level': 'low',
        'onboarding_completed': false, // Not complete
        'app_version': '1.6.0',
      };

  /// Get all test user data as a list
  static List<Map<String, dynamic>> get all => [
        beginner,
        intermediate,
        advanced,
        heavyAthlete,
        lightAthlete,
        ultraRunner,
        newUser,
      ];

  /// Get user data by device ID
  static Map<String, dynamic>? getByDeviceId(String deviceId) {
    try {
      return all.firstWhere(
        (user) => user['device_id'] == deviceId,
      );
    } catch (e) {
      return null;
    }
  }
}

/// Helper functions for user data
class UserHelpers {
  /// Convert weight from pounds to kg
  static double poundsToKg(double pounds) => pounds * 0.453592;

  /// Convert height to cm
  static double heightToCm(int feet, int inches) {
    final totalInches = (feet * 12) + inches;
    return totalInches * 2.54;
  }

  /// Calculate weight in kg from user map
  static double getWeightKg(Map<String, dynamic> user) {
    final pounds = user['weight_pounds'] as double;
    return poundsToKg(pounds);
  }

  /// Calculate height in cm from user map
  static double getHeightCm(Map<String, dynamic> user) {
    final feet = user['height_feet'] as int;
    final inches = user['height_inches'] as int;
    return heightToCm(feet, inches);
  }

  /// Calculate age from birthday string (format: 'YYYY-MM-DD')
  static int getAge(Map<String, dynamic> user, {DateTime? referenceDate}) {
    final birthdayStr = user['birthday'] as String;
    final birthday = DateTime.parse(birthdayStr);
    final ref = referenceDate ?? DateTime(2025, 10, 1); // Test reference date
    return ref.year - birthday.year;
  }
}
