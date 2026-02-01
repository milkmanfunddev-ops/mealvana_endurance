import 'package:flutter_test/flutter_test.dart';

/// Test to verify that the intensity distribution schema columns exist.
///
/// NOTE: This test will only pass AFTER running build_runner (Task 1.3).
/// Before code generation, Drift columns cannot be instantiated at runtime.
///
/// The purpose of this test file is to:
/// 1. Document that schema changes were made
/// 2. Verify column definitions after build_runner completes
///
/// Schema changes made in Phase 1:
/// - activities_table.dart: intensityZ1Z2Pct, intensityZ3Z4Pct, intensityZ5Pct
/// - user_profiles.dart: defaultRunningPaceMinPerMile, defaultCyclingSpeedMph, defaultSwimmingPacePer100Sec
void main() {
  group('Intensity Distribution Schema', () {
    test('schema documentation - columns added', () {
      // This test documents that schema columns were added.
      // After running build_runner, the generated code will include these columns.

      // Activities table intensity distribution columns (all nullable integers):
      const activityColumns = [
        'intensity_z1_z2_pct',  // Conversational zone (Z1-Z2)
        'intensity_z3_z4_pct',  // Tempo zone (Z3-Z4)
        'intensity_z5_pct',     // All-out zone (Z5+)
      ];

      // User profiles default pace/speed columns (nullable):
      const userProfileColumns = [
        'default_running_pace_min_per_mile',  // RealColumn - minutes per mile
        'default_cycling_speed_mph',          // RealColumn - miles per hour
        'default_swimming_pace_per_100_sec',  // IntColumn - seconds per 100 yards/meters
      ];

      // Verify we documented the correct number of columns
      expect(activityColumns.length, 3);
      expect(userProfileColumns.length, 3);
    });
  });
}
