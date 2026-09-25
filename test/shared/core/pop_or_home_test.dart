// Stranding audit 2026-09-23: a back button on a page with nothing under it
// did nothing, and the activity routes showed a dead "Missing activity ID"
// page when their `extra` was lost.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mealvana_endurance/shared/core/app_router.dart';
import 'package:mealvana_endurance/shared/core/pop_or_home.dart';

Widget _page(String name) => Builder(
  builder: (context) => Scaffold(
    body: Center(
      child: TextButton(onPressed: context.popOrHome, child: Text(name)),
    ),
  ),
);

GoRouter _router(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(path: '/main', builder: (_, _) => _page('main')),
    GoRoute(path: '/vana', builder: (_, _) => _page('vana')),
    GoRoute(
      path: '/plan',
      redirect: homeWithoutActivityId,
      builder: (_, _) => _page('plan'),
    ),
  ],
);

String _location(GoRouter r) =>
    r.routerDelegate.currentConfiguration.uri.toString();

void main() {
  testWidgets('back on the only page goes home instead of doing nothing', (
    tester,
  ) async {
    final router = _router('/vana');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('vana'));
    await tester.pumpAndSettle();
    expect(_location(router), '/main');
  });

  testWidgets('back on a pushed page still pops', (tester) async {
    final router = _router('/main');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/vana');
    await tester.pumpAndSettle();
    await tester.tap(find.text('vana'));
    await tester.pumpAndSettle();
    expect(find.text('main'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('an activity route with no activity id goes home', (
    tester,
  ) async {
    final router = _router('/main');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/plan');
    await tester.pumpAndSettle();
    expect(_location(router), '/main');

    router.go('/plan', extra: {'activityId': 'a-1'});
    await tester.pumpAndSettle();
    expect(find.text('plan'), findsOneWidget);
  });
}
