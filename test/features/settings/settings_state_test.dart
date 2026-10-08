/// Pure unit tests for [SettingsState] — domain logic, computed properties,
/// and copyWith semantics. No Flutter widgets, no Supabase, no Riverpod.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/features/onboarding/domain/allergy.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';

SettingsState _baseState() => const SettingsState(
  title: 'Settings',
  profileSectionTitle: 'Profile',
  preferenceSectionTitle: 'Preferences',
  genderLabel: 'Gender',
  birthdayLabel: 'Birthday',
  heightLabel: 'Height',
  weightLabel: 'Weight',
  waterBottleLabel: 'Run with water bottle',
  distanceUnitLabel: 'Distance unit',
  paceUnitLabel: 'Pace unit',
  gutTrainingLabel: 'Gut training level',
  saveButtonText: 'Save Changes',
);

void main() {
  group('SettingsState — unit preferences computed properties', () {
    test('imperial unitSystem → miles + min/mile', () {
      final s = _baseState().copyWith(unitSystem: UnitSystem.imperial);
      expect(s.preferredDistanceUnit, DistanceUnit.miles);
      expect(s.preferredPaceUnit, PaceUnit.minPerMile);
    });

    test('metric unitSystem → kilometers + min/km', () {
      final s = _baseState().copyWith(unitSystem: UnitSystem.metric);
      expect(s.preferredDistanceUnit, DistanceUnit.kilometers);
      expect(s.preferredPaceUnit, PaceUnit.minPerKm);
    });

    test('default unitSystem is imperial', () {
      final s = _baseState();
      expect(s.unitSystem, UnitSystem.imperial);
    });
  });

  group('SettingsState — athleteCode computed property', () {
    test('null userId returns null athleteCode', () {
      final s = _baseState();
      expect(s.userId, isNull);
      expect(s.athleteCode, isNull);
    });

    test('valid UUID produces ATH- prefixed 8-char code', () {
      final s = _baseState().copyWith(
        userId: 'abc12345-6789-0000-0000-000000000000',
      );
      // replaceAll('-', '') on 'abc12345-6789-0000-0000-000000000000'
      // → 'abc1234567890000000000000000000' → first 8 = 'ABC12345' (uppercase)
      expect(s.athleteCode, startsWith('ATH-'));
      expect(s.athleteCode!.length, equals(12)); // 'ATH-' + 8 chars
    });

    test('short userId (< 8 non-hyphen chars) returns null athleteCode', () {
      // Edge case: an ID too short to produce 8 chars after stripping hyphens.
      final s = _baseState().copyWith(userId: 'abc-de');
      expect(s.athleteCode, isNull);
    });
  });

  group('SettingsState — copyWith semantics', () {
    test('copyWith preserves unspecified fields', () {
      final original = _baseState().copyWith(
        gender: Gender.female,
        heightFeet: 5,
        heightInches: 7,
        weightPounds: 130.0,
        unitSystem: UnitSystem.metric,
        gutTrainingLevel: GutTraining.high,
      );

      // Only change weight — all other fields must survive.
      final updated = original.copyWith(weightPounds: 135.0);

      expect(updated.gender, Gender.female);
      expect(updated.heightFeet, 5);
      expect(updated.heightInches, 7);
      expect(updated.unitSystem, UnitSystem.metric);
      expect(updated.gutTrainingLevel, GutTraining.high);
      expect(updated.weightPounds, 135.0);
    });

    test('copyWith isSaving: false resets saving flag', () {
      final saving = _baseState().copyWith(isSaving: true);
      expect(saving.isSaving, isTrue);

      final done = saving.copyWith(isSaving: false);
      expect(done.isSaving, isFalse);
    });

    test('copyWith runsWithWaterBottle toggles correctly', () {
      final s = _baseState().copyWith(runsWithWaterBottle: true);
      expect(s.runsWithWaterBottle, isTrue);

      final off = s.copyWith(runsWithWaterBottle: false);
      expect(off.runsWithWaterBottle, isFalse);
    });

    test('copyWith allergies list is replaced', () {
      final withDairy = _baseState().copyWith(allergies: [Allergy.dairy]);
      expect(withDairy.allergies, [Allergy.dairy]);

      final cleared = withDairy.copyWith(allergies: []);
      expect(cleared.allergies, isEmpty);
    });

    test(
      'copyWith errorMessage: null clears error (SettingsState passes null through)',
      () {
        // SettingsState.copyWith always assigns errorMessage (no ??)
        final errored = _baseState().copyWith(errorMessage: 'boom');
        expect(errored.errorMessage, 'boom');

        final cleared = errored.copyWith(errorMessage: null);
        expect(cleared.errorMessage, isNull);
      },
    );

    test('default allergies are empty list', () {
      final s = _baseState();
      expect(s.allergies, isEmpty);
    });

    test('default isAnonymous is true', () {
      final s = _baseState();
      expect(s.isAnonymous, isTrue);
    });

    test('default isCoach is false', () {
      final s = _baseState();
      expect(s.isCoach, isFalse);
    });
  });

  group('SettingsState — saveAllPreferences firstName/lastName semantics', () {
    // SettingsState.copyWith uses `firstName: firstName ?? this.firstName`,
    // so passing null for firstName PRESERVES the existing name at the
    // SettingsState layer.
    //
    // saveAllPreferences() without name args therefore keeps the state-level
    // name. Clearing a name is an empty string, not null (31-004); that path
    // is pinned through the real screen in
    // presentation/screens/preferences_clear_text_fields_test.dart.

    test(
      'SettingsState.copyWith with null firstName preserves existing firstName',
      () {
        final s = _baseState().copyWith(firstName: 'Alice', lastName: 'Smith');
        expect(s.firstName, 'Alice');
        expect(s.lastName, 'Smith');

        // SettingsState.copyWith guards: firstName: null ?? this.firstName → 'Alice'
        final afterUpdate = s.copyWith(
          weightPounds: 130.0,
          // firstName not passed → null parameter → ?? preserves 'Alice'
        );

        expect(
          afterUpdate.firstName,
          'Alice',
          reason: 'SettingsState.copyWith preserves firstName via ?? guard',
        );
        expect(
          afterUpdate.lastName,
          'Smith',
          reason: 'SettingsState.copyWith preserves lastName via ?? guard',
        );
      },
    );

    test('explicit firstName set replaces previous value', () {
      final s = _baseState().copyWith(firstName: 'Alice');
      final updated = s.copyWith(firstName: 'Bob');
      expect(updated.firstName, 'Bob');
    });
  });

  // Ticket 36: the Email field is editable only when auth has no readable
  // address; a stored relay string reads as an empty contact email.
  group('SettingsState — email editability (ticket 36)', () {
    test('a real auth address is read-only and shown as is', () {
      final s = _baseState().copyWith(authEmail: 'alice@example.com');
      expect(s.emailEditable, isFalse);
      expect(
        SettingsState.displayEmailFor(
          authEmail: 'alice@example.com',
          profileEmail: 'contact@example.com',
        ),
        'alice@example.com',
      );
    });

    test('a private-relay auth address is editable', () {
      final s = _baseState().copyWith(
        authEmail: 'x1y2@privaterelay.appleid.com',
      );
      expect(s.emailEditable, isTrue);
      expect(
        SettingsState.displayEmailFor(
          authEmail: 'x1y2@privaterelay.appleid.com',
          profileEmail: 'lee@example.com',
        ),
        'lee@example.com',
      );
    });

    test('no auth address (null or blank) is editable', () {
      expect(_baseState().emailEditable, isTrue);
      expect(_baseState().copyWith(authEmail: '  ').emailEditable, isTrue);
      expect(
        SettingsState.displayEmailFor(authEmail: null, profileEmail: null),
        isNull,
      );
    });

    test('a stored relay string reads as an empty contact email', () {
      expect(
        SettingsState.displayEmailFor(
          authEmail: 'x1y2@privaterelay.appleid.com',
          profileEmail: 'x1y2@privaterelay.appleid.com',
        ),
        isNull,
      );
    });

    test('copyWith keeps authEmail', () {
      final s = _baseState().copyWith(authEmail: 'alice@example.com');
      expect(s.copyWith(firstName: 'A').authEmail, 'alice@example.com');
    });
  });
}
