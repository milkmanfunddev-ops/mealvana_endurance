/// The Welcome screen shows the sign-out line once (ticket 102, Finding
/// 86-007): after an offline sign-out the athlete reads that their unsynced
/// changes stay on this phone, then the line is taken so it never repeats.
/// It sits above the buttons, never over them (testing-wave 120-006): a tap
/// takes it, and so does leaving the screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:mealvana_endurance/features/settings/application/sign_out_notice.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../helpers/widget_test_harness.dart';

const _line = 'Your unsynced changes stay on this phone.';

void main() {
  testWidgets('shows the pending sign-out line once', (tester) async {
    final container = ProviderContainer(
      overrides: [
        mockAppExternalDeps(),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        mockSharedPreferences(),
      ],
    );
    addTearDown(container.dispose);
    container.read(signOutNoticeProvider.notifier).set(_line);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    final line = find.byKey(const ValueKey('welcome.sign_out_notice'));
    expect(find.text(_line), findsOneWidget);
    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'inline, not over the buttons',
    );
    // Above "I already have an account", not on top of it.
    final lineBottom = tester.getBottomLeft(line).dy;
    final loginTop = tester
        .getTopLeft(find.byKey(const ValueKey('welcome.log_in_button')))
        .dy;
    expect(lineBottom, lessThanOrEqualTo(loginTop));
    expect(
      tester.getTopLeft(line).dy,
      greaterThan(
        tester
            .getBottomLeft(
              find.byKey(const ValueKey('welcome.get_started_button')),
            )
            .dy,
      ),
    );

    // A tap takes it.
    await tester.tap(line);
    await tester.pump();
    expect(find.text(_line), findsNothing);
    expect(container.read(signOutNoticeProvider), isNull, reason: 'shown once');
  });

  testWidgets('shows nothing when no sign-out left a line', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          mockSharedPreferences(),
        ],
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });
}
