/// The Vana settings usage bar (ai-cost ticket 10; mp-430 clause 8, mp-436
/// clause 3, mp-282).
///
/// Through the REAL [CreditsController] over a counting wallet transport, so
/// what is asserted is what the athlete sees given a row the server wrote:
/// a share of the month, a refill date and any bought extra — and never a
/// dollar figure, though the row underneath is in micro-dollars.
///
/// The same host proves the live wallet connection opens with a budget screen
/// and closes when it goes away.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/application/credits_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/application/purchase_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/data/credits_repository.dart';
import 'package:mealvana_endurance/features/ai_credits/presentation/insufficient_credits_handler.dart';
import 'package:mealvana_endurance/features/ai_credits/presentation/widgets/vana_budget_card.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/prefs_provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/meal_planning/presentation/helpers/test_content.dart';
import '../helpers/counting_credits_repository.dart';

/// A subscriber half way through the month with a $4.99 pack in the bank:
/// $2.00 of a $4.00 month left, and $1.00 of that is bought.
const _halfSpent = {
  'balance': 3000000,
  'allowance': 2000000,
  'allowance_monthly': 4000000,
  'allowance_expires_at': '2026-10-15T12:00:00+00:00',
};

/// The month spent and nothing bought.
const _allSpent = {
  'balance': 0,
  'allowance': 0,
  'allowance_monthly': 4000000,
  'allowance_expires_at': '2026-10-15T12:00:00+00:00',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final content = loadDefaultContent();
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    debugResetInsufficientCreditsSheet();
  });

  /// Shown or not, under one provider container — flipping this is a budget
  /// screen arriving and leaving.
  final showing = ValueNotifier<bool>(true);

  Future<CountingCreditsRepository> pumpCard(
    WidgetTester tester, {
    required Map<String, dynamic> row,
    bool showCard = true,
    List<Package> packages = const [],
  }) async {
    showing.value = showCard;
    final repo = CountingCreditsRepository(row: row);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          creditsRepositoryProvider.overrideWithValue(repo),
          contentServiceProvider.overrideWith(testContentService),
          appConfigProvider.overrideWithValue(
            AppConfig.forTesting(aiCreditsEnabled: true),
          ),
          visibleCreditPackagesProvider.overrideWith((ref) async => packages),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: showing,
              builder: (_, show, __) =>
                  show ? const VanaBudgetCard() : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  group('the Vana settings usage bar', () {
    testWidgets('shows a share, a refill date and bought extra, no dollars', (
      tester,
    ) async {
      await pumpCard(tester, row: _halfSpent);

      expect(find.byKey(const ValueKey('ai_credits.usage_bar')), findsOneWidget);

      // The fill is really drawn, half the bar wide and as tall as it. A
      // loose Stack child sized to a childless ColoredBox is zero high, so
      // the bar once rendered as an empty track.
      final bar = tester.getSize(
        find.byKey(const ValueKey('ai_credits.usage_bar')),
      );
      final fill = tester.getSize(
        find.descendant(
          of: find.byKey(const ValueKey('ai_credits.usage_bar')),
          matching: find.byType(ColoredBox),
        ).last,
      );
      expect(fill.height, bar.height);
      expect(fill.width, closeTo(bar.width / 2, 1));

      expect(
        find.text(
          content['ai_credits.usage_used']!.replaceAll('{percent}', '50'),
        ),
        findsOneWidget,
      );

      final refills = DateTime.utc(2026, 10, 15, 12).toLocal();
      expect(
        find.byKey(const ValueKey('ai_credits.usage_refills')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('ai_credits.usage_refills')))
            .data,
        contains('${refills.day}'),
      );

      expect(
        find.text(
          content['ai_credits.usage_bought_extra']!.replaceAll(
            '{percent}',
            '25',
          ),
        ),
        findsOneWidget,
      );

      // Not a dollar figure anywhere, and never the raw micro-dollar balance.
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' | ');
      expect(texts, isNot(contains(r'$')));
      expect(texts, isNot(contains('3000000')));
      expect(texts, isNot(contains('2000000')));
      expect(texts, isNot(contains('4.00')));
    });

    testWidgets('a wallet with no budget window says so and shows no bar fill', (
      tester,
    ) async {
      await pumpCard(
        tester,
        row: const {
          'balance': 0,
          'allowance': 0,
          'allowance_monthly': 0,
          'allowance_expires_at': null,
        },
      );

      expect(
        find.text(content['ai_credits.usage_no_window']!),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('ai_credits.usage_refills')), findsNothing);
    });

    testWidgets('at 100% it says so and offers the top-up sheet (mp-282)', (
      tester,
    ) async {
      await pumpCard(
        tester,
        row: _allSpent,
        packages: [
          _FakePackage('mealvana_credits_50', r'$4.99'),
          _FakePackage('mealvana_credits_250', r'$19.99'),
        ],
      );

      expect(find.text(content['ai_credits.usage_spent']!), findsOneWidget);
      expect(find.byKey(const ValueKey('ai_credits.top_up')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ai_credits.top_up')));
      await tester.pumpAndSettle();

      // The sheet, worded in the new unit — never a credit count, never a gate.
      expect(
        find.text(content['ai_credits.pack_quarter_month']!),
        findsOneWidget,
      );
      expect(
        find.text(content['ai_credits.pack_month_and_quarter']!),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('token'), findsNothing);
      expect(find.textContaining('credit'), findsNothing);
    });
  });

  group('the wallet live connection', () {
    testWidgets('opens with the budget screen and closes when it goes away', (
      tester,
    ) async {
      final repo = await pumpCard(tester, row: _halfSpent);

      expect(repo.subscribes, 1);
      expect(repo.removes, 0);

      // The screen goes away, same container.
      showing.value = false;
      await tester.pumpAndSettle();
      // Riverpod 3 lets an autoDispose provider live a moment past its last
      // listener, so that a rebuild or a route swap does not tear a socket
      // down and put it straight back up. Wait it out.
      await tester.pump(const Duration(seconds: 2));

      expect(repo.subscribes, 1);
      expect(repo.removes, 1);
    });

    testWidgets('no budget screen, no connection', (tester) async {
      final repo = await pumpCard(tester, row: _halfSpent, showCard: false);

      expect(repo.subscribes, 0);
      expect(repo.removes, 0);
    });
  });
}

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
