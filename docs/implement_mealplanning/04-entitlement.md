# 04 — Pro entitlement (Phase 3)

## What exists (verified 2026-09-01 via the RevenueCat API)
- Project `proj77b3c48f` already has entitlement **`pro`** ("Mealvana Endurance Pro", since 2025-11)
  with products `mealvana_pro_monthly` ($9.95/mo, P1M) and `mealvana_pro_annual` ($69/yr, P1Y), in the
  **current** offering `default` (`$rc_monthly`, `$rc_annual`).
- **Both products exist only on the RC "Test Store" app (`appa283bb35a2`).** None of the four real
  apps — iOS prod `app2953aa638a` (`com.milkman.mealvanaendurance`), iOS dev `app2a6d45e56e`
  (`.dev`), Play prod `app7d2f8e3b85`, Play dev `app7536cff235` — has a Pro subscription product.
- App side: `lib/features/ai_credits/data/revenuecat_service.dart` (configure/logIn/getOfferings/
  purchase/restore — no `getCustomerInfo`, no listener), `/pro` static screen, no `user_entitlements`.
- Decision 2026-09-01 (Lee): **Pro only.** The older monetization docs (credit-gated meal planning) are superseded.

## Store work — DONE via API 2026-09-01 (Claude)
| Store | App | Product ids | State |
|---|---|---|---|
| App Store Connect | prod 6751113738 | group `Mealvana Pro` 22351111 → `mealvana_pro_monthly_prod` (6807411442, $9.99), `mealvana_pro_annual_prod` (6807411640, $69.99) | MISSING_METADATA — needs the App Review screenshot (paywall) |
| App Store Connect | dev 6756683509 | group `Mealvana Pro` 22351029 → `mealvana_pro_monthly` (6807411443, $9.99), `mealvana_pro_annual` (6807411689, $69.99) | MISSING_METADATA — same; sandbox purchases work without review |
| Google Play | `com.milkman.mealvanaendurance` + `.dev` | `mealvana_pro_monthly:monthly` (P1M $9.99), `mealvana_pro_annual:annual` (P1Y $69.99), en-US listing, 7-day grace | base plans ACTIVE |
| RevenueCat | all 4 store apps | 8 products created, attached to entitlement `pro` (entla441faaeb4) and to `default` offering packages `$rc_monthly` (pkge316803098d) / `$rc_annual` (pkge4a1810d707) | done |

All four ASC subscriptions: en-US localization, all 175 territories, USA price set (Apple equalizes the rest).
Remaining manual: upload the review screenshot once the paywall exists, then submit with the next binary.
Tooling: `asc.mjs` / `play.mjs` (JWT helpers, no deps) lived in the session scratchpad — recreate from
`secrets/apple/AuthKey_Codemagic_565CMLNU3G.p8` and `secrets/google/mealvanaendurance-61d62e739439.json`
(Play activation is eventually consistent: retry `:activate` until 200).

## DB
```sql
create table public.user_entitlements (
  user_id uuid not null references public.users(id) on delete cascade,
  entitlement text not null,                 -- 'pro'
  active boolean not null default false,
  product_id text, store text, period_type text,
  expires_at timestamptz, unsubscribe_detected_at timestamptz, billing_issue_detected_at timestamptz,
  source text not null default 'revenuecat', -- revenuecat | promo | internal
  updated_at timestamptz not null default now(),
  primary key (user_id, entitlement)
);
-- RLS: owner select; writes service_role only.
create or replace function public.has_entitlement(p_user uuid, p_key text) returns boolean ...
```
`revenuecat-webhook/index.ts`: new branch for `INITIAL_PURCHASE · RENEWAL · CANCELLATION · UNCANCELLATION
· EXPIRATION · BILLING_ISSUE · PRODUCT_CHANGE · SUBSCRIPTION_PAUSED · TRANSFER` when
`event.entitlement_ids` contains `pro` → upsert `user_entitlements` (`active = expiration_at_ms > now`).
Consumable branch unchanged. Idempotent on `event.id`. Also on `INITIAL_PURCHASE` of a Pro product,
grant a Pro welcome credit bundle? — **open**, default no.

## Flutter — `lib/features/subscription/`
```
domain/entitlement.dart              enum Entitlement { pro }  + SubscriptionStatus {active, expiresAt, source, isTrial}
data/subscription_service.dart       wraps Purchases.getCustomerInfo(), addCustomerInfoUpdateListener; keepAlive
data/user_entitlements_repository.dart  reads user_entitlements (remote) → Drift cache table user_entitlements (v19)
application/subscription_status_provider.dart  @Riverpod(keepAlive: true) AsyncNotifier<SubscriptionStatus>
   = RC CustomerInfo.entitlements.active['pro']  ∪  server row (whichever is active)  ∪  internalDeviceFlag
application/pro_gate.dart            bool isProUnlocked(ref) = status.active || appConfig.proGateEnabled == false
presentation/pro_gate_redirect.dart  GoRouter redirect helper: /food/* → /pro when locked
presentation/screens/pro_version_screen.dart (moved from pro_version/) — reads `default` offering, shows real
   prices, Restore works, Buy stays disabled until the paywall design lands (flag `PRO_PURCHASE_ENABLED`)
```
- `AppConfig.proGateEnabled` = `dotenv PRO_GATE_ENABLED` (dev default `false` → everyone sees Food on
  dev builds; prod default `true`). codemagic.yaml: force `false` on dev builds like the AI flags.
- Startup: after `configureIfPossible()` + `logIn()` in `app_startup_service._initializeRevenueCat`,
  register the listener and prime the provider. On sign-out clear it.
- Router: extend the existing redirect block (`app_router.dart:130-138`) with
  `if (currentPath.startsWith('/food') && !isProUnlocked(ref)) return '/pro';`. Tab: `TabsScreen`
  includes the Food tab only when unlocked (rebuilds on provider change).
- Edge functions read the server row (03 §3); the client flag is UX, the server row is the paywall.

## Testers / QA
- `internalDeviceFlagProvider` (7-tap) unlocks the client gate; server side, `internal_users` table
  (exists? — verify; else add `users.is_internal`) unlocks the fn gate.
- RC promotional grant (`grant-customer-entitlement`, MCP available) for named testers on prod.

## Acceptance
- Non-pro prod build: no Food tab, `/food/plan` deep link → `/pro`, `vana-chat` → 403.
- Sandbox purchase of monthly on the dev app → webhook row → provider flips → Food tab appears
  without restart; expiry (sandbox 5-min renewals) flips it back.
- Restore purchases on a fresh install restores Pro. Dev builds with `PRO_GATE_ENABLED=false` see
  everything.
