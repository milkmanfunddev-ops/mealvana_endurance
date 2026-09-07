import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/utils/post_create_navigation.dart';

/// Regression test for ops bug report
/// 2026-08-20-duplicate-activity-via-armed-back-stack.md
///
/// After Create Plan succeeded, the creation flow used to stay on the back
/// stack ARMED: back from the plan detail landed on Adjust Macros, back again
/// landed on the filled New Activity form with a live Generate button, and
/// re-firing inserted a second identical activity.
///
/// These tests pin the navigation contract at the seam the fix lives at
/// ([showPlanAfterSuccessfulCreate]), using stub screens on a real GoRouter
/// with the production stack shape:
///
///   /main -> push /distancepacegut -> push /adjust-macros -> create succeeds
///
/// The real AdjustMacrosScreen/NewActivityScreen are too provider-heavy to
/// mount here; the screens delegate their post-success navigation to this
/// helper, so pinning the helper pins the fix.
void main() {
  late int createCount;
  late Object? currentPlanExtra;

  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: '/main',
      routes: [
        GoRoute(
          path: '/main',
          builder: (context, state) => const _Stub(label: 'dashboard'),
        ),
        GoRoute(
          path: '/distancepacegut',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('new-activity-form'),
                TextButton(
                  // The armed Generate button: every press that reaches a
                  // "create" is counted, standing in for an inserted row.
                  onPressed: () {
                    createCount++;
                    GoRouter.of(context).push('/adjust-macros');
                  },
                  child: const Text('Generate Plan'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/adjust-macros',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => showPlanAfterSuccessfulCreate(
                context,
                activityId: 'activity-1',
              ),
              child: const Text('Create Plan'),
            ),
          ),
        ),
        GoRoute(
          path: '/current-plan',
          builder: (context, state) {
            currentPlanExtra = state.extra;
            return const _Stub(label: 'plan-detail');
          },
        ),
      ],
    );
  }

  setUp(() {
    createCount = 0;
    currentPlanExtra = null;
  });

  Future<GoRouter> pumpThroughSuccessfulCreate(WidgetTester tester) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    // Dashboard -> + Add Activity -> form -> Generate -> Create succeeds.
    router.push('/distancepacegut');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate Plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Plan'));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('successful create shows the plan detail with its extras', (
    tester,
  ) async {
    await pumpThroughSuccessfulCreate(tester);

    expect(find.text('plan-detail'), findsOneWidget);
    expect(createCount, 1);
    expect(currentPlanExtra, {
      'activityId': 'activity-1',
      'isNewActivity': true,
    });
  });

  testWidgets(
    'back from the new plan lands on the dashboard, not the armed form',
    (tester) async {
      final router = pumpThroughSuccessfulCreate(tester);
      final resolvedRouter = await router;

      // First back: must land on the dashboard...
      expect(resolvedRouter.canPop(), isTrue);
      resolvedRouter.pop();
      await tester.pumpAndSettle();
      expect(find.text('dashboard'), findsOneWidget);

      // ...with the spent creation flow gone from the stack: no adjust-macros
      // beneath the plan, no re-fireable Generate form beneath that.
      expect(find.text('Create Plan'), findsNothing);
      expect(find.text('new-activity-form'), findsNothing);
      expect(find.text('Generate Plan'), findsNothing);
      expect(resolvedRouter.canPop(), isFalse);

      // The single create is all that ever happened: the form cannot be
      // reached again with its unchanged inputs to fire a duplicate.
      expect(createCount, 1);
    },
  );

  testWidgets('template path forwards the fromTemplate flag', (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.push('/distancepacegut');
    await tester.pumpAndSettle();

    final formContext = tester.element(find.text('new-activity-form'));
    showPlanAfterSuccessfulCreate(
      formContext,
      activityId: 'activity-2',
      fromTemplate: true,
    );
    await tester.pumpAndSettle();

    expect(find.text('plan-detail'), findsOneWidget);
    expect(currentPlanExtra, {
      'activityId': 'activity-2',
      'isNewActivity': true,
      'fromTemplate': true,
    });

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('dashboard'), findsOneWidget);
    expect(find.text('new-activity-form'), findsNothing);
  });
}

class _Stub extends StatelessWidget {
  const _Stub({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(label));
}
