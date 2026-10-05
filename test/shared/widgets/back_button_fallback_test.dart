// Patch #4 regression (2026-10-04): a visible back control must never do
// NOTHING. When the navigation stack has nothing beneath the current route
// (a stackless deep-link arrival — witnessed on the nudge-tap create page
// 2026-10-01 and again 2026-10-03), CustomAppBarBackButton falls back to
// go('/') instead of silently ignoring the tap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';

GoRouter _router(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(
      path: '/',
      builder: (c, s) => const Scaffold(body: Text('HOME')),
    ),
    GoRoute(
      path: '/dead-end',
      builder: (c, s) => const Scaffold(
        appBar: null,
        body: Column(children: [CustomAppBarBackButton(), Text('DEAD END')]),
      ),
    ),
  ],
);

void main() {
  testWidgets('stackless arrival: back goes home instead of doing nothing', (
    tester,
  ) async {
    final router = _router('/dead-end');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('DEAD END'), findsOneWidget);

    await tester.tap(find.byType(CustomAppBarBackButton));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget, reason: 'fallback must go home');
  });

  testWidgets('normal stack: back still pops (no behavior change)', (
    tester,
  ) async {
    final router = _router('/');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/dead-end');
    await tester.pumpAndSettle();
    expect(find.text('DEAD END'), findsOneWidget);

    await tester.tap(find.byType(CustomAppBarBackButton));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget, reason: 'pop must still work');
  });
}
