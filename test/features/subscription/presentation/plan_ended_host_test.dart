/// The read-only shell (mp-457 §3): a lapsed account reaches app routes with
/// the plan-ended bar over every screen, its Subscribe opens the paywall
/// over the screen, and the bar leaves when the account subscribes. Driven
/// by producer-shaped customer info through the REAL status notifier and
/// gate, the router wired the way app_router.dart wires it, and the host
/// composed the way root_app_widget.dart composes it.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/subscription/application/pro_gate.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/application/write_guard.dart';
import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';
import 'package:mealvana_endurance/features/subscription/data/user_entitlements_repository.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/features/subscription/presentation/plan_ended_host.dart';
import 'package:mealvana_endurance/features/subscription/presentation/pro_gate_redirect.dart';
import 'package:mealvana_endurance/shared/providers/is_admin_provider.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/feedback/plan_ended_bar.dart';

import '../../meal_planning/presentation/helpers/test_content.dart';
import '../customer_info_fixtures.dart';

class _MockSubscriptionService extends Mock implements SubscriptionService {}

class _MockRepository extends Mock implements UserEntitlementsRepository {}

const _userId = 'u-1';
const _subscribe = ValueKey('plan_ended_bar.subscribe');

final _content = loadDefaultContent();

void main() {
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
          inv.positionalArguments.first as void Function(SubscriptionStatus)?;
    });
    when(() => service.currentAppUserId()).thenAnswer((_) async => _userId);
    when(() => service.logIn(any())).thenAnswer((_) async {});
  });

  Future<GoRouter> pump(WidgetTester tester, {required String initial}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = ProviderContainer(
      overrides: [
        subscriptionServiceProvider.overrideWithValue(service),
        userEntitlementsRepositoryProvider.overrideWithValue(repo),
        entitlementAnswerTimeoutProvider.overrideWithValue(
          const Duration(milliseconds: 60),
        ),
        isAdminProvider.overrideWith((_) async => false),
        contentServiceProvider.overrideWith(
          (ref) => TestContentService(ref, _content),
        ),
      ],
    );
    addTearDown(c.dispose);

    final refresh = ChangeNotifier();
    addTearDown(refresh.dispose);
    late final GoRouter router;
    final sub = c.listen(appGateProvider, (prev, next) {
      if (!next.hasValue || next.isLoading) return;
      if (prev?.value == next.value) return;
      refresh.notifyListeners();
      yieldPushedPaywall(router, next.value);
    });
    addTearDown(sub.close);

    Widget page(String label) => Scaffold(body: Center(child: Text(label)));
    router = GoRouter(
      initialLocation: initial,
      refreshListenable: refresh,
      redirect: (context, state) async {
        final path = state.uri.path;
        if (isUngatedPath(path)) return null;
        final access = await c.read(appGateProvider.future);
        return gateRedirect(path: path, access: access);
      },
      routes: [
        GoRoute(path: '/main', builder: (_, _) => page('main')),
        GoRoute(path: '/settings', builder: (_, _) => page('settings')),
        GoRoute(path: '/welcome', builder: (_, _) => page('welcome')),
        GoRoute(path: kPaywallPath, builder: (_, _) => page('paywall')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) =>
              PlanEndedHost(router: router, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('lapsed: app routes render under the bar, with its copy', (
    tester,
  ) async {
    when(
      () => service.fetchStatus(),
    ).thenAnswer((_) async => statusOf(customerInfoLapsed));
    final router = await pump(tester, initial: '/main');

    expect(find.text('main'), findsOneWidget);
    expect(find.byType(PlanEndedBar), findsOneWidget);
    expect(find.text(_content['plan_ended.message']!), findsOneWidget);
    expect(find.text(_content['plan_ended.subscribe_button']!), findsOneWidget);

    router.go('/settings');
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
    expect(find.byType(PlanEndedBar), findsOneWidget);
  });

  testWidgets('the page starts below the bar, never under it', (tester) async {
    when(
      () => service.fetchStatus(),
    ).thenAnswer((_) async => statusOf(customerInfoLapsed));
    await pump(tester, initial: '/main');

    final barBottom = tester.getBottomLeft(find.byType(PlanEndedBar)).dy;
    final pageTop = tester.getTopLeft(find.byType(Scaffold)).dy;
    expect(pageTop, barBottom);
  });

  testWidgets('Subscribe opens the paywall over the screen; the bar is not '
      'on the paywall; back returns to the screen under the bar', (
    tester,
  ) async {
    when(
      () => service.fetchStatus(),
    ).thenAnswer((_) async => statusOf(customerInfoLapsed));
    final router = await pump(tester, initial: '/settings');

    await tester.tap(find.byKey(_subscribe));
    await tester.pumpAndSettle();
    expect(find.text('paywall'), findsOneWidget);
    expect(find.byType(PlanEndedBar), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
    expect(find.byType(PlanEndedBar), findsOneWidget);
  });

  testWidgets('a refused write in a controller opens the paywall over the '
      'screen, once however many ask', (tester) async {
    when(
      () => service.fetchStatus(),
    ).thenAnswer((_) async => statusOf(customerInfoLapsed));
    final router = await pump(tester, initial: '/settings');
    final c = ProviderScope.containerOf(tester.element(find.text('settings')));

    c.read(paywallRequestsProvider.notifier).request();
    await tester.pumpAndSettle();
    c.read(paywallRequestsProvider.notifier).request();
    await tester.pumpAndSettle();
    expect(find.text('paywall'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
  });

  testWidgets('subscribing from the paywall removes the bar and lands on '
      '/main', (tester) async {
    when(
      () => service.fetchStatus(),
    ).thenAnswer((_) async => statusOf(customerInfoLapsed));
    await pump(tester, initial: '/settings');
    await tester.tap(find.byKey(_subscribe));
    await tester.pumpAndSettle();

    capturedListener!(statusOf(customerInfoOpen));
    await tester.pumpAndSettle();

    expect(find.text('main'), findsOneWidget);
    expect(find.byType(PlanEndedBar), findsNothing);
  });

  testWidgets('an expiry mid-session raises the bar over the same screen', (
    tester,
  ) async {
    when(
      () => service.fetchStatus(),
    ).thenAnswer((_) async => statusOf(customerInfoOpen));
    await pump(tester, initial: '/settings');
    expect(find.byType(PlanEndedBar), findsNothing);

    capturedListener!(statusOf(customerInfoLapsed));
    await tester.pumpAndSettle();

    expect(find.text('settings'), findsOneWidget);
    expect(find.byType(PlanEndedBar), findsOneWidget);
  });

  testWidgets('open: no bar', (tester) async {
    when(
      () => service.fetchStatus(),
    ).thenAnswer((_) async => statusOf(customerInfoOpen));
    await pump(tester, initial: '/main');
    expect(find.text('main'), findsOneWidget);
    expect(find.byType(PlanEndedBar), findsNothing);
  });

  testWidgets('never: the paywall and nothing else, no bar', (tester) async {
    when(
      () => service.fetchStatus(),
    ).thenAnswer((_) async => statusOf(customerInfoNever));
    await pump(tester, initial: '/main');
    expect(find.text('paywall'), findsOneWidget);
    expect(find.text('main'), findsNothing);
    expect(find.byType(PlanEndedBar), findsNothing);
  });

  testWidgets('lapsed: ungated routes carry no bar', (tester) async {
    when(
      () => service.fetchStatus(),
    ).thenAnswer((_) async => statusOf(customerInfoLapsed));
    await pump(tester, initial: '/welcome');
    expect(find.text('welcome'), findsOneWidget);
    expect(find.byType(PlanEndedBar), findsNothing);
  });

  group('planEndedBarShownOn', () {
    test('every signed-in route but the paywall', () {
      for (final p in ['/main', '/settings', '/food', '/events/e-1']) {
        expect(planEndedBarShownOn(p), isTrue, reason: p);
      }
      for (final p in [
        '',
        '/',
        kPaywallPath,
        '/welcome',
        '/auth/email-login',
      ]) {
        expect(planEndedBarShownOn(p), isFalse, reason: p);
      }
    });
  });
}
