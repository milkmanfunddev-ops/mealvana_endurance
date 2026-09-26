/// Widget tests and goldens for [SubscriptionScreen] (mp-495, approved as
/// mp-500), driven the way mp-497 §1 says: the real screen, the REAL status
/// notifier and screen controller, and the same mocked [SubscriptionService]
/// the client seam uses, answering with producer-shaped customer info
/// (`customer_info_fixtures.dart`).
///
/// Covers: trial, active and founding member, each with its status and date
/// (mp-497 §2); no ended state and no Upgrade, since a lapsed athlete stays
/// on the paywall (mp-457, 87-008); Manage subscription only with a store
/// subscription, the one Manage the paywall's ⋯ menu uses too (87-007); the
/// tick list with the AI features under the
/// one Vana line; Redeem code on every plan state, opening our own Code
/// entry, where a giveaway Code sent to `redeem-code` (its own answer, fed at
/// the functions client) shows the Grant it gave (mp-458, mp-495 §3); a Grant with where it came from and its days left, with no
/// Manage subscription, while a store subscription keeps its own (mp-558);
/// Settings opening the screen as a named push; light and dark goldens
/// (mp-497 §3).
///
/// Fonts: widget tests render with the test font, so the goldens pin LAYOUT,
/// COLOUR and STRUCTURE, not glyph shapes.
///
///   flutter test test/features/subscription/presentation/subscription_screen_test.dart
///   flutter test test/features/subscription/presentation/subscription_screen_test.dart --update-goldens
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/settings_screen.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_screen_controller.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/data/grant_source_repository.dart';
import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';
import 'package:mealvana_endurance/features/subscription/data/user_entitlements_repository.dart';
import 'package:mealvana_endurance/features/subscription/presentation/pro_gate_redirect.dart';
import 'package:mealvana_endurance/features/subscription/presentation/screens/paywall_screen.dart';
import 'package:mealvana_endurance/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:mealvana_endurance/features/subscription/domain/grant.dart';
import 'package:mealvana_endurance/features/subscription/presentation/widgets/redeem_code_sheet.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/cards/feature_list.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/icons/vana_avatar.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

import '../../../helpers/widget_test_harness.dart';
import '../../meal_planning/presentation/helpers/test_content.dart';
import '../customer_info_fixtures.dart';

class _MockSubscriptionService extends Mock implements SubscriptionService {}

class _MockRepository extends Mock implements UserEntitlementsRepository {}

class _MockGrantSources extends Mock implements GrantSourceRepository {}

class _MockSupabase extends Mock implements SupabaseClient {}

class _MockFunctions extends Mock implements FunctionsClient {}

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

class _SeededSettings extends SettingsController {
  @override
  FutureOr<SettingsState> build() => const SettingsState(
    title: 'Settings',
    profileSectionTitle: 'Profile',
    preferenceSectionTitle: 'Preferences',
    genderLabel: 'Gender',
    birthdayLabel: 'Birthday',
    heightLabel: 'Height',
    weightLabel: 'Weight',
    waterBottleLabel: 'Water Bottle',
    distanceUnitLabel: 'Distance',
    paceUnitLabel: 'Pace',
    gutTrainingLabel: 'Gut Training',
    saveButtonText: 'Save',
  );
}

class _RecordingObserver extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}

const _userId = 'u-1';

/// 19 October 2026, midday UTC: the day mp-558's example opens Settings.
final _today = DateTime.utc(2026, 10, 19, 12);
final _content = loadDefaultContent();
String _copy(String key) => _content[key]!;
String _dated(String key, DateTime utc) =>
    _copy(key).replaceAll('{date}', DateFormat.yMMMMd().format(utc.toLocal()));

const _status = ValueKey('subscription.status');
const _date = ValueKey('subscription.date');
const _upgrade = ValueKey('subscription.upgrade_button');
const _manage = ValueKey('subscription.manage_button');
const _redeem = ValueKey('subscription.redeem_code_button');

void main() {
  late _MockSubscriptionService service;
  late _MockRepository repo;
  late _MockGrantSources grantSources;
  late List<Uri> launched;

  setUp(() {
    service = _MockSubscriptionService();
    repo = _MockRepository();
    grantSources = _MockGrantSources();
    when(() => grantSources.recentGrants()).thenAnswer((_) async => const []);
    launched = [];
    when(() => repo.currentUserId).thenReturn(_userId);
    when(
      () => repo.authUserIdChanges,
    ).thenAnswer((_) => const Stream<String?>.empty());
    when(() => service.setStatusListener(any())).thenReturn(null);
    when(() => service.currentAppUserId()).thenAnswer((_) async => _userId);
    when(() => service.logIn(any())).thenAnswer((_) async {});
    when(
      () => service.managementUrl(),
    ).thenAnswer((_) async => Uri.parse(kAppleSubscriptionsUrl));
  });

  List<Override> overrides({
    required CustomerInfo info,
    bool storeSubscription = true,
    bool launchOpens = true,
    SupabaseClient? supabase,
  }) {
    when(() => service.fetchStatus()).thenAnswer((_) async => statusOf(info));
    when(
      () => service.hasStoreSubscriptionOnRecord(),
    ).thenAnswer((_) async => storeSubscription);
    return [
      mockAppExternalDeps(supabaseClient: supabase),
      subscriptionServiceProvider.overrideWithValue(service),
      userEntitlementsRepositoryProvider.overrideWithValue(repo),
      grantSourceRepositoryProvider.overrideWithValue(grantSources),
      entitlementAnswerTimeoutProvider.overrideWithValue(
        const Duration(milliseconds: 60),
      ),
      localNotificationSchedulerProvider.overrideWithValue(_NoopScheduler()),
      subscriptionScreenClockProvider.overrideWithValue(() => _today),
      subscriptionClockProvider.overrideWithValue(() => customerInfoFetchedAt),
      contentServiceProvider.overrideWith(
        (ref) => TestContentService(ref, _content),
      ),
      paywallUrlLauncherProvider.overrideWithValue((uri) async {
        launched.add(uri);
        return launchOpens;
      }),
    ];
  }

  /// The screen under a router with a stand-in paywall, the way Settings'
  /// push sits over the app's GoRouter.
  Future<void> pump(
    WidgetTester tester, {
    required CustomerInfo info,
    bool storeSubscription = true,
    bool launchOpens = true,
    SupabaseClient? supabase,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, _) => const SubscriptionScreen(),
        ),
        GoRoute(
          path: kPaywallPath,
          builder: (_, _) => const Scaffold(body: Text('paywall stand-in')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        // A fresh scope per pump: a test that pumps twice gets a second
        // account, not the first one's cached status.
        key: UniqueKey(),
        overrides: overrides(
          info: info,
          storeSubscription: storeSubscription,
          launchOpens: launchOpens,
          supabase: supabase,
        ),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  String? textOf(WidgetTester tester, Key key) {
    final f = find.byKey(key);
    if (f.evaluate().isEmpty) return null;
    return tester.widget<Text>(f).data;
  }

  group('the plan status and its date (mp-495 §2, mp-497 §2)', () {
    testWidgets('trial: the free week with the day it ends', (tester) async {
      await pump(tester, info: customerInfoTrial);
      expect(textOf(tester, _status), _copy('subscription.status_trial'));
      expect(
        textOf(tester, _date),
        _dated('subscription.trial_ends', DateTime.utc(2026, 9, 29, 10)),
      );
    });

    testWidgets('active: subscribed, with the day it renews', (tester) async {
      await pump(tester, info: customerInfoOpen);
      expect(textOf(tester, _status), _copy('subscription.status_active'));
      expect(
        textOf(tester, _date),
        _dated('subscription.renews', DateTime.utc(2026, 11, 1, 10)),
      );
    });

    testWidgets('active and cancelled: the day it ends', (tester) async {
      await pump(tester, info: customerInfoOpenCancelled);
      expect(textOf(tester, _status), _copy('subscription.status_active'));
      expect(
        textOf(tester, _date),
        _dated('subscription.ends', DateTime.utc(2026, 11, 1, 10)),
      );
    });

    testWidgets('founding: founding member, with the day it renews', (
      tester,
    ) async {
      await pump(tester, info: customerInfoFounding);
      expect(textOf(tester, _status), _copy('subscription.status_founding'));
      expect(
        textOf(tester, _date),
        _dated('subscription.renews', DateTime.utc(2027, 10, 1, 10)),
      );
    });

    // 87-008: a lapsed athlete stays on the paywall (mp-457), so there is
    // no ended state. Only an Admin, open without Pro, reaches the screen
    // with no plan running: no status card, no Upgrade.
    testWidgets('no plan running: no ended state and no Upgrade', (
      tester,
    ) async {
      await pump(tester, info: customerInfoLapsed);
      expect(
        find.byKey(const ValueKey('subscription.status_card')),
        findsNothing,
      );
      expect(find.byKey(_status), findsNothing);
      expect(find.byKey(_date), findsNothing);
      expect(find.byKey(_upgrade), findsNothing);
      expect(find.byKey(_redeem), findsOneWidget);
    });
  });

  group('Manage subscription (mp-495 §3, mp-558)', () {
    testWidgets('Manage only with a store subscription', (tester) async {
      await pump(tester, info: customerInfoGranted, storeSubscription: false);
      expect(find.byKey(_manage), findsNothing);

      await pump(tester, info: customerInfoOpen);
      expect(find.byKey(_manage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(_manage),
          matching: find.text(_copy('paywall.manage_button')),
        ),
        findsOneWidget,
      );

      // An ended store subscription still has a page to resubscribe from.
      await pump(tester, info: customerInfoLapsed);
      expect(find.byKey(_manage), findsOneWidget);
    });

    testWidgets('Manage opens the store page the paywall\'s Manage opens', (
      tester,
    ) async {
      await pump(tester, info: customerInfoOpen);
      await tester.tap(find.byKey(_manage));
      await tester.pumpAndSettle();
      expect(launched, [Uri.parse(kAppleSubscriptionsUrl)]);
    });

    testWidgets('a store page that will not open says where to manage it', (
      tester,
    ) async {
      await pump(tester, info: customerInfoOpen, launchOpens: false);
      await tester.tap(find.byKey(_manage));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(_copy('paywall.manage_unavailable')), findsOneWidget);
    });

    testWidgets('no management URL (a Test Store subscription) says where '
        'to manage it and opens nothing (finding 09-001)', (tester) async {
      when(() => service.managementUrl()).thenAnswer((_) async => null);
      await pump(tester, info: customerInfoOpen);
      await tester.tap(find.byKey(_manage));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(_copy('subscription.manage_no_page')), findsOneWidget);
      expect(launched, isEmpty);
    });
  });

  group('the plan bought on the status card (mp-628, finding 08-001)', () {
    String planLine(String label) =>
        _copy('subscription.plan_name').replaceAll('{plan}', _copy(label));

    testWidgets('a monthly subscription shows Monthly', (tester) async {
      await pump(tester, info: customerInfoOpen);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('subscription.status_card')),
          matching: find.text(planLine('paywall.monthly_label')),
        ),
        findsOneWidget,
      );
      expect(planLine('paywall.monthly_label'), contains('Monthly'));
    });

    testWidgets('a founding annual plan shows Annual', (tester) async {
      await pump(tester, info: customerInfoFounding);
      expect(
        textOf(tester, const ValueKey('subscription.plan')),
        planLine('paywall.annual_label'),
      );
    });

    testWidgets('an ended plan names no plan', (tester) async {
      await pump(tester, info: customerInfoLapsed);
      expect(find.byKey(const ValueKey('subscription.plan')), findsNothing);
    });
  });

  group('a Grant: where it came from and its days left (mp-558)', () {
    testWidgets('the Legacy grace month, with no Manage subscription', (
      tester,
    ) async {
      await pump(
        tester,
        info: customerInfoGraceGrant,
        storeSubscription: false,
      );
      expect(textOf(tester, _status), _copy('subscription.status_grant_grace'));
      expect(
        textOf(tester, _date),
        _copy('subscription.grant_days_left').replaceAll('{days}', '12'),
      );
      expect(find.byKey(_manage), findsNothing);
      expect(find.byKey(_redeem), findsOneWidget);
    });

    testWidgets("a coach's own Code, as the server recorded it (mp-615)", (
      tester,
    ) async {
      when(() => grantSources.recentGrants()).thenAnswer(
        (_) async => [
          GrantRecord(
            source: GrantSource.coach,
            grantedAt: DateTime.utc(2026, 10, 1, 10, 0, 2),
            proDays: 30,
          ),
        ],
      );
      await pump(
        tester,
        info: customerInfoGraceGrant,
        storeSubscription: false,
      );
      expect(textOf(tester, _status), _copy('subscription.status_grant_coach'));
      expect(_copy('subscription.status_grant_coach'), 'Coach access');
      expect(
        textOf(tester, _date),
        _copy('subscription.grant_days_left').replaceAll('{days}', '12'),
      );
    });

    testWidgets('a Code, with its days left', (tester) async {
      await pump(tester, info: customerInfoGranted, storeSubscription: false);
      expect(textOf(tester, _status), _copy('subscription.status_grant_code'));
      expect(
        textOf(tester, _date),
        _copy('subscription.grant_days_left').replaceAll('{days}', '338'),
      );
      expect(find.byKey(_manage), findsNothing);
    });

    testWidgets('a store subscription still shows as today, with Manage', (
      tester,
    ) async {
      await pump(tester, info: customerInfoOpen);
      expect(textOf(tester, _status), _copy('subscription.status_active'));
      expect(
        textOf(tester, _date),
        _dated('subscription.renews', DateTime.utc(2026, 11, 1, 10)),
      );
      expect(find.byKey(_manage), findsOneWidget);
    });
  });

  testWidgets('what Pro includes: the tick list, AI under the one Vana line '
      '(mp-495 §2, mp-493 §2)', (tester) async {
    await pump(tester, info: customerInfoOpen);
    expect(find.text(_copy('subscription.includes_header')), findsOneWidget);
    final list = find.byType(FeatureList);
    expect(list, findsOneWidget);
    expect(
      find.descendant(of: list, matching: find.byType(VanaAvatar)),
      findsOneWidget,
    );
    for (final key in [
      'paywall.feature_fuel_title',
      'paywall.feature_vana_title',
      'paywall.feature_shopping_title',
      'paywall.feature_sync_title',
      'paywall.feature_recipes',
      'paywall.feature_brick',
      'paywall.feature_hydration',
      'paywall.feature_formulas',
      'paywall.feature_targets',
    ]) {
      expect(find.text(_copy(key)), findsOneWidget, reason: key);
    }
    // Every feature but Vana's is ticked.
    expect(
      find.descendant(of: list, matching: find.byIcon(Icons.check)),
      findsNWidgets(8),
    );
  });

  group('Redeem code (mp-458, mp-495 §3)', () {
    for (final (name, info) in [
      ('trial', customerInfoTrial),
      ('active', customerInfoOpen),
      ('no plan running', customerInfoLapsed),
    ]) {
      testWidgets('there on $name, opening our own Code entry', (tester) async {
        await pump(tester, info: info);
        await tester.ensureVisible(find.byKey(_redeem));
        expect(
          tester
              .widget<Text>(
                find.descendant(
                  of: find.byKey(_redeem),
                  matching: find.byType(Text),
                ),
              )
              .data,
          _copy('redeem_code.button'),
        );
        await tester.tap(find.byKey(_redeem));
        await tester.pumpAndSettle();
        expect(find.byType(RedeemCodeSheet), findsOneWidget);
        expect(find.text(_copy('redeem_code.title')), findsOneWidget);
      });
    }

    testWidgets('a giveaway Code shows the Grant it gave', (tester) async {
      final functions = _MockFunctions();
      when(
        () => functions.invoke('redeem-code', body: any(named: 'body')),
      ).thenAnswer(
        (_) async => FunctionResponse(
          status: 200,
          data: {'ok': true, 'kind': 'giveaway', 'pro_days': 365},
        ),
      );
      final supabase = _MockSupabase();
      when(() => supabase.functions).thenReturn(functions);
      var granted = false;
      when(() => service.forgetCachedStatus()).thenAnswer((_) async {
        granted = true;
      });

      await pump(tester, info: customerInfoLapsed, supabase: supabase);
      // RevenueCat holds the grant once the cache is dropped.
      when(() => service.fetchStatus()).thenAnswer(
        (_) async =>
            statusOf(granted ? customerInfoGranted : customerInfoLapsed),
      );
      expect(find.byKey(_status), findsNothing);

      await tester.ensureVisible(find.byKey(_redeem));
      await tester.tap(find.byKey(_redeem));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(RedeemCodeSheet.fieldKey), 'win365');
      await tester.pump();
      await tester.tap(find.byKey(RedeemCodeSheet.submitKey));
      await tester.pumpAndSettle();

      verify(
        () => functions.invoke('redeem-code', body: {'code': 'WIN365'}),
      ).called(1);
      expect(find.byType(RedeemCodeSheet), findsNothing);
      expect(
        find.text('Code redeemed. You have 365 days of Pro.'),
        findsOneWidget,
      );
      expect(textOf(tester, _status), _copy('subscription.status_grant_code'));
    });
  });

  testWidgets('renders without overflow (smoke)', (tester) async {
    await smokeScreen(
      tester,
      const SubscriptionScreen(),
      overrides: overrides(info: customerInfoOpen).skip(1).toList(),
    );
  });

  testWidgets('Settings opens it as a named push, its status on it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final observer = _RecordingObserver();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides(info: customerInfoTrial),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          mockSharedPreferences(),
          settingsControllerProvider.overrideWith(_SeededSettings.new),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, _) => MaterialApp(
            navigatorObservers: [observer],
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('settings.subscription_row'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: row,
        matching: find.text(_copy('subscription.settings_row_title')),
      ),
      findsOneWidget,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byType(SubscriptionScreen), findsOneWidget);
    expect(observer.pushed.last.settings.name, SubscriptionScreen.routeName);
    expect(SubscriptionScreen.routeName, '/settings/subscription');
    expect(textOf(tester, _status), _copy('subscription.status_trial'));
  });

  group('goldens — the Subscription screen (mp-497 §3)', () {
    Future<void> golden(
      WidgetTester tester,
      Brightness brightness,
      CustomerInfo info,
      String name,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(info: info),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: brightness,
              scaffoldBackgroundColor: brightness == Brightness.dark
                  ? AppColors.blackberry
                  : AppColors.cream,
            ),
            home: const RepaintBoundary(
              key: Key('golden'),
              child: SubscriptionScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final mode = brightness == Brightness.dark ? 'dark' : 'light';
      await expectLater(
        find.byKey(const Key('golden')),
        matchesGoldenFile('goldens/subscription_${name}_$mode.png'),
      );
    }

    for (final brightness in Brightness.values) {
      final mode = brightness == Brightness.dark ? 'dark' : 'light';
      testWidgets(
        'active $mode',
        (tester) => golden(tester, brightness, customerInfoOpen, 'active'),
      );
    }
  });
}
