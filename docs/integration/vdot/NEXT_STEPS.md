# V.O2 (VDOT) — Connection Fix Runbook

**Status:** ✅ RESOLVED 2026-06-03 (verified live on iOS simulator).
**Date:** 2026-06-03
**Owner handoff:** This runbook is written so another Claude Code instance can execute it end-to-end.

Companion doc: `docs/integration/vdot/README.md` (architecture + full implementation status).

---

## ✅ Resolution (2026-06-03)

Two things were verified/fixed:

1. **`exchangeCodeForToken` `invalid_payload` = empty `client_secret` in the request
   BODY, caused by a STALE BUNDLED `.env` ASSET** (not a Dart bug). Root cause proven
   on 2026-06-03:
   - Live-endpoint probes established the exact rule: VDOT returns `invalid_payload`
     **iff** the body's `client_secret` (or `client_id`) is empty; a wrong-but-present
     secret returns `invalid_code`. VDOT reads creds from the **body** and ignores the
     Basic auth header (confirmed: valid Basic header + empty body secret still →
     `invalid_payload`).
   - The secret was added to `.env.*` on **2026-05-18**, but the `build/` tree still
     held `flutter_assets/.env.*` bundles from **2026-04-02 / 04-17 / 04-22 with NO
     VDOT key at all** (e.g. `build/ios/dev-Debug-iphonesimulator/...` vs the newer
     `build/ios/Debug-dev-iphonesimulator/...`). An incremental `flutter run` reused a
     stale, secret-less bundle → `dotenv` returns the `''` fallback for the secret
     while `client_id` falls back to its literal real value `'mealvana'` (so the
     failure is silent) → server `invalid_payload`.
   - **The actual fix is `flutter clean` + rebuild** (re-bundles the current `.env`).
     Verified live: after a clean rebuild the diagnostic logs `client_secret len 64`
     and the V.O2 sync succeeds (refresh + 13 workouts). The Final Surge `.env` line
     is already single-quoted in both files (Step 3 done).
   - Hardening shipped so this never again hides as an opaque server error:
     `exchangeCodeForToken` + `refreshAccessToken` now throw a clear
     "credentials are not loaded … clean rebuild" error on empty creds (fires in
     release too), and `vdotApiClient` logs `client_secret len N` at construction
     (debug) — `len 0` is the instant smoking gun.

2. **NEW BUG FOUND + FIXED — the refresh-token path.** `refreshAccessToken` in
   `vdot_api_client.dart` sent `client_id`/`client_secret` **only via the Basic auth
   header, not in the form body**. VDOT's custom .NET endpoint **ignores Basic auth
   and reads creds from the body** (the same reason `exchangeCodeForToken` puts them
   in the body). So **every token refresh returned `invalid_payload`**, dropping the
   integration to `requires_reauth` the moment the ~short-lived access token expired —
   forcing a needless full re-OAuth on a routine refresh.
   Proven against the live endpoint:
   | Refresh request shape | Response |
   |---|---|
   | Basic auth only, no body creds (the app's old shape) | `invalid_payload` (400) |
   | creds in the body | payload **accepted** (500 only on the dummy token) |
   **Fix:** added `client_id`/`client_secret` to the refresh body (mirrors
   `exchangeCodeForToken`) + the same empty-cred guard. After the fix, a live sync on
   a previously-`requires_reauth` account auto-recovered: proactive refresh succeeded,
   13 workouts synced, token rotated (new expiry +90d), status → `success`, UI shows
   "Synced!". No re-OAuth needed.

**Verified end-to-end on simulator (dev flavor):** secret loads, refresh succeeds,
13 V.O2 workouts imported and matched to the correct local day (e.g. "Easy Run · 9.6 mi"
on Jun 1), DB `integrations` CHECK allows `provider='vdot'`.

The steps below are retained as the original runbook for reference.

---

## TL;DR of the diagnosis

The VDOT token endpoint (`https://app.vdoto2.com/oauth/token`) returns
`{"status":"NOK","error":"invalid_payload"}` when the **form body is missing a
non-empty `grant_type`, `client_id`, or `client_secret`** (or when the body is
sent as JSON instead of `application/x-www-form-urlencoded`). This was proven by
probing the live endpoint with a dummy code:

| Request shape | Response |
|---|---|
| form-urlencoded, creds in body | `invalid_code` (payload accepted) |
| JSON body | `invalid_payload` |
| form, **empty `client_secret`** | **`invalid_payload`** ← the app's failure |
| form, wrong (non-empty) secret | `invalid_code` |
| form, missing `redirect_uri` | `invalid_code` (redirect is NOT the cause) |

In the failing run the app sent an **empty `client_secret`**. `client_id` was
present (`mealvana`, visible in the auth URL) and `grant_type` is a hardcoded
constant — so the secret was the empty field.

**Why it was empty:** `.env` files are bundled as Flutter **assets at build
time**. The failing session ran a **stale build** (made before the secret was
present/loaded). The on-disk `.env.dev.local` / `.env.prod.local` both contain a
correct 64-char secret and flutter_dotenv parses the VDOT line cleanly, so a
**clean rebuild loads it correctly**.

Trap to remember: in `lib/shared/services/app_config.dart`, `vdotClientId`'s
fallback is literally `'mealvana'` (the real value) while `vdotClientSecret`'s
fallback is `''`. So when env doesn't load, `client_id` still looks correct and
only the secret silently goes empty.

---

## Step 1 — Clean rebuild and re-run (the actual fix)

Device choice does **not** matter. Use the already-booted iOS simulator (no
physical device needed).

> Do NOT just hot-reload a running app — `.env` files are bundled as **assets**
> baked in at build time. You need a fresh `flutter run`/build.

### This must work for every build variant

The same root cause and fix apply across **dev + prod flavors** and **debug +
release** modes, because the secret is loaded from a **bundled `.env` asset** the
same way in all of them (assets are bundled identically in debug and release).
Both env files carry the correct 64-char secret:

| Variant | Entry point | Env file (asset) | Notes |
|---|---|---|---|
| Dev · debug | `lib/main_dev.dart` | `.env.dev.local` | `./scripts/run_dev.sh` |
| Dev · release | `lib/main_dev.dart` | `.env.dev.local` | add `--release` |
| Prod · debug | `lib/main_prod.dart` | `.env.prod.local` | VS Code "Prod Flavor" |
| Prod · release | `lib/main_prod.dart` | `.env.prod.local` | add `--release` |
| **Web** | `lib/main_web.dart` | **none — `--dart-define`** | see below |

Commands:

```bash
# Dev flavor (loads .env.dev.local). Pin a device or omit -d for the picker.
./scripts/run_dev.sh -d "iPhone 15 Pro Max"                     # debug
./scripts/run_dev.sh -d "iPhone 15 Pro Max" --release           # release

# Prod flavor (loads .env.prod.local)
flutter run --flavor prod -t lib/main_prod.dart                 # debug
flutter run --flavor prod -t lib/main_prod.dart --release       # release
```

**Web is the one different path.** `AppConfig.fromDartDefines()`
(`app_config.dart`) reads `VDOT_CLIENT_SECRET` via `String.fromEnvironment`, NOT
dotenv — so the secret must be supplied at build time or it falls back to `''`
(same `invalid_payload` trap). Pass the env file as defines:

```bash
flutter run -t lib/main_web.dart -d chrome \
  --dart-define-from-file=.env.prod.local
```

The runtime guard added to `VdotApiClient` is **not** gated by `kDebugMode`, so it
fires identically in release and debug, for native and web — whichever way config
was sourced. Only the cred-length debug log is suppressed in release (by design;
never log secrets in release). So if the secret is missing in any variant, you get
the same clear error rather than an opaque server `invalid_payload`.

**Verify the secret loaded.** `VdotApiClient.exchangeCodeForToken` now logs (debug
only, value never printed):

```
🔑 [vdot] Token exchange creds: client_id="mealvana" (len 8), client_secret len 64
```

- `client_secret len 64` → good, proceed to Step 2.
- `client_secret len 0` → env still not loading; the client will now throw a
  clear error instead of hitting the server. Jump to **Troubleshooting A**.

---

## Step 2 — Retry the V.O2 connection and branch on the result

In the app: **Settings → Connected Apps → V.O2 → Connect**, complete the VDOT
login/authorize, and read the console.

- ✅ **Success** (integration saved, workouts import) → go to Step 4.
- ❌ **`invalid_code`** → the payload is now correct but the **secret VALUE is
  wrong/stale**. Go to **Troubleshooting B**.
- ❌ **`invalid_payload` still** → secret is still empty at runtime. Go to
  **Troubleshooting A**.

---

## Step 3 — Apply the Final Surge `.env` fix (separate bug, do this too)

`.env.prod.local` (and check `.env.dev.local`) line for
`FINAL_SURGE_CLIENT_SECRET` has an **unquoted value containing `'`, `#`, and
`$`**. flutter_dotenv (v5.2.1, line-by-line `Parser`) strips `#…` as a comment,
interpolates `$x`, and treats `'` as a quote — so the **Final Surge secret loads
corrupted**. VDOT (clean hex) is unaffected, but fix FS while here:

- Wrap the value in **single quotes**: `FINAL_SURGE_CLIENT_SECRET='…'`.
  Single-quoted values skip interpolation and comment-stripping.
- ⚠️ If the secret itself contains a `'`, single-quote wrapping won't round-trip
  cleanly — in that case confirm the exact secret with Lee and escape as `\'`.
- These files are git-ignored local secrets — **do not commit them**, and never
  print the secret value.
- After editing any `.env`, **clean rebuild** (same as Step 1) for it to take effect.

---

## Step 4 — End-to-end verification once connected

1. **DB CHECK constraint** must allow `provider='vdot'` or saving the integration
   row fails. Memory says this was applied to dev + prod on 2026-05-27; re-confirm
   against the live DB before relying on it. SQL (idempotent — paste into DataGrip,
   NOT `db push`; see memory note `supabase-schema-via-datagrip`):
   ```sql
   ALTER TABLE integrations DROP CONSTRAINT IF EXISTS integrations_provider_check;
   ALTER TABLE integrations ADD CONSTRAINT integrations_provider_check
     CHECK (provider IN ('final_surge','training_peaks','strava','garmin','vdot'));
   ```
   Projects: dev `vlmtsdzpnjnavdgytcmi`, prod `wvmvsodrvbkxfydabqed`.
2. **Import** workouts from V.O2 (auto-runs on connect as of commit `5f5aed2`).
3. **Match check:** VDOT `eventDate` is tz-naive — confirm imported workouts match
   to planned `activities.scheduled_date_time` on the correct local day (same
   gotcha as TP/Final Surge). Verify a V.O2-attributed note renders in the
   activity detail (coach-notes widget).

---

## Troubleshooting

### A — `client_secret` still empty after a clean rebuild
The env isn't loading the VDOT key for the running entrypoint.
1. Confirm which entrypoint ran and which file it loads:
   - `lib/main_dev.dart` → `.env.dev.local`
   - `lib/main_prod.dart` / `lib/main.dart` → `.env.prod.local`
2. Confirm the loaded file actually has the key (value masked):
   ```bash
   awk -F= '/^VDOT_CLIENT_SECRET=/{print "len="length($2)}' .env.dev.local .env.prod.local
   ```
3. Confirm `.env.*` are listed under `flutter/assets:` in `pubspec.yaml` (they are
   as of 2026-06-03). If you changed pubspec, run `flutter clean` then rebuild.
4. Check no earlier line in the file breaks parsing for following keys (an
   unbalanced quote / stray `$` / `#`). The Step 3 Final Surge line is the known
   offender — fix it and re-test.

### B — `invalid_code` (payload OK, secret value wrong)
The 64-char secret on disk is not the credential VDOT expects. Re-obtain the
client secret from VDOT (partner contact `info@vdoto2.com`), update
`VDOT_CLIENT_SECRET` in both `.env.dev.local` and `.env.prod.local`, and clean
rebuild. Note: the authorize step succeeding (you see the VDOT "Authorize
Mealvana" screen) only validates `client_id` + `redirect_uri`, NOT the secret —
the secret is first checked at token exchange.

### Re-probe the live endpoint (no app needed)
Reproduces server behavior without exposing the secret in shell history; reads
creds from the env file. A dummy code returning `invalid_code` proves the payload
shape + creds are accepted (only the code is bad):
```bash
CID=$(awk -F= '/^VDOT_CLIENT_ID=/{print $2}' .env.prod.local)
CSEC=$(awk -F= '/^VDOT_CLIENT_SECRET=/{print $2}' .env.prod.local)
curl -s -w "\nHTTP %{http_code}\n" -X POST "https://app.vdoto2.com/oauth/token" \
  -H "Content-Type: application/x-www-form-urlencoded" -H "Accept: application/json" \
  --data-urlencode "grant_type=authorization_code" \
  --data-urlencode "code=00000000-0000-0000-0000-000000000000" \
  --data-urlencode "redirect_uri=com.milkman.mealvanaendurance://callback" \
  --data-urlencode "client_id=$CID" --data-urlencode "client_secret=$CSEC"
```

---

## Reference: code touched on 2026-06-03
- `lib/features/integrations/data/vdot_api_client.dart`
  - `exchangeCodeForToken` now throws a clear error if `client_id`/`client_secret`
    is empty (instead of the opaque server `invalid_payload`).
  - Logs credential **lengths** in debug (never the value).
  - Annotates a real `invalid_payload` server response with its likely cause.
- Memory: `project_vdot_invalid_payload.md`.
