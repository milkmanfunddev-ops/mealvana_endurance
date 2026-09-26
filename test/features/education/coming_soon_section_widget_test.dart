// The Learn tab's "Coming Soon" cards.
//
// 2026-07-20 UX pass: the Notify Me button was a KylePrimaryButton with
// onPressed: null — full-opacity brand amber that read as a live CTA but did
// nothing. It became the coming-soon pattern from
// integration_provider_card.dart (_NotifyButton): a light-variant
// KyleSecondaryButtonSmall.
//
// Finding 117-006 (ticket 141): drawn as a live pill, the button still did
// nothing on either card. It now records the interest once, says "We'll let
// you know", and reads "Noted" and inert from then on: a second tap writes
// nothing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/education/presentation/widgets/coming_soon_section_widget.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../helpers/widget_test_harness.dart';
import '../meal_planning/presentation/helpers/test_content.dart';

const _buttonKey = ValueKey('test.coming_soon_notify_button');

final _content = loadDefaultContent();

Widget _card() => Scaffold(
  body: ComingSoonSectionWidget(
    notifyButtonKey: _buttonKey,
    icon: FontAwesomeIcons.crown,
    iconColor: AppColors.orange,
    title: 'Premium Video Library',
    description: 'Expert-led deep dives.',
  ),
);

/// The card with a recording analytics tracker and the app's own content.
Future<MockAnalyticsTracker> pumpCard(WidgetTester tester) async {
  final analytics = MockAnalyticsTracker();
  when(
    () => analytics.track(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});
  await smokeScreen(
    tester,
    _card(),
    withAppDeps: false,
    overrides: [
      appExternalDepsProvider.overrideWithValue(
        AppExternalDeps(
          analytics: analytics,
          supabaseClient: fakeSupabaseClient(),
          sentry: MockSentryReporter(),
          logger: MockAppLogger(),
          sharedPreferences: MockSharedPreferences(),
        ),
      ),
      contentServiceProvider.overrideWith(
        (ref) => TestContentService(ref, _content),
      ),
    ],
  );
  return analytics;
}

void main() {
  testWidgets('Notify Me renders the de-emphasized coming-soon pattern, '
      'not a primary CTA', (tester) async {
    await pumpCard(tester);

    final secondary = tester.widget<KyleSecondaryButtonSmall>(
      find.byKey(_buttonKey),
    );
    expect(secondary.variant, SecondaryButtonVariant.light);
    expect(find.byType(KylePrimaryButton), findsNothing);
    expect(find.text(_content['learn.notify_me']!), findsOneWidget);
  });

  testWidgets('Notify Me records the interest once and says so; a second '
      'tap is inert (117-006)', (tester) async {
    final analytics = await pumpCard(tester);

    await tester.tap(find.byKey(_buttonKey));
    await tester.pump();

    expect(find.text(_content['learn.notify_me_confirm']!), findsOneWidget);
    expect(find.text(_content['learn.notify_me_noted']!), findsOneWidget);
    verify(
      () => analytics.track(
        ComingSoonSectionWidget.notifyEvent,
        properties: {'card': 'Premium Video Library'},
      ),
    ).called(1);

    // Noted: the button is disabled, so the second tap writes nothing.
    final button = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(_buttonKey),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);

    ScaffoldMessenger.of(tester.element(find.byKey(_buttonKey)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_buttonKey), warnIfMissed: false);
    await tester.pump();

    expect(find.text(_content['learn.notify_me_confirm']!), findsNothing);
    verifyNever(
      () => analytics.track(any(), properties: any(named: 'properties')),
    );
  });
}
