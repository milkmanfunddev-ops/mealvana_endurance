// Ticket 28 (Finding 01-011): the dev launch-trail dialog shows once per
// process, however many resumes follow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/launch_trail.dart';
import 'package:mealvana_endurance/shared/widgets/root_app_widget.dart';

import '../../helpers/fakes/recording_report.dart';

void main() {
  setUp(LaunchTrail.debugReset);

  testWidgets('two resumes with notification evidence show one dialog', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final report = RecordingReport();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
    );

    LaunchTrail.add(
      'launchDetails didNotificationLaunchApp=false payload=null',
    );
    LaunchTrail.add('routing id=act_123 type=reminder');

    for (var i = 0; i < 2; i++) {
      LaunchTrail.add('app resumed');
      showLaunchTrailDialogOnce(navigatorKey.currentContext, report);
      await tester.pumpAndSettle();
    }

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      report.calls.where((c) => (c.message ?? '').contains('already shown')),
      hasLength(1),
    );
    expect(LaunchTrail.text, contains('trail dialog skipped'));
  });

  testWidgets('an ordinary launch shows no dialog', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
    );

    LaunchTrail.add(
      'launchDetails didNotificationLaunchApp=false payload=null',
    );
    LaunchTrail.add('app resumed');
    showLaunchTrailDialogOnce(navigatorKey.currentContext, RecordingReport());
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(LaunchTrail.dialogShown, isFalse);
  });
}
