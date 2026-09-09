import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/kroger/application/kroger_controller.dart';
import 'package:mealvana_endurance/features/kroger/application/kroger_availability.dart';
import 'package:mealvana_endurance/features/kroger/data/kroger_repository.dart';
import 'package:mealvana_endurance/features/kroger/domain/kroger_models.dart';
import 'package:mealvana_endurance/features/kroger/presentation/kroger_screen.dart';
import 'package:mealvana_endurance/features/meal_planning/application/shopping_list_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/shopping_item.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/shopping_tab.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/shopping_list.dart';
import '../meal_planning/presentation/helpers/test_content.dart';
import 'kroger_repository_test.dart' show FakeRemote;

const plan = '11111111-1111-4111-8111-111111111111';
const product = KrogerProduct(
  upc: '0001111040101',
  name: 'Kroger Milk',
  size: '1 l',
  price: 3,
  available: true,
);
const store = KrogerStore(
  id: '01400943',
  name: 'Test store',
  address: 'Test address',
);

class TestShopping extends ShoppingListController {
  @override
  Future<ShoppingListState> build() async => const ShoppingListState(
    planId: plan,
    items: [ShoppingItem(aisle: 'Dairy', name: 'Milk', qty: '2 l')],
  );
  void changeQuantity() => state = const AsyncData(
    ShoppingListState(
      planId: plan,
      items: [ShoppingItem(aisle: 'Dairy', name: 'Milk', qty: '3 l')],
    ),
  );
}

void main() {
  late ProviderContainer container;
  late KrogerRepository repo;
  late FakeRemote remote;
  late KrogerController controller;
  var exports = 0;
  var ambiguous = false;
  var browserCallback = '';
  var account = 'user-a';
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    exports = 0;
    ambiguous = false;
    browserCallback = '';
    account = 'user-a';
    remote = FakeRemote();
    remote.onCall = (action, data) async {
      switch (action) {
        case 'search':
          return {
            'products': [product.toJson()],
          };
        case 'export':
          exports++;
          if (ambiguous) throw const KrogerException('unavailable');
          return {
            'receipt': {'id': 'receipt', 'status': 'sent'},
          };
        default:
          return {
            'available': true,
            'connected': true,
            'environment': 'certification',
            'receipt': null,
          };
      }
    };
    repo = KrogerRepository(await SharedPreferences.getInstance(), remote);
    container = ProviderContainer(
      overrides: [
        krogerRepositoryProvider.overrideWith((ref) => repo),
        krogerUserIdProvider.overrideWith((ref) async => account),
        shoppingListControllerProvider.overrideWith(TestShopping.new),
        contentServiceProvider.overrideWith(testContentService),
        krogerShoppingEnabledProvider.overrideWithValue(true),
        krogerBrowserProvider.overrideWith(
          (ref) =>
              (url, scheme) async => browserCallback,
        ),
      ],
    );
    container.listen(krogerControllerProvider(plan), (_, _) {});
    await container.read(shoppingListControllerProvider.future);
    await container.read(krogerControllerProvider(plan).future);
    controller = container.read(krogerControllerProvider(plan).notifier);
  });
  tearDown(() => container.dispose());
  KrogerState current() =>
      container.read(krogerControllerProvider(plan)).requireValue;
  Future<void> reviewed() async {
    await controller.selectStore(store, 'PICKUP');
    await controller.matchAll();
    await controller.approve(current().draft.lines.single.id);
  }

  test(
    'matching suggests package count but requires shopper approval',
    () async {
      await controller.selectStore(store, 'PICKUP');
      await controller.matchAll();
      expect(current().draft.lines.single.quantity, 2);
      expect(current().draft.ready, false);
      await controller.approve(current().draft.lines.single.id);
      expect(current().draft.ready, true);
      await controller.quantity(current().draft.lines.single.id, 4);
      expect(current().draft.ready, false);
      expect(repo.load('user-a', plan).lines.single.quantity, 4);
    },
  );
  test('store or modality change clears previous matches', () async {
    await reviewed();
    await controller.selectStore(store, 'DELIVERY');
    expect(current().draft.lines.single.product, null);
    expect(current().draft.ready, false);
  });
  test(
    'source quantity edits revoke product approval without losing its selection',
    () async {
      await reviewed();
      (container.read(shoppingListControllerProvider.notifier) as TestShopping)
          .changeQuantity();
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      expect(current().draft.lines.single.requiredQty, '3 l');
      expect(current().draft.lines.single.quantity, 3);
      expect(current().draft.lines.single.product?.upc, product.upc);
      expect(current().draft.ready, false);
    },
  );
  test('a late lookup cannot mutate the next account draft', () async {
    await controller.selectStore(store, 'PICKUP');
    final pending = Completer<Map<String, dynamic>>();
    remote.onCall = (action, data) async => action == 'search'
        ? await pending.future
        : {
            'available': true,
            'connected': true,
            'environment': 'certification',
            'receipt': null,
          };
    final search = controller.search(current().draft.lines.single.id, 'milk');
    account = 'user-b';
    container.invalidate(krogerUserIdProvider);
    await container.read(krogerControllerProvider(plan).future);
    pending.complete({
      'products': [product.toJson()],
    });
    await search;
    expect(current().products, isEmpty);
    expect(repo.load('user-b', plan).lines.single.product, null);
  });
  test(
    'export waits for sync and records receipt; repeat taps cannot resend',
    () async {
      await reviewed();
      await controller.export();
      expect(remote.saves, greaterThan(0));
      expect(current().draft.receiptStatus, 'sent');
      await controller.export();
      expect(exports, 1);
    },
  );
  test('ambiguous network failure keeps local send lock', () async {
    await reviewed();
    ambiguous = true;
    await controller.export();
    expect(current().draft.receiptStatus, 'sending');
    await controller.export();
    expect(exports, 1);
  });
  test('unconfirmed cloud save prevents cart mutation', () async {
    await reviewed();
    remote.onSave = (_) async => throw const KrogerException('draft_conflict');
    await controller.export();
    expect(exports, 0);
    expect(current().message, 'draft_conflict');
    expect(current().draft.dirty, true);
  });
  test('incorrect OAuth callback state is rejected before exchange', () async {
    var exchanged = false;
    remote.onCall = (action, data) async {
      if (action == 'connect') {
        return {
          'url': 'https://api-ce.kroger.com/v1/connect/oauth2/authorize',
          'redirect': 'com.milkman.mealvanaendurance://callback',
          'state': 'expected',
        };
      }
      exchanged = action == 'exchange';
      return {};
    };
    browserCallback =
        'com.milkman.mealvanaendurance://callback?state=wrong&code=test-code';
    await controller.connect();
    expect(current().message, 'invalid_oauth_state');
    expect(exchanged, false);
  });
  testWidgets('review screen renders editable items and manual additions', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: KrogerScreen(planId: plan)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);
    final copy = loadDefaultContent();
    await tester.ensureVisible(find.text(copy['kroger.add_item']!));
    await tester.tap(find.text(copy['kroger.add_item']!));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Coffee');
    await tester.tap(find.text(copy['kroger.continue']!));
    await tester.pumpAndSettle();
    expect(
      current().draft.lines.any((l) => l.manual && l.name == 'Coffee'),
      true,
    );
    expect(tester.takeException(), null);
  });
  testWidgets('Kroger icon action is above groceries and opens review', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ShoppingTab())),
      ),
    );
    await tester.pumpAndSettle();
    final entry = find.byKey(const ValueKey('meal_planning.kroger'));
    expect(entry.hitTestable(), findsOneWidget);
    expect(
      find.descendant(
        of: entry,
        matching: find.byIcon(Icons.shopping_cart_outlined),
      ),
      findsOneWidget,
    );
    expect(
      tester.getBottomLeft(entry).dy,
      lessThan(tester.getTopLeft(find.byType(ShoppingList)).dy),
    );
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(KrogerScreen), findsOneWidget);
    expect(tester.takeException(), null);
  });
  testWidgets(
    'send is disabled until review; certification receipt does not open production cart',
    (tester) async {
      await reviewed();
      await controller.export();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: KrogerScreen(planId: plan)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kroger.export')), findsNothing);
      expect(
        find.text(loadDefaultContent()['kroger.open_cart']!),
        findsNothing,
      );
      expect(tester.takeException(), null);
    },
  );
}
