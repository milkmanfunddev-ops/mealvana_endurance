# Kroger verification and rollout

## Automated checks

From the repo root (do not run `flutter build` as assistant execution):

```sh
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test test/features/kroger
flutter test test/features/meal_planning/presentation/screens/shopping_tab_test.dart
deno check supabase/functions/kroger/index.ts
deno test supabase/functions/_shared/kroger/kroger_test.ts
scripts/design-library-check.sh --warn
```

`test/features/kroger/migration_test.sql` executes the real migration and checks
grants, owner RLS, compare-and-swap and the atomic limiter. **Run it only in an
empty disposable PostgreSQL instance**, not a linked Supabase project: it
creates fake auth roles/schema and a minimal `meal_plans` fixture, then rolls
everything back. It was exercised using `initdb`/`pg_ctl` on a temporary Unix
socket, with no TCP listener, and that server was stopped afterward.

The server tests use in-memory PostgREST and upstream doubles for concurrency,
price changes, expired/replayed/cross-owner OAuth state, wrong-plan ownership,
reservation failures, uncertain writes, and retry prevention. Flutter tests
exercise quantities, reconciliation, dirty sync/conflicts, controller flows,
OAuth callback validation, dialogs and the receipt UI. These do not replace
real device/customer OAuth and cart verification.

## Live read-only probe

```sh
deno run --allow-read=secrets/kroger.env --allow-net=api-ce.kroger.com scripts/kroger-probe.ts
```

Uses only certification client credentials from the ignored server file and
requests a `product.compact` token. It looks up one store around test ZIP 45202
and searches its catalog. Credentials and tokens are never printed. It does
not access profiles, authorize customers, add to a cart or place orders.

Verified 2026-09-07: token authentication, location lookup and store-specific
product search, UPC detail lookup, and product normalization all passed against
the live certification API. The sampled product supplied a size and price but
was not pickup-eligible; this is not a verified end-to-end cart fixture.

## Deployment sequence

Dev schema, secrets, function and live status verification completed 2026-09-08;
the dev pilot now uses Kroger Production credentials. Mealvana production has
not been touched. See
[DEPLOYMENT.md](DEPLOYMENT.md) for the execution record. The sequence below is
the repeatable rollout checklist; customer/device acceptance remains outstanding.

1. Review this feature's changes separately from unrelated work in the shared
   checkout. Read `docs/deployment/README.md` and the migration runbook. Choose
   the **dev** target explicitly; do not rely on the CLI's linked-project default.
2. Rotate the Kroger secret if any app artifact was built after it was initially
   placed in bundled `.env` files. Update the matching environment's private env and
   registration record without logging or committing values.
3. Apply only `supabase/migrations/20260907120000_kroger_shopping.sql` through the
   established migration process after checking the target's prior migrations.
   Do not blindly push every pending migration from this shared checkout.
4. Review `docs/kroger/server.env.example` and `PRODUCTION.md`. Customer OAuth
   requires the Production registration in `secrets/kroger.prod.env`; the
   Certification template is only suitable for application-level API tests.
   Upload only reviewed Kroger server
   keys from the private file using `supabase secrets set --env-file ...
   --project-ref <verified-dev-ref>`. Initially keep `KROGER_ENABLED=false`.
   Never send these credentials to an arbitrary URL or expose them as Dart defines.
5. Deploy the single function with `scripts/deploy_dev.sh kroger`; its
   `verify_jwt=false` config is intentional because it validates bearer JWTs
   internally with Supabase Auth. Verify unauthenticated POSTs fail and that a
   disabled integration returns `available:false` for a signed-in caller.
6. Confirm registration/platform callback alignment. Existing registered URI:
   `com.milkman.mealvanaendurance://callback`. Android **dev** handles
   `com.milkman.mealvanaendurance.dev://callback`; register that URI before using
   it and configure the matching test backend. The browser wrapper refuses an
   Android scheme/package mismatch. iOS native-session routing still needs a
   device test. Web is intentionally unsupported for sign-in.
7. Enable the dev server flag for the internal pilot. The entry is automatically
   visible in a dev app running the new code, per deployment policy. Production
   requires `--dart-define=KROGER_SHOPPING_ENABLED=true`; fresh server environments
   default off. Existing Food/Pro rules still apply.
8. Complete the approved live checklist below. Follow the repo release-cut
   process whenever a build is actually cut or pushed. No build/commit/push
   was performed. Only the dev schema/secrets/function have been deployed.
9. Kroger Production credentials are already configured on Mealvana dev. Before
   Mealvana production rollout, verify customer OAuth and quotas, repeat smoke
   checks on the approved target, then enable production flags through the
   normal release process. Certification
   credentials must never be relabeled as production credentials.

## Required customer/device acceptance test

Use a Kroger customer test account in Kroger Production; Certification has no
customer accounts. Test OAuth separately first, with no cart writes. Explicitly
approve any later test-cart additions. Do not use a customer's real cart for unattended QA.

- Connect/cancel/reconnect on iOS and Android; reject expired, mismatched and
  replayed callbacks; verify a secret or customer token never reaches the app.
- Verify refresh when a customer access token expires, concurrent refreshes,
  disconnect and Pro expiry. Disconnect must still work with the feature disabled.
- Pick a store/fulfillment mode with known fixtures. Verify products, prices,
  package sizes, stock flags and modality accepted by the actual cart endpoint.
- Inspect fresh vs dried/frozen and diet-sensitive alternatives manually. No
  suggestion is a promise about allergen safety or current stock.
- Change package counts, replace a product, add coffee, skip a pantry item and
  add it back. Regenerate the meal plan; check stable selections and renewed approval.
- Go offline, edit, reopen, then reconnect. Test simultaneous edits on two devices
  and explicit cloud-load confirmation after a revision conflict.
- Send one approved batch; verify exact UPC/counts in Kroger, same store and
  fulfillment mode, and no order/checkout operation. Check existing cart items
  are not mistaken for newly sent items.
- Simulate uncertain response and repeated taps: no automatic second add.
  Treat `sending`/`unknown` as a prompt to inspect Kroger, not permission to retry.
- Change store/product availability/price between review and export; require
  renewed review without a cart mutation.
- Sign out/switch Mealvana accounts during a delayed lookup; no stale result or
  local draft must become the next account's editable state.

## Operational safeguards

Keep logs limited to sanitized error categories; do not capture request bodies,
Authorization headers, codes, refresh tokens, or raw Kroger error responses.
Only service-role operators may inspect receipt status; opening up table grants
to fix an access problem is not a valid workaround. Add quota monitoring/caching
before broad rollout; the 60 requests/minute per-user limiter does not bound
the upstream application's daily quota. Cleanup of expired OAuth sessions and
local draft retention can be added through the established maintenance process.
