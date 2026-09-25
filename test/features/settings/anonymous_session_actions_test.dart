// Anonymous sessions get NO plain sign-out (ruling, Xuan 2026-09-21).
//
// Signing an anonymous user out discards the session's refresh token, which
// makes that identity — and every athlete record behind it — permanently
// unreachable. See
// ops/data/bug-reports/2026-09-17-new-anonymous-uid-minted-per-open-and-signout.md.
//
// So the Settings account card offers an anonymous session two
// SESSION-PRESERVING actions instead: create an account, or log into an
// existing one. Both push the existing /auth/post-onboarding destination;
// neither touches the session. A REGISTERED session keeps sign-out unchanged.
//
// Pattern: seed the real SettingsController subclass (build() overridden with a
// fixed state, as the settings smoke/content suites do) and record whether
// signOut() is reached. signOut() itself is not exercised here — it tears down
// the controller, clears prefs and uploads through eight repositories; the
// assertion that matters is whether the anonymous path reaches it at all.

// ignore_for_file: must_be_immutable

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/auth/application/auth_service.dart'
    show currentUserProvider;
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/settings_screen.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../helpers/widget_test_harness.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class _MockUserRepository extends Mock implements UserRepository {}

class _MockCoachRepository extends Mock implements CoachRepository {}

// ─── Seeded controller that records sign-out attempts ────────────────────────

class _SignOutSpy {
  int calls = 0;
}

class _SeededSettingsController extends SettingsController {
  _SeededSettingsController(this._seed, this._spy);

  final SettingsState _seed;
  final _SignOutSpy _spy;

  @override
  FutureOr<SettingsState> build() => _seed;

  @override
  Future<void> signOut() async => _spy.calls++;
}

// ─── Seeds ───────────────────────────────────────────────────────────────────

SettingsState _seedState({required bool isAnonymous}) => SettingsState(
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
  isAnonymous: isAnonymous,
  authProvider: isAnonymous ? 'anonymous' : 'email',
  email: isAnonymous ? null : 'athlete@example.com',
);

/// Pumps SettingsScreen inside a real GoRouter so that the account CTAs can be
/// tapped and their destination asserted (the screen navigates with
/// `context.push`, which needs a router above it).
Future<void> _pumpSettings(
  WidgetTester tester, {
  required bool isAnonymous,
  required _SignOutSpy spy,
}) async {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/auth/post-onboarding',
        builder: (_, state) => Scaffold(
          body: Text(
            'post-onboarding:${state.uri.queryParameters['mode'] ?? 'signup'}',
          ),
        ),
      ),
      GoRoute(
        path: '/welcome',
        builder: (_, __) => const Scaffold(body: Text('welcome')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mockAppExternalDeps(),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        mockSharedPreferences(),
        settingsControllerProvider.overrideWith(
          () => _SeededSettingsController(
            _seedState(isAnonymous: isAnonymous),
            spy,
          ),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, __) => MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapByKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  const createAccountLabel = 'Create an account to save your data';
  const logInLabel = 'Log into an existing account';

  group('Anonymous session — no plain sign-out', () {
    testWidgets('account card offers the two session-preserving actions', (
      tester,
    ) async {
      await _pumpSettings(tester, isAnonymous: true, spy: _SignOutSpy());

      expect(
        find.byKey(const ValueKey('settings.create_account_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings.log_in_button')),
        findsOneWidget,
      );
      expect(find.text(createAccountLabel), findsOneWidget);
      expect(find.text(logInLabel), findsOneWidget);
    });

    // The ruled labels are much longer than the old 'Create Account' / 'Log In'
    // and sit in fixed-height buttons, so guard the narrow widths explicitly.
    testWidgets('account card lays out without overflow across device sizes', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const SettingsScreen(),
        overrides: [
          settingsControllerProvider.overrideWith(
            () => _SeededSettingsController(
              _seedState(isAnonymous: true),
              _SignOutSpy(),
            ),
          ),
        ],
        sizes: kSmokeSizes,
        overflowSizes: kSmokeSizes,
      );
    });

    testWidgets('no sign-out control is rendered at all', (tester) async {
      await _pumpSettings(tester, isAnonymous: true, spy: _SignOutSpy());

      expect(
        find.byKey(const ValueKey('settings.sign_out_button')),
        findsNothing,
      );
      expect(find.text('Sign Out'), findsNothing);
      expect(find.text('Sign Out Anyway'), findsNothing);
    });

    testWidgets('create-account action preserves the session and routes to '
        'the existing account-creation destination', (tester) async {
      final spy = _SignOutSpy();
      await _pumpSettings(tester, isAnonymous: true, spy: spy);

      await _tapByKey(tester, 'settings.create_account_button');

      expect(find.text('post-onboarding:signup'), findsOneWidget);
      expect(spy.calls, 0, reason: 'anonymous path must never sign out');
    });

    testWidgets('log-in action preserves the session and routes to the '
        'existing login destination', (tester) async {
      final spy = _SignOutSpy();
      await _pumpSettings(tester, isAnonymous: true, spy: spy);

      await _tapByKey(tester, 'settings.log_in_button');

      expect(find.text('post-onboarding:login'), findsOneWidget);
      expect(spy.calls, 0, reason: 'anonymous path must never sign out');
    });
  });

  group('Registered session — sign-out unchanged', () {
    testWidgets('sign-out is still offered and still signs out', (
      tester,
    ) async {
      final spy = _SignOutSpy();
      await _pumpSettings(tester, isAnonymous: false, spy: spy);

      final signOutButton = find.widgetWithText(OutlinedButton, 'Sign Out');
      await tester.ensureVisible(signOutButton);
      await tester.pumpAndSettle();
      await tester.tap(signOutButton);
      await tester.pumpAndSettle();

      // Confirmation dialog, then the confirm action. Its copy is pinned in
      // settings_account_dialogs_test.dart.
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings.confirm.action')));
      await tester.pumpAndSettle();

      expect(spy.calls, 1);
      expect(find.text('welcome'), findsOneWidget);
    });

    testWidgets('the anonymous-only actions are not rendered', (tester) async {
      await _pumpSettings(tester, isAnonymous: false, spy: _SignOutSpy());

      expect(find.text(createAccountLabel), findsNothing);
      expect(find.text(logInLabel), findsNothing);
    });
  });

  group('SettingsController.build() — real notifier', () {
    test(
      'supplies the ruled anonymous action copy as content defaults',
      () async {
        final userRepository = _MockUserRepository();
        when(userRepository.getCurrentUser).thenAnswer((_) async => null);

        final container = ProviderContainer(
          overrides: [
            userRepositoryProvider.overrideWith((_) async => userRepository),
            currentUserProvider.overrideWith((_) async => null),
            coachRepositoryProvider.overrideWithValue(_MockCoachRepository()),
            // develop's SettingsController reaches further than the release
            // branch's — meal-planning repositories and the Pro-entitlement
            // clear pull in the analytics tracker and the prefs store. Real
            // runs get both from main.dart after loading .env; a bare
            // container has to supply them, as the widget cases above do.
            mockAppExternalDeps(),
            appConfigProvider.overrideWithValue(AppConfig.forTesting()),
            mockSharedPreferences(),
          ],
        );
        addTearDown(container.dispose);

        final state = await container.read(settingsControllerProvider.future);

        expect(state.isAnonymous, isTrue);
        expect(state.createAccountButton, createAccountLabel);
        expect(state.logInButton, logInLabel);
      },
    );
  });
}
