/// The credit packs provisioned in the stores, keyed by store product id.
///
/// This map is the single client-side source of truth for "how many credits
/// does this SKU grant". It must stay in step with `RC_PRODUCT_CREDITS` in
/// `supabase/functions/revenuecat-webhook/index.ts`, which performs the actual
/// server-side grant — the client value is display-only.
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
};

/// Credits granted by [productId], or null when the SKU is unknown to this
/// build (e.g. a pack added to the store after this version shipped).
int? creditsForProductId(String productId) => kCreditsByProductId[productId];
