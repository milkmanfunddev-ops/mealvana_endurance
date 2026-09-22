/// The top-up sheet and the one 402 handler (mp-282, ticket 20; reworded for
/// the monthly budget in ai-cost ticket 10).
///
/// The sheet is what every spent-budget 402 raises, so it must say how much of
/// this month's Vana is used, when it refills and any bought extra, and offer
/// the two packs — worded as a share of a month, never a credit count and
/// never dollars of budget (mp-430 clauses 7 and 8, mp-436 clause 3). The
/// wallet is fed as the server's `token_wallets` row, in whole micro-dollars;
/// the packs as RevenueCat packages (never this code's own output).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/application/credits_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/application/purchase_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/credit_wallet.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/insufficient_credits_exception.dart';
import 'package:mealvana_endurance/features/ai_credits/presentation/insufficient_credits_handler.dart';
import 'package:mealvana_endurance/features/ai_credits/presentation/sheets/token_top_up_sheet.dart';
import 'package:mealvana_endurance/features/ai_credits/data/credits_repository.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../meal_planning/presentation/helpers/test_content.dart';
import '../helpers/counting_credits_repository.dart';

class _FakeStoreProduct extends Fake implements StoreProduct {
  _FakeStoreProduct(this.identifier, this.priceString, this.title);

  @override
  final String identifier;
  @override
  final String priceString;
  @override
  final String title;
}

class _FakePackage extends Fake implements Package {
  _FakePackage(String sku, String price)
    : storeProduct = _FakeStoreProduct(sku, price, sku);

  @override
  final StoreProduct storeProduct;
}

/// A wallet pinned to one row — no Supabase, no realtime channel.
class _FixedCredits extends CreditsController {
  _FixedCredits(this.wallet);

  final CreditWallet wallet;

  @override
  Future<CreditWallet> build() async => wallet;
}

final _twoPacks = <Package>[
  _FakePackage('mealvana_credits_50', r'$4.99'),
  _FakePackage('mealvana_credits_250', r'$19.99'),
];

/// The server's row for a subscriber who spent this month's budget: whole
/// micro-dollars, a $4.00 month, nothing left and nothing bought.
const _spentAllowance = {
  'balance': 0,
  'allowance': 0,
  'allowance_monthly': 4000000,
  'allowance_expires_at': '2026-10-15T12:00:00+00:00',
};

void main() {
  final content = loadDefaultContent();

  setUp(debugResetInsufficientCreditsSheet);

  Future<void> pumpHost(
    WidgetTester tester, {
    required CreditWallet wallet,
    List<Package> packages = const [],
    required Widget Function(BuildContext) child,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          creditsControllerProvider.overrideWith(() => _FixedCredits(wallet)),
          // The sheet is a budget screen, so it opens the wallet's live
          // connection: give it a transport that has no socket.
          creditsRepositoryProvider.overrideWithValue(
            CountingCreditsRepository(),
          ),
          visibleCreditPackagesProvider.overrideWith((ref) async => packages),
        ],
        child: MaterialApp(
          home: Scaffold(body: Builder(builder: child)),
        ),
      ),
    );
    await tester.pump();
  }

  group('the top-up sheet', () {
    testWidgets(
      'shows the share used, the refill date and the two packs in the new unit',
      (tester) async {
        await pumpHost(
          tester,
          wallet: CreditWallet.fromMap(_spentAllowance),
          packages: _twoPacks,
          child: (context) => TextButton(
            onPressed: () => showTokenTopUpSheet(context),
            child: const Text('open'),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('tokens.allowance')), findsOneWidget);
        expect(
          find.text(
            content['ai_credits.usage_used']!.replaceAll('{percent}', '100'),
          ),
          findsOneWidget,
        );
        final renews = DateTime.utc(2026, 10, 15, 12).toLocal();
        expect(
          find.text(
            content['ai_credits.usage_refills']!.replaceAll(
              '{date}',
              '${_month(renews.month)} ${renews.day}',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(content['ai_credits.top_up_title_spent']!),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('tokens.pack_mealvana_credits_50')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('tokens.pack_mealvana_credits_250')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('tokens.buy')), findsOneWidget);

        // The new unit, and no dollar figure but the store's own prices.
        expect(
          find.text(content['ai_credits.pack_quarter_month']!),
          findsOneWidget,
        );
        expect(
          find.text(content['ai_credits.pack_month_and_quarter']!),
          findsOneWidget,
        );
        expect(find.textContaining('token'), findsNothing);
        expect(find.textContaining('credit'), findsNothing);
        expect(find.textContaining('4000000'), findsNothing);
      },
    );

    testWidgets('a wallet with no budget window shows only the packs', (
      tester,
    ) async {
      await pumpHost(
        tester,
        wallet: CreditWallet.fromMap(const {'balance': 0}),
        packages: _twoPacks,
        child: (context) => TextButton(
          onPressed: () => showTokenTopUpSheet(context),
          child: const Text('open'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('tokens.allowance')), findsNothing);
      expect(find.text(content['ai_credits.top_up_title']!), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tokens.pack_mealvana_credits_50')),
        findsOneWidget,
      );
    });

    testWidgets('bought budget is named as a share of a month, with no date', (
      tester,
    ) async {
      await pumpHost(
        tester,
        // The month is spent; a $4.99 pack ($1.00) is left.
        wallet: CreditWallet.fromMap(const {
          'balance': 1000000,
          'allowance': 0,
          'allowance_monthly': 4000000,
          'allowance_expires_at': '2026-10-15T12:00:00+00:00',
        }),
        packages: _twoPacks,
        child: (context) => TextButton(
          onPressed: () => showTokenTopUpSheet(context),
          child: const Text('open'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          content['ai_credits.usage_bought_extra']!.replaceAll(
            '{percent}',
            '25',
          ),
        ),
        findsOneWidget,
      );
    });
  });

  group('the one 402 handler', () {
    testWidgets(
      'an InsufficientCreditsException raises the sheet and returns true',
      (tester) async {
        late bool handled;
        await pumpHost(
          tester,
          wallet: CreditWallet.fromMap(_spentAllowance),
          packages: _twoPacks,
          child: (context) => TextButton(
            onPressed: () {
              handled = handleInsufficientCredits(
                const InsufficientCreditsException(
                  balance: 0,
                  cost: 1,
                  message: 'You are out of AI credits.',
                ),
                context: context,
              );
            },
            child: const Text('call'),
          ),
        );
        await tester.tap(find.text('call'));
        await tester.pumpAndSettle();

        expect(handled, isTrue);
        expect(find.byKey(const ValueKey('tokens.allowance')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('tokens.pack_mealvana_credits_250')),
          findsOneWidget,
        );
        // Never the old dialog, never a gate.
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Get credits'), findsNothing);
      },
    );

    testWidgets(
      'a second 402 while the sheet is up does not stack a second sheet',
      (tester) async {
        await pumpHost(
          tester,
          wallet: CreditWallet.fromMap(_spentAllowance),
          packages: _twoPacks,
          child: (context) => TextButton(
            onPressed: () {
              showInsufficientCreditsSheet(context: context);
              showInsufficientCreditsSheet(context: context);
            },
            child: const Text('twice'),
          ),
        );
        await tester.tap(find.text('twice'));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('tokens.allowance')), findsOneWidget);
      },
    );

    testWidgets('any other error is not handled and raises nothing', (
      tester,
    ) async {
      late bool handled;
      await pumpHost(
        tester,
        wallet: CreditWallet.zero,
        child: (context) => TextButton(
          onPressed: () {
            handled = handleInsufficientCredits(
              StateError('boom'),
              context: context,
            );
          },
          child: const Text('call'),
        ),
      );
      await tester.tap(find.text('call'));
      await tester.pumpAndSettle();

      expect(handled, isFalse);
      expect(find.byKey(const ValueKey('tokens.buy')), findsNothing);
    });
  });
}

String _month(int m) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][m - 1];
