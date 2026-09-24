# Sandbox trial run: store-checks, 2026-09-24

Gate for any meal-planning release (mp-270, mp-289; playbook §8 P3c).
Written by `scripts/sandbox-trial-wizard.sh store-checks`. Every call is a read (store and RevenueCat GETs, a SELECT on DEV `vlmtsdzpnjnavdgytcmi`).

- Started: 2026-09-24T11:51:54Z
- Build commit: `fafdeec9937fda9c69b5931686289225f4b74a65` on `wave/paywall/13-the-store-checks-before-release`
- Working tree had uncommitted changes to tracked files at start

Claude's part of the gate (mp-463): no phone. App Store Connect and Google Play through
`scripts/store/asc.mjs` / `play.mjs` (read-only `list` and `show`), RevenueCat through v2 GETs,
the Pro row through a read-only SELECT on DEV. The phone part is `sandbox-trial-wizard.sh ios|android`.

## C1 App Store (dev): products, prices, free week: PASS

Checked 2026-09-24T11:52:03Z.

```
me_pro_monthly (6814502580) · ONE_MONTH · MISSING_METADATA · USA 24.99 · priced in 175 territories · free week in 175
me_pro_annual (6814503792) · ONE_YEAR · MISSING_METADATA · USA 199.99 · priced in 175 territories · free week in 175
me_pro_monthly_founding (6814504935) · ONE_MONTH · MISSING_METADATA · USA 12.49 · priced in 175 territories · free week in 175
me_pro_annual_founding (6814505643) · ONE_YEAR · MISSING_METADATA · USA 99.99 · priced in 175 territories · free week in 175
```

## C2 Google Play (dev): products, prices, free week: PASS

Checked 2026-09-24T11:52:06Z.

```
me_pro_monthly/monthly · P1M · ACTIVE · US 24.99 USD · offers free-week ACTIVE [P7D×1 free]
me_pro_annual/annual · P1Y · ACTIVE · US 199.99 USD · offers free-week ACTIVE [P7D×1 free]
me_pro_monthly_founding/monthly · P1M · ACTIVE · US 12.49 USD · offers free-week ACTIVE [P7D×1 free]
me_pro_annual_founding/annual · P1Y · ACTIVE · US 99.99 USD · offers free-week ACTIVE [P7D×1 free]
```

## C1 App Store (prod): products, prices, free week: PASS

Checked 2026-09-24T11:52:15Z.

```
me_pro_monthly_prod (6815251933) · ONE_MONTH · MISSING_METADATA · USA 24.99 · priced in 175 territories · free week in 175
me_pro_annual_prod (6815253177) · ONE_YEAR · MISSING_METADATA · USA 199.99 · priced in 175 territories · free week in 175
me_pro_monthly_founding_prod (6815253736) · ONE_MONTH · MISSING_METADATA · USA 12.49 · priced in 175 territories · free week in 175
me_pro_annual_founding_prod (6815254459) · ONE_YEAR · MISSING_METADATA · USA 99.99 · priced in 175 territories · free week in 175
```

## C2 Google Play (prod): products, prices, free week: PASS

Checked 2026-09-24T11:52:18Z.

```
me_pro_monthly_prod/monthly · P1M · ACTIVE · US 24.99 USD · offers free-week ACTIVE [P7D×1 free]
me_pro_annual_prod/annual · P1Y · ACTIVE · US 199.99 USD · offers free-week ACTIVE [P7D×1 free]
me_pro_monthly_founding_prod/monthly · P1M · ACTIVE · US 12.49 USD · offers free-week ACTIVE [P7D×1 free]
me_pro_annual_founding_prod/annual · P1Y · ACTIVE · US 99.99 USD · offers free-week ACTIVE [P7D×1 free]
```

## C3 RevenueCat: the default offering holds the me_pro products on all four apps: PASS

Checked 2026-09-24T11:52:19Z.

```
offering default (ofrngabf12e1136) · active · current
  $rc_monthly prod08b912f933  me_pro_monthly_prod:monthly on app7d2f8e3b85
  $rc_monthly prod350601b768  mealvana_pro_monthly on appa283bb35a2
  $rc_monthly prod75d15f97ab  me_pro_monthly:monthly on app7536cff235
  $rc_monthly prodb9fcd056f7  me_pro_monthly on app2a6d45e56e
  $rc_monthly prodc5b9854c12  me_pro_monthly_prod on app2953aa638a
  $rc_annual prod4cada97036  me_pro_annual:annual on app7536cff235
  $rc_annual prod4e44d96638  me_pro_annual_prod:annual on app7d2f8e3b85
  $rc_annual prod5ba80a209c  me_pro_annual_prod on app2953aa638a
  $rc_annual proda5ec006335  me_pro_annual on app2a6d45e56e
  $rc_annual prodcaf0460693  mealvana_pro_annual on appa283bb35a2
```

## C4 RevenueCat: the founding offering holds the founding products on all four apps: PASS

Checked 2026-09-24T11:52:19Z.

```
offering founding (ofrng5d8be9a189) · active · not current
  $rc_monthly prod18ea2e66f1  me_pro_monthly_founding:monthly on app7536cff235
  $rc_monthly prod7b21d0a714  me_pro_monthly_founding_prod:monthly on app7d2f8e3b85
  $rc_monthly prod962151e66c  me_pro_monthly_founding on app2a6d45e56e
  $rc_monthly prodf0771a8e20  me_pro_monthly_founding_prod on app2953aa638a
  $rc_annual prod6f92119809  me_pro_annual_founding on app2a6d45e56e
  $rc_annual prod9c8d8270de  me_pro_annual_founding:annual on app7536cff235
  $rc_annual prodc0e4507cc0  me_pro_annual_founding_prod on app2953aa638a
  $rc_annual prodc7762e331e  me_pro_annual_founding_prod:annual on app7d2f8e3b85
```

## C5 RevenueCat: entitlement pro (entla441faaeb4) holds every me_pro product: PASS

Checked 2026-09-24T11:52:19Z.

```
entitlement pro holds 26 products
  me_pro_annual_founding on ios-dev
  me_pro_annual_founding_prod on ios-prod
  me_pro_annual_founding:annual on play-dev
  me_pro_annual_founding_prod:annual on play-prod
  me_pro_monthly_founding on ios-dev
  me_pro_monthly_founding_prod on ios-prod
  me_pro_monthly_founding:monthly on play-dev
  me_pro_monthly_founding_prod:monthly on play-prod
```

## C6 A hand-granted account (`607f9dd5-6fa7-48ee-a628-720d4a0506a1`) shows pro in RevenueCat and its DEV row matches: PASS

Checked 2026-09-24T11:52:20Z.

```
subscription subPrm06b217df13d1de86c4daac901f89acfa · store promotional · active · gives access True · 2026-09-23T02:34:07Z -> 2026-10-23T02:34:07Z
subscription subPrm819471e8d5f0f5140e49873f51aee417 · store promotional · active · gives access True · 2026-09-15T19:39:17Z -> 2027-09-15T19:39:14Z
subscription subPrm92001e8072bf7f9ca251a1ed978061e8 · store promotional · active · gives access True · 2026-09-22T02:42:37Z -> 2026-10-22T02:42:37Z
RevenueCat active pro until 2027-09-15T19:39:14Z
DEV row: active_until 2027-09-15 19:39:14.349+00 · period_type NORMAL · event_at 2026-09-23 02:34:07.638+00 · active True
```

Webhook lines around the row's event_at (2026-09-23 02:34:07.638+00), the webhook writing it:

```
2026-09-23T02:34:08Z [rc-webhook] NON_RENEWING_PURCHASE: active_until=2027-09-15T19:39:14.349Z period=NORMAL for 607f9dd5-6fa7-48ee-a628-720d4a0506a1
```

## C7 RevenueCat webhooks: dev and prod hear every lifecycle event, no environment filter: FAIL

Checked 2026-09-24T11:52:22Z.

```
whintgre4c0c2670c -> vlmtsdzpnjnavdgytcmi · environment filter None · events billing_issue cancellation expiration initial_purchase non_renewing_purchase product_change renewal subscription_extended subscription_paused transfer uncancellation
whintgraa6c9e50e5 -> wvmvsodrvbkxfydabqed · environment filter None · events initial_purchase non_renewing_purchase renewal
MISSING/WRONG: whintgraa6c9e50e5 (wvmvsodrvbkxfydabqed) lacks billing_issue cancellation expiration product_change transfer uncancellation
```

## Result: RED (1 check(s) failed)

Finished 2026-09-24T11:52:22Z. Commit this file with the release.

## Notes from the run (Claude, read-only, 2026-09-24)

- **C7 is the one red check.** The prod RevenueCat webhook `whintgraa6c9e50e5` still takes only
  `initial_purchase`, `non_renewing_purchase` and `renewal`. That is the known cutover item
  (docs/implement_mealplanning/04-entitlement.md): widen it with the prod webhook deploy. Nothing
  was changed here.
- **The prod half of "the webhook wrote the row" cannot hold yet.** A read-only SELECT on prod
  (`wvmvsodrvbkxfydabqed`) answers `42P01: relation "public.user_entitlements" does not exist`: the
  table arrives with the 1 October cutover. C6 is therefore a DEV check. Re-run `store-checks` after
  the cutover and add a prod row check before the release that carries the paywall.
- **Signed-in browser: not used.** Every item mp-463 lists was answerable through the APIs.
- **The founding offering is not current** (C4). That is intended: it becomes current by hand on
  1 October. The phone run overrides it for the sandbox customer only (README step 2).
- **All eight App Store subscriptions are `MISSING_METADATA`** (the review screenshot). Sandbox
  purchases work without review; the screenshot goes in with the release binary.
- **App Store Connect has no sandbox testers** (`GET /v2/sandboxTesters` → 0). The iOS phone run
  must create one first (stage 1).
- **The `default` offering still holds the Test Store's `mealvana_pro_monthly` / `mealvana_pro_annual`**
  (`appa283bb35a2`), as ticket 05 recorded; C3 checks only the four real apps.

## The phone run (Lee): to fill in

Run `scripts/sandbox-trial-wizard.sh ios` and `scripts/sandbox-trial-wizard.sh android` on physical
devices. Each writes its own `YYYY-MM-DD-<store>.md` here with a `## Result` line; list them below.

| Store | Log | Founding offering shows both prices (2) | Purchase through founding, free week (3-5) | Day-five reminder, clock moved on (6) | Restore (9) | Result |
|---|---|---|---|---|---|---|
| iOS | | | | | | |
| Android | | | | | | |

Before starting:

- Create a sandbox tester in App Store Connect (there are none) and add a fresh Google account under
  Play Console → License testing.
- **Day-five reminder: expect it may not fire.** Sandbox shortens the free week to minutes, and
  `TrialReminder.fireTimeFor` schedules nothing when 10:00 two days before the end has already
  passed. Moving the clock on afterwards cannot bring back a notification that was never set.
  Record what you see; this is an open question for Lee, not a device fault.
