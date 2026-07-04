// Seeded CONTENT tests for settings screens.
//
// Pattern: seed each screen's controller with known state via a local fake
// that overrides `build()`, then assert the rendered VALUES are correct.
//
// NutritionProfileScreen note: that screen calls _loadCurrentValues() in
// initState() (NOT addPostFrameCallback), which awaits userRepositoryProvider.
// We override userRepositoryProvider + garminLastBodyCompProvider so the
// screen renders immediately with real seeded data.
//
// SweatProfileScreen note: the known 35 px overflow (BUGS_FOUND #14) is
// suppressed via settle:true + overflow not asserted. Tests focus on value
// correctness only.

// ignore_for_file: must_be_immutable

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/enums.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_target_overrides.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/sweat_profile_controller.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/nutrition_profile_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/nutrition_targets_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/preferences_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/sweat_profile_screen.dart';
import 'package:mealvana_endurance/shared/providers/unit_system_provider.dart';

import '../helpers/widget_test_harness.dart';

// ─── Mock UserRepository ─────────────────────────────────────────────────────

class _MockUserRepository extends Mock implements UserRepository {}

// ─── Seeded SettingsController ───────────────────────────────────────────────

class _SeededSettingsController extends SettingsController {
  final SettingsState _seedState;
  _SeededSettingsController(this._seedState);

  @override
  FutureOr<SettingsState> build() => _seedState;
}

// ─── Seeded SweatProfileController ───────────────────────────────────────────

class _SeededSweatProfileController extends SweatProfileController {
  final SweatProfileState _seedState;
  _SeededSweatProfileController(this._seedState);

  @override
  FutureOr<SweatProfileState> build() => _seedState;
}

// ─── Seed helpers ────────────────────────────────────────────────────────────

SettingsState _makeSettingsState({
  Gender gender = Gender.female,
  DateTime? birthday,
  int heightFeet = 5,
  int heightInches = 8,
  double weightPounds = 145.0,
  bool runsWithWaterBottle = true,
  UnitSystem unitSystem = UnitSystem.imperial,
  GutTraining gutTraining = GutTraining.high,
  SweatRateCat sweatRate = SweatRateCat.heavy,
  String? firstName,
  String? lastName,
  String? email,
  NutritionTargetOverrides? nutritionTargetOverrides,
}) =>
    SettingsState(
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
      gender: gender,
      birthday: birthday ?? DateTime(1990, 6, 15),
      heightFeet: heightFeet,
      heightInches: heightInches,
      weightPounds: weightPounds,
      runsWithWaterBottle: runsWithWaterBottle,
      unitSystem: unitSystem,
      gutTrainingLevel: gutTraining,
      sweatRate: sweatRate,
      firstName: firstName,
      lastName: lastName,
      email: email,
      nutritionTargetOverrides: nutritionTargetOverrides,
    );

UserProfile _makeUserProfile({
  double weightPounds = 165.0,
  int heightFeet = 5,
  int heightInches = 11,
  double? bodyFatPct = 18.5,
  Lifestyle lifestyle = Lifestyle.mixed,
  double? typicalWeeklyHours = 10.0,
  TrainingPhase trainingPhase = TrainingPhase.build,
  bool carbCycleOptIn = true,
}) {
  final now = DateTime.now();
  return UserProfile(
    id: 'test-user-id',
    deviceId: 'test-device-id',
    gender: Gender.male,
    birthday: DateTime(1985, 3, 20),
    heightFeet: heightFeet,
    heightInches: heightInches,
    weightPounds: weightPounds,
    runsWithWaterBottle: false,
    createdAt: now,
    updatedAt: now,
    appVersion: '1.0.0',
    bodyFatPct: bodyFatPct,
    lifestyle: lifestyle,
    typicalWeeklyHours: typicalWeeklyHours,
    carbCycleOptIn: carbCycleOptIn,
    trainingPhase: trainingPhase,
  );
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. NutritionTargetsScreen — macro override field values
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // _loadCurrentOverrides() is called via addPostFrameCallback → reads
  // settingsControllerProvider.value.nutritionTargetOverrides and fills
  // TextEditingControllers with the override values.

  // NOTE on NutritionTargetsScreen ListView laziness:
  // The screen uses ListView(children: [...]) which is backed by SliverList.
  // Flutter's widget test engine only builds the items within the test
  // viewport (standard phone = 800×600 logic px). Pre-activity (5 fields)
  // + During Run (3 fields) = 8 fields are above the fold. During Bike,
  // During Swim, and Post-Activity sections are off-screen and NOT in the
  // widget tree until scrolled. We therefore assert only on visible items.
  // For off-screen sections we scroll the list first before asserting.
  //
  // BUG FOUND #NT-1: Off-screen ListView items are not in the test widget
  // tree even with explicit children list. This means content regressions in
  // below-fold sections are invisible without scroll-then-assert. A smoke
  // test at multiple scroll positions would improve coverage.

  group('NutritionTargetsScreen — content', () {
    testWidgets(
      'pre-activity and during-run fields show seeded override values '
      '(visible viewport)',
      (tester) async {
        // Use unique numbers that won't collide in the viewport.
        final overrides = NutritionTargetOverrides(
          pre: const PreActivityOverrides(
            carbsG: 75,
            proteinG: 21,
            fatG: 13,
            sodiumMg: 402,
            fluidMl: 503,
          ),
          duringRun: const DuringActivityOverrides(
            carbRateGPerH: 47,
            sodiumRateMgPerH: 511,
            fluidRateMlPerH: 622,
          ),
        );

        final seededState = _makeSettingsState(
          nutritionTargetOverrides: overrides,
        );

        await pumpSeeded(
          tester,
          const NutritionTargetsScreen(),
          overrides: [
            settingsControllerProvider.overrideWith(
              () => _SeededSettingsController(seededState),
            ),
          ],
          settle: true,
        );

        // Pre-activity fields are above the fold.
        expect(find.text('75'), findsOneWidget,
            reason: 'pre-carbs field must show 75');
        expect(find.text('21'), findsOneWidget,
            reason: 'pre-protein field must show 21');
        expect(find.text('13'), findsOneWidget,
            reason: 'pre-fat field must show 13');
        expect(find.text('402'), findsOneWidget,
            reason: 'pre-sodium field must show 402');
        expect(find.text('503'), findsOneWidget,
            reason: 'pre-fluid field must show 503');

        // During Run section is also above the fold.
        expect(find.text('47'), findsOneWidget,
            reason: 'during-run carb rate must show 47');
        expect(find.text('511'), findsOneWidget,
            reason: 'during-run sodium rate must show 511');
        expect(find.text('622'), findsOneWidget,
            reason: 'during-run fluid rate must show 622');
      },
    );

    testWidgets(
      'post-activity carbs field shows seeded value after scrolling to bottom',
      (tester) async {
        final overrides = NutritionTargetOverrides(
          post: const PostActivityOverrides(carbsG: 63),
        );

        final seededState = _makeSettingsState(
          nutritionTargetOverrides: overrides,
        );

        await pumpSeeded(
          tester,
          const NutritionTargetsScreen(),
          overrides: [
            settingsControllerProvider.overrideWith(
              () => _SeededSettingsController(seededState),
            ),
          ],
          settle: true,
        );

        // Scroll far enough to bring Post-Activity and Save Changes into view.
        await tester.drag(
          find.byType(ListView),
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();

        expect(find.text('63'), findsOneWidget,
            reason:
                'post-carbs field must show 63 after scrolling to bottom');
        expect(find.text('Save Changes'), findsOneWidget,
            reason: 'Save Changes button must be visible after scroll');
      },
    );

    testWidgets(
      'during-bike carb rate shows 91 after scrolling to that section',
      (tester) async {
        final overrides = NutritionTargetOverrides(
          duringCycling: const DuringActivityOverrides(
            carbRateGPerH: 91,
            sodiumRateMgPerH: 703,
            fluidRateMlPerH: 801,
          ),
        );

        final seededState = _makeSettingsState(
          nutritionTargetOverrides: overrides,
        );

        await pumpSeeded(
          tester,
          const NutritionTargetsScreen(),
          overrides: [
            settingsControllerProvider.overrideWith(
              () => _SeededSettingsController(seededState),
            ),
          ],
          settle: true,
        );

        // Scroll to bring During Bike section into view.
        await tester.drag(find.byType(ListView), const Offset(0, -900));
        await tester.pumpAndSettle();

        expect(find.text('91'), findsOneWidget,
            reason: 'during-bike carb rate must show 91 after scroll');
        expect(find.text('703'), findsOneWidget,
            reason: 'during-bike sodium rate must show 703 after scroll');
        expect(find.text('801'), findsOneWidget,
            reason: 'during-bike fluid rate must show 801 after scroll');
      },
    );

    testWidgets(
      'info banner and Pre-Activity label are visible with no overrides set',
      (tester) async {
        final seededState = _makeSettingsState();
        await pumpSeeded(
          tester,
          const NutritionTargetsScreen(),
          overrides: [
            settingsControllerProvider.overrideWith(
              () => _SeededSettingsController(seededState),
            ),
          ],
          settle: true,
        );

        expect(
          find.textContaining('Set your preferred macro targets'),
          findsOneWidget,
          reason: 'info banner must describe the screen purpose',
        );
        expect(
          find.text('Pre-Activity'),
          findsOneWidget,
          reason: 'Pre-Activity section label must be present',
        );

        // With no overrides, numeric values should not appear in the viewport.
        expect(find.text('75'), findsNothing,
            reason: 'no override value should appear with default state');
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. NutritionProfileScreen — weight / height / body-fat / hours fields
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // The screen calls _loadCurrentValues() in initState (not in
  // addPostFrameCallback) which awaits userRepositoryProvider.future.
  // We override userRepositoryProvider to return a mock repo immediately,
  // and garminLastBodyCompProvider (family) to return null so no Garmin
  // auto-fill interferes.

  group('NutritionProfileScreen — content', () {
    late _MockUserRepository mockRepo;
    late UserProfile seedProfile;

    setUp(() {
      mockRepo = _MockUserRepository();
      seedProfile = _makeUserProfile(
        weightPounds: 165.0,
        heightFeet: 5,
        heightInches: 11,
        bodyFatPct: 18.5,
        lifestyle: Lifestyle.active,
        typicalWeeklyHours: 10.0,
        trainingPhase: TrainingPhase.build,
        carbCycleOptIn: true,
      );
      when(() => mockRepo.getCurrentUser())
          .thenAnswer((_) async => seedProfile);
    });

    testWidgets(
      'weight field shows 165 from seeded profile',
      (tester) async {
        await pumpSeeded(
          tester,
          const NutritionProfileScreen(),
          overrides: [
            userRepositoryProvider.overrideWith((_) async => mockRepo),
            garminLastBodyCompProvider
                .overrideWith((ref, userId) async => null),
          ],
          settle: true,
        );

        // weightPounds = 165.0 → toStringAsFixed(0) = "165"
        expect(find.text('165'), findsOneWidget,
            reason: 'weight field must show 165 from seeded profile');
      },
    );

    testWidgets(
      'height feet and inches fields show 5 and 11 from seeded profile',
      (tester) async {
        await pumpSeeded(
          tester,
          const NutritionProfileScreen(),
          overrides: [
            userRepositoryProvider.overrideWith((_) async => mockRepo),
            garminLastBodyCompProvider
                .overrideWith((ref, userId) async => null),
          ],
          settle: true,
        );

        expect(find.text('5'), findsOneWidget,
            reason: 'height feet field must show 5');
        expect(find.text('11'), findsOneWidget,
            reason: 'height inches field must show 11');
      },
    );

    testWidgets(
      'body fat field shows 18.5 from seeded profile',
      (tester) async {
        await pumpSeeded(
          tester,
          const NutritionProfileScreen(),
          overrides: [
            userRepositoryProvider.overrideWith((_) async => mockRepo),
            garminLastBodyCompProvider
                .overrideWith((ref, userId) async => null),
          ],
          settle: true,
        );

        // bodyFatPct = 18.5 → toStringAsFixed(1) = "18.5"
        expect(find.text('18.5'), findsOneWidget,
            reason: 'body fat field must show 18.5 from seeded profile');
      },
    );

    testWidgets(
      'weekly training hours field shows 10.0 from seeded profile',
      (tester) async {
        await pumpSeeded(
          tester,
          const NutritionProfileScreen(),
          overrides: [
            userRepositoryProvider.overrideWith((_) async => mockRepo),
            garminLastBodyCompProvider
                .overrideWith((ref, userId) async => null),
          ],
          settle: true,
        );

        // typicalWeeklyHours = 10.0 → toStringAsFixed(1) = "10.0"
        expect(find.text('10.0'), findsOneWidget,
            reason: 'weekly hours field must show 10.0');
      },
    );

    testWidgets(
      'profile fields are absent (screen stays empty) without seeded repository',
      (tester) async {
        // Without overriding userRepositoryProvider the in-memory DB has no
        // user, so _loadCurrentValues returns early (profile == null) and
        // all form fields remain blank.
        await pumpSeeded(
          tester,
          const NutritionProfileScreen(),
          settle: false,
        );

        expect(find.text('165'), findsNothing,
            reason:
                'weight must NOT appear without seeded userRepository');
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. PreferencesScreen — name / email / birthday / gut-training / sweat-rate
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // The screen uses addPostFrameCallback → reads settingsControllerProvider
  // to initialise local form state.

  group('PreferencesScreen — content', () {
    testWidgets(
      '"Tell us about yourself" heading is visible in data state',
      (tester) async {
        final seededState = _makeSettingsState(
          firstName: 'Jane',
          lastName: 'Doe',
          email: 'jane@example.com',
          birthday: DateTime(1990, 6, 15),
        );

        await pumpSeeded(
          tester,
          const PreferencesScreen(),
          overrides: [
            settingsControllerProvider.overrideWith(
              () => _SeededSettingsController(seededState),
            ),
          ],
          settle: true,
        );

        expect(
          find.textContaining('Tell us about yourself'),
          findsOneWidget,
          reason: 'main heading must render in data state',
        );
      },
    );

    testWidgets(
      'first name, last name and email fields show seeded values',
      (tester) async {
        final seededState = _makeSettingsState(
          firstName: 'Jane',
          lastName: 'Doe',
          email: 'jane@example.com',
        );

        await pumpSeeded(
          tester,
          const PreferencesScreen(),
          overrides: [
            settingsControllerProvider.overrideWith(
              () => _SeededSettingsController(seededState),
            ),
          ],
          settle: true,
        );

        expect(find.text('Jane'), findsOneWidget,
            reason: 'first name field must show Jane');
        expect(find.text('Doe'), findsOneWidget,
            reason: 'last name field must show Doe');
        expect(find.text('jane@example.com'), findsOneWidget,
            reason: 'email field must show jane@example.com');
      },
    );

    testWidgets(
      'birthday renders as formatted date string 6/15/1990',
      (tester) async {
        final seededState = _makeSettingsState(
          birthday: DateTime(1990, 6, 15),
        );

        await pumpSeeded(
          tester,
          const PreferencesScreen(),
          overrides: [
            settingsControllerProvider.overrideWith(
              () => _SeededSettingsController(seededState),
            ),
          ],
          settle: true,
        );

        // Screen formats birthday as '${month}/${day}/${year}'.
        expect(
          find.text('6/15/1990'),
          findsOneWidget,
          reason: 'birthday must render as 6/15/1990',
        );
      },
    );

    testWidgets(
      'HIGH gut training label is visible when seeded with GutTraining.high',
      (tester) async {
        final seededState = _makeSettingsState(
          gutTraining: GutTraining.high,
        );

        await pumpSeeded(
          tester,
          const PreferencesScreen(),
          overrides: [
            settingsControllerProvider.overrideWith(
              () => _SeededSettingsController(seededState),
            ),
          ],
          settle: true,
        );

        // KyleGutTrainingSegmentedControl with showValues:true renders
        // GutTraining.high.displayName = 'HIGH'.
        expect(
          find.text('HIGH'),
          findsOneWidget,
          reason: 'HIGH gut training segment must render when seeded with high',
        );
      },
    );

    testWidgets(
      'Heavy sweat rate label is visible when seeded with SweatRateCat.heavy',
      (tester) async {
        final seededState = _makeSettingsState(
          sweatRate: SweatRateCat.heavy,
        );

        await pumpSeeded(
          tester,
          const PreferencesScreen(),
          overrides: [
            settingsControllerProvider.overrideWith(
              () => _SeededSettingsController(seededState),
            ),
          ],
          settle: true,
        );

        // KyleSweatRateSegmentedControl: SweatRateCat.heavy.displayName = 'Heavy'.
        expect(
          find.text('Heavy'),
          findsOneWidget,
          reason: 'Heavy sweat rate segment must render when seeded with heavy',
        );
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. SweatProfileScreen — sweat rate / sodium / test field values
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // Bug #14 FIXED: 35 px overflow resolved (isExpanded on DropdownButtonFormField).
  // Bug #17 FIXED: unit-label ternary was always 'mL/hr'; now shows 'oz/hr'
  // when the toggle is in oz/hr mode. Regression test below.

  group('SweatProfileScreen — content', () {
    testWidgets(
      'Sweat Rate and Sweat Sodium section headings are visible',
      (tester) async {
        const seedState = SweatProfileState(
          sweatRate: SweatRateCat.heavy,
          sweatSodium: SweatSodiumCat.high,
        );

        await pumpSeeded(
          tester,
          const SweatProfileScreen(),
          overrides: [
            sweatProfileControllerProvider.overrideWith(
              () => _SeededSweatProfileController(seedState),
            ),
          ],
          settle: true,
        );

        expect(find.text('Sweat Rate'), findsOneWidget,
            reason: 'Sweat Rate section heading must be visible');
        expect(find.text('Sweat Sodium'), findsOneWidget,
            reason: 'Sweat Sodium section heading must be visible');
      },
    );

    testWidgets(
      'Heavy sweat rate segment renders when seeded with SweatRateCat.heavy',
      (tester) async {
        const seedState = SweatProfileState(
          sweatRate: SweatRateCat.heavy,
          sweatSodium: SweatSodiumCat.average,
        );

        await pumpSeeded(
          tester,
          const SweatProfileScreen(),
          overrides: [
            sweatProfileControllerProvider.overrideWith(
              () => _SeededSweatProfileController(seedState),
            ),
          ],
          settle: true,
        );

        // SweatRateCat.heavy.displayName = 'Heavy'
        expect(
          find.text('Heavy'),
          findsOneWidget,
          reason: 'Heavy sweat rate segment must render',
        );
      },
    );

    testWidgets(
      'AVERAGE sweat sodium segment renders when seeded with SweatSodiumCat.average',
      (tester) async {
        const seedState = SweatProfileState(
          sweatRate: SweatRateCat.medium,
          sweatSodium: SweatSodiumCat.average,
        );

        await pumpSeeded(
          tester,
          const SweatProfileScreen(),
          overrides: [
            sweatProfileControllerProvider.overrideWith(
              () => _SeededSweatProfileController(seedState),
            ),
          ],
          settle: true,
        );

        // KyleSweatSodiumSegmentedControl renders displayName.toUpperCase() = 'AVERAGE'.
        expect(
          find.text('AVERAGE'),
          findsOneWidget,
          reason: 'AVERAGE sweat sodium segment must render',
        );
      },
    );

    testWidgets(
      'known sweat rate field is pre-populated from seeded state (1500) '
      'when the global unit pref is metric',
      (tester) async {
        const seedState = SweatProfileState(
          sweatRate: SweatRateCat.heavy,
          sweatSodium: SweatSodiumCat.high,
          knownSweatRateMlPerHour: 1500,
          knownSodiumConcentrationMgPerLiter: 900,
        );

        await pumpSeeded(
          tester,
          const SweatProfileScreen(),
          overrides: [
            sweatProfileControllerProvider.overrideWith(
              () => _SeededSweatProfileController(seedState),
            ),
            // Sweat rate is stored canonically in mL/hr — metric display
            // is the un-converted value, so force metric here to assert
            // the raw seeded number renders unmodified.
            unitSystemProvider.overrideWith((ref) async => UnitSystem.metric),
          ],
          settle: true,
        );

        // _initFromState sets _sweatRateController.text = '1500'
        // and _sodiumController.text = '900'.
        expect(
          find.text('1500'),
          findsOneWidget,
          reason: 'known sweat rate field must show 1500 from seeded state',
        );
        expect(
          find.text('900'),
          findsOneWidget,
          reason: 'sodium concentration field must show 900 from seeded state',
        );
      },
    );

    testWidgets(
      'known sweat rate field converts to oz/hr when the global unit '
      'pref is imperial',
      (tester) async {
        const seedState = SweatProfileState(
          sweatRate: SweatRateCat.heavy,
          sweatSodium: SweatSodiumCat.high,
          knownSweatRateMlPerHour: 1500,
        );

        await pumpSeeded(
          tester,
          const SweatProfileScreen(),
          overrides: [
            sweatProfileControllerProvider.overrideWith(
              () => _SeededSweatProfileController(seedState),
            ),
            unitSystemProvider
                .overrideWith((ref) async => UnitSystem.imperial),
          ],
          settle: true,
        );

        // Scroll down so the "Personalize with a sweat test" section
        // (which contains the known-sweat-rate field) is in the viewport.
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();

        // 1500 mL/hr × 0.033814 ≈ 50.7 → rounds to 51 oz/hr. The field is
        // driven by the global unit pref (unitSystemProvider), not a
        // screen-local toggle.
        expect(
          find.text('51'),
          findsOneWidget,
          reason: 'known sweat rate must be converted to oz/hr display '
              'when the global pref is imperial',
        );
        expect(
          find.text('oz/hr'),
          findsOneWidget,
          reason: 'field suffix must read oz/hr in imperial mode',
        );
      },
    );

    testWidgets(
      'sweat test date renders as 3/10/2024 when seeded',
      (tester) async {
        final seedState = SweatProfileState(
          sweatRate: SweatRateCat.medium,
          sweatSodium: SweatSodiumCat.average,
          sweatTestDate: DateTime(2024, 3, 10),
        );

        await pumpSeeded(
          tester,
          const SweatProfileScreen(),
          overrides: [
            sweatProfileControllerProvider.overrideWith(
              () => _SeededSweatProfileController(seedState),
            ),
          ],
          settle: true,
        );

        // Screen formats date as '${month}/${day}/${year}'.
        expect(
          find.text('3/10/2024'),
          findsOneWidget,
          reason: 'sweat test date must render as 3/10/2024',
        );
      },
    );

    testWidgets(
      'HIGH sweat sodium segment renders when seeded with SweatSodiumCat.high',
      (tester) async {
        const seedState = SweatProfileState(
          sweatRate: SweatRateCat.light,
          sweatSodium: SweatSodiumCat.high,
        );

        await pumpSeeded(
          tester,
          const SweatProfileScreen(),
          overrides: [
            sweatProfileControllerProvider.overrideWith(
              () => _SeededSweatProfileController(seedState),
            ),
          ],
          settle: true,
        );

        // displayName.toUpperCase() = 'HIGH'
        expect(
          find.text('HIGH'),
          findsOneWidget,
          reason: 'HIGH sweat sodium segment must render',
        );
      },
    );

    // ── Unit label reflects the global unit-system preference ──────────────
    //
    // The screen-local mL/hr-vs-oz/hr toggle was removed; the "Known Sweat
    // Rate" field suffix is now driven entirely by the shared
    // unitSystemProvider (coach/athlete-wide pref), not a per-screen toggle.
    testWidgets(
      'known sweat rate field suffix reads mL/hr when the global unit '
      'pref is metric',
      (tester) async {
        const seedState = SweatProfileState(
          sweatRate: SweatRateCat.medium,
          sweatSodium: SweatSodiumCat.average,
        );

        await pumpSeeded(
          tester,
          const SweatProfileScreen(),
          overrides: [
            sweatProfileControllerProvider.overrideWith(
              () => _SeededSweatProfileController(seedState),
            ),
            unitSystemProvider.overrideWith((ref) async => UnitSystem.metric),
          ],
          settle: true,
        );

        // Scroll down to bring the "Personalize with a sweat test" section
        // (which contains the known-sweat-rate field) into the viewport.
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('mL/hr'),
          findsOneWidget,
          reason: 'field suffix must read mL/hr when the global pref is metric',
        );
        expect(
          find.text('oz/hr'),
          findsNothing,
          reason: 'no local toggle exists — oz/hr must not appear in metric mode',
        );
      },
    );
  });
}
