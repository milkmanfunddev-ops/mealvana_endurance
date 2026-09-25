// The Settings "Profile & Preferences" tile reads the content system, not a
// string in the screen (testing-wave 94 item 5, Finding 31-014's leftover).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/settings_screen.dart';

import '../../helpers/widget_test_harness.dart';
import '../meal_planning/presentation/helpers/test_content.dart';

class _SeededSettingsController extends SettingsController {
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

void main() {
  testWidgets('the Profile & Preferences tile shows the content values', (
    tester,
  ) async {
    final content = loadDefaultContent();
    await smokeScreen(
      tester,
      const SettingsScreen(),
      overrides: [
        settingsControllerProvider.overrideWith(_SeededSettingsController.new),
        contentServiceProvider.overrideWith(testContentService),
      ],
    );

    expect(
      find.text(content['settings.profile_preferences_title']!),
      findsOneWidget,
    );
    expect(
      find.text(content['settings.profile_preferences_subtitle']!),
      findsOneWidget,
    );
  });
}
