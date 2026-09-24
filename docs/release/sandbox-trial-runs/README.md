# Sandbox trial runs: the meal-planning release gate

**No meal-planning release without green store checks and a green sandbox trial run on both stores.**
Decisions mp-270 (meal planning ships only with the trial and purchase model), mp-289 (the store
trial is verified by hand in sandbox, never in CI) and mp-463 (Claude checks everything that needs
no phone; a person runs only what needs one). The gate is step P3c of the prod sequence in
[`docs/deployment/supabase-deploy-playbook.md` §8](../../deployment/supabase-deploy-playbook.md).

## Claude's part: the store checks, no phone

`scripts/sandbox-trial-wizard.sh store-checks <user id>` reads, and writes nothing but its log:

1. the four products (`me_pro_monthly`, `me_pro_annual` and their `_founding` pair; `_prod` on the
   prod apps) exist on the App Store and Google Play, dev and prod, with their prices and an active
   free-week offer;
2. RevenueCat's `default` and `founding` offerings hold those products on all four apps, and the
   `pro` entitlement holds every one;
3. a hand-granted account (`<user id>`, a DEV account with a promotional `pro` grant) shows `pro` in
   RevenueCat, and its DEV row matches RevenueCat's expiry, with the webhook's log line as evidence;
4. both RevenueCat webhooks hear every lifecycle event and filter on no environment.

## The phone part: what a run is

A person with a fresh sandbox account on each store, on a physical device running the dev app:

1. finishes onboarding as a new athlete and lands on the paywall with the introductory offer;
2. (2b) with the `founding` offering overridden for that customer in RevenueCat (never made the
   project's current offering: the project is shared with prod), sees the founding prices beside the
   normal ones struck through;
3. subscribes through the founding offering's seven-day free offer;
3. the entitlement row on DEV is active on day one (`period_type = TRIAL`, `active_until > now()`);
4. the monthly Allowance landed in the wallet (a `grant_allowance` ledger row keyed on the RevenueCat event id);
   (5b) with the device clock moved on to day five, the reminder arrives and its tap opens the
   store's subscription page;
5. cancels in the store, and the cancellation reaches DEV;
6. the trial ends, the server gate closes, and the app shows the paywall and nothing else;
7. resubscribes in the store's own subscription settings, taps Restore purchases, and the app and the
   server gate reopen.

The webhook's own logic (grant on renewal, stale event ignored, transfer moves the row) is tested at
the server seam with fake events (`supabase/functions/revenuecat-webhook/index.test.ts`), not here.

## How to run it

From the repo root, on the branch whose build is on the device:

```bash
scripts/sandbox-trial-wizard.sh store-checks <user id>  # [no phone] Claude's checks
scripts/sandbox-trial-wizard.sh preflight   # [no phone] read-only DEV checks, no prompts
scripts/sandbox-trial-wizard.sh             # both stores, iOS first
scripts/sandbox-trial-wizard.sh ios         # or one store at a time
scripts/sandbox-trial-wizard.sh android
```

You need:

- a physical iPhone and a physical Android phone (the iOS simulator cannot sign into sandbox, and a
  StoreKit-configuration purchase never reaches RevenueCat);
- a new sandbox Apple Account (App Store Connect → Users and Access → Sandbox) and a new Google
  account added under Play Console → License testing, neither of which has ever subscribed;
- the dev app from this branch on each device (`./scripts/run_dev.sh -d <device id>`; on Android,
  the internal testing track if billing refuses a side-loaded build);
- a Supabase Management API token (`secrets/supabase_management_api.env` or
  `$SUPABASE_MANAGEMENT_TOKEN`).

Every stage is marked `[phone]` or `[no phone]`. The wizard reads only (DEV SELECTs; in
`store-checks`, store and RevenueCat GETs) and writes nothing but the log. It refuses to run under CI
variables; the phone run also refuses without a terminal.

## The logs

`store-checks` writes `YYYY-MM-DD-store-checks.md`; each store writes `YYYY-MM-DD-<store>.md` here (a `-2`, `-3` suffix for a second run on the same day):
the build commit, device, accounts, every step with the DEV rows that proved it, and a closing
`## Result: GREEN` or `## Result: RED (…)`. Commit the logs with the release. A RED log stays in
the history; the gate needs a later GREEN log for that store.

## The gate, for the release reviewer

Before P4 (merge to `release/*`) of any release that carries meal planning:

- [ ] `docs/release/sandbox-trial-runs/` has a `## Result: GREEN` **store-checks** log from the
      release week.
- [ ] …a `## Result: GREEN` log for **ios**, run on a commit
      in the release candidate's history.
- [ ] …and one for **android**, likewise.
- [ ] Neither log's commit predates a change to the paywall, the subscription gate, the
      `revenuecat-webhook` function or the Allowance that the release carries.
