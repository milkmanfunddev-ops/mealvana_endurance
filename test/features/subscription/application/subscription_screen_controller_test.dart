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
  });

  ProviderContainer container({
    required CustomerInfo info,
    bool storeSubscription = true,
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
    expect(s.canUpgrade, isFalse);
  });

  test('active: the plan with the day it renews', () async {
    final s = await read(container(info: customerInfoOpen));
    expect(s.plan, PlanStatus.active);
    expect(s.date, DateTime.utc(2026, 11, 1, 10));
    expect(s.willRenew, isTrue);
    expect(s.canUpgrade, isFalse);
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
    expect(s.canUpgrade, isFalse);
  });

  test('ended: the day it ended, and Upgrade', () async {
    final s = await read(container(info: customerInfoLapsed));
    expect(s.plan, PlanStatus.ended);
    expect(s.date, DateTime.utc(2026, 9, 1, 10));
    expect(s.canUpgrade, isTrue);
  });

  test('no plan on record reads as ended, with no date', () async {
    final s = await read(
      container(info: customerInfoNever, storeSubscription: false),
    );
    expect(s.plan, PlanStatus.ended);
    expect(s.date, isNull);
    expect(s.canUpgrade, isTrue);
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
    test('the Legacy grace month: its source and days left, no Manage, '
        'no Upgrade', () async {
      final s = await read(
        container(info: customerInfoGraceGrant, storeSubscription: false),
      );
      expect(s.plan, PlanStatus.grant);
      expect(s.grantSource, GrantSource.legacyGrace);
      expect(s.daysLeft, 12);
      expect(s.date, DateTime.utc(2026, 10, 31, 10));
      expect(s.canManage, isFalse);
      expect(s.canUpgrade, isFalse);
    });

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

  test('a status RevenueCat pushes (a purchase from Upgrade) '
      'replaces ended with active', () async {
    final c = container(info: customerInfoLapsed);
    expect((await read(c)).plan, PlanStatus.ended);

    pushStatus!(statusOf(customerInfoOpen));
    await Future<void>.delayed(Duration.zero);

    final s = await read(c);
    expect(s.plan, PlanStatus.active);
    expect(s.canUpgrade, isFalse);
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
}
