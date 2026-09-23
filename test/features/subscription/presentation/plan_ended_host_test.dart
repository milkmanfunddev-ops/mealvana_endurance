/// The host over the router (until ticket 20 deletes it): there is no
/// read-only shell and no plan-ended bar any more (mp-457, mp-611), so a
/// closed account meets the full-screen paywall and nothing else, and a
/// controller's refused write lands on that same paywall. Driven by
/// producer-shaped customer info through the REAL status notifier and gate,
/// the router wired the way app_router.dart wires it, and the host composed
/// the way root_app_widget.dart composes it.
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
    final sub = c.listen(appGateProvider, (prev, next) {
      if (!next.hasValue || next.isLoading) return;
      if (prev?.value == next.value) return;
      refresh.notifyListeners();
    });
    addTearDown(sub.close);

    Widget page(String label) => Scaffold(body: Center(child: Text(label)));
    final router = GoRouter(
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

  /// The paywall alone: nothing under it, no bar over it.
  void onlyThePaywall(GoRouter router) {
    expect(find.text('paywall'), findsOneWidget);
    expect(router.canPop(), isFalse);
    expect(find.byType(PlanEndedBar), findsNothing);
  }

  testWidgets('lapsed: the paywall and nothing else, no bar', (tester) async {
    when(
      () => service.fetchStatus(),
    ).thenAnswer((_) async => statusOf(customerInfoLapsed));
    final router = await pump(tester, initial: '/settings');
    onlyThePaywall(router);
    expect(find.text('settings'), findsNothing);
  });

  testWidgets('never: the paywall and nothing else, no bar', (tester) async {
    when(
      () => service.fetchStatus(),
    ).thenAnswer((_) async => statusOf(customerInfoNever));
    final router = await pump(tester, initial: '/main');
    onlyThePaywall(router);
    expect(find.text('main'), findsNothing);
  });

  testWidgets('an expiry mid-session lands on the paywall, no bar', (
    tester,
  ) async {
    when(
      () => service.fetchStatus(),
    ).thenAnswer((_) async => statusOf(customerInfoOpen));
    final router = await pump(tester, initial: '/settings');
    expect(find.text('settings'), findsOneWidget);

    capturedListener!(statusOf(customerInfoLapsed));
    await tester.pumpAndSettle();

    onlyThePaywall(router);
    expect(find.text('settings'), findsNothing);
  });

  testWidgets('a refused write lands on the one paywall, however many ask', (
    tester,
  ) async {
    when(
      () => service.fetchStatus(),
    ).thenAnswer((_) async => statusOf(customerInfoLapsed));
    final router = await pump(tester, initial: '/settings');
    final c = ProviderScope.containerOf(tester.element(find.text('paywall')));

    c.read(paywallRequestsProvider.notifier).request();
    await tester.pumpAndSettle();
    c.read(paywallRequestsProvider.notifier).request();
    await tester.pumpAndSettle();
    onlyThePaywall(router);
  });

  testWidgets('subscribing from the paywall lands on /main', (tester) async {
    when(
      () => service.fetchStatus(),
    ).thenAnswer((_) async => statusOf(customerInfoLapsed));
    await pump(tester, initial: '/settings');

    capturedListener!(statusOf(customerInfoOpen));
    await tester.pumpAndSettle();

    expect(find.text('main'), findsOneWidget);
    expect(find.byType(PlanEndedBar), findsNothing);
  });

  testWidgets('open: no bar', (tester) async {
    when(
      () => service.fetchStatus(),
    ).thenAnswer((_) async => statusOf(customerInfoOpen));
    await pump(tester, initial: '/main');
    expect(find.text('main'), findsOneWidget);
    expect(find.byType(PlanEndedBar), findsNothing);
  });
}
