// Finding 100-003 (Lee, 2026-09-26): tapping a provider-completed workout
// opens its activity detail, never Create New Activity Plan. Pinned at the
// one tap router every card uses, on a stub GoRouter.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/presentation/navigation/open_activity_fuel.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  final day = DateTime(2026, 9, 25, 19, 25);

  Activity swim({
    required ActivityStatus status,
    String? completionType,
    Map<String, dynamic>? plan,
  }) => Activity(
    id: 'fs-swim',
    userId: 'u1',
    activityType: ActivityType.swimming,
    title: 'Swim',
    scheduledDateTime: day,
    plannedTime: day,
    status: status,
    completionType: completionType,
    nutritionPlanData: plan,
    durationMinutes: 34,
    createdAt: day,
    updatedAt: day,
  );

  late String? landed;
  late Object? landedExtra;

  Future<void> tapCard(WidgetTester tester, Activity activity) async {
    landed = null;
    landedExtra = null;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => openActivityFuel(context, activity),
              child: const Text('card'),
            ),
          ),
        ),
        GoRoute(
          path: '/plan',
          builder: (context, state) {
            landed = '/plan';
            landedExtra = state.extra;
            return const Scaffold(body: Text('detail'));
          },
        ),
        GoRoute(
          path: '/distancepacegut',
          builder: (context, state) {
            landed = '/distancepacegut';
            landedExtra = state.extra;
            return const Scaffold(body: Text('form'));
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('card'));
    await tester.pumpAndSettle();
  }

  testWidgets('a provider-completed swim without a plan opens Detail', (
    tester,
  ) async {
    await tapCard(
      tester,
      swim(
        status: ActivityStatus.completed,
        completionType: Activity.providerCompletionType,
      ),
    );
    expect(landed, '/plan');
    expect(landedExtra, {'mode': 'view', 'activityId': 'fs-swim'});
  });

  testWidgets('an athlete-completed workout without a plan opens Detail', (
    tester,
  ) async {
    await tapCard(tester, swim(status: ActivityStatus.completed));
    expect(landed, '/plan');
  });

  testWidgets('a planned workout without a plan still opens the form', (
    tester,
  ) async {
    await tapCard(tester, swim(status: ActivityStatus.planned));
    expect(landed, '/distancepacegut');
    expect((landedExtra as Map)['activityId'], 'fs-swim');
  });

  testWidgets('a planned workout with a plan opens Detail', (tester) async {
    await tapCard(
      tester,
      swim(status: ActivityStatus.planned, plan: const {'sections': []}),
    );
    expect(landed, '/plan');
  });
}
