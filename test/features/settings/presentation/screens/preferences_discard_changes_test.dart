// Ticket 138 (Finding 119-010, Lee 2026-09-26): Profile & Preferences asks
// "Discard changes?" on the back arrow, the bottom Back and the system back
// (iOS swipe) when edits are unsaved. With no changes, it leaves at once.
//
// Drives the real screen pushed onto a real Navigator, so leaving is
// observable; only the user repository is faked.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/preferences_screen.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/features/daily_macros/application/daily_macro_service.dart';

import '../../../../helpers/widget_test_harness.dart';
import '../../../../helpers/test_content.dart';

class _MockUserRepository extends Mock implements UserRepository {}

// develop's save reads DailyMacroService before anything else; the real one
// needs Supabase.
class _MockDailyMacroService extends Mock implements DailyMacroService {}

final _birthday = DateTime(1985, 3, 20);

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

/// A home page with one button that pushes Profile & Preferences.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const ValueKey('host.open'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PreferencesScreen()),
        ),
        child: const Text('Open'),
      ),
    ),
  );
}

void main() {
  late _MockUserRepository repo;
  UserProfile? saved;
  final content = loadDefaultContent();

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

  Future<void> pumpAndOpen(WidgetTester tester) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          mockSharedPreferences(),
          userRepositoryProvider.overrideWith((_) async => repo),
          settingsControllerProvider.overrideWith(
            _SeededSettingsController.new,
          ),
          contentServiceProvider.overrideWith(testContentService),
        ],
        child: wrapForTest(const _Host()),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('host.open')));
    await tester.pumpAndSettle();
    expect(find.byType(PreferencesScreen), findsOneWidget);
  }

  Future<void> edit(WidgetTester tester) async {
    final field = find.byKey(const ValueKey('profile_edit.first_name_field'));
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Alicia');
    await tester.pumpAndSettle();
  }

  Future<void> systemBack(WidgetTester tester) async {
    // What the iOS swipe and the Android back gesture do.
    final dynamic app = tester.state(find.byType(WidgetsApp));
    await app.didPopRoute();
    await tester.pumpAndSettle();
  }

  final dialogTitle = content['profile_edit.discard_title']!;

  testWidgets('with no changes, the back arrow leaves at once', (tester) async {
    await pumpAndOpen(tester);

    await tester.tap(
      find.byKey(const ValueKey('preferences.app_bar_back_button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PreferencesScreen), findsNothing);
    expect(find.text(dialogTitle), findsNothing);
  });

  testWidgets('with no changes, the system back leaves at once', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    await systemBack(tester);
    expect(find.byType(PreferencesScreen), findsNothing);
  });

  testWidgets('with edits, the back arrow asks; Keep editing stays', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    await edit(tester);

    await tester.tap(
      find.byKey(const ValueKey('preferences.app_bar_back_button')),
    );
    await tester.pumpAndSettle();
    expect(find.text(dialogTitle), findsOneWidget);
    expect(find.text(content['profile_edit.discard_body']!), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile_edit.keep_editing')));
    await tester.pumpAndSettle();
    expect(find.byType(PreferencesScreen), findsOneWidget);
    expect(find.text('Alicia'), findsOneWidget, reason: 'the edit is kept');
  });

  testWidgets('with edits, the bottom Back asks; Discard leaves unsaved', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    await edit(tester);

    final back = find.byKey(const ValueKey('profile_edit.back_button'));
    await tester.ensureVisible(back);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text(dialogTitle), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile_edit.discard')));
    await tester.pumpAndSettle();
    expect(find.byType(PreferencesScreen), findsNothing);
    expect(saved, isNull, reason: 'Discard writes nothing');
  });

  testWidgets('with edits, the system back asks too', (tester) async {
    await pumpAndOpen(tester);
    await edit(tester);

    await systemBack(tester);
    expect(find.text(dialogTitle), findsOneWidget);
    expect(find.byType(PreferencesScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile_edit.discard')));
    await tester.pumpAndSettle();
    expect(find.byType(PreferencesScreen), findsNothing);
  });
}
