import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthRetryableFetchException, PostgrestException;
import 'package:url_launcher/url_launcher.dart';
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

  /// Two things to buy, one of which Kroger will not match.
  void twoItems() => state = const AsyncData(
    ShoppingListState(
      planId: plan,
      items: [
        ShoppingItem(aisle: 'Produce', name: 'Broccoli', qty: '2 ct'),
        ShoppingItem(aisle: 'Bakery', name: 'Bread', qty: '1 ct'),
      ],
    ),
  );

  /// One item already in the cupboard, one still to buy.
  void tickOneOff() => state = const AsyncData(
    ShoppingListState(
      planId: plan,
      items: [
        ShoppingItem(
          aisle: 'Produce',
          name: 'Broccoli',
          qty: '2 ct',
          checked: true,
        ),
        ShoppingItem(aisle: 'Bakery', name: 'Bread', qty: '1 ct'),
      ],
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
  late Map<String, KrogerProduct> catalog;
  late Set<String> unmatchable;
  late Set<String> unreachable;
  late List<String> searches;
  Map<String, dynamic>? sent;
  Map<String, dynamic>? receipt;
  late List<(Uri, LaunchMode)> launches;
  late Set<LaunchMode> installed;
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
    // Each Location has its own catalogue. The Spoke's Broccoli has no price
    // and comes by the count; the Store's has a price and comes by weight.
    catalog = {locations['35242']!: storeProduct};
    unmatchable = {};
    unreachable = {};
    searches = [];
    sent = null;
    receipt = null;
    launches = [];
    // Both a Kroger app and a browser to fall back on, until a test says
    // otherwise.
    installed = {
      LaunchMode.externalNonBrowserApplication,
      LaunchMode.externalApplication,
    };
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
          searches.add(data['query'] as String);
          if (unreachable.contains(data['query'])) {
            throw const KrogerException('rate_limited');
          }
          return {
            'products': [
              if (found && !unmatchable.contains(data['query']))
                (catalog[data['store'] as String] ?? product).toJson(),
            ],
          };
        case 'export_status':
          if (loadFailure != null) throw KrogerException(loadFailure!);
          // A sent draft stays sent across a reload, as the server's does.
          return {'receipt': receipt};
        case 'export':
          exports++;
          sent = data;
          if (ambiguous) throw const KrogerException('unavailable');
          receipt = {'id': 'receipt', 'status': 'sent'};
          return {'receipt': receipt};
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
        krogerLauncherProvider.overrideWith(
          (ref) => (url, mode) async {
            launches.add((url, mode));
            return installed.contains(mode);
          },
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

  /// Lets a change to the shopping list reach the draft: the controller
  /// listens for it and reconciles off the listener, not the call.
  Future<void> sourceChanged() async {
    await container.pump();
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> restart() async {
    container.invalidate(krogerControllerProvider(plan));
    await container.read(krogerControllerProvider(plan).future);
    await areaSettled();
  }

  /// The one environment whose cart is the shopper's own. Certification's is
  /// not at kroger.com, so nothing is ever handed off to it.
  Future<void> inProduction() async {
    status = {
      'available': true,
      'connected': true,
      'environment': 'production',
    };
    await restart();
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
        child: MaterialApp.router(routerConfig: _router('/food/kroger/$plan')),
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
    await sourceChanged();
    await controller.matchAll();
    expect(current().message, 'all_skipped');
  });
  test('a Spoke product carries no price, never a zero one', () async {
    await controller.matchAll();
    expect(current().draft.lines.single.product?.price, null);
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
  group('a failure is blamed on what actually failed', () {
    Future<void> failingWith(Object error) async {
      remote.onCall = (action, data) async => throw error;
      await restart();
    }

    test('a request that never got an answer could not reach Kroger', () async {
      for (final error in [
        http.ClientException('Connection refused'),
        // Offline with an expired session: the refresh before the request
        // fails first, and gotrue reports it as this.
        AuthRetryableFetchException(message: 'Connection refused'),
      ]) {
        await failingWith(error);
        expect(current().message, 'unavailable', reason: '$error');
        expect(current().unavailableReason, 'unavailable', reason: '$error');
      }
    });
    test('anything else went wrong on this side', () async {
      for (final error in [
        StateError('bug'),
        const PostgrestException(message: 'boom'),
      ]) {
        await failingWith(error);
        expect(current().message, 'unexpected', reason: '$error');
      }
    });
    test('an action that fails the same way says the same', () async {
      remote.onCall = (action, data) async => throw StateError('bug');
      await controller.refresh();
      expect(current().message, 'unexpected');
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
      await sourceChanged();
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
    expect(await search, isEmpty);
    expect(repo.load('user-b', plan).lines.single.product, null);
  });
  group('sending once, and handing off once', () {
    test('the sign-in the shopper completed is shared, not thrown away', () {
      // An ephemeral session keeps the Kroger sign-in inside the OAuth
      // browser and drops it afterwards, so the Hand-off would land on a
      // Kroger that has never heard of them and ask them to sign in again.
      expect(krogerAuthOptions.preferEphemeral, isFalse);
    });
    test('a successful send takes the shopper to Kroger', () async {
      await inProduction();
      await reviewed();
      await controller.export();
      expect(current().draft.receiptStatus, 'sent');
      expect(launches.first.$1, Uri.parse('https://www.kroger.com/cart'));
    });
    test('the Kroger app is opened when it is installed', () async {
      await inProduction();
      await reviewed();
      installed = {LaunchMode.externalNonBrowserApplication};
      await controller.export();
      expect(launches.map((l) => l.$2), [
        LaunchMode.externalNonBrowserApplication,
      ]);
    });
    test('and the system browser when it is not', () async {
      // Where they are already signed in, because the OAuth step no longer
      // asks for a session of its own.
      await inProduction();
      await reviewed();
      installed = {LaunchMode.externalApplication};
      await controller.export();
      expect(launches.map((l) => l.$2), [
        LaunchMode.externalNonBrowserApplication,
        LaunchMode.externalApplication,
      ]);
    });
    test('a Hand-off that cannot open Kroger is not a failed send', () async {
      // The items are in the cart either way. Reporting the send as broken
      // because a launch failed would send the shopper back to do it twice.
      await inProduction();
      await reviewed();
      installed = {};
      await controller.export();
      expect(current().draft.receiptStatus, 'sent');
      expect(current().message, isNull);
    });
    test('nothing is handed off to a certification cart', () async {
      await reviewed();
      await controller.export();
      expect(current().draft.receiptStatus, 'sent');
      expect(launches, isEmpty);
    });
    test('a sent draft is sent again only when asked outright', () async {
      await reviewed();
      await controller.export();
      await controller.export();
      expect(exports, 1);
      await controller.export(resend: true);
      expect(exports, 2);
      expect(sent!['resend'], true);
    });
    test('an ambiguous send is not offered a second one', () async {
      // The screen says it cannot tell what reached the cart. Offering to
      // send it all again under those words would be the app guessing on the
      // shopper's behalf; Kroger's own cart is where this one is settled.
      await reviewed();
      ambiguous = true;
      await controller.export();
      expect(current().draft.receiptStatus, 'sending');
      expect(current().draft.sent, false);
      await controller.export(resend: true);
      expect(exports, 1);
    });
    testWidgets('and no control to do it with', (tester) async {
      await tester.runAsync(() async {
        await reviewed();
        ambiguous = true;
        await controller.export();
      });
      await showScreen(tester);
      expect(find.byKey(const ValueKey('kroger.export_again')), findsNothing);
      expect(find.byKey(const ValueKey('kroger.export')), findsNothing);
    });
    testWidgets(
      'the second send is behind a confirmation that says what it does',
      (tester) async {
        final copy = loadDefaultContent();
        await tester.runAsync(() async {
          await reviewed();
          await controller.export();
        });
        await showScreen(tester);
        // The plain send is gone: a sent draft is a record, not something to
        // tap again by accident.
        expect(find.byKey(const ValueKey('kroger.export')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('kroger.export_again')));
        await tester.pumpAndSettle();
        expect(find.text(copy['kroger.send_again_confirm']!), findsOneWidget);
        await tester.tap(find.text(copy['kroger.cancel']!));
        await tester.pumpAndSettle();
        expect(exports, 1);
        await tester.tap(find.byKey(const ValueKey('kroger.export_again')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(copy['kroger.continue']!));
        await tester.pumpAndSettle();
        expect(exports, 2);
      },
    );
    test('Kroger is never embedded, and payment is never handled here', () {
      // Mealvana takes the shopper to Kroger and stops. Embedding Kroger's
      // site takes a webview package, and a webview carries a cookie jar of
      // its own — which is a second sign-in, and Mealvana standing between
      // the shopper and Kroger's checkout. What the feature imports is the
      // evidence: nothing can be embedded that was never depended on.
      final imports = Directory('lib/features/kroger')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .expand(
            (f) => RegExp(
              r"^import '([^']+)'",
              multiLine: true,
            ).allMatches(f.readAsStringSync()).map((m) => m.group(1)!),
          )
          .toList();
      expect(imports, isNotEmpty);
      for (final package in const [
        'webview',
        'inappwebview',
        'in_app_browser',
        'pay',
        'stripe',
      ]) {
        expect(
          imports.where((i) => i.contains(package)),
          isEmpty,
          reason: package,
        );
      }
    });
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
  testWidgets('a code the app has no copy for does not blame Kroger', (
    tester,
  ) async {
    // The 2026-09-10 simulator pass: a function three tickets behind the app
    // answered `invalid_action`, and the shopper read that Kroger was down.
    final copy = loadDefaultContent();
    await showScreen(tester);
    remote.onCall = (action, data) async =>
        throw const KrogerException('invalid_action');
    await tester.runAsync(controller.refresh);
    await tester.pumpAndSettle();
    expect(find.text(copy['kroger.unexpected']!), findsWidgets);
    expect(find.textContaining('Kroger could not be reached'), findsNothing);
  });
  testWidgets('no control is labelled with an error message', (tester) async {
    // "Choose a store first." explains a refusal. A button says what it does.
    final copy = loadDefaultContent();
    await showScreen(tester);
    final forbidden = const [
      'kroger.choose_store',
      'kroger.product_unavailable',
      'kroger.no_products',
      'kroger.review_required',
    ].map((k) => copy[k]).toList();
    final buttons = find.byWidgetPredicate((w) => w is ButtonStyleButton);
    expect(buttons, findsWidgets);
    for (final label in tester.widgetList<Text>(
      find.descendant(of: buttons, matching: find.byType(Text)),
    )) {
      expect(forbidden, isNot(contains(label.data)));
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
      expect(button.enabled, true);
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
    await showScreen(tester);
    expect(find.text('Broccoli'), findsOneWidget);
    final copy = loadDefaultContent();
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
        child: MaterialApp.router(routerConfig: _router('/')),
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

  group('the shopper sees the match before anything is sent', () {
    /// A list where one line matches and one cannot, which is the ordinary
    /// case: a Spoke's catalogue does not cover a whole week's shopping.
    Future<void> twoLines() async {
      unmatchable = {'Bread'};
      (container.read(shoppingListControllerProvider.notifier) as TestShopping)
          .twoItems();
      await sourceChanged();
    }

    String lineId(String name) =>
        current().draft.lines.firstWhere((l) => l.name == name).id;
    final matched = find.byKey(const ValueKey('kroger.matched'));
    final unmatched = find.byKey(const ValueKey('kroger.unmatched'));
    final unsearched = find.byKey(const ValueKey('kroger.unsearched'));
    List<String> names(List<KrogerLine> lines) =>
        lines.map((l) => l.name).toList();

    test('nothing is said to have no match before anything is searched', () {
      // setUp resolved a Location and ran no search. "Kroger has no match"
      // is a claim about a search, and there has not been one.
      expect(searches, isEmpty);
      expect(current().draft.unmatched, isEmpty);
      expect(names(current().draft.unsearched), ['Broccoli']);
    });
    test(
      'after a run, only what Kroger returned nothing for is unmatched',
      () async {
        await twoLines();
        await controller.matchAll();
        expect(names(current().draft.matched), ['Broccoli']);
        expect(names(current().draft.unmatched), ['Bread']);
        expect(current().draft.unsearched, isEmpty);
      },
    );
    test(
      'a run that fails partway leaves unreached lines unanswered',
      () async {
        // Broccoli is searched and Kroger has nothing; the run fails on Bread.
        // Bread was never answered, so it is not Kroger's to have no match for.
        await twoLines();
        unmatchable = {'Broccoli'};
        unreachable = {'Bread'};
        await controller.matchAll();
        expect(current().message, 'rate_limited');
        expect(names(current().draft.unmatched), ['Broccoli']);
        expect(names(current().draft.unsearched), ['Bread']);
        // And the answer it did get is kept, not just shown.
        expect(names(repo.load(account, plan).unmatched), ['Broccoli']);
      },
    );
    test('a search the shopper runs for a line answers for it too', () async {
      await twoLines();
      await controller.search(lineId('Bread'), 'Bread');
      expect(current().message, 'no_products');
      expect(names(current().draft.unmatched), ['Bread']);
      expect(names(current().draft.unsearched), ['Broccoli']);
    });
    test('a new Location takes the old answers with it', () async {
      // Catalogues are per-Location: the Spoke having no bread says nothing
      // about what the next Location has.
      await twoLines();
      await controller.matchAll();
      await controller.setArea('30301');
      expect(current().draft.unmatched, isEmpty);
      expect(names(current().draft.unsearched), ['Broccoli', 'Bread']);
    });
    test(
      'a search that could not run shows no results, not old ones',
      () async {
        // 2026-09-10: a search refused while another action held the controller
        // left the screen reading the previous line's results, and a tap on one
        // chose it for this line.
        await twoLines();
        expect(await controller.search(lineId('Broccoli'), 'Broccoli'), [
          isA<KrogerProduct>(),
        ]);
        final held = Completer<Map<String, dynamic>>();
        final answer = remote.onCall!;
        remote.onCall = (action, data) =>
            action == 'status' ? held.future : answer(action, data);
        final refresh = controller.refresh();
        expect(await controller.search(lineId('Bread'), 'Bread'), isEmpty);
        held.complete(await answer('status', const {}));
        await refresh;
        expect(current().draft.lines.every((l) => l.product == null), true);
      },
    );
    test(
      'a different query that finds something takes the answer away',
      () async {
        // The answer was about what was searched for, and that has changed.
        await twoLines();
        await controller.search(lineId('Bread'), 'Bread');
        expect(names(current().draft.unmatched), ['Bread']);
        expect(
          await controller.search(lineId('Bread'), 'Sourdough'),
          isNotEmpty,
        );
        expect(current().draft.unmatched, isEmpty);
        expect(names(current().draft.unsearched), ['Broccoli', 'Bread']);
      },
    );
    test('a different Kroger environment takes the answers with it', () async {
      await twoLines();
      await controller.matchAll();
      expect(names(current().draft.unmatched), ['Bread']);
      await inProduction();
      expect(current().draft.unmatched, isEmpty);
      expect(names(current().draft.unsearched), ['Broccoli', 'Bread']);
    });
    test('choosing a product answers the line', () async {
      await twoLines();
      await controller.matchAll();
      await controller.choose(lineId('Bread'), product);
      expect(current().draft.unmatched, isEmpty);
      expect(names(current().draft.matched), ['Broccoli', 'Bread']);
    });
    test(
      'a draft stored before answers were recorded is not matched yet',
      () async {
        // No migration: a line without the flag reads as unanswered, which is
        // the one thing that is true of it. The draft is written out in the
        // shape the app stored before the flag existed, on the device and in
        // the cloud row alike.
        final legacy = {
          'planId': plan,
          'store': {...store.toJson(), 'id': locations['35209']},
          'modality': 'DELIVERY',
          'environment': 'certification',
          'lines': [
            {
              'id': KrogerLine.sourceId(plan, 'Broccoli'),
              'name': 'Broccoli',
              'requiredQty': '2 ct',
              'product': null,
              'quantity': 1,
              'quantityEdited': false,
              'approved': false,
              'excluded': false,
              'sourceExcluded': false,
              'manual': false,
            },
          ],
          'revision': 1,
          'dirty': false,
          'receiptStatus': null,
        };
        await prefs.setString(
          'kroger.draft.$account.$plan',
          jsonEncode(legacy),
        );
        await restart();
        expect(current().draft.unmatched, isEmpty);
        expect(names(current().draft.unsearched), ['Broccoli']);
        await prefs.remove('kroger.draft.$account.$plan');
        remote.onLoad = (_) async => {'revision': 1, 'draft': legacy};
        await restart();
        expect(current().draft.unmatched, isEmpty);
        expect(names(current().draft.unsearched), ['Broccoli']);
      },
    );
    testWidgets('before a run the screen promises nothing about Kroger', (
      tester,
    ) async {
      final copy = loadDefaultContent();
      await tester.runAsync(twoLines);
      await showScreen(tester);
      expect(unmatched, findsNothing);
      expect(find.text(copy['kroger.unmatched_note']!), findsNothing);
      expect(
        find.descendant(
          of: unsearched,
          matching: find.text(copy['kroger.unsearched_heading']!),
        ),
        findsOneWidget,
      );
      for (final name in ['Broccoli', 'Bread']) {
        expect(
          find.descendant(of: unsearched, matching: find.text(name)),
          findsOneWidget,
        );
      }
      // The action that answers them is on the screen with them.
      expect(find.text(copy['kroger.match_all']!), findsOneWidget);
    });

    testWidgets('a matched line carries Kroger\'s product name and pack size', (
      tester,
    ) async {
      // Exactly as Kroger returned it. Kroger's terms forbid altering the
      // data, and a shopper approving "Broccoli" cannot tell which broccoli
      // is coming.
      await tester.runAsync(controller.matchAll);
      await showScreen(tester);
      final copy = loadDefaultContent();
      // The literal is Kroger's own `description` from the captured payload,
      // so a trim, a titlecase or an appended brand on the way to the screen
      // fails here.
      expect(product.name, 'Broccoli Crowns');
      expect(
        find.descendant(of: matched, matching: find.text(product.name)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: matched,
          matching: find.text(
            ContentKeys.format(copy['kroger.package']!, {'size': '1 ct'}),
          ),
        ),
        findsOneWidget,
      );
    });
    testWidgets('what did not match is listed plainly and on its own', (
      tester,
    ) async {
      final copy = loadDefaultContent();
      await tester.runAsync(twoLines);
      await tester.runAsync(controller.matchAll);
      await showScreen(tester);
      expect(
        find.descendant(of: unmatched, matching: find.text('Bread')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: unmatched,
          matching: find.text(copy['kroger.unmatched_note']!),
        ),
        findsOneWidget,
      );
      expect(unsearched, findsNothing);
      expect(
        find.descendant(of: matched, matching: find.text('Bread')),
        findsNothing,
      );
      expect(
        find.descendant(of: matched, matching: find.text('Broccoli')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: unmatched, matching: find.text('Broccoli')),
        findsNothing,
      );
    });
    testWidgets('the unmatched list is still there after the Hand-off', (
      tester,
    ) async {
      // The shopper is on Kroger's site adding these by hand. Switching back
      // to a screen that has forgotten them would be the app losing the one
      // piece of work it left them.
      await tester.runAsync(() async {
        await twoLines();
        await controller.matchAll();
        await controller.approve(lineId('Broccoli'));
        await controller.export();
        await restart();
      });
      expect(current().draft.exported, true);
      await showScreen(tester);
      expect(
        find.descendant(of: unmatched, matching: find.text('Bread')),
        findsOneWidget,
      );
    });
    testWidgets('no price and no cost estimate appears anywhere', (
      tester,
    ) async {
      // Deliberately at the Location whose catalogue *does* carry a price:
      // a Spoke's priceless one would let a leftover price widget pass.
      // Kroger's terms forbid comparative pricing, and a delivery Location
      // publishes none, so no price is shown at all.
      final copy = loadDefaultContent();
      await tester.runAsync(() async {
        await controller.setArea('35242');
        await controller.matchAll();
      });
      expect(current().draft.lines.single.product?.price, 2.19);
      await showScreen(tester);
      expect(find.textContaining('2.19'), findsNothing);
      expect(find.textContaining(r'$'), findsNothing);
      expect(find.textContaining('stimate'), findsNothing);
      // Including in the product picker, which listed a price of its own.
      await tester.tap(find.text(copy['kroger.change']!));
      await tester.pumpAndSettle();
      await tester.tap(find.text(copy['kroger.continue']!));
      await tester.pumpAndSettle();
      expect(find.text(storeProduct.name), findsWidgets);
      expect(find.textContaining('2.19'), findsNothing);
      expect(find.textContaining(r'$'), findsNothing);
    });
    testWidgets('one match can still be corrected, skipped and restored', (
      tester,
    ) async {
      // Per-line correction is no longer the path the shopper is expected to
      // take, but it is still there — and a line taken out of the order has
      // to be findable, or taking it out is a one-way door.
      final copy = loadDefaultContent();
      await tester.runAsync(controller.matchAll);
      await showScreen(tester);
      await tester.tap(
        find.descendant(
          of: matched,
          matching: find.byIcon(FontAwesomeIcons.plus.data),
        ),
      );
      await tester.pumpAndSettle();
      expect(current().draft.lines.single.quantity, 3);
      await tester.tap(find.text(copy['kroger.skip']!));
      await tester.pumpAndSettle();
      expect(matched, findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('kroger.skipped')),
          matching: find.text('Broccoli'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(copy['kroger.include']!));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: matched, matching: find.text('Broccoli')),
        findsOneWidget,
      );
    });
    test('a price is never carried over from another Location', () async {
      // Kroger forbids substituting one Location's price for another's, and
      // an approved choice is remembered per Location. What comes back from
      // the Spoke is the Spoke's product, priceless and sold by the count.
      await controller.setArea('35242');
      await controller.matchAll();
      expect(current().draft.lines.single.product?.price, 2.19);
      await controller.approve(current().draft.lines.single.id);
      await controller.setArea('35209');
      await controller.matchAll();
      expect(current().draft.lines.single.product?.price, isNull);
      expect(current().draft.lines.single.product?.size, '1 ct');
    });
    test('a line already ticked off is never searched for', () async {
      (container.read(shoppingListControllerProvider.notifier) as TestShopping)
          .tickOneOff();
      await sourceChanged();
      searches.clear();
      await controller.matchAll();
      expect(searches, ['Bread']);
    });
    test('sending sends what matched, and only that', () async {
      await twoLines();
      await controller.matchAll();
      await controller.approve(lineId('Broccoli'));
      expect(current().draft.ready, true);
      await controller.export();
      expect(current().draft.receiptStatus, 'sent');
      expect((sent!['items'] as List).single['upc'], product.upc);
    });
  });
}

/// The two screens under test, wired the way the app wires them: the Shopping
/// tab at the root and Kroger under `/food`, so tapping the entry point
/// exercises the real route rather than a Navigator push the app no longer
/// makes.
GoRouter _router(String initialLocation) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(body: ShoppingTab()),
      routes: [
        GoRoute(
          path: 'food/kroger/:planId',
          builder: (_, state) =>
              KrogerScreen(planId: state.pathParameters['planId']!),
        ),
      ],
    ),
  ],
);
