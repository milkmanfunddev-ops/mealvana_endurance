// AI Credits can always be left, and "How credits work" names what credits
// buy (round develop-2026-10, ticket 46: Findings 32-003 and 32-004).
//
// Opened by deep link the screen is the root of its stack: the back control
// must go home. Pushed from somewhere, it must pop back there. The
// explanation comes from `ai_credits.how_*`, not a Dart literal.
//
// 69-013 (ticket 82): the tester pack read "1 Credits". Pack titles and the
// balance come from the `ai_credits.pack_title_*` / `balance_*` one/other
// pairs.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:mealvana_endurance/features/ai_credits/application/credits_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/application/purchase_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/credit_wallet.dart';
import 'package:mealvana_endurance/features/ai_credits/presentation/screens/buy_credits_screen.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';

import '../../helpers/test_content.dart';

class _FakeCreditsController extends CreditsController {
  @override
  FutureOr<CreditWallet> build() => const CreditWallet(balance: 12);
}

class _OneCreditController extends CreditsController {
  @override
  FutureOr<CreditWallet> build() => const CreditWallet(balance: 1);
}

/// A real RevenueCat [Package] for a credits SKU, as the store returns it.
Package _creditsPackage(String sku, String price) => Package(
  sku,
  PackageType.custom,
  StoreProduct(sku, 'AI credits', 'Credits ($sku)', 0.99, price, 'USD'),
  const PresentedOfferingContext('credits', null, null),
);

class _IdlePurchaseController extends PurchaseController {
  @override
  FutureOr<void> build() => null;
}

void main() {
  final defaults = loadDefaultContent();

  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    required String initialLocation,
    bool aiCreditsEnabled = true,
    List<Package> packages = const [],
    CreditsController Function() credits = _FakeCreditsController.new,
  }) async {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                const Text('stub home'),
                TextButton(
                  onPressed: () => context.push('/buy-credits'),
                  child: const Text('open credits'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/buy-credits',
          builder: (_, __) => const BuyCreditsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.forTesting(aiCreditsEnabled: aiCreditsEnabled),
          ),
          contentServiceProvider.overrideWith(testContentService),
          creditsControllerProvider.overrideWith(credits),
          visibleCreditPackagesProvider.overrideWith((ref) async => packages),
          purchaseControllerProvider.overrideWith(_IdlePurchaseController.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  String path(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  Future<void> tapBack(WidgetTester tester) async {
    await tester.tap(find.byType(CustomAppBarBackButton));
    // The button re-arms itself after 500ms; let that timer finish inside
    // the test body.
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
  }

  testWidgets('opened by deep link, the back control goes home', (
    tester,
  ) async {
    final router = await pumpApp(tester, initialLocation: '/buy-credits');

    expect(path(router), '/buy-credits');
    expect(find.byType(CustomAppBarBackButton), findsOneWidget);
    // The Restore action is kept.
    expect(find.text('Restore'), findsOneWidget);

    await tapBack(tester);

    expect(path(router), '/');
    expect(find.text('stub home'), findsOneWidget);
  });

  testWidgets('pushed from home, the back control pops back', (tester) async {
    final router = await pumpApp(tester, initialLocation: '/');

    await tester.tap(find.text('open credits'));
    await tester.pumpAndSettle();
    // A push sits on top of `/` (the base configuration path stays `/`), so
    // assert on what is showing and on the router's ability to pop.
    expect(find.byType(BuyCreditsScreen), findsOneWidget);
    expect(router.canPop(), isTrue);

    await tapBack(tester);

    expect(find.byType(BuyCreditsScreen), findsNothing);
    expect(router.canPop(), isFalse);
    expect(path(router), '/');
    expect(find.text('stub home'), findsOneWidget);
  });

  testWidgets('the explanation reads the ai_credits.how_* content', (
    tester,
  ) async {
    expect(defaults[ContentKeys.aiCreditsHowTitle], 'How credits work');
    expect(
      defaults[ContentKeys.aiCreditsHowBody],
      'AI credits pay for meal descriptions, meal photo analysis and '
      'Formula Kit coach insights. Each request uses credits, and credits '
      'never expire.',
    );

    await pumpApp(tester, initialLocation: '/buy-credits');

    expect(find.text(defaults[ContentKeys.aiCreditsHowTitle]!), findsOneWidget);
    expect(find.text(defaults[ContentKeys.aiCreditsHowBody]!), findsOneWidget);
    expect(find.textContaining('Mealvana AI conversations'), findsNothing);
  });

  testWidgets('the coming-soon screen also has the back control', (
    tester,
  ) async {
    final router = await pumpApp(
      tester,
      initialLocation: '/buy-credits',
      aiCreditsEnabled: false,
    );

    expect(find.text('AI Credits — Coming Soon'), findsOneWidget);
    expect(find.byType(CustomAppBarBackButton), findsOneWidget);

    await tapBack(tester);

    expect(path(router), '/');
  });

  testWidgets('69-013: "1 Credit", "50 Credits", "250 Credits"; a balance '
      'of 12 reads "12 credits"', (tester) async {
    expect(defaults[ContentKeys.aiCreditsPackTitleOne], '{n} Credit');
    expect(defaults[ContentKeys.aiCreditsPackTitleOther], '{n} Credits');

    await pumpApp(
      tester,
      initialLocation: '/buy-credits',
      packages: [
        _creditsPackage('mealvana_credits_test_1', r'$0.99'),
        _creditsPackage('mealvana_credits_50', r'$4.99'),
        _creditsPackage('mealvana_credits_250', r'$19.99'),
      ],
    );

    expect(find.text('1 Credit'), findsOneWidget);
    expect(find.text('1 Credits'), findsNothing);
    expect(find.text('50 Credits'), findsOneWidget);
    expect(find.text('250 Credits'), findsOneWidget);
    expect(find.text('12 credits'), findsOneWidget);
  });

  testWidgets('a balance of 1 reads "1 credit"', (tester) async {
    await pumpApp(
      tester,
      initialLocation: '/buy-credits',
      credits: _OneCreditController.new,
    );

    expect(find.text('1 credit'), findsOneWidget);
    expect(find.text('1 credits'), findsNothing);
  });
}
