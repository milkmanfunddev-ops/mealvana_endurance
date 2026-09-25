/// Testing-wave 31-004: on Profile & Preferences, clearing First name or Last
/// name and tapping Save Changes kept the old name. The screen sent null for an
/// empty field, and the save merged `null ?? existing`, so "cleared" read as
/// "not touched". Email, the screen's other free-text field, had the same
/// problem.
///
/// Drives the real screen and the real SettingsController save path; only the
/// user repository (the local write plus upload) is faked.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/preferences_screen.dart';

import '../../../../helpers/widget_test_harness.dart';

class _MockUserRepository extends Mock implements UserRepository {}

final _birthday = DateTime(1985, 3, 20);

/// The real controller with a canned build(), seeded from the same profile the
/// repository returns.
class _SeededSettingsController extends SettingsController {
  @override
  FutureOr<SettingsState> build() => SettingsState(
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
    gender: Gender.male,
    birthday: _birthday,
    firstName: 'Alice',
    lastName: 'Smith',
    email: 'alice@example.com',
  );
}

UserProfile _profile() => UserProfile(
  id: 'u1',
  deviceId: 'd1',
  gender: Gender.male,
  birthday: _birthday,
  heightFeet: 5,
  heightInches: 11,
  weightPounds: 165,
  runsWithWaterBottle: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  appVersion: '1.0.0',
  firstName: 'Alice',
  lastName: 'Smith',
  email: 'alice@example.com',
);

void main() {
  late _MockUserRepository repo;
  UserProfile? saved;

  setUpAll(() => registerFallbackValue(_profile()));

  setUp(() {
    saved = null;
    repo = _MockUserRepository();
    when(() => repo.getCurrentUser()).thenAnswer((_) async => _profile());
    when(
      () =>
          repo.updateUserProfile(any(), needsUpload: any(named: 'needsUpload')),
    ).thenAnswer((inv) async {
      saved = inv.positionalArguments.first as UserProfile;
    });
  });

  Future<void> pumpScreen(WidgetTester tester) => smokeScreen(
    tester,
    const PreferencesScreen(),
    overrides: [
      userRepositoryProvider.overrideWith((_) async => repo),
      settingsControllerProvider.overrideWith(_SeededSettingsController.new),
    ],
  );

  Future<void> clearAndSave(WidgetTester tester, String fieldKey) async {
    final field = find.byKey(ValueKey(fieldKey));
    await tester.ensureVisible(field);
    await tester.enterText(field, '');
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('profile_edit.save_button'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  testWidgets('clearing First name saves it cleared, Last name kept', (
    tester,
  ) async {
    await pumpScreen(tester);
    await clearAndSave(tester, 'profile_edit.first_name_field');

    expect(saved, isNotNull, reason: 'Save Changes must write the profile');
    expect(saved!.firstName, isNull);
    expect(saved!.lastName, 'Smith');
    expect(saved!.email, 'alice@example.com');
    // The payload the upload sends.
    expect(saved!.toJson()['first_name'], isNull);
  });

  testWidgets('clearing Last name saves it cleared, First name kept', (
    tester,
  ) async {
    await pumpScreen(tester);
    await clearAndSave(tester, 'profile_edit.last_name_field');

    expect(saved, isNotNull, reason: 'Save Changes must write the profile');
    expect(saved!.lastName, isNull);
    expect(saved!.firstName, 'Alice');
    expect(saved!.toJson()['last_name'], isNull);
  });

  testWidgets('clearing Email saves it cleared, names kept', (tester) async {
    await pumpScreen(tester);
    await clearAndSave(tester, 'profile_edit.email_field');

    expect(saved, isNotNull, reason: 'Save Changes must write the profile');
    expect(saved!.email, isNull);
    expect(saved!.firstName, 'Alice');
    expect(saved!.lastName, 'Smith');
  });

  test('a save that does not mention the text fields keeps them', () async {
    // The other caller (the gut-training chip on the activity's full story)
    // passes only the field it changes.
    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWith((_) async => repo),
        settingsControllerProvider.overrideWith(_SeededSettingsController.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsControllerProvider.future);

    await container
        .read(settingsControllerProvider.notifier)
        .saveAllPreferences(gutTrainingLevel: GutTraining.high);

    expect(saved!.gutTraining, GutTraining.high);
    expect(saved!.firstName, 'Alice');
    expect(saved!.lastName, 'Smith');
    expect(saved!.email, 'alice@example.com');
  });
}
