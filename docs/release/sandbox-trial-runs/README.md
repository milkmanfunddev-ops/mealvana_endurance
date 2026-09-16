# Sandbox trial runs: the meal-planning release gate

**No meal-planning release without a green sandbox trial run on both stores.**
Decisions mp-270 (meal planning ships only with the trial and purchase model) and mp-289 (the store
trial is verified by hand in sandbox, never in CI). The gate is step P3c of the prod sequence in
[`docs/deployment/supabase-deploy-playbook.md` §8](../../deployment/supabase-deploy-playbook.md).

## What a run is

A person with a fresh sandbox account on each store, on a physical device running the dev app:

1. finishes onboarding as a new athlete and lands on the paywall with the introductory offer;
2. subscribes through the seven-day free offer;
3. the entitlement row on DEV is active on day one (`period_type = TRIAL`, `active_until > now()`);
4. the monthly Allowance landed in the wallet (a `grant_allowance` ledger row keyed on the RevenueCat event id);
5. cancels in the store, and the cancellation reaches DEV;
6. the trial ends, the server gate closes, and the app shows the paywall and nothing else;
7. resubscribes in the store's own subscription settings, taps Restore purchases, and the app and the
   server gate reopen.

The webhook's own logic (grant on renewal, stale event ignored, transfer moves the row) is tested at
the server seam with fake events (`supabase/functions/revenuecat-webhook/index.test.ts`), not here.

## How to run it

From the repo root, on the branch whose build is on the device:

```bash
scripts/sandbox-trial-wizard.sh preflight   # read-only DEV checks, no prompts
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

The wizard reads DEV only, with read-only SELECTs, and writes nothing but the log. It refuses to run
under CI variables or without a terminal.

## The logs

Each store writes `YYYY-MM-DD-<store>.md` here (a `-2`, `-3` suffix for a second run on the same day):
the build commit, device, accounts, every step with the DEV rows that proved it, and a closing
`## Result: GREEN` or `## Result: RED (…)`. Commit the logs with the release. A RED log stays in
the history; the gate needs a later GREEN log for that store.

## The gate, for the release reviewer

Before P4 (merge to `release/*`) of any release that carries meal planning:

- [ ] `docs/release/sandbox-trial-runs/` has a `## Result: GREEN` log for **ios**, run on a commit
      in the release candidate's history.
- [ ] …and one for **android**, likewise.
- [ ] Neither log's commit predates a change to the paywall, the subscription gate, the
      `revenuecat-webhook` function or the Allowance that the release carries.
