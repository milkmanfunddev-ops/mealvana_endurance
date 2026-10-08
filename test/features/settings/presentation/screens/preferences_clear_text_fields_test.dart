/// Testing-wave 31-004: on Profile & Preferences, clearing First name or Last
/// name and tapping Save Changes kept the old name. The screen sent null for an
/// empty field, and the save merged `null ?? existing`, so "cleared" read as
/// "not touched". Email had the same problem until it became read-only
/// (ticket 138, 119-002).
///
/// Ticket 36 (Lee 2026-10-08): Email is read-only only when auth holds a real
/// address; with no auth address or an Apple private relay it is an editable
/// contact email, and a read-only save never echoes the auth address into the
/// profile row.
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
import 'package:mealvana_endurance/features/daily_macros/application/daily_macro_service.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';

import '../../../../helpers/test_content.dart';
import '../../../../helpers/widget_test_harness.dart';

class _MockUserRepository extends Mock implements UserRepository {}

// develop's save reads DailyMacroService before anything else; the real one
// needs Supabase.
class _MockDailyMacroService extends Mock implements DailyMacroService {}

final _birthday = DateTime(1985, 3, 20);

/// The real controller with a canned build(), seeded from the same profile the
/// repository returns. [authEmail] is the auth login address; the Email
/// field's value follows the production display rule.
class _SeededSettingsController extends SettingsController {
  _SeededSettingsController({
    this.authEmail = 'alice@example.com',
    this.profileEmail = 'alice@example.com',
  });

  final String? authEmail;
  final String? profileEmail;

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
    authEmail: authEmail,
    email: SettingsState.displayEmailFor(
      authEmail: authEmail,
      profileEmail: profileEmail,
    ),
  );
}

UserProfile _profile({String? email = 'alice@example.com'}) => UserProfile(
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
  email: email,
);

void main() {
  late _MockUserRepository repo;
  UserProfile? saved;

  setUpAll(() => registerFallbackValue(_profile()));

  /// The profile row the repository returns.
  String? rowEmail = 'alice@example.com';

  setUp(() {
    saved = null;
    rowEmail = 'alice@example.com';
    repo = _MockUserRepository();
    when(
      () => repo.getCurrentUser(),
    ).thenAnswer((_) async => _profile(email: rowEmail));
    when(
      () =>
          repo.updateUserProfile(any(), needsUpload: any(named: 'needsUpload')),
    ).thenAnswer((inv) async {
      saved = inv.positionalArguments.first as UserProfile;
    });
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    String? authEmail = 'alice@example.com',
    String? profileEmail = 'alice@example.com',
  }) => smokeScreen(
    tester,
    const PreferencesScreen(),
    overrides: [
      userRepositoryProvider.overrideWith((_) async => repo),
      settingsControllerProvider.overrideWith(
        () => _SeededSettingsController(
          authEmail: authEmail,
          profileEmail: profileEmail,
        ),
      ),
      dailyMacroServiceProvider.overrideWithValue(_MockDailyMacroService()),
      // develop's default ContentService answers keys until it loads.
      contentServiceProvider.overrideWith(testContentService),
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

  // Ticket 138 (119-002, Lee 2026-09-26): Email is the login email and
  // read-only on this screen; the save never sends it.
  testWidgets('Email is shown read-only as the login email and never saved', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(
      find.byKey(const ValueKey('profile_edit.email_field')),
      findsNothing,
    );
    final value = find.byKey(const ValueKey('profile_edit.email_value'));
    expect(value, findsOneWidget);
    expect(tester.widget<Text>(value).data, 'alice@example.com');
    expect(find.text('Your login email'), findsOneWidget);

    await clearAndSave(tester, 'profile_edit.first_name_field');
    expect(saved!.email, 'alice@example.com');
  });

  test('a save that does not mention the text fields keeps them', () async {
    // The other caller (the gut-training chip on the activity's full story)
    // passes only the field it changes.
    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWith((_) async => repo),
        settingsControllerProvider.overrideWith(_SeededSettingsController.new),
        dailyMacroServiceProvider.overrideWithValue(_MockDailyMacroService()),
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

  // Ticket 36: the auth address is display only. A save with the field
  // read-only keeps the row's own value; it never copies the login address
  // (or an Apple relay) into public.users.email.
  test(
    'a read-only save does not echo the auth address into the row',
    () async {
      rowEmail = null;
      final container = ProviderContainer(
        overrides: [
          userRepositoryProvider.overrideWith((_) async => repo),
          settingsControllerProvider.overrideWith(
            () => _SeededSettingsController(profileEmail: null),
          ),
          dailyMacroServiceProvider.overrideWithValue(_MockDailyMacroService()),
        ],
      );
      addTearDown(container.dispose);
      final state = await container.read(settingsControllerProvider.future);
      expect(state.emailEditable, isFalse);
      expect(state.email, 'alice@example.com');

      await container
          .read(settingsControllerProvider.notifier)
          .saveAllPreferences(firstName: 'Alice', email: 'other@example.com');

      expect(saved, isNotNull);
      expect(
        saved!.email,
        isNull,
        reason: 'the row keeps its own (empty) value',
      );
      expect(saved!.toJson()['email'], isNull);
    },
  );

  test('a read-only save keeps a different contact value in the row', () async {
    rowEmail = 'old@contact.com';
    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWith((_) async => repo),
        settingsControllerProvider.overrideWith(
          () => _SeededSettingsController(profileEmail: 'old@contact.com'),
        ),
        dailyMacroServiceProvider.overrideWithValue(_MockDailyMacroService()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsControllerProvider.future);

    await container
        .read(settingsControllerProvider.notifier)
        .saveAllPreferences(gutTrainingLevel: GutTraining.high);

    expect(saved!.email, 'old@contact.com');
  });

  for (final (name, auth) in [
    ('an Apple private relay', 'x1y2@privaterelay.appleid.com'),
    ('no auth address', null),
  ]) {
    testWidgets('with $name, Email is an editable contact email that saves', (
      tester,
    ) async {
      rowEmail = auth;
      await pumpScreen(tester, authEmail: auth, profileEmail: auth);

      expect(
        find.byKey(const ValueKey('profile_edit.email_value')),
        findsNothing,
      );
      final field = find.byKey(const ValueKey('profile_edit.email_field'));
      expect(field, findsOneWidget);
      expect(tester.widget<TextFormField>(field).controller!.text, isEmpty);
      expect(find.text('Contact email'), findsOneWidget);
      expect(find.text('Your login email'), findsNothing);

      await tester.ensureVisible(field);
      await tester.enterText(field, '  lee@example.com ');
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('profile_edit.save_button'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(saved, isNotNull, reason: 'Save Changes must write the profile');
      expect(saved!.email, 'lee@example.com');
    });
  }

  testWidgets('clearing an editable contact email saves it cleared', (
    tester,
  ) async {
    rowEmail = 'lee@example.com';
    await pumpScreen(
      tester,
      authEmail: 'x1y2@privaterelay.appleid.com',
      profileEmail: 'lee@example.com',
    );
    final field = find.byKey(const ValueKey('profile_edit.email_field'));
    expect(
      tester.widget<TextFormField>(field).controller!.text,
      'lee@example.com',
    );

    await clearAndSave(tester, 'profile_edit.email_field');
    expect(saved!.email, isNull);
  });
}
