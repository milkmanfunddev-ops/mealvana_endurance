// Regression coverage for the Learn tab's "Coming Soon" cards.
//
// Bug (2026-07-20 UX pass): the Notify Me button was a KylePrimaryButton with
// onPressed: null — full-opacity brand amber that read as a live CTA but did
// nothing. The fix applies the existing coming-soon pattern from
// integration_provider_card.dart (_NotifyButton): a light-variant
// KyleSecondaryButtonSmall, whose outlined style reads as de-emphasized.
//
// Mutation check: reverting the widget back to KylePrimaryButton fails the
// first test (KylePrimaryButton findsNothing / KyleSecondaryButtonSmall
// findsOneWidget).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:mealvana_endurance/features/education/presentation/widgets/coming_soon_section_widget.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../helpers/widget_test_harness.dart';

const _buttonKey = ValueKey('test.coming_soon_notify_button');

Widget _card() => Scaffold(
  body: ComingSoonSectionWidget(
    notifyButtonKey: _buttonKey,
    icon: FontAwesomeIcons.crown,
    iconColor: AppColors.orange,
    title: 'Premium Video Library',
    description: 'Expert-led deep dives.',
  ),
);

void main() {
  testWidgets('Notify Me renders the de-emphasized coming-soon pattern, '
      'not a primary CTA', (tester) async {
    await smokeScreen(tester, _card(), withAppDeps: false);

    // The existing pattern (_NotifyButton in integration_provider_card.dart):
    // light-variant secondary button — NOT a solid primary button.
    final secondary = tester.widget<KyleSecondaryButtonSmall>(
      find.byKey(_buttonKey),
    );
    expect(secondary.variant, SecondaryButtonVariant.light);
    expect(find.byType(KylePrimaryButton), findsNothing);
    expect(find.text('Notify Me'), findsOneWidget);
  });

  testWidgets('Notify Me is disabled — tapping fires nothing', (tester) async {
    await smokeScreen(tester, _card(), withAppDeps: false);

    final button = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(_buttonKey),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(button.enabled, isFalse);

    // Tapping a disabled button must not throw or trigger anything.
    await tester.tap(find.byKey(_buttonKey), warnIfMissed: false);
    await tester.pump();
  });
}
