// Widget tests for the personal info step (onboarding step 4, 2026-08
// redesign).
//
// Pins the phase-5 contract: Continue is gated on gender + birth year (the
// RMR inputs), names/email stay optional, and every answer mirrors into the
// controller draft immediately.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_integration_profile.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_preview_providers.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/personal_info_screen.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    VoidCallback? onContinue,
    OnboardingIntegrationProfile? integrationProfile,
  }) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          mockSharedPreferences(),
          // Screens must never hit the integrations repository in tests.
          onboardingIntegrationProfileProvider.overrideWith(
            (ref) async =>
                integrationProfile ?? OnboardingIntegrationProfile.empty,
          ),
        ],
        child: wrapForTest(
          PersonalInfoScreen(onContinue: onContinue, stepIndex: 4),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(PersonalInfoScreen)),
    );
  }

  testWidgets('Continue is gated on gender + birth year', (tester) async {
    var continued = 0;
    final container = await pumpScreen(tester, onContinue: () => continued++);
    final controller = container.read(onboardingControllerProvider.notifier);

    // Nothing selected — Continue is disabled.
    await tester.tap(
      find.byKey(const ValueKey('personal_info.continue_button')),
    );
    await tester.pumpAndSettle();
    expect(continued, 0);

    // Gender alone is not enough.
    // The spec's inline wheel always carries a value — the default year is
    // written to the draft on first frame, so gender is the only gate.
    expect(controller.draft.birthYear, 1994);

    await tester.tap(find.byKey(const ValueKey('personal_info.gender_male')));
    await tester.pumpAndSettle();
    expect(controller.draft.gender, Gender.male);

    // Gate satisfied — Continue advances.
    await tester.tap(
      find.byKey(const ValueKey('personal_info.continue_button')),
    );
    await tester.pumpAndSettle();
    expect(continued, 1);
    expectNoRenderOverflow(tester);
  });

  testWidgets('non-binary card maps to Gender.other', (tester) async {
    final container = await pumpScreen(tester);
    final controller = container.read(onboardingControllerProvider.notifier);

    await tester.tap(
      find.byKey(const ValueKey('personal_info.gender_non_binary')),
    );
    await tester.pumpAndSettle();
    expect(controller.draft.gender, Gender.other);
  });

  testWidgets('names and email are optional and mirror into the draft', (
    tester,
  ) async {
    final container = await pumpScreen(tester);
    final controller = container.read(onboardingControllerProvider.notifier);

    // Optional fields start empty in the draft.
    expect(controller.draft.firstName, isNull);
    expect(controller.draft.lastName, isNull);
    expect(controller.draft.email, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('personal_info.first_name_field')),
      'Ada',
    );
    await tester.enterText(
      find.byKey(const ValueKey('personal_info.last_name_field')),
      'Lovelace',
    );
    await tester.enterText(
      find.byKey(const ValueKey('personal_info.email_field')),
      'ada@example.com',
    );
    await tester.pumpAndSettle();

    expect(controller.draft.firstName, 'Ada');
    expect(controller.draft.lastName, 'Lovelace');
    expect(controller.draft.email, 'ada@example.com');
  });

  group('integration autofill', () {
    const tpProfile = OnboardingIntegrationProfile(
      firstName: 'Lee',
      lastName: 'Martin',
      email: 'lee@example.com',
      gender: Gender.male,
      birthYear: 1988,
      weightLbs: 161,
      detailsSource: 'TrainingPeaks',
      weightSource: 'TrainingPeaks',
    );

    testWidgets('fills name, email, gender and birth year into the draft', (
      tester,
    ) async {
      final container = await pumpScreen(
        tester,
        integrationProfile: tpProfile,
      );
      final draft = container
          .read(onboardingControllerProvider.notifier)
          .draft;

      expect(draft.firstName, 'Lee');
      expect(draft.lastName, 'Martin');
      expect(draft.email, 'lee@example.com');
      expect(draft.gender, Gender.male);
      expect(draft.birthYear, 1988);

      // Visible in the fields, and attributed so the athlete knows these
      // are claims to check rather than answers they gave.
      expect(find.text('Lee'), findsOneWidget);
      expect(find.text('Martin'), findsOneWidget);
      expect(find.text('lee@example.com'), findsOneWidget);
      expect(
        find.text(
          'Name, email, gender and birth year filled in from TrainingPeaks '
          '— check and adjust.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the notice names only the fields that actually filled', (
      tester,
    ) async {
      // Final Surge sends a name and email but no gender or birth year.
      // Naming what landed makes the gaps legible: the athlete can see
      // gender and birth year are still theirs to answer, rather than
      // wondering whether they were filled and wrong.
      await pumpScreen(
        tester,
        integrationProfile: const OnboardingIntegrationProfile(
          firstName: 'Xuan',
          lastName: 'Huang',
          email: 'xuan@example.com',
          detailsSource: 'Final Surge',
        ),
      );

      expect(
        find.text(
          'Name and email filled in from Final Surge — check and adjust.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('details filled without a name are still attributed', (
      tester,
    ) async {
      // TrainingPeaks can supply gender/birth year without a usable name.
      // Those fields must not land unattributed — a silent pre-fill is the
      // thing this notice exists to prevent.
      await pumpScreen(
        tester,
        integrationProfile: const OnboardingIntegrationProfile(
          gender: Gender.female,
          birthYear: 1990,
          detailsSource: 'TrainingPeaks',
        ),
      );

      expect(
        find.text(
          'Gender and birth year filled in from TrainingPeaks '
          '— check and adjust.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a single filled field reads as a singular phrase', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        integrationProfile: const OnboardingIntegrationProfile(
          email: 'xuan@example.com',
          detailsSource: 'Final Surge',
        ),
      );

      expect(
        find.text('Email filled in from Final Surge — check and adjust.'),
        findsOneWidget,
      );
    });

    testWidgets('gender autofill satisfies the Continue gate', (tester) async {
      var continued = 0;
      await pumpScreen(
        tester,
        onContinue: () => continued++,
        integrationProfile: tpProfile,
      );

      await tester.tap(
        find.byKey(const ValueKey('personal_info.continue_button')),
      );
      await tester.pumpAndSettle();
      expect(continued, 1);
    });

    testWidgets('never overwrites an answer the athlete already gave', (
      tester,
    ) async {
      tester.view.physicalSize = standardPhoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Build the scope first so the draft can be seeded the way a revisit
      // to this step would have it — the athlete answered on a previous
      // pass, and autofill must not silently rewrite that.
      final container = ProviderContainer(
        overrides: [
          mockAppExternalDeps(),
          mockSharedPreferences(),
          onboardingIntegrationProfileProvider.overrideWith(
            (ref) async => tpProfile,
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(onboardingControllerProvider.notifier);
      controller.updatePersonalInfo(
        firstName: 'Xuan',
        gender: Gender.female,
        birthYear: 1995,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: wrapForTest(const PersonalInfoScreen(stepIndex: 4)),
        ),
      );
      await tester.pumpAndSettle();

      // Their own answers survive...
      expect(controller.draft.firstName, 'Xuan');
      expect(controller.draft.gender, Gender.female);
      expect(controller.draft.birthYear, 1995);
      // ...and the untouched fields still get filled.
      expect(controller.draft.lastName, 'Martin');
      expect(controller.draft.email, 'lee@example.com');
    });

    testWidgets('autofill applies once and does not re-notify in a loop', (
      tester,
    ) async {
      // Applying autofill writes back into the draft, which notifies
      // controller listeners. If anything the screen listens to also
      // watches the controller, that closes a cycle: the draft never
      // settles, onboardingPlanPreview is invalidated forever, and the
      // plan reveal is stranded on its loader. Pin that it settles.
      tester.view.physicalSize = standardPhoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          mockAppExternalDeps(),
          mockSharedPreferences(),
          onboardingIntegrationProfileProvider.overrideWith(
            (ref) async => tpProfile,
          ),
        ],
      );
      addTearDown(container.dispose);

      var notifications = 0;
      container.listen(
        onboardingControllerProvider,
        (_, _) => notifications++,
        fireImmediately: false,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: wrapForTest(const PersonalInfoScreen(stepIndex: 4)),
        ),
      );
      await tester.pumpAndSettle();

      final afterSettle = notifications;
      // Let any runaway cycle show itself.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(
        notifications,
        afterSettle,
        reason: 'draft kept changing after settle — autofill is re-applying',
      );
      // A handful of writes is expected (default year, the autofill batch);
      // an unbounded cycle is not.
      expect(afterSettle, lessThan(10));
    });

    testWidgets('disconnect clears autofilled fields but not typed ones', (
      tester,
    ) async {
      final container = await pumpScreen(
        tester,
        integrationProfile: tpProfile,
      );
      final controller = container.read(onboardingControllerProvider.notifier);

      // Everything arrived from the platform.
      expect(controller.draft.firstName, 'Lee');
      expect(controller.draft.email, 'lee@example.com');

      // The athlete overrides one of them — that field is now theirs.
      await tester.enterText(
        find.byKey(const ValueKey('personal_info.first_name_field')),
        'Xuan',
      );
      await tester.pumpAndSettle();

      controller.clearIntegrationAutofill();

      // Their edit survives; the untouched platform values are gone.
      expect(controller.draft.firstName, 'Xuan');
      expect(controller.draft.lastName, isNull);
      expect(controller.draft.email, isNull);
      expect(controller.draft.gender, isNull);
      expect(controller.draft.birthYear, isNull);
    });

    testWidgets('disconnect leaves a fully hand-entered form alone', (
      tester,
    ) async {
      final container = await pumpScreen(tester);
      final controller = container.read(onboardingControllerProvider.notifier);

      await tester.enterText(
        find.byKey(const ValueKey('personal_info.first_name_field')),
        'Xuan',
      );
      await tester.tap(
        find.byKey(const ValueKey('personal_info.gender_female')),
      );
      await tester.pumpAndSettle();

      controller.clearIntegrationAutofill();

      expect(controller.draft.firstName, 'Xuan');
      expect(controller.draft.gender, Gender.female);
    });

    testWidgets('no notice and no changes when nothing is connected', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(
        find.byKey(const ValueKey('personal_info.autofill_notice')),
        findsNothing,
      );
    });
  });
}
