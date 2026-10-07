/// Testing-wave 31-002: the "I run with a water bottle" box read as static
/// text in both states, so VoiceOver could not tell whether it was on.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/preferences_screen.dart';

import '../../../../helpers/widget_test_harness.dart';

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
  testWidgets('the water-bottle box exposes its checked state', (tester) async {
    final handle = tester.ensureSemantics();
    await smokeScreen(
      tester,
      const PreferencesScreen(),
      overrides: [
        settingsControllerProvider.overrideWith(_SeededSettingsController.new),
      ],
    );

    final toggle = find.byKey(const ValueKey('preferences.water_bottle'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(toggle),
      isSemantics(
        label:
            'I run with a water bottle\n'
            'This helps us estimate your hydration needs',
        hasCheckedState: true,
        isChecked: false,
        hasTapAction: true,
      ),
    );

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(toggle),
      isSemantics(hasCheckedState: true, isChecked: true, hasTapAction: true),
    );
    handle.dispose();
  });
}
