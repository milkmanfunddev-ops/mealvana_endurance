/// Kroger payloads for the Flutter seam tests.
///
/// The repo's seam rule (`docs/test/README.md`) wants producer-shaped data.
/// The controller's producer is the edge function, so these read the captured
/// Kroger responses in `supabase/functions/_shared/kroger/fixtures/` — the
/// same files the Deno suite reads — and apply the mapping the edge function
/// applies. The UPC, pack size and price a seam test feeds the controller are
/// then the ones Kroger returned, and cannot drift from them by being retyped.
///
/// The hand-written product this replaced had a price and `available: true`,
/// which is the fixture shape that hid the delivery bug.
library;

import 'dart:convert';
import 'dart:io';

import 'package:mealvana_endurance/features/kroger/domain/kroger_models.dart';

const _dir = 'supabase/functions/_shared/kroger/fixtures';

/// Read relative to the package root, which is where `flutter test` runs.
Map<String, dynamic> _payload(String name) {
  final file = File('$_dir/$name.json');
  if (!file.existsSync()) {
    throw StateError(
      'Missing ${file.path}. Run flutter test from the repo root.',
    );
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// The edge function's product for the first item of a captured `/products`
/// response. Availability follows the request's fulfillment filter, so a
/// product present in the payload is available unless it is out of stock.
///
/// This mirrors `productFromApi` in
/// `supabase/functions/_shared/kroger/catalog.ts` — the price pick, the
/// out-of-stock rule, the featured-image walk. Change that and change this;
/// nothing here will fail on its own if the two drift.
KrogerProduct krogerProductFixture(String name) {
  final raw = (_payload(name)['data'] as List).first as Map<String, dynamic>;
  final item = (raw['items'] as List).first as Map<String, dynamic>;
  final price = item['price'] as Map<String, dynamic>?;
  final promo = (price?['promo'] as num?)?.toDouble() ?? 0;
  final image =
      ((raw['images'] as List?)?.first as Map<String, dynamic>?)?['sizes']
          as List?;
  return KrogerProduct(
    upc: raw['upc'] as String,
    name: raw['description'] as String,
    brand: raw['brand'] as String? ?? '',
    size: item['size'] as String? ?? '',
    price: promo > 0 ? promo : (price?['regular'] as num?)?.toDouble(),
    available:
        (item['inventory'] as Map?)?['stockLevel'] !=
        'TEMPORARILY_OUT_OF_STOCK',
    image: (image?.first as Map<String, dynamic>?)?['url'] as String?,
  );
}

/// The edge function's store for the first Location of a captured
/// `/locations` response.
KrogerStore krogerStoreFixture(String name) {
  final raw = (_payload(name)['data'] as List).first as Map<String, dynamic>;
  final address = raw['address'] as Map<String, dynamic>;
  return KrogerStore(
    id: raw['locationId'] as String,
    name: raw['name'] as String,
    address: [
      address['addressLine1'],
      address['city'],
      address['state'],
    ].whereType<String>().join(', '),
  );
}

/// Birmingham 35209: delivery only, no price for anything, and fulfillment
/// booleans that claim curbside for an item curbside will not return.
final spokeProduct = krogerProductFixture('spoke_product');

/// The same item id at a real Store: priced, and a different pack size.
final storeProduct = krogerProductFixture('store_product');

/// The one Location postcode 35209 returns — a Spoke, zero departments.
final spokeStore = krogerStoreFixture('locations_delivery_only');
