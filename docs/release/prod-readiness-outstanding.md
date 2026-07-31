# Production Readiness — Outstanding Work

**Compiled 2026-07-31** against `develop @ 6afb3455`, dev project
`vlmtsdzpnjnavdgytcmi`, prod project `wvmvsodrvbkxfydabqed`.

This is the running list of everything that must happen before the next
production release. It is a *verified* snapshot, not a wishlist — every claim
below was checked against the live projects on the compile date. Re-verify
before acting; deploys and dashboard edits happen outside this file.

Related: `docs/deployment/README.md` (deploy commands + refs),
`docs/ci-cd/` (Codemagic), `docs/test/coverage-status-2026-07.md`.

---

## 0. The short version

| Area | Blocking prod? | Summary |
|---|---|---|
| Edge functions | **Yes** | 26 of 28 are behind dev; `ensure-credits` does not exist in prod at all |
| AI credits / RevenueCat | **Yes** | No store products provisioned; prod secrets unverified |
| Supabase auth emails | **Yes** | Signup verification never configured |
| AI feature flags | Decision | Describe/Photo/Jade/Coach are OFF in prod by design — flipping them is a cost decision |
| Garmin | **Yes** | Prod is 7 versions behind on `garmin-push`; two filed bugs are fixed in dev only |
| Schema | No | Prod already has the meal/jade/token tables and credit RPCs (an earlier note claiming otherwise is stale) |

---

## 1. Edge functions — prod is broadly behind dev

Verified version numbers on the compile date. Everything in `supabase/functions/`
was deployed to **dev** on 2026-07-31; prod was not touched.

| Function | dev | prod | Notes |
|---|---|---|---|
| `ensure-credits` | 2 | **absent** | New. Without it prod users see a 0 balance until their first AI call |
| `generate-nutrition-plan-v3` | 87 | 72 | 15 versions of engine work (during-phase cascade, gap-fill, target-seeking) |
| `generate-macros-v4` | 59 | 52 | |
| `garmin-push` | 50 | 43 | Carries two filed Garmin bug fixes — see §5 |
| `garmin-ping` | 42 | 36 | Deploy together with `garmin-push` |
| `describe-meal` | 20 | 9 | Sonnet revert, credit metering, cost logging |
| `analyze-meal-photo` | 20 | 9 | Same, plus the 1000px downscale |
| `jade-chat` | 21 | 9 | |
| `ai-coach` | 16 | 10 | |
| `revenuecat-webhook` | 11 | 7 | **Prod still maps the retired 100/500/1200 SKUs** |
| `sync-all-data` | 51 | 48 | |
| `lookup-product` | 56 | 53 | |
| `create-user` | 41 | 39 | |
| `upsert-user-profile` | 37 | 28 | |
| `upload-all-data` | 36 | 28 | |
| `sync-final-surge` | 36 | 30 | |
| `delete-user` | 37 | 34 | |
| `get-weather-forecast` | 42 | 34 | |
| `send-nutrition-plan-email` | 40 | 34 | |
| `search-public-events` | 37 | 35 | |
| `get-foods` | 44 | 52 | prod is **ahead** — investigate before overwriting |
| `search-catalog` | 27 | 25 | |
| `search-nutrition-products` | 6 | 3 | |
| `calculate-daily-macros` | 31 | 29 | |
| `garmin-backfill` | 16 | 14 | |
| `garmin-deregistration` | 31 | 26 | |
| `garmin-oauth-callback` | 24 | 22 | |
| `garmin-user-mapping` | 17 | 16 | |

Two dev-only functions to decide on: `parse-meal-plan` (v3, dev only — belongs to
the parked meal-plan-import work) and `ensure-credits` (must ship).

> `get-foods` being higher in prod than dev is the one anomaly here. Do not
> blind-deploy over it; find out what shipped to prod that never landed in dev.

Deploy command (see `docs/deployment/README.md`):
```
supabase functions deploy <fn> --project-ref wvmvsodrvbkxfydabqed --no-verify-jwt
```

---

## 2. AI credits + RevenueCat

Project `proj77b3c48f`. Dev is fully working end to end against the Test Store;
**prod has never processed a real purchase.**

### 2.1 Store products do not exist
`mealvana_credits_50` and `mealvana_credits_250` exist in the RevenueCat
catalogue for all three apps, but **not in App Store Connect or Google Play**.
Real purchases cannot happen until they are created there as consumables and the
prices match ($4.99 / $19.99).

RevenueCat also has **no App Store Connect API credentials configured**, so RC
cannot read live pricing or product status. Configure before launch.

The retired `mealvana_credits_100/500/1200` products are still in the RC
catalogue (unattached to any package). Archive them once nothing references them.

### 2.2 Prod secrets to verify
Confirmed present in prod on the compile date: `REVENUECAT_WEBHOOK_SECRET`,
`AI_GATEWAY_API_KEY`, `AI_FREE_MONTHLY_CREDITS`, `SENTRY_DSN`.

Confirmed **absent** in prod (so code defaults apply):
- `AI_CREDITS_ENFORCED` — absent means enforcement is **OFF**: AI calls are free
  and unmetered. Flipping this to `true` is the moment the paywall goes live.
- `RC_PRODUCT_CREDITS` — absent is correct; the code default now maps 50/250.
- `DESCRIBE_MEAL_MODEL` / `ANALYZE_MEAL_PHOTO_MODEL` / `COACH_INSIGHT_MODEL` /
  `JADE_MODEL` — absent means the code default, currently **Sonnet 4.6**.

**`AI_FREE_MONTHLY_CREDITS` is set in prod to an unverified value.** Its digest
differs from dev's. Dev was found set to 500, which at Sonnet rates is
~$6.50/user/month — more than the $4.99 pack. It has been corrected to **20** in
dev and in the code default. **Read and correct the prod value before launch.**

### 2.3 Webhook routing
Both webhook integrations now filter by environment (set 2026-07-31):
dev → `sandbox`, prod → `production`. Before this they were unfiltered and every
Test Store purchase also hit the prod webhook.

Residual: dev and prod ship the **same bundle id**, so they share one RevenueCat
App Store app. A *prod* TestFlight build's sandbox purchases will therefore route
to the dev webhook. Fully separating them requires distinct bundle ids.

### 2.4 Pricing basis
Packs are sized from the Sonnet 4.6 economics — Notion "AI Features — Cost
Accounting & Token Pricing" §5 Scenario B, worst case ~$0.013/analysis against
Apple's 15% small-business cut. **Re-derive if the meal-analysis model changes**;
Haiku is ~3× cheaper and would support materially larger packs at the same price.

---

## 3. Supabase auth — signup email verification

**Never configured.** Dev auto-confirms signups, so no verification email has
ever been exercised. Prod needs, at minimum:

- SMTP configured in Supabase Auth settings (Resend is already in use for
  nutrition-plan emails — `RESEND_API_KEY` is present in prod).
- Signup confirmation enabled, with the email template written and branded.
- Redirect / deep-link URLs allow-listed so the confirmation link returns to the
  app rather than a browser dead end.
- Password reset and email-change templates checked at the same time.
- End-to-end test with a real address on prod before release.

Related: the linked-password flow changed in `cc896bab` (set the password *after*
verification, not before) — re-test that path once verification emails are live.

---

## 4. AI feature flags — a cost decision, not a bug

These default **OFF** in prod and ON in dev by deliberate policy:

| Flag | Prod | Controls |
|---|---|---|
| `DESCRIBE_MEAL_ENABLED` | off | Text + photo meal analysis entry points |
| `COACH_INSIGHTS_ENABLED` | off | Formula Kit coach insight one-liners |
| `AI_CREDITS_ENABLED` | off | Token balance UI + purchase surfaces |

Turning these on in prod means real AI spend. Sequence matters: **credits
enforcement (`AI_CREDITS_ENFORCED`) and the store products must be live before
the AI surfaces are**, or users get unmetered AI for free.

Note `analyze-meal-photo` now costs **1** credit (was 2), matching the "Each
analysis costs 1 token" copy and the pack maths.

---

## 5. Garmin

`garmin-push` v43 in prod vs v50 in dev. Two filed bugs are **already fixed and
dev-deployed but not in prod**:

- Race-loser payloads zeroing out metrics (payloads now enrich rather than
  overwrite with zeros).
- The "pending forever" telemetry artifact (fix `cf70fba9`).

Also unshipped to prod: the tz-naive `scheduled_date_time` handling
(`garminTimestampToLocalNaiveISO`) and the body-composition mirror to
`users.weight_pounds` / `body_fat_pct`.

Deploy `garmin-push` **and** `garmin-ping` together.

---

## 6. Schema — largely fine (supersedes an older note)

Verified present in prod: `token_wallets`, `token_ledger`, `ai_usage`,
`ai_usage_per_user`, `meal_logs`, `saved_meals`, `jade_conversations`,
`jade_messages`, `jade_calls`, `carb_loading_day_meals`; plus the
`ensure_free_credits` / `grant_credits` / `debit_credits` RPCs.

An earlier note that "prod still lacks 6 meal/jade tables" is **stale** — it was
true when meal logging was built and has since been resolved.

Still to confirm at release time: the Drift schema version the shipping binary
expects vs `docs/prod_schema.txt`, via the schema-version guard test.

---

## 7. Client / release mechanics

- **Codemagic `DOTENV_PROD_LOCAL`** must carry the RevenueCat Apple/Google keys
  and must **not** carry `REVENUECAT_API_KEY_TEST`. A prod build ignores the test
  key by construction (`AppConfig.revenueCatApiKey` gates it on `isDevelopment`),
  but it should not be in the prod variable group at all.
- **Codemagic `DOTENV_DEV_LOCAL`** — confirm it *does* carry
  `REVENUECAT_API_KEY_TEST`, otherwise CI-built dev apps can't reach the Test
  Store even though local dev builds can.
- **Shorebird**: prod iOS releases are Shorebird-backed. A patch replaces the
  whole Dart snapshot, so backport onto the release branch — never patch from
  dev. `is_internal` can never be patched (native plugin).
- **Sentry**: `SENTRY_DSN` present in prod. `SENTRY_AUTH_TOKEN` lives in
  Codemagic for symbol upload — verify it survived the repo move to
  `milkmanfunddev-ops`, which wiped GitHub Actions secrets.
- **Changelog automation**: the release GitHub Action needs `ANTHROPIC_API_KEY`
  (still missing after the repo move) and a **dot-free Sanity document id** —
  `generate_and_publish.mjs` builds `changelog-v1.22.0`, whose dots make the
  document unreadable by the anon role. Latent for every semver release.

---

## 8. Known-failing tests (environmental, not release blockers)

Two tests fail on every run and are not regressions:
- `test/e2e/dev_cloud_e2e_test.dart` — strict macro validation, hits dev cloud.
- `test/manual_live/training_peaks_api_test.dart` — expired TrainingPeaks token.

Full suite is otherwise green: 3,071 passing, plus 78 edge-function tests and 93
widget smoke tests.

---

## 9. Unmerged branches carrying work

Merged branches were deleted on 2026-07-31. These remain and are **not** in
`develop` — each needs a decision before release:

| Branch | Last commit | Note |
|---|---|---|
| `release/1.20` | 2026-07-03 | Base for the shipped 1.20 Shorebird patch — keep |
| `analytics/1.20-shorebird-patch` | 2026-07-13 | Deliberately not on develop |
| `wip/meal-plan-import-snapshot` | 2026-07-08 | Parked meal-plan import; pairs with the dev-only `parse-meal-plan` fn |
| `feat/formula-kit` | 2026-06-05 | Stale; previously excluded from a dev build |
| `fix/preworkout-bundle-may2026` | 2026-05-11 | Superseded by the engine rebuild — likely deletable |
| `claude/fix-3abe3fdb-ai-quantity-mirrors-portion` | 2026-07-28 | Merging alone turns a test RED (the test asserted the bug) |
| `ci/m1-runner-smoke` | 2026-07-30 | Recent CI work |
| `chore/app-store-screenshots` | 2026-07-26 | Release asset work |
| `feat/analytics-events` | 2026-07-22 | |
| `docs/athlete-profile-fields` | 2026-07-24 | |
| `qa/patrol-recommendation-h5-stacking` | 2026-07-28 | |
| `claude/fix-3a3e3fdb-fuel-log-add-food-not-persisted` | 2026-07-20 | |
| `claude/fix-3a3e3fdb-timeline-eaten-at-date` | 2026-07-20 | |
| `claude/fix-3a3e3fdb-8f6c-timeline-eaten-at-...` | 2026-07-20 | |

---

## 10. Suggested order

1. Resolve the `get-foods` dev/prod inversion.
2. Read and fix prod `AI_FREE_MONTHLY_CREDITS`.
3. Deploy edge functions to prod (Garmin pair first — it fixes filed bugs with no
   flag dependency).
4. Configure Supabase signup verification email; test end to end.
5. Create the store products in App Store Connect / Play; wire RC's ASC API key.
6. Verify a sandbox purchase credits a prod wallet.
7. Only then: flip `AI_CREDITS_ENFORCED`, then the AI surface flags.
