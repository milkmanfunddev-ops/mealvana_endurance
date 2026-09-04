/// Tests for the Pro-gate redirect rule — the pure helper, and the rule wired
/// into a GoRouter the way app_router.dart wires it (same inline-router shape
/// as test/shared/core/guarded_navigation_test.dart).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mealvana_endurance/features/subscription/presentation/pro_gate_redirect.dart';

void main() {
  group('isProGatedPath', () {
    test('food and vana subtrees are gated', () {
      for (final p in [
        '/food',
        '/food/plan',
        '/food/cook/abc',
        '/vana',
        '/vana/chat',
      ]) {
        expect(isProGatedPath(p), isTrue, reason: p);
      }
    });

    test('everything else is not — including look-alike prefixes', () {
      for (final p in [
        '/',
        '/main',
        '/pro',
        '/settings',
        '/foods',
        '/vanadium',
        '/buy-credits',
      ]) {
        expect(isProGatedPath(p), isFalse, reason: p);
      }
    });
  });

  group('proGateRedirect', () {
    test('locked + gated → /pro; otherwise null', () {
      expect(proGateRedirect(path: '/food/plan', unlocked: false), '/pro');
      expect(proGateRedirect(path: '/food/plan', unlocked: true), isNull);
      expect(proGateRedirect(path: '/settings', unlocked: false), isNull);
      expect(kProPaywallPath, '/pro');
    });
  });

  group('wired into GoRouter', () {
    /// Mirrors the app_router.dart branch: session present, gated path,
    /// [unlocked] decides.
    GoRouter routerWith({required bool unlocked, String initial = '/'}) {
      return GoRouter(
        initialLocation: initial,
        redirect: (context, state) {
          final path = state.uri.path;
          if (path != '/') {
            if (isProGatedPath(path) && !unlocked) return kProPaywallPath;
            return null;
          }
          return null;
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/pro',
            builder: (_, _) => const Scaffold(body: Text('paywall')),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) => const Scaffold(body: Text('settings')),
          ),
          // Phase 4 lands the real screens; a placeholder proves the guard
          // fires before the route is even built.
          GoRoute(
            path: '/food/plan',
            builder: (_, _) => const Scaffold(body: Text('food plan')),
          ),
        ],
      );
    }

    testWidgets('locked user deep-linking to /food/plan lands on the paywall', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: routerWith(unlocked: false, initial: '/food/plan'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('paywall'), findsOneWidget);
      expect(find.text('food plan'), findsNothing);
    });

    testWidgets('unlocked user reaches /food/plan', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: routerWith(unlocked: true, initial: '/food/plan'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('food plan'), findsOneWidget);
    });

    testWidgets('non-gated routes are untouched when locked', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: routerWith(unlocked: false, initial: '/settings'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('settings'), findsOneWidget);
    });

    testWidgets('the paywall itself never redirects (no loop)', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: routerWith(unlocked: false, initial: '/pro'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('paywall'), findsOneWidget);
    });
  });
}
