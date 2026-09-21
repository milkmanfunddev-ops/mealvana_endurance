/// RevenueCat offerings in the shape the SDK's native bridge hands to
/// `Offerings.fromJson` — the producer side of the paywall's seam
/// (docs/test/README.md, Seam tests). Mirrors the dev project as configured
/// on 2026-09-21: the `default` offering sells `me_pro_monthly` ($24.99) and
/// `me_pro_annual` ($199.99), the `founding` offering sells
/// `me_pro_monthly_founding` ($12.49) and `me_pro_annual_founding` ($99.99),
/// both under the same `$rc_monthly` / `$rc_annual` package slots, every
/// product with a seven-day free intro offer (mp-452).
library;

import 'package:purchases_flutter/purchases_flutter.dart';

Map<String, dynamic> _freeWeek() => {
  'price': 0,
  'priceString': r'$0.00',
  'period': 'P1W',
  'cycles': 1,
  'periodUnit': 'WEEK',
  'periodNumberOfUnits': 1,
};

Map<String, dynamic> _package({
  required String offering,
  required String slot,
  required String sku,
  required double price,
  required String priceString,
  bool intro = true,
}) {
  final monthly = slot == r'$rc_monthly';
  final context = {'offeringIdentifier': offering};
  return {
    'identifier': slot,
    'packageType': monthly ? 'MONTHLY' : 'ANNUAL',
    'presentedOfferingContext': context,
    'product': {
      'identifier': sku,
      'description': '',
      'title': monthly ? 'Monthly' : 'Annual',
      'price': price,
      'priceString': priceString,
      'currencyCode': 'USD',
      'introPrice': intro ? _freeWeek() : null,
      'productCategory': 'SUBSCRIPTION',
      'subscriptionPeriod': monthly ? 'P1M' : 'P1Y',
      'presentedOfferingContext': context,
    },
  };
}

Map<String, dynamic> _offering(
  String id,
  Map<String, dynamic> monthly,
  Map<String, dynamic> annual,
) => {
  'identifier': id,
  'serverDescription': id,
  'metadata': <String, Object>{},
  'availablePackages': [monthly, annual],
  'monthly': monthly,
  'annual': annual,
};

Map<String, dynamic> defaultOfferingJson() => _offering(
  'default',
  _package(
    offering: 'default',
    slot: r'$rc_monthly',
    sku: 'me_pro_monthly',
    price: 24.99,
    priceString: r'$24.99',
  ),
  _package(
    offering: 'default',
    slot: r'$rc_annual',
    sku: 'me_pro_annual',
    price: 199.99,
    priceString: r'$199.99',
  ),
);

Map<String, dynamic> foundingOfferingJson() => _offering(
  'founding',
  _package(
    offering: 'founding',
    slot: r'$rc_monthly',
    sku: 'me_pro_monthly_founding',
    price: 12.49,
    priceString: r'$12.49',
  ),
  _package(
    offering: 'founding',
    slot: r'$rc_annual',
    sku: 'me_pro_annual_founding',
    price: 99.99,
    priceString: r'$99.99',
  ),
);

/// Both offerings on the project; [current] names the one made current in
/// the dashboard (null: none marked current).
Offerings offeringsFixture({String? current = 'default'}) {
  final all = {
    'default': defaultOfferingJson(),
    'founding': foundingOfferingJson(),
  };
  return Offerings.fromJson({
    'all': all,
    'current': current == null ? null : all[current],
  });
}

/// One offering parsed through the SDK's own decoder.
Offering offeringFixture(String id) => Offering.fromJson(
  id == 'founding' ? foundingOfferingJson() : defaultOfferingJson(),
);
