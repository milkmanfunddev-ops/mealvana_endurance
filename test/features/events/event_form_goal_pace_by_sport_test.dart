// Claudia bug (2026-08-27, ticketed 2026-09-15): the event form asked every
// event type for a RUNNING pace ("Goal Pace (per mile)" min/sec) — including
// cycling, where a rider means mph. The wrong unit was stored as min/mile and
// followed the athlete into the fuel plan. Cycling now shows "Goal Speed
// (mph)"; storage stays goalPaceMinutesPerMile (min/mile = 60 / mph, Option A).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/events/presentation/screens/event_form_screen.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  Event event(ActivityType type, {double? pace}) => Event(
    id: 'e1',
    userId: 'u1',
    eventType: type,
    goalPaceMinutesPerMile: pace,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );

  Future<void> pump(WidgetTester tester, Event e) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => EventFormScreen(event: e),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    // Goal Time / Pace live inside a collapsed "Additional Details" tile that
    // builds its children lazily — expand it before asserting on them.
    await tester.tap(find.text('Additional Details (Optional)'));
    await tester.pumpAndSettle();
  }

  testWidgets('running event shows the run-pace field (per mile)', (
    tester,
  ) async {
    await pump(tester, event(ActivityType.running, pace: 8.5));
    expect(find.text('Goal Pace (per mile)'), findsOneWidget);
    expect(find.text('Goal Speed (mph)'), findsNothing);
    expect(find.text('Minutes'), findsWidgets);
    expect(find.text('Seconds'), findsWidgets);
  });

  testWidgets('cycling event shows a Goal Speed (mph) field, not run pace', (
    tester,
  ) async {
    // 3.0 min/mile stored == 20.0 mph shown (60 / 3).
    await pump(tester, event(ActivityType.cycling, pace: 3.0));
    expect(find.text('Goal Speed (mph)'), findsOneWidget);
    expect(
      find.text('Goal Pace (per mile)'),
      findsNothing,
      reason: 'a cyclist must never be asked for a run pace',
    );
    // The stored min/mile is shown back as its reciprocal speed.
    expect(find.widgetWithText(TextFormField, '20.0'), findsOneWidget);
  });
}
