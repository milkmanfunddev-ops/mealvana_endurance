/// The Subscription screen's controller (mp-495 §2, §3), driven through the
/// REAL status notifier by producer-shaped customer info
/// (`customer_info_fixtures.dart`, docs/test/README.md Seam tests): which of
/// trial, active, founding member or ended the plan is, the date that goes
/// with it, and whether Upgrade and Manage subscription belong on the screen;
/// a Grant with where it came from and its days left (mp-558).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:mealvana_endurance/features/subscription/application/subscription_screen_controller.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';
import 'package:mealvana_endurance/features/subscription/data/user_entitlements_repository.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/features/subscription/domain/grant.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';

import '../customer_info_fixtures.dart';

class _MockSubscriptionService extends Mock implements SubscriptionService {}

class _MockRepository extends Mock implements UserEntitlementsRepository {}

class _NoopScheduler implements LocalNotificationScheduler {
  @override
  Future<bool> scheduleOnce({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async => true;

  @override
  Future<void> cancel(int id) async {}
}

const _userId = 'u-1';

/// 19 October 2026, midday UTC: the day mp-558's example opens Settings.
final _today = DateTime.utc(2026, 10, 19, 12);

void main() {
  late _MockSubscriptionService service;
  late _MockRepository repo;
  void Function(SubscriptionStatus)? pushStatus;

  setUp(() {
    service = _MockSubscriptionService();
    repo = _MockRepository();
    pushStatus = null;
    when(() => repo.currentUserId).thenReturn(_userId);
    when(
      () => repo.authUserIdChanges,
    ).thenAnswer((_) => const Stream<String?>.empty());
    when(() => service.setStatusListener(any())).thenAnswer((inv) {
      pushStatus =
          inv.positionalArguments.first as void Function(SubscriptionStatus)?;
    });
    when(() => service.currentAppUserId()).thenAnswer((_) async => _userId);
    when(() => service.logIn(any())).thenAnswer((_) async {});
    when(() => service.forgetCachedStatus()).thenAnswer((_) async {});
  });

  ProviderContainer container({
    required CustomerInfo info,
    bool storeSubscription = true,
    bool keepOpen = true,
  }) {
    when(() => service.fetchStatus()).thenAnswer((_) async => statusOf(info));
    when(
      () => service.hasStoreSubscriptionOnRecord(),
    ).thenAnswer((_) async => storeSubscription);
    final c = ProviderContainer(
      overrides: [
        subscriptionServiceProvider.overrideWithValue(service),
        userEntitlementsRepositoryProvider.overrideWithValue(repo),
        entitlementAnswerTimeoutProvider.overrideWithValue(
          const Duration(milliseconds: 60),
        ),
        localNotificationSchedulerProvider.overrideWithValue(_NoopScheduler()),
        subscriptionScreenClockProvider.overrideWithValue(() => _today),
        subscriptionClockProvider.overrideWithValue(
          () => customerInfoFetchedAt,
        ),
      ],
    );
    addTearDown(c.dispose);
    if (!keepOpen) return c;
    // Keep the auto-dispose controller alive between reads.
    final sub = c.listen(subscriptionScreenControllerProvider, (_, _) {});
    addTearDown(sub.close);
    return c;
  }

  Future<SubscriptionScreenState> read(ProviderContainer c) =>
      c.read(subscriptionScreenControllerProvider.future);

  test('trial: the free week with the day it ends', () async {
    final s = await read(container(info: customerInfoTrial));
    expect(s.plan, PlanStatus.trial);
    expect(s.date, DateTime.utc(2026, 9, 29, 10));
    expect(s.willRenew, isTrue);
  });

  test('active: the plan with the day it renews', () async {
    final s = await read(container(info: customerInfoOpen));
    expect(s.plan, PlanStatus.active);
    expect(s.date, DateTime.utc(2026, 11, 1, 10));
    expect(s.willRenew, isTrue);
  });

  test('active but cancelled: it will not renew', () async {
    final s = await read(container(info: customerInfoOpenCancelled));
    expect(s.plan, PlanStatus.active);
    expect(s.willRenew, isFalse);
  });

  test('founding: a founding product is a founding member', () async {
    final s = await read(container(info: customerInfoFounding));
    expect(s.plan, PlanStatus.founding);
    expect(s.date, DateTime.utc(2027, 10, 1, 10));
  });

  // 87-008: no ended state. A lapsed athlete stays on the paywall
  // (mp-457); only an Admin, open without Pro, reaches the screen with no
  // plan running, and the screen names none.
  test('a plan that ended names no plan and no date, and keeps Manage '
      'for its store subscription (mp-558)', () async {
    final s = await read(container(info: customerInfoLapsed));
    expect(s.plan, isNull);
    expect(s.date, isNull);
    expect(s.term, isNull);
    expect(s.canManage, isTrue);
  });

  test('no plan on record names no plan, no date and no Manage', () async {
    final s = await read(
      container(info: customerInfoNever, storeSubscription: false),
    );
    expect(s.plan, isNull);
    expect(s.date, isNull);
    expect(s.canManage, isFalse);
  });

  test('Manage only with a store subscription on record', () async {
    expect((await read(container(info: customerInfoOpen))).canManage, isTrue);
    expect(
      (await read(
        container(info: customerInfoGranted, storeSubscription: false),
      )).canManage,
      isFalse,
    );
  });

  group('a Grant (mp-558)', () {
    test(
      'the Legacy grace month: its source and days left, no Manage',
      () async {
        final s = await read(
          container(info: customerInfoGraceGrant, storeSubscription: false),
        );
        expect(s.plan, PlanStatus.grant);
        expect(s.grantSource, GrantSource.legacyGrace);
        expect(s.daysLeft, 12);
        expect(s.date, DateTime.utc(2026, 10, 31, 10));
        expect(s.canManage, isFalse);
      },
    );

    test('a Code: 365 days read as a Code, with its days left', () async {
      final s = await read(
        container(info: customerInfoGranted, storeSubscription: false),
      );
      expect(s.plan, PlanStatus.grant);
      expect(s.grantSource, GrantSource.code);
      expect(s.daysLeft, 338); // 19 October 2026 to 22 September 2027
      expect(s.canManage, isFalse);
    });

    test('a store subscription is no Grant', () async {
      final s = await read(container(info: customerInfoOpen));
      expect(s.plan, PlanStatus.active);
      expect(s.grantSource, isNull);
      expect(s.daysLeft, isNull);
      expect(s.canManage, isTrue);
    });
  });

  group('the plan bought, Monthly or Annual (mp-628, finding 08-001)', () {
    test('a monthly subscription is Monthly', () async {
      final s = await read(container(info: customerInfoOpen));
      expect(s.term, PlanTerm.monthly);
    });

    test('a trial names the plan it starts', () async {
      final s = await read(container(info: customerInfoTrial));
      expect(s.term, PlanTerm.monthly);
    });

    test('a founding annual product is Annual', () async {
      final s = await read(container(info: customerInfoFounding));
      expect(s.term, PlanTerm.annual);
    });

    test('an ended plan and a Grant name no plan', () async {
      expect((await read(container(info: customerInfoLapsed))).term, isNull);
      expect(
        (await read(
          container(info: customerInfoGranted, storeSubscription: false),
        )).term,
        isNull,
      );
    });

    test('the term is read from the store SKU', () {
      expect(
        SubscriptionScreenState.termOf('mealvana_pro_monthly'),
        PlanTerm.monthly,
      );
      expect(
        SubscriptionScreenState.termOf('me_pro_annual_prod'),
        PlanTerm.annual,
      );
      // Google Play reports `product:base-plan`.
      expect(
        SubscriptionScreenState.termOf('me_pro_monthly:monthly'),
        PlanTerm.monthly,
      );
      expect(SubscriptionScreenState.termOf('prod350601b768'), isNull);
      expect(SubscriptionScreenState.termOf(null), isNull);
    });
  });

  test('a status RevenueCat pushes (a Code redeemed on the screen) '
      'replaces the plan shown', () async {
    final c = container(info: customerInfoOpen);
    expect((await read(c)).plan, PlanStatus.active);

    pushStatus!(statusOf(customerInfoGranted));
    await Future<void>.delayed(Duration.zero);

    final s = await read(c);
    expect(s.plan, PlanStatus.grant);
  });

  test('managementUrl is the service\'s, as the paywall\'s Manage', () async {
    final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
    when(() => service.managementUrl()).thenAnswer((_) async => uri);
    final c = container(info: customerInfoOpen);
    await read(c);
    expect(
      await c
          .read(subscriptionScreenControllerProvider.notifier)
          .managementUrl(),
      uri,
    );
  });

  group('the screen asks RevenueCat each time it opens (ticket 105, '
      'Finding 87-006)', () {
    /// Whether the SDK's saved copy has been dropped, so the next fetch
    /// reaches RevenueCat itself.
    late bool asked;

    ProviderContainer opened({
      required CustomerInfo saved,
      required Future<SubscriptionStatus?> Function() revenueCat,
      bool keepOpen = true,
    }) {
      asked = false;
      final c = container(info: saved, keepOpen: keepOpen);
      when(() => service.forgetCachedStatus()).thenAnswer((_) async {
        asked = true;
      });
      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) => asked ? revenueCat() : Future.value(statusOf(saved)));
      return c;
    }

    test(
      'a plan in its last period reads "Ends on", not "Renews on"',
      () async {
        // The saved copy was fetched before the athlete cancelled; RevenueCat
        // knows it will not renew.
        final c = opened(
          saved: customerInfoOpen,
          revenueCat: () async => statusOf(customerInfoOpenCancelled),
        );
        final s = await read(c);
        expect(asked, isTrue);
        expect(s.plan, PlanStatus.active);
        expect(s.date, DateTime.utc(2026, 11, 1, 10));
        // The screen's date line: willRenew false is "Ends on {date}. It
        // won't renew." (ContentKeys.subscriptionEnds).
        expect(s.willRenew, isFalse);
      },
    );

    test('each open asks again; a status change while open does not', () async {
      final c = opened(
        saved: customerInfoOpen,
        revenueCat: () async => statusOf(customerInfoOpen),
        keepOpen: false,
      );
      Future<void> openAndClose(Future<void> Function() whileOpen) async {
        final sub = c.listen(subscriptionScreenControllerProvider, (_, _) {});
        await read(c);
        await whileOpen();
        sub.close();
        // The auto-dispose providers go with the screen.
        await Future<void>.delayed(Duration.zero);
      }

      await openAndClose(() async {
        // RevenueCat pushes a change while the screen is open: the screen
        // follows it without asking again.
        pushStatus!(statusOf(customerInfoOpenCancelled));
        await Future<void>.delayed(Duration.zero);
        expect((await read(c)).willRenew, isFalse);
      });
      verify(() => service.forgetCachedStatus()).called(1);

      await openAndClose(() async {});
      verify(() => service.forgetCachedStatus()).called(1);
    });

    test('offline, the screen shows the saved copy rather than an ended '
        'plan', () async {
      final c = opened(saved: customerInfoOpen, revenueCat: () async => null);
      final s = await read(c);
      expect(s.plan, PlanStatus.active);
      expect(s.willRenew, isTrue);
    });
  });
}
