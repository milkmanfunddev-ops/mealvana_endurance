// Regression coverage for bug 3a3e3fdb-81d7 — "Cramped layout: Garmin banner
// sits flush against the energy card on the Fuel Timeline".
//
// Two tests that must BOTH hold:
//   1. Banner visible   -> exactly AppSpacing.md between banner and card.
//   2. Banner hidden    -> the gap above the card is UNCHANGED (still one
//                          AppSpacing.md, not two).
//
// Test 2 is the one that earns its keep: it fails if the gap is implemented as
// an unconditional SizedBox in the screen's Column, because the banner's three
// self-hiding paths (dismissed / signed out / already connected) leave a
// zero-height box behind and the spacer would double up to 32px for the
// majority of users.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/fuel_timeline/application/day_timeline_assembler.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/providers/fuel_timeline_controller.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/screens/fuel_timeline_screen.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/widgets/energy_dashboard_card.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/features/integrations/presentation/widgets/garmin_connect_banner.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';

import '../../helpers/widget_test_harness.dart';

const _userId = 'banner-spacing-user-001';

void main() {
  late PreferencesService prefs;

  setUp(() async {
    // Empty prefs => garminBannerDismissed is false, so the banner is eligible
    // to show. This is the state no pre-existing test ever exercised.
    SharedPreferences.setMockInitialValues({});
    prefs = PreferencesService(await SharedPreferences.getInstance());
  });

  UserProfile profileFixture() => UserProfile(
        id: _userId,
        deviceId: 'dev-001',
        authUserId: 'aa000000-0000-0000-0000-000000000001',
        authProvider: 'email',
        isAnonymous: false,
        gender: Gender.male,
        birthday: DateTime(1985, 3, 20),
        heightFeet: 6,
        heightInches: 0,
        weightPounds: 180.0,
        runsWithWaterBottle: false,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        onboardingCompleted: true,
        appVersion: '1.0',
      );

  DayTimelineResult fixtureResult() {
    final date = DateTime(2026, 6, 17);
    final meal = MealLog(
      id: 'm1',
      userId: _userId,
      logDate: '2026-06-17',
      slot: MealSlot.breakfast,
      name: 'Everything Bagel',
      source: MealLogSource.manual,
      components: const [],
      calories: 574,
      carbsG: 58,
      proteinG: 30,
      fatG: 25,
      eatenAt: DateTime(2026, 6, 17, 7, 30),
      createdAt: DateTime(2026, 6, 17, 7, 30),
      updatedAt: DateTime(2026, 6, 17, 7, 30),
    );
    final ride = Activity(
      id: 'a1',
      userId: _userId,
      activityType: ActivityType.cycling,
      title: '25 mi Ride',
      scheduledDateTime: DateTime(2026, 6, 17, 16, 15),
      distanceMiles: 25,
      cyclingSpeedMph: 15,
      durationMinutes: 100,
      createdAt: date,
      updatedAt: date,
    );
    final targets = DailyMacroTargets(
      id: 't1',
      userId: _userId,
      targetDate: date,
      carbG: 300,
      protG: 140,
      fatG: 75,
      tdee: 1911,
      rmr: 1091,
      sessionKcal: 502,
      neatKcal: 300,
      mode: 'prospective',
      createdAt: date,
      updatedAt: date,
    );
    return const DayTimelineAssembler().assemble(
      selectedDate: date,
      now: DateTime(2026, 6, 17, 20),
      meals: [meal],
      activities: [ride],
      targets: targets,
      consumed: const ConsumedTotals(
        calories: 574,
        carbsG: 58,
        proteinG: 30,
        fatG: 25,
      ),
    );
  }

  List<Override> baseOverrides() => [
        preferencesServiceProvider.overrideWithValue(prefs),
        fuelTimelineDayProvider.overrideWith((ref) async => fixtureResult()),
      ];

  /// The banner's painted bottom edge. Anchoring on the [DecoratedBox] rather
  /// than the Container/BaseCard matters: `Container` implements `margin` by
  /// wrapping itself in a Padding, so its RenderBox INCLUDES the margin and
  /// would report a 0px gap — passing for the wrong reason.
  double bannerPaintedBottom(WidgetTester tester) {
    final decoration = find
        .descendant(
          of: find.byType(GarminConnectBanner),
          matching: find.byType(DecoratedBox),
        )
        .first;
    return tester.getRect(decoration).bottom;
  }

  testWidgets(
    'banner visible: exactly AppSpacing.md between banner and energy card',
    (tester) async {
      await smokeScreen(
        tester,
        const FuelTimelineScreen(),
        overrides: [
          ...baseOverrides(),
          currentUserProvider.overrideWith((ref) async => profileFixture()),
          isGarminConnectedProvider(_userId).overrideWith((ref) async => false),
        ],
      );

      // Guard: without this the geometry assertion can pass vacuously against
      // a SizedBox.shrink()-ed banner.
      expect(find.text('Connect Garmin'), findsOneWidget);
      // Guard: view.trackingOn defaults true; fail loudly if that ever flips.
      expect(find.byType(EnergyDashboardCard), findsOneWidget);

      final gap = tester.getTopLeft(find.byType(EnergyDashboardCard)).dy -
          bannerPaintedBottom(tester);

      expect(gap, closeTo(AppSpacing.md, 0.5));
    },
  );

  testWidgets(
    'banner hidden: gap above the energy card stays a single AppSpacing.md',
    (tester) async {
      await smokeScreen(
        tester,
        const FuelTimelineScreen(),
        // currentUserProvider left at the harness default (null) so the banner
        // takes its "no authenticated user" early return.
        overrides: baseOverrides(),
      );

      expect(find.text('Connect Garmin'), findsNothing);
      expect(find.byType(EnergyDashboardCard), findsOneWidget);

      // Measure from the top of the Column that holds the banner: the only
      // thing between it and the card should be the single leading spacer.
      final column = find
          .ancestor(
            of: find.byType(GarminConnectBanner),
            matching: find.byType(Column),
          )
          .first;
      final gap = tester.getTopLeft(find.byType(EnergyDashboardCard)).dy -
          tester.getTopLeft(column).dy;

      expect(
        gap,
        closeTo(AppSpacing.md, 0.5),
        reason: 'A hidden banner must not leave a doubled 32px dead band. '
            'If this reads ~32, the gap was added as an unconditional '
            'SizedBox in the screen instead of a margin on the banner.',
      );
    },
  );

  testWidgets('banner visible with tracking off: no overflow', (tester) async {
    await prefs.setFuelTrackingEnabled(false);

    await smokeScreen(
      tester,
      const FuelTimelineScreen(),
      overrides: [
        ...baseOverrides(),
        currentUserProvider.overrideWith((ref) async => profileFixture()),
        isGarminConnectedProvider(_userId).overrideWith((ref) async => false),
      ],
    );

    expect(find.text('Connect Garmin'), findsOneWidget);
    expect(find.byType(EnergyDashboardCard), findsNothing);
  });
}
