import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
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
import 'kroger_fixtures.dart';
import 'kroger_repository_test.dart' show FakeRemote;

const plan = '11111111-1111-4111-8111-111111111111';

/// The Location the server resolves for each delivery area, so a test can
/// tell one area's Location from another's. Real Kroger `locationId` shapes,
/// and deliberately not built out of the postcode: what is persisted must be
/// assertable as carrying no trace of it.
const locations = {
  '35209': '70100108',
  '35242': '70100109',
  '30301': '01400943',
};

/// Broccoli at the Birmingham Spoke: no price, sold by the count, and a
/// Location that only delivers. See `kroger_fixtures.dart`.
final product = spokeProduct;
final store = spokeStore;

class TestShopping extends ShoppingListController {
  @override
  Future<ShoppingListState> build() async => const ShoppingListState(
    planId: plan,
    items: [ShoppingItem(aisle: 'Produce', name: 'Broccoli', qty: '2 ct')],
  );
  void changeQuantity() => state = const AsyncData(
    ShoppingListState(
      planId: plan,
      items: [ShoppingItem(aisle: 'Produce', name: 'Broccoli', qty: '3 ct')],
    ),
  );
  void tickEverythingOff() => state = const AsyncData(
    ShoppingListState(
      planId: plan,
      items: [
        ShoppingItem(
          aisle: 'Produce',
          name: 'Broccoli',
          qty: '2 ct',
          checked: true,
        ),
      ],
    ),
  );
}

void main() {
  late ProviderContainer container;
  late KrogerRepository repo;
  late SharedPreferences prefs;
  late FakeRemote remote;
  late KrogerController controller;
  var exports = 0;
  var ambiguous = false;
  var browserCallback = '';
  var account = 'user-a';
  var found = true;
  String? deviceArea;
  var serves = true;
  Object? covered;
  String? coverageFailure;
  Map<String, dynamic>? status;
  String? loadFailure;
  KrogerState current() =>
      container.read(krogerControllerProvider(plan)).requireValue;

  /// Lets the delivery-area resolution `build` schedules run to completion.
  /// It is deliberately not part of the build future: the screen must not
  /// wait behind a twenty-second device-location timeout to appear.
  Future<void> areaSettled() async {
    for (var turn = 0; turn < 12; turn++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    exports = 0;
    ambiguous = false;
    browserCallback = '';
    account = 'user-a';
    found = true;
    deviceArea = '35209';
    serves = true;
    covered = true;
    coverageFailure = null;
    status = null;
    loadFailure = null;
    remote = FakeRemote();
    remote.onCall = (action, data) async {
      switch (action) {
        case 'coverage':
          if (coverageFailure != null) throw KrogerException(coverageFailure!);
          return {'covered': covered};
        case 'location':
          return {
            'location': serves
                ? {...store.toJson(), 'id': locations[data['zip']]}
                : null,
          };
        case 'search':
          return {
            'products': [if (found) product.toJson()],
          };
        case 'export_status':
          if (loadFailure != null) throw KrogerException(loadFailure!);
          return {'receipt': null};
        case 'export':
          exports++;
          if (ambiguous) throw const KrogerException('unavailable');
          return {
            'receipt': {'id': 'receipt', 'status': 'sent'},
          };
        default:
          return status ??
              {
                'available': true,
                'connected': true,
                'environment': 'certification',
                'receipt': null,
              };
      }
    };
    prefs = await SharedPreferences.getInstance();
    repo = KrogerRepository(prefs, remote);
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
        krogerAreaFinderProvider.overrideWith(
          (ref) =>
              () async => deviceArea,
        ),
      ],
    );
    container.listen(krogerControllerProvider(plan), (_, _) {});
    await container.read(shoppingListControllerProvider.future);
    await container.read(krogerControllerProvider(plan).future);
    controller = container.read(krogerControllerProvider(plan).notifier);
    await areaSettled();
  });
  tearDown(() => container.dispose());
  Future<void> restart() async {
    container.invalidate(krogerControllerProvider(plan));
    await container.read(krogerControllerProvider(plan).future);
    await areaSettled();
  }

  /// A shopper opening this for the first time with a device that will not
  /// say where they are: nothing resolved, nothing saved.
  Future<void> firstUse() async {
    deviceArea = null;
    await prefs.remove('kroger.draft.$account.$plan');
    await restart();
  }

  /// Pumps the screen on a surface tall enough to build the whole list. A
  /// `ListView` does not build its off-screen children, so on a phone-sized
  /// surface `findsNothing` cannot tell "not rendered" from "not scrolled to".
  Future<void> showScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: KrogerScreen(planId: plan)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reviewed() async {
    await controller.matchAll();
    await controller.approve(current().draft.lines.single.id);
  }

  group('the shopper is never asked to choose a Location', () {
    test('the area comes from the device, and the Location from the area', () {
      // Nothing was chosen and nothing was typed: the device said 35209 and
      // the Location follows from that and DELIVERY together.
      expect(current().area, '35209');
      expect(current().draft.store?.id, locations['35209']);
      expect(current().draft.modality, 'DELIVERY');
    });
    test('declining the permission leaves a typed postcode path', () async {
      await firstUse();
      expect(current().area, isNull);
      expect(current().draft.store, isNull);
      await controller.setArea('35209');
      expect(current().area, '35209');
      expect(current().draft.store?.id, locations['35209']);
    });
    test('a typed postcode must be a postcode', () async {
      await firstUse();
      await controller.setArea('nope');
      expect(current().message, 'invalid_zip');
      expect(current().draft.store, isNull);
    });
    test('an area no Location can serve at DELIVERY selects none', () async {
      // Coverage answers presence; only the filtered search knows whether a
      // Location will actually deliver. A Location that will not is no
      // Location at all, and is never quietly written to the draft.
      serves = false;
      await prefs.remove('kroger.draft.$account.$plan');
      await restart();
      expect(current().draft.store, isNull);
      expect(current().message, 'no_delivery_area');
    });
    test('neither the coordinates nor the postcode are persisted', () async {
      // Kroger's acceptable-use terms for Locations forbid storing data about
      // a customer's location. The resolved Location is ours to keep; where
      // the shopper is standing is not.
      deviceArea = '35242';
      await restart();
      expect(current().area, '35242');
      expect(
        jsonEncode(repo.load('user-a', plan).toJson()),
        isNot(contains('35242')),
      );
      // The Location survives a restart; the area it was resolved from does
      // not, and is asked for again rather than remembered.
      deviceArea = null;
      await restart();
      expect(current().area, isNull);
      expect(current().draft.store?.id, locations['35242']);
    });
    test(
      'a persisted Location still works when the area is not known',
      () async {
        // Persisting the Location has to buy the shopper something. Coming back
        // to a resolved draft with a device that says nothing, they can still
        // match against it without saying where they are all over again.
        deviceArea = null;
        await restart();
        expect(current().area, isNull);
        await controller.matchAll();
        expect(current().draft.lines.single.product?.upc, product.upc);
      },
    );
  });
  test('a new draft is for delivery', () async {
    // There is no Kroger in Birmingham, only a Spoke, and a Spoke only
    // delivers. Defaulting to pickup is what made the feature inert there.
    expect(current().draft.modality, 'DELIVERY');
  });
  test('a run that matched nothing says it matched nothing', () async {
    found = false;
    await controller.matchAll();
    expect(current().draft.lines.single.product, null);
    expect(current().message, 'no_products');
  });
  test('a run with nothing to match says nothing was selected', () async {
    (container.read(shoppingListControllerProvider.notifier) as TestShopping)
        .tickEverythingOff();
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await controller.matchAll();
    expect(current().message, 'all_skipped');
  });
  test('a Spoke product carries no price, never a zero one', () async {
    await controller.matchAll();
    expect(current().draft.lines.single.product?.price, null);
    expect(current().draft.estimate, 0);
    expect(current().draft.unknownPrices, 1);
  });
  group('a failure reason survives the initial load', () {
    test('an unavailable service reports its own reason', () async {
      for (final reason in const ['pro_required', 'not_configured']) {
        status = {
          'available': false,
          'connected': true,
          'environment': 'certification',
          'reason': reason,
        };
        await restart();
        expect(current().unavailableReason, reason, reason: reason);
        expect(current().available, false, reason: reason);
      }
    });
    test('and is not degraded by the next action', () async {
      status = {
        'available': false,
        'connected': true,
        'environment': 'certification',
        'reason': 'pro_required',
      };
      await prefs.remove('kroger.draft.$account.$plan');
      await restart();
      // matchAll fails on its own terms; that must not rewrite why the
      // service is unavailable in the first place.
      await controller.matchAll();
      expect(current().message, 'choose_store');
      expect(current().unavailableReason, 'pro_required');
    });
    test('a failing call reports its own code', () async {
      for (final code in const ['rate_limited', 'reconnect_required']) {
        loadFailure = code;
        await restart();
        expect(current().message, code, reason: code);
        expect(current().unavailableReason, code, reason: code);
      }
    });
  });
  test(
    'matching suggests package count but requires shopper approval',
    () async {
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
  test('a new delivery area clears the matches the old one made', () async {
    // Products are per-Location. Carrying a Spoke's matches into another
    // market would send the shopper things that market cannot supply.
    await reviewed();
    await controller.setArea('30301');
    expect(current().area, '30301');
    expect(current().draft.store?.id, locations['30301']);
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
      expect(current().draft.lines.single.requiredQty, '3 ct');
      expect(current().draft.lines.single.quantity, 3);
      expect(current().draft.lines.single.product?.upc, product.upc);
      expect(current().draft.ready, false);
    },
  );
  test('a late lookup cannot mutate the next account draft', () async {
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
  testWidgets('each failure cause says its own thing', (tester) async {
    // Every one of these used to render as "Kroger shopping is being set up",
    // which is a lie in three cases out of four.
    final copy = loadDefaultContent();
    for (final (cause, key) in const [
      ('pro_required', 'kroger.pro_required'),
      ('not_configured', 'kroger.not_configured'),
      ('rate_limited', 'kroger.rate_limited'),
      ('reconnect_required', 'kroger.reconnect_required'),
    ]) {
      if (cause == 'rate_limited' || cause == 'reconnect_required') {
        loadFailure = cause;
      } else {
        status = {
          'available': false,
          'connected': true,
          'environment': 'certification',
          'reason': cause,
        };
      }
      await tester.runAsync(restart);
      await showScreen(tester);
      expect(find.text(copy[key]!), findsWidgets, reason: cause);
      if (key != 'kroger.not_configured') {
        expect(
          find.text(copy['kroger.not_configured']!),
          findsNothing,
          reason: cause,
        );
      }
      loadFailure = null;
      status = null;
    }
  });
  testWidgets('a later failure is still reported to an unavailable session', (
    tester,
  ) async {
    // The body shows why the service is unavailable. It must not also swallow
    // what happens next: a rate limit while in that state has to be visible.
    final copy = loadDefaultContent();
    status = {
      'available': false,
      'connected': true,
      'environment': 'certification',
      'reason': 'pro_required',
    };
    await tester.runAsync(restart);
    await showScreen(tester);
    remote.onCall = (action, data) async =>
        throw const KrogerException('rate_limited');
    await tester.runAsync(controller.refresh);
    await tester.pumpAndSettle();
    expect(find.text(copy['kroger.rate_limited']!), findsWidgets);
  });
  testWidgets('no control is labelled with an error message', (tester) async {
    // "Choose a store first." explains a refusal. A button says what it does.
    final copy = loadDefaultContent();
    await showScreen(tester);
    for (final button in tester.widgetList<ButtonStyleButton>(
      find.byWidgetPredicate((w) => w is ButtonStyleButton),
    )) {
      final label = button.child;
      if (label is Text) {
        expect(
          const [
            'kroger.choose_store',
            'kroger.product_unavailable',
            'kroger.no_products',
            'kroger.review_required',
          ].map((k) => copy[k]),
          isNot(contains(label.data)),
        );
      }
    }
  });
  testWidgets('a control that cannot act is not rendered', (tester) async {
    // No delivery area resolved, so there is no Location to search and
    // nothing to match against.
    await tester.runAsync(firstUse);
    await showScreen(tester);
    final copy = loadDefaultContent();
    expect(find.byKey(const ValueKey('kroger.export')), findsNothing);
    expect(find.text(copy['kroger.choose']!), findsNothing);
    expect(find.text(copy['kroger.match_all']!), findsNothing);
    for (final button in tester.widgetList<ButtonStyleButton>(
      find.byWidgetPredicate((w) => w is ButtonStyleButton),
    )) {
      final label = button.child;
      expect(button.enabled, true, reason: label is Text ? label.data : '?');
    }
    await tester.runAsync(() async {
      await controller.setArea('35209');
      await reviewed();
    });
    await tester.pumpAndSettle();
    expect(current().message, isNull);
    expect(current().draft.ready, true);
    expect(find.byKey(const ValueKey('kroger.export')), findsOneWidget);
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
    expect(find.text('Broccoli'), findsOneWidget);
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

  /// Pumps the Shopping tab with Coverage already answered. The entry point is
  /// withheld until it is: a shopper Kroger cannot serve must never see the
  /// feature appear and then vanish.
  Future<void> showShopping(WidgetTester tester) async {
    await tester.runAsync(() => container.read(krogerCoverageProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ShoppingTab())),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('a market Kroger does not serve is never offered the feature', () {
    testWidgets('an empty Coverage hides the entry point', (tester) async {
      covered = false;
      await showShopping(tester);
      expect(find.byKey(const ValueKey('meal_planning.kroger')), findsNothing);
    });
    testWidgets('Coverage is answered without a Kroger account', (
      tester,
    ) async {
      // Nothing here is connected: the check is paid for by the application
      // token, so a shopper who has never authorized Kroger still gets an
      // answer — and, being served, still gets the feature.
      status = {
        'available': true,
        'connected': false,
        'environment': 'certification',
      };
      await tester.runAsync(restart);
      await showShopping(tester);
      expect(current().connected, false);
      expect(container.read(krogerCoverageProvider).value, true);
      expect(
        find.byKey(const ValueKey('meal_planning.kroger')),
        findsOneWidget,
      );
    });
    testWidgets('an unanswerable Coverage check keeps the entry point', (
      tester,
    ) async {
      // Unknown is not "no". Losing the feature because a check failed would
      // be worse than offering it and reporting the failure on the screen.
      coverageFailure = 'rate_limited';
      await showShopping(tester);
      expect(container.read(krogerCoverageProvider).value, isNull);
      expect(
        find.byKey(const ValueKey('meal_planning.kroger')),
        findsOneWidget,
      );
    });
  });
  testWidgets('Kroger icon action is above groceries and opens review', (
    tester,
  ) async {
    await showShopping(tester);
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

  group('the screen says where the groceries go, not which facility', () {
    testWidgets('it presents the delivery area', (tester) async {
      final copy = loadDefaultContent();
      await showScreen(tester);
      expect(
        find.text(
          ContentKeys.format(copy['kroger.delivery_to']!, {'area': '35209'}),
        ),
        findsOneWidget,
      );
      // "Kroger - - Birmingham Spoke", at 300 Delivery Way, is exactly what a
      // shopper must never be handed and told to drive to.
      expect(find.textContaining(store.name), findsNothing);
      expect(find.textContaining('300 Delivery Way'), findsNothing);
    });
    testWidgets('correcting the area asks for a postcode, not a Location', (
      tester,
    ) async {
      final copy = loadDefaultContent();
      await showScreen(tester);
      await tester.tap(find.text(copy['kroger.change_area']!));
      await tester.pumpAndSettle();
      expect(find.text(copy['kroger.zip']!), findsOneWidget);
      expect(find.textContaining(store.name), findsNothing);
      await tester.enterText(find.byType(TextField), '30301');
      await tester.tap(find.text(copy['kroger.continue']!));
      await tester.pumpAndSettle();
      expect(current().draft.store?.id, locations['30301']);
      expect(
        find.text(
          ContentKeys.format(copy['kroger.delivery_to']!, {'area': '30301'}),
        ),
        findsOneWidget,
      );
    });
    testWidgets('a known Location without a known area still offers matching', (
      tester,
    ) async {
      final copy = loadDefaultContent();
      deviceArea = null;
      await tester.runAsync(restart);
      await showScreen(tester);
      expect(find.text(copy['kroger.area_unknown']!), findsOneWidget);
      expect(find.text(copy['kroger.match_all']!), findsOneWidget);
    });
    testWidgets('a shopper with no resolved area is asked for one', (
      tester,
    ) async {
      final copy = loadDefaultContent();
      await tester.runAsync(firstUse);
      await showScreen(tester);
      expect(find.text(copy['kroger.area_unknown']!), findsOneWidget);
      expect(find.text(copy['kroger.set_area']!), findsOneWidget);
    });
  });
}
