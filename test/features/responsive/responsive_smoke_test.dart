import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mealvana_endurance/features/app_startup/presentation/screens/force_upgrade_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/allergies_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/dietary_preference_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/running_details_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/sports_selection_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import '../../helpers/responsive_test_harness.dart';

class _MockAnalyticsTracker extends Mock implements AnalyticsTracker {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockSentryReporter extends Mock implements SentryReporter {}

class _MockAppLogger extends Mock implements AppLogger {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

_responsiveOverrides() {
  final analytics = _MockAnalyticsTracker();
  when(
    () => analytics.track(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});

  return [
    appExternalDepsProvider.overrideWithValue(
      AppExternalDeps(
        analytics: analytics,
        supabaseClient: _MockSupabaseClient(),
        sentry: _MockSentryReporter(),
        logger: _MockAppLogger(),
        sharedPreferences: _MockSharedPreferences(),
      ),
    ),
  ];
}

void main() {
  group('Responsive smoke tests', () {
    testWidgets('WelcomeScreen renders without overflow on key sizes', (
      tester,
    ) async {
      for (final size in [
        smallPhoneSize,
        standardPhoneSize,
        tabletPortraitSize,
      ]) {
        await pumpResponsiveScreen(
          tester,
          screen: const WelcomeScreen(),
          surfaceSize: size,
        );
        expectNoRenderOverflow(tester);
      }
    });

    testWidgets('ForceUpgradeScreen renders without overflow on key sizes', (
      tester,
    ) async {
      for (final size in [smallPhoneSize, standardPhoneSize, desktopSize]) {
        await pumpResponsiveScreen(
          tester,
          screen: const ForceUpgradeScreen(
            currentVersion: '1.0.0',
            requiredVersion: '2.0.0',
          ),
          surfaceSize: size,
        );
        expectNoRenderOverflow(tester);
      }
    });

    testWidgets('SportsSelectionScreen renders without overflow on key sizes', (
      tester,
    ) async {
      for (final size in [
        smallPhoneSize,
        standardPhoneSize,
        tabletPortraitSize,
      ]) {
        await pumpResponsiveScreen(
          tester,
          screen: const SportsSelectionScreen(),
          surfaceSize: size,
          overrides: _responsiveOverrides(),
        );
        expectNoRenderOverflow(tester);
      }
    });

    testWidgets('RunningDetailsScreen renders without overflow on key sizes', (
      tester,
    ) async {
      for (final size in [
        smallPhoneSize,
        standardPhoneSize,
        tabletPortraitSize,
      ]) {
        await pumpResponsiveScreen(
          tester,
          screen: const RunningDetailsScreen(),
          surfaceSize: size,
          overrides: _responsiveOverrides(),
        );
        expectNoRenderOverflow(tester);
      }
    });

    testWidgets(
      'DietaryPreferenceScreen renders without overflow on key sizes',
      (tester) async {
        for (final size in [
          smallPhoneSize,
          standardPhoneSize,
          tabletPortraitSize,
        ]) {
          await pumpResponsiveScreen(
            tester,
            screen: const DietaryPreferenceScreen(),
            surfaceSize: size,
            overrides: _responsiveOverrides(),
          );
          expectNoRenderOverflow(tester);
        }
      },
    );

    testWidgets('AllergiesScreen renders without overflow on key sizes', (
      tester,
    ) async {
      for (final size in [
        smallPhoneSize,
        standardPhoneSize,
        tabletPortraitSize,
      ]) {
        await pumpResponsiveScreen(
          tester,
          screen: const AllergiesScreen(),
          surfaceSize: size,
          overrides: _responsiveOverrides(),
        );
        expectNoRenderOverflow(tester);
      }
    });
  });
}
