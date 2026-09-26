// Ticket 138 (Finding 119-007): Body Composition offered "Garmin · 185 lb,
// tap to use" when the field already read 185. The chip shows only when the
// Garmin reading differs from the field at the displayed precision (Xuan,
// 2026-09-13: a provider badges when the values differ).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/nutrition_profile_screen.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart' show UnitSystem;
import 'package:mealvana_endurance/shared/providers/unit_system_provider.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/data/kyle_source_chip.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/widget_test_harness.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _StubSettingsController extends SettingsController {
  @override
  FutureOr<SettingsState> build() => const SettingsState(
    title: 'Settings',
    profileSectionTitle: 'Profile',
    preferenceSectionTitle: 'Preferences',
    genderLabel: 'Gender',
    birthdayLabel: 'Birthday',
    heightLabel: 'Height',
    weightLabel: 'Weight',
    waterBottleLabel: 'Water Bottle',
    distanceUnitLabel: 'Distance',
    paceUnitLabel: 'Pace',
    gutTrainingLabel: 'Gut Training',
    saveButtonText: 'Save',
  );
}

/// 165 lb on the profile, entered by hand today, so the manual value stands
/// over any Garmin reading (older-Garmin/newer-manual).
UserProfile _profile() => UserProfile(
  id: 'u1',
  deviceId: 'd1',
  gender: Gender.male,
  birthday: DateTime(1985, 3, 20),
  heightFeet: 5,
  heightInches: 11,
  weightPounds: 165,
  runsWithWaterBottle: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  appVersion: '1.0.0',
  bodyFatPct: 18.5,
  weightPoundsUpdatedAt: DateTime.now().toUtc(),
  bodyFatPctUpdatedAt: DateTime.now().toUtc(),
);

/// A Garmin reading that displays as [pounds] lb.
GarminBodyCompData _garmin({required double pounds, double? bodyFat}) =>
    GarminBodyCompData(
      weightKg: pounds * 0.45359237,
      bodyFatPct: bodyFat,
      measurementTime: DateTime.now().subtract(const Duration(days: 1)),
    );

void main() {
  late _MockUserRepository repo;

  setUpAll(() => registerFallbackValue(_profile()));

  setUp(() {
    repo = _MockUserRepository();
    when(() => repo.getCurrentUser()).thenAnswer((_) async => _profile());
  });

  Future<void> pump(WidgetTester tester, GarminBodyCompData garmin) async {
    await pumpSeeded(
      tester,
      const NutritionProfileScreen(),
      overrides: [
        userRepositoryProvider.overrideWith((_) async => repo),
        // The load sequence awaits the unit preference before reading Garmin;
        // without a signed-in user that future never completes in a test.
        userIdProvider.overrideWith((ref) async => 'u1'),
        unitSystemProvider.overrideWith((ref) async => UnitSystem.imperial),
        garminLastBodyCompProvider.overrideWith((ref, userId) async => garmin),
        settingsControllerProvider.overrideWith(_StubSettingsController.new),
      ],
      settle: true,
    );
    await tester.pumpAndSettle();
  }

  Finder tapToUse(String source) => find.byWidgetPredicate(
    (w) => w is KyleTapToUseChip && w.source == source,
  );

  testWidgets('no Garmin chip when the field already reads the Garmin value',
      (tester) async {
    await pump(tester, _garmin(pounds: 165, bodyFat: 18.5));

    expect(tapToUse('Garmin'), findsNothing);
    // The plain source pill still shows (equal values read as Garmin's).
    expect(find.byType(KyleSourceChip), findsWidgets);
  });

  testWidgets('the Garmin chip shows when the reading differs',
      (tester) async {
    await pump(tester, _garmin(pounds: 185, bodyFat: 21.0));
    expect(tapToUse('Garmin'), findsNWidgets(2));
    expect(find.textContaining('185 lb'), findsOneWidget);
    expect(find.textContaining('21.0 %'), findsOneWidget);
  });

  testWidgets('a reading that rounds to the same displayed number is equal',
      (tester) async {
    // 165.4 lb rounds to 165 in the field, so nothing to adopt.
    await pump(tester, _garmin(pounds: 165.4, bodyFat: 18.54));

    expect(tapToUse('Garmin'), findsNothing);
  });
}
