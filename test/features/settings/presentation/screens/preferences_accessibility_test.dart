// Ticket 141 (Findings 119-005, 119-006): Profile & Preferences to a screen
// reader. The bottom back arrow is named "Back"; the gender, units, gut
// training and sweat options are buttons that report selected; Email and
// Birthday have names; a filled name field keeps its name; the tap-to-use
// chip is a button; Nutrition Targets fields are named by their target, not
// by the "Auto" placeholder.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/nutrition_targets_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/preferences_screen.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/data/kyle_source_chip.dart';

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

Future<void> _pumpPreferences(WidgetTester tester) => smokeScreen(
  tester,
  const PreferencesScreen(),
  overrides: [
    settingsControllerProvider.overrideWith(_SeededSettingsController.new),
  ],
);

Future<SemanticsNode> _visibleSemantics(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  return tester.getSemantics(f);
}

/// A text field's own node: the editable inside it.
Finder _editable(Finder field) =>
    find.descendant(of: field, matching: find.byType(EditableText));

void main() {
  testWidgets('the bottom back arrow is named Back', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpPreferences(tester);
    expect(
      await _visibleSemantics(
        tester,
        find.byKey(const ValueKey('profile_edit.back_button')),
      ),
      // An IconButton is named by its tooltip.
      isSemantics(tooltip: 'Back', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('gender, units, gut training and sweat options are buttons '
      'that report selected', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpPreferences(tester);

    final male = find.byKey(const ValueKey('profile_edit.gender_male_button'));
    expect(
      await _visibleSemantics(tester, male),
      isSemantics(
        label: 'Male',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    final female = find.byKey(
      const ValueKey('profile_edit.gender_female_button'),
    );
    expect(
      tester.getSemantics(female),
      isSemantics(
        label: 'Female',
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
      ),
    );
    await tester.tap(female);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(female), isSemantics(isSelected: true));
    expect(tester.getSemantics(male), isSemantics(isSelected: false));

    // Units default to imperial; gut training and sweat rate to moderate.
    final imperial = find.bySemanticsLabel('IMPERIAL');
    expect(
      await _visibleSemantics(tester, imperial),
      isSemantics(isButton: true, hasSelectedState: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('METRIC')),
      isSemantics(isButton: true, hasSelectedState: true, isSelected: false),
    );
    // Gut training shows its multipliers ("LOW 0.7×"); moderate is on.
    final low = find.bySemanticsLabel(RegExp('^LOW'), skipOffstage: false);
    await tester.ensureVisible(low.first);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(low.first),
      isSemantics(isButton: true, hasSelectedState: true, isSelected: false),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('^MODERATE')).first),
      isSemantics(isButton: true, hasSelectedState: true, isSelected: true),
    );
    handle.dispose();
  });

  testWidgets('Email and Birthday have names, and a filled name field keeps '
      'its name', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpPreferences(tester);

    final email = find.byKey(const ValueKey('profile_edit.email_field'));
    expect(
      (await _visibleSemantics(tester, _editable(email))).label,
      startsWith('Email'),
    );

    final first = find.byKey(const ValueKey('profile_edit.first_name_field'));
    expect(
      await _visibleSemantics(tester, _editable(first)),
      isSemantics(isTextField: true, label: 'First name'),
    );
    await tester.enterText(first, 'Xuan');
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(_editable(first)),
      isSemantics(isTextField: true, label: 'First name', value: 'Xuan'),
    );

    final birthday = find.byKey(
      const ValueKey('profile_edit.birthday_button'),
    );
    expect(
      await _visibleSemantics(tester, birthday),
      isSemantics(
        label: 'Birthday',
        value: 'Select your birthday',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the tap-to-use chip is a button', (tester) async {
    final handle = tester.ensureSemantics();
    var adopted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KyleTapToUseChip(
            source: 'TrainingPeaks',
            value: '240 W',
            onTap: () => adopted++,
          ),
        ),
      ),
    );
    final chip = find.byType(KyleTapToUseChip);
    expect(
      tester.getSemantics(chip),
      isSemantics(
        label: 'TrainingPeaks · 240 W — tap to use',
        isButton: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(chip);
    expect(adopted, 1);
    handle.dispose();
  });

  testWidgets('Nutrition Targets fields are named by their target, not Auto', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await smokeScreen(
      tester,
      const NutritionTargetsScreen(),
      overrides: [
        settingsControllerProvider.overrideWith(_SeededSettingsController.new),
      ],
    );

    final carbs = find.byKey(
      const ValueKey('nutrition_targets.pre_carbs_field'),
    );
    final empty = await _visibleSemantics(tester, _editable(carbs));
    expect(empty, isSemantics(isTextField: true));
    expect(empty.label, startsWith('Carbs (g)'));
    await tester.enterText(carbs, '50.4');
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(_editable(carbs)),
      isSemantics(isTextField: true, label: 'Carbs (g)', value: '50.4'),
    );
    handle.dispose();
  });
}
