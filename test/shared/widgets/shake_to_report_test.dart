import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/shared/widgets/shake_to_report.dart';

import '../../features/meal_planning/presentation/helpers/test_content.dart';

void main() {
  late StreamController<void> shakes;
  late GlobalKey<NavigatorState> navKey;
  late List<String> events;
  late int reports;
  late ValueNotifier<bool> reportVisible;

  setUp(() {
    shakes = StreamController<void>.broadcast();
    navKey = GlobalKey<NavigatorState>();
    events = [];
    reports = 0;
    reportVisible = ValueNotifier(false);
  });

  tearDown(() => shakes.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: ShakeToReport(
          navigatorKey: navKey,
          shakeEvents: shakes.stream,
          reportVisible: reportVisible,
          onShakeDetected: events.add,
          onReport: (_) async => reports++,
          child: MaterialApp(
            navigatorKey: navKey,
            home: const Scaffold(body: Text('screen')),
          ),
        ),
      ),
    );
  }

  Future<void> shake(WidgetTester tester) async {
    shakes.add(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('shake prompts; confirm opens the report', (tester) async {
    await pump(tester);
    await shake(tester);

    expect(find.byKey(const ValueKey('shake_report.title')), findsOneWidget);
    expect(find.text('Report a problem?'), findsOneWidget);
    expect(reports, 0);

    await tester.tap(find.byKey(const ValueKey('shake_report.confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('shake_report.title')), findsNothing);
    expect(reports, 1);
    expect(events, ['shake_report_prompted', 'shake_report_confirmed']);
  });

  testWidgets('dismiss closes without reporting', (tester) async {
    await pump(tester);
    await shake(tester);
    await tester.tap(find.byKey(const ValueKey('shake_report.dismiss')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('shake_report.title')), findsNothing);
    expect(reports, 0);
    expect(events.last, 'shake_report_dismissed');
  });

  testWidgets('second shake while the sheet is open is ignored', (
    tester,
  ) async {
    await pump(tester);
    await shake(tester);
    await shake(tester);

    expect(find.byKey(const ValueKey('shake_report.title')), findsOneWidget);
    expect(events, ['shake_report_prompted']);
  });

  testWidgets('shake is ignored while the report tool is visible', (
    tester,
  ) async {
    await pump(tester);
    reportVisible.value = true;
    await shake(tester);

    expect(find.byKey(const ValueKey('shake_report.title')), findsNothing);
    expect(events, isEmpty);
  });

  testWidgets('cooldown swallows a shake right after dismissing', (
    tester,
  ) async {
    await pump(tester);
    await shake(tester);
    await tester.tap(find.byKey(const ValueKey('shake_report.dismiss')));
    await tester.pumpAndSettle();

    await shake(tester);
    expect(find.byKey(const ValueKey('shake_report.title')), findsNothing);
  });
}
