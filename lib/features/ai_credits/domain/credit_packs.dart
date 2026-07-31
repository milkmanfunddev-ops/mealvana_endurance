/// The credit packs provisioned in the stores, keyed by store product id.
///
/// This map is the single client-side source of truth for "how many credits
/// does this SKU grant". It must stay in step with `RC_PRODUCT_CREDITS` in
/// `supabase/functions/revenuecat-webhook/index.ts`, which performs the actual
/// server-side grant — the client value is display-only.
///
/// Anything not listed here is still purchasable; the UI simply falls back to
/// the store's own product title rather than inventing a credit count.
const Map<String, int> kCreditsByProductId = {
  'mealvana_credits_100': 100,
  'mealvana_credits_500': 500,
  'mealvana_credits_1200': 1200,
};

/// Credits granted by [productId], or null when the SKU is unknown to this
/// build (e.g. a pack added to the store after this version shipped).
int? creditsForProductId(String productId) => kCreditsByProductId[productId];
