/// Tests for the app-gate redirect — the pure rule, and the rule wired into
/// a GoRouter the way app_router.dart wires it, driven by the REAL status
/// notifier (docs/test/README.md: every controller path through the real
/// notifier) so the timeout-locks and cache-opens cases are proven end to
/// end, not against a stubbed boolean.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/subscription/application/pro_gate.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';
import 'package:mealvana_endurance/features/subscription/data/user_entitlements_repository.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/features/subscription/presentation/pro_gate_redirect.dart';

class _MockSubscriptionService extends Mock implements SubscriptionService {}

class _MockRepository extends Mock implements UserEntitlementsRepository {}

const _userId = 'u-1';
const _active = SubscriptionStatus(
  active: true,
  source: SubscriptionSource.revenuecat,
);

void main() {
  group('isUngatedPath', () {
    test('startup, upgrade, consent and the public flows are ungated', () {
      for (final p in [
        '/',
        '/force-upgrade',
        '/privacy-consent',
        '/welcome',
        '/onboarding',
        '/onboarding/x',
        '/auth/post-onboarding',
        '/auth/email-login',
      ]) {
        expect(isUngatedPath(p), isTrue, reason: p);
      }
    });

    test('every app route is gated — including look-alike prefixes', () {
      for (final p in [
        '/main',
        '/paywall',
        '/settings',
        '/food',
        '/food/plan',
        '/vana',
        '/buy-credits',
        '/coach-portal',
        '/events',
        '/welcomes',
        '/authors',
        '/onboardings',
      ]) {
        expect(isUngatedPath(p), isFalse, reason: p);
      }
    });
  });

  group('gateRedirect', () {
    test('locked: every app route lands on the paywall', () {
      for (final p in ['/main', '/settings', '/food/plan', '/coach-portal']) {
        expect(gateRedirect(path: p, unlocked: false), kPaywallPath, reason: p);
      }
    });

    test('locked: the paywall renders (no loop)', () {
      expect(gateRedirect(path: kPaywallPath, unlocked: false), isNull);
    });

    test('unlocked: app routes render, the paywall yields to /main', () {
      expect(gateRedirect(path: '/main', unlocked: true), isNull);
      expect(gateRedirect(path: '/settings', unlocked: true), isNull);
      expect(gateRedirect(path: kPaywallPath, unlocked: true), '/main');
    });

    test('ungated routes are never redirected either way', () {
      for (final p in ['/welcome', '/onboarding', '/auth/email-login', '/']) {
        expect(gateRedirect(path: p, unlocked: false), isNull, reason: p);
        expect(gateRedirect(path: p, unlocked: true), isNull, reason: p);
      }
    });

    test('kPaywallPath is /paywall', () {
      expect(kPaywallPath, '/paywall');
    });
  });

  group('wired into GoRouter through the real notifier', () {
    late _MockSubscriptionService service;
    late _MockRepository repo;
    void Function(SubscriptionStatus)? capturedListener;

    setUp(() {
      service = _MockSubscriptionService();
      repo = _MockRepository();
      capturedListener = null;
      when(() => repo.currentUserId).thenReturn(_userId);
      when(
        () => repo.authUserIdChanges,
      ).thenAnswer((_) => const Stream<String?>.empty());
      when(() => service.setStatusListener(any())).thenAnswer((inv) {
        capturedListener =
            inv.positionalArguments.first
                as void Function(SubscriptionStatus)?;
      });
      when(() => service.currentAppUserId()).thenAnswer((_) async => _userId);
      when(() => service.logIn(any())).thenAnswer((_) async {});
    });

    /// Mirrors the app_router.dart branch: session present, the gate read
    /// through [readAppGate], the rule applied by [gateRedirect]. The router
    /// re-evaluates when the gate flips, as the app's does. The root widget
    /// WATCHES the router provider (root_app_widget.dart), which is what
    /// keeps its `ref.listen` on the gate active under Riverpod 3's lazy
    /// rebuilds — the pump below does the same.
    Provider<GoRouter> routerProvider(String initial) {
      return Provider<GoRouter>((ref) {
        final refresh = ChangeNotifier();
        ref.listen(appGateProvider, (prev, next) {
          if (next.hasValue && !next.isLoading) refresh.notifyListeners();
        });
        Widget page(String label) => Scaffold(body: Text(label));
        return GoRouter(
          initialLocation: initial,
          refreshListenable: refresh,
          redirect: (context, state) async {
            final path = state.uri.path;
            if (path == '/') return '/main';
            if (isUngatedPath(path)) return null;
            final unlocked = await readAppGate(ref);
            return gateRedirect(path: path, unlocked: unlocked);
          },
          routes: [
            GoRoute(path: '/', builder: (_, _) => page('root')),
            GoRoute(path: '/main', builder: (_, _) => page('main')),
            GoRoute(path: '/settings', builder: (_, _) => page('settings')),
            GoRoute(path: '/food/plan', builder: (_, _) => page('food plan')),
            GoRoute(path: kPaywallPath, builder: (_, _) => page('paywall')),
            GoRoute(path: '/welcome', builder: (_, _) => page('welcome')),
          ],
        );
      });
    }

    Future<void> pump(
      WidgetTester tester, {
      required String initial,
      Duration timeout = const Duration(milliseconds: 60),
    }) async {
      final c = ProviderContainer(
        overrides: [
          subscriptionServiceProvider.overrideWithValue(service),
          userEntitlementsRepositoryProvider.overrideWithValue(repo),
          entitlementAnswerTimeoutProvider.overrideWithValue(timeout),
        ],
      );
      addTearDown(c.dispose);
      final router = routerProvider(initial);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: Consumer(
            builder: (_, ref, _) =>
                MaterialApp.router(routerConfig: ref.watch(router)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a cached entitlement opens the app', (tester) async {
      when(() => service.fetchStatus()).thenAnswer((_) async => _active);
      await pump(tester, initial: '/');
      expect(find.text('main'), findsOneWidget);
      expect(find.text('paywall'), findsNothing);
    });

    testWidgets('no cache and no answer within the timeout lands on the '
        'paywall, and nothing renders behind it', (tester) async {
      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) => Completer<SubscriptionStatus?>().future);
      await pump(tester, initial: '/food/plan');
      expect(find.text('paywall'), findsOneWidget);
      expect(find.text('food plan'), findsNothing);
      expect(find.text('main'), findsNothing);
    });

    testWidgets('a later refresh reopens: the push moves the paywall to /main',
        (tester) async {
      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) async => SubscriptionStatus.none);
      await pump(tester, initial: '/settings');
      expect(find.text('paywall'), findsOneWidget);

      capturedListener!(_active);
      await tester.pumpAndSettle();

      expect(find.text('main'), findsOneWidget);
      expect(find.text('paywall'), findsNothing);
    });

    testWidgets('an expiry mid-session closes the app onto the paywall',
        (tester) async {
      when(() => service.fetchStatus()).thenAnswer((_) async => _active);
      await pump(tester, initial: '/settings');
      expect(find.text('settings'), findsOneWidget);

      capturedListener!(SubscriptionStatus.none);
      await tester.pumpAndSettle();

      expect(find.text('paywall'), findsOneWidget);
      expect(find.text('settings'), findsNothing);
    });

    testWidgets('ungated routes render while locked', (tester) async {
      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) async => SubscriptionStatus.none);
      await pump(tester, initial: '/welcome');
      expect(find.text('welcome'), findsOneWidget);
    });
  });
}
