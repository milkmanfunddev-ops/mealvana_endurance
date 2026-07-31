import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/core/guarded_navigation.dart';

/// Pins the duplicate-push guard.
///
/// The bug this exists for: while the main isolate is stalled, taps queue
/// instead of being dropped. When it thaws, every queued `onTap` runs
/// back-to-back and each one pushes a route — observed as ~10 stacked Settings
/// pages from one unresponsive dashboard.
void main() {
  setUp(resetPushGuardForTest);

  /// A two-route app whose home fires [taps] pushes to /settings in a single
  /// synchronous burst — the flush pattern, not a user tapping deliberately.
  Widget appThatPushes(int taps, {required VoidCallback onBuilt}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            return TextButton(
              key: const ValueKey('go'),
              onPressed: () {
                for (var i = 0; i < taps; i++) {
                  context.pushOnce('/settings');
                }
                onBuilt();
              },
              child: const Text('go'),
            );
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const Scaffold(body: Text('settings')),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('a burst of identical pushes yields exactly one route', (
    tester,
  ) async {
    var fired = false;
    await tester.pumpWidget(appThatPushes(10, onBuilt: () => fired = true));

    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pumpAndSettle();

    expect(fired, isTrue, reason: 'precondition: the burst actually ran');
    expect(
      find.text('settings'),
      findsOneWidget,
      reason: '10 queued taps must not become 10 stacked routes',
    );
  });

  test('the same destination is suppressed until it renders', () {
    expect(shouldSuppressPushForTest('/settings'), isFalse);
    expect(shouldSuppressPushForTest('/settings'), isTrue);
    expect(shouldSuppressPushForTest('/settings'), isTrue);
  });

  test('a different destination is never suppressed by a previous one', () {
    expect(shouldSuppressPushForTest('/settings'), isFalse);
    expect(
      shouldSuppressPushForTest('/add-activity'),
      isFalse,
      reason: 'the guard is per-destination, not a global nav lock',
    );
    expect(
      shouldSuppressPushForTest('/settings'),
      isTrue,
      reason: 'settings remains guarded until its own first frame',
    );
  });

  test('a destination unlocks after its first frame', () {
    expect(shouldSuppressPushForTest('/settings'), isFalse);
    completePushForTest('/settings');
    expect(shouldSuppressPushForTest('/settings'), isFalse);
  });

  test('a fresh guard suppresses nothing', () {
    resetPushGuardForTest();
    expect(shouldSuppressPushForTest('/settings'), isFalse);
  });
}
