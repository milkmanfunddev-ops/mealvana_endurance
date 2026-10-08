// Ticket 141 (Findings 118-005, 124-005): onboarding to a screen reader.
// The back circle is a button named "Back"; the sport and obstacle tiles are
// buttons with a checked state; the Continue pill is one named button the
// size of the pill, enabled or not (disabled, it used to be a label-less
// element the size of the screen); a filled name field keeps its name.
// Labels only: no onboarding body copy changes (Xuan's).
//
// Ticket 43 (Finding 30-010): Welcome's Build My Plan and the three sign-in
// pills on Create account are named buttons (they read as static text), and
// a busy sign-in pill keeps its name while it shows only a spinner.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/auth/application/apple_web_authentication.dart';
import 'package:mealvana_endurance/features/auth/presentation/providers/post_onboarding_auth_controller.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/post_onboarding_auth_screen.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_integration_profile.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_preview_providers.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/personal_info_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/widgets/onboarding_multi_select_step.dart';

import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../helpers/widget_test_harness.dart';

/// A text field's own node: the editable inside it (the TextField widget's
/// render object carries none of its own).
SemanticsNode _fieldSemantics(WidgetTester tester, Finder field) =>
    tester.getSemantics(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );

/// Create account's controller at rest: no Supabase, no sign-in.
class _IdleAuthController extends PostOnboardingAuthController {
  @override
  FutureOr<void> build() {}
}

/// Create account's controller, put mid sign-in by the test: `isBusy` on
/// the screen, the state a real sign-in sets before its first await.
class _BusyAuthController extends PostOnboardingAuthController {
  @override
  FutureOr<void> build() {}

  void startSignIn() => state = const AsyncLoading();
}

void main() {
  Future<void> pumpMultiSelect(
    WidgetTester tester, {
    required Set<String> selected,
    required ValueChanged<String> onToggle,
    VoidCallback? onBack,
  }) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingMultiSelectStep<String>(
          title: 'What do you train for?',
          subtitle: 'Pick every sport you race.',
          options: const [
            OnboardingMultiSelectOption(
              value: 'running',
              label: 'Running',
              itemKey: ValueKey('tile.running'),
            ),
            OnboardingMultiSelectOption(
              value: 'cycling',
              label: 'Cycling',
              itemKey: ValueKey('tile.cycling'),
            ),
          ],
          selected: selected,
          onToggle: onToggle,
          onContinue: () {},
          onBack: onBack,
          stepIndex: 1,
          backButtonKey: const ValueKey('step.back'),
          continueButtonKey: const ValueKey('step.continue'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the back circle is a button named Back', (tester) async {
    final handle = tester.ensureSemantics();
    var backs = 0;
    await pumpMultiSelect(
      tester,
      selected: {},
      onToggle: (_) {},
      onBack: () => backs++,
    );

    expect(
      tester.getSemantics(find.byKey(const ValueKey('step.back'))),
      isSemantics(label: 'Back', isButton: true, hasTapAction: true),
    );
    await tester.tap(find.byKey(const ValueKey('step.back')));
    expect(backs, 1);
    handle.dispose();
  });

  testWidgets('sport tiles are buttons with a checked state', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpMultiSelect(tester, selected: {'cycling'}, onToggle: (_) {});

    expect(
      tester.getSemantics(find.byKey(const ValueKey('tile.running'))),
      isSemantics(
        label: 'Running',
        isButton: true,
        hasCheckedState: true,
        isChecked: false,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('tile.cycling'))),
      isSemantics(
        label: 'Cycling',
        isButton: true,
        hasCheckedState: true,
        isChecked: true,
      ),
    );
    // Every tap target on the step carries a name.
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('the Continue pill is one named, enabled button the size of '
      'the pill', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpMultiSelect(tester, selected: {}, onToggle: (_) {});

    final pill = find.byKey(const ValueKey('step.continue'));
    final node = tester.getSemantics(pill);
    expect(
      node,
      isSemantics(label: 'Continue', isButton: true, hasTapAction: true),
    );
    expect(node.rect.size.height, lessThan(80));
    handle.dispose();
  });

  group('Tell us about yourself', () {
    Future<void> pumpPersonalInfo(WidgetTester tester) async {
      tester.view.physicalSize = standardPhoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockAppExternalDeps(),
            mockSharedPreferences(),
            onboardingIntegrationProfileProvider.overrideWith(
              (ref) async => OnboardingIntegrationProfile.empty,
            ),
          ],
          child: wrapForTest(const PersonalInfoScreen(stepIndex: 4)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the disabled Continue is a named button the size of the '
        'pill, not the screen', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPersonalInfo(tester);

      final pill = find.byKey(const ValueKey('personal_info.continue_button'));
      final node = tester.getSemantics(pill);
      expect(
        node,
        isSemantics(
          label: 'Continue',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      final pillRect = tester.getRect(pill);
      expect(node.rect.height, closeTo(pillRect.height, 1));
      expect(node.rect.height, lessThan(standardPhoneSize.height / 2));
      handle.dispose();
    });

    testWidgets('a filled name field keeps its name', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPersonalInfo(tester);

      final first = find.byKey(
        const ValueKey('personal_info.first_name_field'),
      );
      expect(
        _fieldSemantics(tester, first),
        isSemantics(isTextField: true, label: 'First name'),
      );

      await tester.enterText(first, 'Xuan');
      await tester.pumpAndSettle();
      expect(
        _fieldSemantics(tester, first),
        isSemantics(isTextField: true, label: 'First name', value: 'Xuan'),
      );

      final last = find.byKey(const ValueKey('personal_info.last_name_field'));
      await tester.enterText(last, 'Huang');
      await tester.pumpAndSettle();
      expect(
        _fieldSemantics(tester, last),
        isSemantics(isTextField: true, label: 'Last name', value: 'Huang'),
      );
      handle.dispose();
    });
  });

  testWidgets('Welcome: Build My Plan is one named, enabled button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          mockSharedPreferences(),
        ],
        child: wrapForTest(const WelcomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('welcome.get_started_button')),
      ),
      matchesSemantics(
        label: 'Build My Plan',
        isButton: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    // Read once: no second node carries the visible text.
    expect(find.bySemanticsLabel('Build My Plan'), findsOneWidget);
    handle.dispose();
  });

  group('Create account: the sign-in pills', () {
    // Pill key → (content key, fallback), exactly as the screen reads its
    // labels. A busy pill draws only a spinner, so its expected name comes
    // from the same content lookup the screen made on that (busy) build.
    const pills = {
      'post_onboarding.apple_button': (
        'auth.post_onboarding.apple_button',
        'Continue with Apple',
      ),
      'post_onboarding.google_button': (
        'auth.post_onboarding.google_button',
        'Continue with Google',
      ),
      'post_onboarding.email_button': (
        'auth.post_onboarding.email_button',
        'Sign up with email',
      ),
    };

    String visibleLabel(WidgetTester tester, (String, String) pill) =>
        ProviderScope.containerOf(
          tester.element(find.byType(PostOnboardingAuthScreen)),
        ).read(contentServiceProvider).getValue(pill.$1, defaultValue: pill.$2);

    Future<void> pumpAuth(
      WidgetTester tester,
      PostOnboardingAuthController Function() controller,
    ) async {
      tester.view.physicalSize = standardPhoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockAppExternalDeps(),
            appConfigProvider.overrideWithValue(AppConfig.forTesting()),
            mockSharedPreferences(),
            appleSignInAvailableProvider.overrideWithValue(true),
            postOnboardingAuthControllerProvider.overrideWith(controller),
          ],
          child: wrapForTest(const PostOnboardingAuthScreen(mode: 'signup')),
        ),
      );
      // A busy pill spins forever, so pump frames rather than settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('each is a named, enabled button', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAuth(tester, _IdleAuthController.new);

      for (final key in pills.keys) {
        // The name is the string drawn on the pill.
        final drawn = tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(Text),
              ),
            )
            .data!;
        expect(
          tester.getSemantics(find.byKey(ValueKey(key))),
          matchesSemantics(
            label: drawn,
            isButton: true,
            hasTapAction: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasFocusAction: true,
          ),
          reason: key,
        );
      }
      handle.dispose();
    });

    testWidgets('busy, each is a named, disabled button; the spinning '
        'Google pill keeps its name', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAuth(tester, _BusyAuthController.new);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PostOnboardingAuthScreen)),
      );
      (container.read(postOnboardingAuthControllerProvider.notifier)
              as _BusyAuthController)
          .startSignIn();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The Google pill shows only a spinner now; its name must survive.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('post_onboarding.google_button')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      for (final entry in pills.entries) {
        expect(
          tester.getSemantics(find.byKey(ValueKey(entry.key))),
          matchesSemantics(
            label: visibleLabel(tester, entry.value),
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
          ),
          reason: entry.key,
        );
      }
      handle.dispose();
    });
  });
}
