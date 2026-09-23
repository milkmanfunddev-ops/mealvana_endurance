# RevenueCat Implementation Spec — for Lee

*2026-09-07, revised 2026-09-16 for handoff. What to build, in ship order, for the
**paywall + Founding Month opening Thursday Oct 1**. Business context: gtm/coach-offer.md
and gtm/GTM-PLAN.md. Deadline logic: **store submission ~Sep 25** (both stores), leaving
room for one review rejection before Oct 1 — first subscription submissions routinely
bounce on terms/privacy links or trial-disclosure copy, so have those ready.*

## Three questions before you start

1. **Scope check:** with meal planning running to the Sep 22 checkpoint, can Phase 1 below
   reach store review by ~Sep 25? Phase 1 is roughly 3–4 focused days. If not, say so now —
   the launch date moves on this answer, nothing else.
2. **Phase 2 owner:** who runs Phase 2 (and support) after September, and what
   Supabase + RevenueCat context do they need from you before you go?
3. **Ask RevenueCat support one question before creating any products** (see "Verify before
   building," below): same subscription group for all eight SKUs, or discounted tiers in a
   separate group?

## Verify before building (store mechanics that bite late)

- **Apple grants ONE intro offer per subscription group per customer.** A user who consumed
  the 7-day trial and lapsed cannot later get the 14-day on a coach SKU in the same group.
  Accepted for v1 — just don't promise "14 days" to returning lapsed users in copy.
- **Same-group switching leak:** if all eight products share one subscription group, ANY
  subscriber can self-switch to a founding or c30 product through Apple's own Manage
  Subscriptions screen — RC targeting controls what the paywall shows, not what Apple's
  screen offers. Mitigations: **remove founding SKUs from sale on Nov 30** (existing subs
  keep renewing) and/or put discounted tiers in a separate group. Confirm the tradeoffs
  with RC support first (separate groups change upgrade/crossgrade behavior).
- **Budget one App Review rejection** in the Sep 25 → Oct 1 window; that's the whole reason
  the submission date isn't Sep 29.

## The shape in one paragraph

One entitlement (`pro`). Discounts are **separate store products** served by RevenueCat
Offerings + Targeting — never runtime price changes, never Apple offer codes (all codes are
OUR in-app codes; Apple's redemption sheet is not used). Free time (trials, coach comps,
giveaways) = RevenueCat **promotional/granted entitlements** from our backend. Attribution =
**subscriber attributes** set at code entry. Rule: one price applies (best wins); attribution
always records.

## 1. Products (create in BOTH App Store Connect and Play Console)

| Product id (suggested) | Price | Intro offer | Notes |
|---|---|---|---|
| `me_pro_monthly` | $24.99 | 7-day free trial | base |
| `me_pro_annual` | $199.99 | 7-day free trial | base |
| `me_pro_monthly_founding` | $12.49 | 7-day free trial | Oct 1–Nov 30 window |
| `me_pro_annual_founding` | $99.99 | 7-day free trial | window |
| `me_pro_monthly_c15` | $20.99 | **14-day** free trial | coach champion / influencer 15% (nearest tier to −15%) |
| `me_pro_annual_c15` | $169.99 | **14-day** free trial | |
| `me_pro_monthly_c30` | $17.49 | **14-day** free trial | founding-pilot coach 30% |
| `me_pro_annual_c30` | $139.99 | **14-day** free trial | |

Play mapping: mirror as base plans / offers however is cleanest — price parity is what
matters, not structure parity. All eight attach to the single `pro` entitlement.

## 2. Offerings + Targeting (priority = best price wins)

- `default` → base products.
- `founding` → founding products. **During Oct 1–Nov 30 make this the Current Offering for
  everyone** (manual flip on open + close; no date logic needed). Founding beats every code
  discount, so during the window the c15/c30 offerings are effectively dormant — which is
  why they're Phase 3, not Phase 1.
- `coach_30` → c30 products, Targeting rule: subscriber attribute `price_tier == c30`.
- `coach_15` → c15 products, rule: `price_tier == c15`.
- Rule order after the window closes: c30 → c15 → default.

## 3. Codes are ours, not the stores'

Backend (Supabase) owns a `codes` table: code → type (coach / influencer / giveaway),
owner, validity window, perk. On validation the app/backend:
1. Sets subscriber attributes: `coach_code`, `influencer_code`, `price_tier` (c15/c30).
2. Pairs athlete↔coach in our DB (pending coach confirmation — portal side).
3. Grants trial time (next section).
No store machinery involved; time-boxing an influencer code is a validity-window column.

## 4. Granted (promotional) entitlements — REST API, server-side

- **Trials are STORE intro offers, plan-picked upfront, auto-renewing** (final call
  2026-09-07, Xuan's decision — Bevel ran the same pattern): paywall is a front gate; user
  picks monthly/annual, trial attaches, auto-renews at expiry, cancel anytime. Coach-code
  14-day trials live in the c15/c30 SKUs' intro offers — **which means NO 14-day trial
  exists during Founding Month** (c15/c30 are Phase 3 and dormant while founding is the
  Current Offering). That's the decided Option B: during the window the coach code's job
  is pairing + portal only; don't build any special October trial path — so granted entitlements are now
  ONLY: coach comps (30d + first-pair extend + ≥5-active cron), founding-pilot
  grandfathers, and giveaway free-years. **Trust-keeper requirement: day-5-of-7 (day-11-of-14)
  reminder push+email — "trial ends in 2 days, $X after, cancel here." Non-negotiable; it's
  what separates a standard trial from Fuelin's 'misleading' reviews and protects the
  referring coach.**
- **Coaches register like everyone else** — grants pin to a stable app_user_id (anonymous
  ids evaporate on reinstall), and the same identity carries pairing, portal, rev share,
  W-9. **How the system knows it's a coach:** they enter their OWN code at the code screen
  — the backend detects code-owner (vs referred athlete), flags the account as coach, and
  fires the grant instantly, so a coach never sees the paywall.
- **Coach's own account:** grant `pro` 30 days at signup (= at own-code entry, above); **+30 auto-extend when their
  first athlete pairs**; ongoing via the **expiring-grant cron**: daily job counts each
  coach's confirmed-active athletes (active = app use in 14d); while ≥5, re-grant with
  ~35-day expiry; below 5, stop renewing and it lapses on its own. Fail-safe by design.
  **Decided 2026-09-16: while-earned, not forever-once-earned** (forever-after-a-spike is
  gameable; the 35-day tail absorbs normal dips). **Lapse-warning nudge:** when a coach
  falls below 5, push+email "your free account pauses in N days — X of your athletes are
  active, you need 5" — the best coach-driven athlete re-engagement trigger in the system.
  **v1 (Oct 1, zero code):** at ≤10 coaches this runs as a manual monthly ritual — read the
  per-coach confirmed/active counters on the Road-to-Nov-30 dashboard, grant 35d of `pro`
  by hand in the RevenueCat dashboard. The cron automates it when Phase 2 lands.
- **Giveaway free-years:** ~20 one-shot grants (365d) for the founding-month community
  giveaway.
- **Founding-pilot grandfathers:** Claudia = free forever (long-dated grant); Lana = c30
  price_tier standing.
- **Legacy existing-user grace (missing until 2026-09-16 — the critique caught it):** at
  paywall flip, every pre-paywall account gets a **30-day granted `pro`** + founding-member
  status, announced by the heads-up email ~1 week prior. Grace end = the normal gate
  (register/subscribe at founding price), data read-only if they don't. Subscribing during
  the grace simply starts billing then — the grant must not silently truncate.
- **Explicit non-item: there is NO free-tier SKU.** Free = `pro` entitlement absent,
  rendered app-side (stores don't sell $0 subscriptions). No product, no offering.

## 5. Identity

- Anonymous users: RC anonymous app user IDs; purchases still restore via store account.
- On registration/login call `logIn(<auth uid>)` so RC aliases anon → identified.
- **Purchasing and code entry require a registered account** (product decision — see the
  onboarding spec): keeps entitlements, coach attribution, and support sane.

## 6. Webhooks → funnel

RC webhook → Supabase endpoint → events table (`trial_started`, `initial_purchase`,
`renewal`, `cancellation`, `expiration`) keyed by app_user_id → join to coach pairing →
Mixpanel. This is what scores the Nov 30 gate (paying athletes per coach) — needed before
Oct 1, not before Sep 25 — and it can trail into early Oct (see drop order).

## 6b. Rev share (post-Oct, no store impact)

The founding-coach 15–25% rev share is a **monthly read-only query** on the Phase-2 webhook
tables (paired-athlete payments per coach × rate) — no store machinery, no affiliate SDK,
payouts manual. Just make sure webhook rows carry app_user_id joinable to the pairing table.

## 7. Ship order (matches the GTM calendar)

1. **By ~Sep 25 (store review):** `pro` entitlement · 4 base+founding products · paywall UI
   (RC Paywalls or custom — founding needs strikethrough styling + "Founding member" copy)
   · intro-offer trials · **day-5 trial reminder scheduled CLIENT-SIDE at purchase** (OneSignal scheduled push — deliberately no webhook dependency, so Phase 1 stands alone; the email variant can follow with Phase 2) · restore · logIn aliasing · **legacy grace batch script** (one-time RC REST loop granting 30d `pro` to every registered pre-paywall uid at flip; legacy *anonymous* installs claim grace by registering via the Settings path).
2. **By Oct 1 (target; can trail a few days without blocking launch — see drop order):**
   code rail (codes table, attributes, coach own-code detection + 30d coach grant) ·
   giveaway grants · webhook → Supabase → Mixpanel (consumers are metrics + rev share;
   the reminder no longer depends on it) · flip Current Offering to `founding` on Oct 1.
3. **Mid-Oct (dormant until window closes anyway):** c15/c30 products + targeting rules.
4. **Nov 30:** flip Current Offering back to `default`.

**If time runs short — pre-decided drop order (cut from the bottom):**
1. c15/c30 products + targeting (Phase 3 — dormant until Dec 1 anyway).
2. The comp cron → manual RC-dashboard grants (fine at ≤10 coaches through November).
3. Giveaway grants → manual.
4. Webhook pipeline → trails into early Oct; the dashboard's manual counters carry the
   gate metrics meanwhile.
Never cut: Phase 1 (products, paywall, trials, client-side reminder, grace script, restore).

Post-trial behavior: no free-tier entitlement exists — `pro` absent = trial-expired state (read-only data + paywall), enforced app-side. OneSignal external_id should bind to the Supabase uid (anon uids included) so lifecycle pushes reach unregistered installs.

Sandbox-test the granted-entitlement + logIn-alias path specifically — anon user enters
code after registering is the flow most likely to have edge cases.
