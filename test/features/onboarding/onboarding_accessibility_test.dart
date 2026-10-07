// Ticket 141 (Findings 118-005, 124-005): onboarding to a screen reader.
// The back circle is a button named "Back"; the sport and obstacle tiles are
// buttons with a checked state; the Continue pill is one named button the
// size of the pill, enabled or not (disabled, it used to be a label-less
// element the size of the screen); a filled name field keeps its name.
// Labels only: no onboarding body copy changes (Xuan's).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/onboarding/domain/onboarding_integration_profile.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_preview_providers.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/personal_info_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/widgets/onboarding_multi_select_step.dart';

import '../../helpers/widget_test_harness.dart';

/// A text field's own node: the editable inside it (the TextField widget's
/// render object carries none of its own).
SemanticsNode _fieldSemantics(WidgetTester tester, Finder field) =>
    tester.getSemantics(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );

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
    await pumpMultiSelect(
      tester,
      selected: {'cycling'},
      onToggle: (_) {},
    );

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

      final first = find.byKey(const ValueKey('personal_info.first_name_field'));
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
}
