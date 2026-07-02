# AI Credits — operational status & go-live plan

**Last updated:** 2026-07-01
Companion to [ai_credits_design.md](./ai_credits_design.md) (architecture). This
doc = **where we are + what's left + how to run a test transaction.**

Users buy app-defined **AI credits** (consumable IAPs) and spend them per AI
action. Free monthly allotment + buy-more. Backend fully built + deployed;
enforcement + UI are **flag-gated OFF** until we flip them on.

---

## TL;DR status

| Layer | State |
|---|---|
| Supabase wallet (tables + RPCs) | ✅ live dev + prod |
| AI edge-fn enforcement + webhook | ✅ deployed dev + prod, tested |
| RevenueCat catalog (Test/App Store/Play) | ✅ apps + products + offering created |
| RevenueCat webhooks | ✅ dev + prod, verified |
| App Store Connect IAPs | ✅ created + priced + available (need screenshots + submit) |
| Google Play IAPs | ❌ not created yet |
| Flutter client (paywall, balance, 402) | ✅ scaffolded, flag-gated OFF |
| Prod app config (RC keys) | ✅ in .env.prod.local + Codemagic secret |
| Paid Apps agreement | ✅ active (2026-07-01) |

**Nothing is user-visible.** `AI_CREDITS_ENABLED=false` in prod; the balance
chip is not mounted; enforcement (`AI_CREDITS_ENFORCED`) is unset.

---

## Reference IDs

**RevenueCat** — project `proj77b3c48f` ("Mealvana Endurance")
- Apps: Test Store `appa283bb35a2` · App Store `app2953aa638a` · Play `app7d2f8e3b85`
- Offering `credits` (`ofrng47b65d3141`) → packages `pkge5f75413b8a` (100),
  `pkge31d7e32a61` (500), `pkgeacafc6973d` (1200). Each serves the Test/App
  Store/Play product for that pack.
- Store product identifiers (same across stores): `mealvana_credits_100/500/1200`
- Public SDK keys (publishable): Apple `appl_AGrlvOFexMAOrDPYHOxPgYdnCTs`,
  Google `goog_PmhsRTWZzOvPMXCPvgDSvzfKOIq`
- Webhooks → Supabase `revenuecat-webhook`: dev `whintgre4c0c2670c`,
  prod `whintgraa6c9e50e5` (env=all). Shared secret in `REVENUECAT_WEBHOOK_SECRET`.

**App Store Connect** — app Apple ID `6751113738`, team/issuer
`4ddd5f89-a054-4c06-b65a-ac9ed980786d` (Milkman Inc). Consumable IAPs (status
"Missing Metadata", price + all-country availability set):
- `mealvana_credits_100` → Apple ID `6786356290` → **$1.99**
- `mealvana_credits_500` → Apple ID `6786356515` → **$7.99**
- `mealvana_credits_1200` → Apple ID `6786356572` → **$14.99**

**Supabase** — dev `vlmtsdzpnjnavdgytcmi`, prod `wvmvsodrvbkxfydabqed`
- Tables: `token_wallets`, `token_ledger`, `ai_usage`
- RPCs: `grant_credits`, `debit_credits`, `ensure_free_credits` (service-role only)
- Secrets: `REVENUECAT_WEBHOOK_SECRET` (dev + prod set), `AI_FREE_MONTHLY_CREDITS=50`.
  `AI_CREDITS_ENFORCED` unset (= off) on both.
- Edge fns with credit logic: `revenuecat-webhook` (verify_jwt=false in
  config.toml), `ai-coach` / `jade-chat` / `describe-meal` / `analyze-meal-photo`
  (enforce via `_shared/ai/credits.ts`).

**Flutter** — `lib/features/ai_credits/`. Config: `AI_CREDITS_ENABLED`
(dev `.env.dev.local` = true, prod `.env.prod.local` = false),
`REVENUECAT_API_KEY_APPLE/GOOGLE`. Route `/buy-credits`. Hidden tester entry:
Settings → tap version 7× → "Buy AI Credits (tester)". RC init wired in
`app_startup_service._initializeRevenueCat()` (logs in with Supabase user id).

**Credit costs** (per action, tunable via secrets): ai-coach 1, describe-meal 1,
analyze-meal-photo 2, jade-chat 1. Free monthly: 50.

---

## What's LEFT to be fully operational

### A. Google Play (ON HOLD — no dev app exists yet)
> **BLOCKED / WAITING (2026-07-01):** there is currently **no "Mealvana Endurance
> dev" app**, so there's nothing to build+upload for testing, and the whole Play
> path is on hold until a dev app is set up. Everything below waits on that.

**Play Console will NOT let you create one-time products until an APK/AAB with the
`com.android.vending.BILLING` permission is uploaded to a track.** The One-time
products page currently shows only "Upload a new APK" — no Create button.
(Confirmed 2026-07-01.) Unlike Apple (which let us pre-create IAPs), Play requires
the build first.

Sequence:
1. Build an Android release **with `purchases_flutter`** (already in pubspec → the
   RevenueCat/Billing library adds the BILLING permission automatically) and upload
   it to at least an **internal testing** track (via Codemagic `prod-android` /
   `dev` android, or a manual upload).
2. THEN create 3 **one-time / consumable** products with IDs
   `mealvana_credits_100/500/1200`, prices ~$1.99/$7.99/$14.99, **Active**.
3. Link the Play **service account** (`secrets/google/mealvanaendurance-61d62e739439.json`)
   in RevenueCat (Play app `app7d2f8e3b85` → credentials) so RC validates Play
   purchases.
- App/dev IDs: Play app `4974680763463873240`, developer `7736074690794268989`.

### B. App Store Connect (mostly done — finish metadata + submit)
1. **Add a review screenshot** to each IAP (required to submit). *Blocked: no asset yet.*
2. Add **display name + description** (localization) to each IAP.
3. The **first** IAP must be **submitted with a new app version** (Apple rule);
   later ones can submit standalone.
4. Configure RC App Store app (`app2953aa638a`) credentials — upload the In-App
   Purchase Key `secrets/apple/SubscriptionKey_3Q27QQ626C.p8` (Key ID `3Q27QQ626C`,
   Issuer `4ddd5f89-...`) so RC validates receipts.

### C. Native build
- iOS: `cd ios && pod install` (pulls RevenueCat pod). Android: gradle auto-resolves.
- Adopt the 402 → paywall catch in the jade-chat/describe-meal/analyze-meal-photo
  clients (only ai-coach does it today).

### D. Flip it on (when ready to expose)
1. Mount `<CreditBalanceChip/>` in a real screen (e.g. Nutrition/coach surface).
2. `AI_CREDITS_ENABLED=true` (dev first; prod via `.env.prod.local` +
   `DOTENV_PROD_LOCAL` Codemagic secret — already contains the keys).
3. `supabase secrets set AI_CREDITS_ENFORCED=true --project-ref <ref>` (dev first).

---

## How to run a TEST TRANSACTION

### Path 1 — RevenueCat Test Store (fastest; no Apple/Play needed) ✅ ready
Everything for this is wired on **dev**.
1. `cd ios && pod install`, build the **dev** flavor (`main_dev.dart`) to a device/simulator.
2. Log in (so RC `logIn(<supabase user id>)` runs — required for the webhook to
   credit the right wallet).
3. Settings → tap version 7× → **Buy AI Credits (tester)** → tap a pack.
4. Complete the RC Test Store purchase → dev webhook (`whintgre4c0c2670c`) grants
   credits → paywall balance updates (polls ~7s).
5. To test spending/402: `supabase secrets set AI_CREDITS_ENFORCED=true
   --project-ref vlmtsdzpnjnavdgytcmi`, drain the balance with AI calls, confirm
   the next call returns 402. Turn back off after.
- Verify server-side: `SELECT * FROM token_ledger WHERE user_id='<id>' ORDER BY created_at;`

### Path 2 — Apple sandbox (real StoreKit; agreement now active) 
1. Finish ASC item **B** (screenshots + pricing already done) enough that the IAPs
   are fetchable (products are purchasable in sandbox once created + priced +
   agreement active, even before review).
2. Create a **Sandbox Tester**: App Store Connect → Users and Access → **Sandbox** →
   Testers → add a test Apple ID (use an email you control, not a real Apple ID).
3. On a real device: Settings → Developer → sign in to **Sandbox Account** with the
   tester; build the app with the **App Store** RC key (prod flavor or a build
   using `REVENUECAT_API_KEY_APPLE`).
4. Open the paywall, buy a pack → StoreKit sandbox purchase → RC validates →
   prod webhook (`whintgraa6c9e50e5`) grants credits → balance updates.
- Sandbox purchases are free and repeatable.

### Path 3 — Google Play internal testing
After Google Play item **A**: add the tester's Google account as an internal
tester + a Play license tester, install from the internal track, purchase. Same
webhook → grant flow.

---

## Go-live checklist (order)
1. ☑ Paid Apps agreement active
2. ☐ **Set up a Mealvana Endurance dev app** (none exists yet — prerequisite for
   any dev-build testing + the whole Android/Play path)
3. ☐ Google Play products created + active (needs #2 + an uploaded billing build)
3. ☐ ASC IAP screenshots + display names, submit first with next app version
4. ☐ RC store credentials (Apple IAP key + Play service account) configured
5. ☐ `pod install`; adopt 402 catch in remaining AI clients
6. ☐ Run Path 1 (Test Store) end-to-end, then Path 2/3 (sandbox) end-to-end
7. ☐ Mount balance chip in UI
8. ☐ `AI_CREDITS_ENABLED=true` (dev → prod) + `AI_CREDITS_ENFORCED=true` (dev → prod)
9. ☐ Ship the app version carrying the IAPs

## Admin queries
```sql
SELECT user_id, balance, free_period FROM public.token_wallets ORDER BY balance DESC;
SELECT reason, count(*), sum(delta) FROM public.token_ledger
  WHERE created_at > now() - interval '30 days' GROUP BY reason;
SELECT user_id, sum(input_tokens+output_tokens) AS tokens, count(*) AS calls
  FROM public.ai_usage WHERE created_at > now() - interval '30 days'
  GROUP BY user_id ORDER BY tokens DESC;
```
