/// The credit packs provisioned in the stores, keyed by store product id.
///
/// This map is the single client-side source of truth for "how many credits
/// does this SKU grant". It must stay in step with `DEFAULT_PRODUCT_BUDGET` in
/// `supabase/functions/_shared/ai/allowance.ts`, which the RevenueCat webhook
/// grants from in micro-dollars (2 cents a credit since ai-cost ticket 09) —
/// the client value is display-only.
///
/// Anything not listed here is still purchasable; the UI simply falls back to
/// the store's own product title rather than inventing a credit count.
/// Pack sizes are set by the Sonnet 4.6 unit economics, not by round numbers:
/// worst-case ~$0.013 per analysis (Notion "AI Features — Cost Accounting &
/// Token Pricing", §5 Scenario B), against Apple's 15% small-business cut which
/// nets $4.24 on $4.99 and $16.99 on $19.99. 50 and 250 are the high-margin
/// row of that table ($3.59 and $13.74 profit per pack). Re-derive these if the
/// meal-analysis model changes — Haiku is ~3x cheaper per token and would
/// support materially larger packs at the same price.
const Map<String, int> kCreditsByProductId = {
  'mealvana_credits_50': 50,
  'mealvana_credits_250': 250,
  // Prod App Store SKUs. The dev app owns the plain ids above (Apple rejects a
  // product id any app in the team has ever claimed), so the production app
  // sells `_prod` variants — same packs, same packages, per-app products.
  'mealvana_credits_50_prod': 50,
  'mealvana_credits_250_prod': 250,
  // Pipeline-test pack: $0.99 for 1 credit, tester-only (see
  // kTesterOnlyProductIds). It exists so the full money path — StoreKit sheet
  // → RevenueCat receipt → revenuecat-webhook → wallet grant — can be
  // exercised for under a dollar, in sandbox on dev builds and for real on a
  // 7-tap tester device once a production release carries the SKU.
  'mealvana_credits_test_1': 1,
  // Same pack, prod App Store SKU. Apple rejects a product id that any app in
  // the team has ever claimed, and the dev app owns the plain id — so the
  // production app carries a `_prod` variant. One RevenueCat package
  // ($rc_custom_credits_test_1) holds both; each app is served its own.
  'mealvana_credits_test_1_prod': 1,
};

/// SKUs that must never be shown to regular users.
///
/// `visibleCreditPackages` hides these unless the build is a dev flavor or the
/// device is flagged internal via the 7-tap tester reveal in Settings. The
/// products stay live in the stores either way — hiding is a client-side
/// display rule, which is what lets a tester buy the $0.99 pack on the
/// production app after release while nobody else ever sees it.
const Set<String> kTesterOnlyProductIds = {
  'mealvana_credits_test_1',
  'mealvana_credits_test_1_prod',
};

/// Credits granted by [productId], or null when the SKU is unknown to this
/// build (e.g. a pack added to the store after this version shipped).
int? creditsForProductId(String productId) => kCreditsByProductId[productId];

/// What a pack adds, as a share of a month of Vana (mp-430 clause 7).
///
/// Since ai-cost ticket 09 a pack adds budget, not credits: $4.99 adds a
/// quarter of a month ($1.00 of the $4.00 monthly budget) and $19.99 adds a
/// month and a quarter ($5.00). This map is the display unit for both; the
/// grant itself is `DEFAULT_PRODUCT_BUDGET` in `allowance.ts` and this side
/// never sends a number to the server. Prices stay as the store shows them,
/// so nothing here is a price.
///
/// The $0.99 pipeline-test pack adds one old credit's worth (2 cents), which
/// is half a percent of a month — "a sliver", because a percentage that
/// rounds to nothing reads as a bug.
const Map<String, double> kPackShareOfMonthByProductId = {
  'mealvana_credits_50': 0.25,
  'mealvana_credits_250': 1.25,
  'mealvana_credits_50_prod': 0.25,
  'mealvana_credits_250_prod': 1.25,
  'mealvana_credits_test_1': 0.005,
  'mealvana_credits_test_1_prod': 0.005,
};

/// The content key that names what [productId] adds, or null for a SKU this
/// build does not know — the sheet then falls back to the store's own product
/// title rather than inventing a unit.
const Map<String, String> kPackContentKeyByProductId = {
  'mealvana_credits_50': 'ai_credits.pack_quarter_month',
  'mealvana_credits_250': 'ai_credits.pack_month_and_quarter',
  'mealvana_credits_50_prod': 'ai_credits.pack_quarter_month',
  'mealvana_credits_250_prod': 'ai_credits.pack_month_and_quarter',
  'mealvana_credits_test_1': 'ai_credits.pack_sliver',
  'mealvana_credits_test_1_prod': 'ai_credits.pack_sliver',
};

/// The share of a month [productId] adds, or null when the SKU is unknown.
double? packShareForProductId(String productId) =>
    kPackShareOfMonthByProductId[productId];

/// The content key naming what [productId] adds, or null when unknown.
String? packContentKeyForProductId(String productId) =>
    kPackContentKeyByProductId[productId];
