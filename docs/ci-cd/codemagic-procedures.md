# Codemagic Procedures — Day-to-Day Operations

**Last updated:** 2026-04-24

This is the canonical operational guide for the Codemagic CI/CD pipeline. If you want to ship a build, patch a bug via OTA, or figure out why CI is angry, start here.

- For initial setup / first-time onboarding → [codemagic-setup.md](./codemagic-setup.md)
- For Shorebird reference → [shorebird-integration.md](./shorebird-integration.md)
- For secrets inventory → [secrets-and-environments.md](./secrets-and-environments.md)

---

## TL;DR — the map

| Git action | Workflow(s) fired | Destination | Shorebird? |
|---|---|---|---|
| Push to `develop` | `dev-ios`, `dev-android` | iOS dev TestFlight (`com.mealvana.endurance.dev`) + Play **Internal** | No |
| Push to `release/*` | `prod-ios`, `prod-android` | iOS prod TestFlight (`com.mealvana.endurance`) + Play **Alpha** (closed testing) | **Yes** |
| Push to `main` | `main-ios`, `main-android` | **App Store** (manual release gate) + Play **Beta** (open testing) | **Yes** |
| Open/update a PR | `pr-validation`, `integration-tests` (PRs to develop/feature/release only) | — | — |
| Manual: "prod-ci" | `prod-ci-ios` | iOS dev TestFlight with **prod flavor code** | No |
| Manual: OTA patch | `prod-ios-patch`, `prod-android-patch` | Shorebird CDN only (no store upload) | **Yes (patch)** |
| Manual: emergency non-Shorebird build | `ios-build-legacy`, `android-build-legacy` | TestFlight / Play **Internal** | No |

**Rule of thumb for the version in `pubspec.yaml`:**
- Every Shorebird-enabled `release` (prod-ios / prod-android / main-ios / main-android) needs a **version that hasn't been released before for that flavor**. If two workflows try to release the same `X.Y.Z+build`, the second one errors.
- Shorebird **patches** (prod-*-patch) do NOT bump the version. They target an existing release.

---

## Workflows in detail

### Automatic on `develop` push → dev TestFlight + Play Internal

| Workflow | What it does |
|---|---|
| `dev-ios` | Builds `--flavor dev --target lib/main_dev.dart` → uploads to TestFlight for the `com.mealvana.endurance.dev` ASC app (Internal Testers group). Does **not** use Shorebird. |
| `dev-android` | Builds `--flavor dev --target lib/main_dev.dart` → uploads to Play **Internal** track. Does **not** use Shorebird. |

**When to use:** every push to `develop`. This is the everyday internal dogfooding build. Testers should be on the Internal Testers TestFlight group or Play Internal track.

**Version bump:** not required. Dev builds aren't user-visible production releases. TestFlight/Play auto-increment build numbers per upload so multiple pushes just queue up as build 1, 2, 3, ... of the same version.

### Automatic on `release/*` push → prod TestFlight + Play Alpha (closed)

| Workflow | What it does |
|---|---|
| `prod-ios` | `shorebird release ios --flavor prod --target lib/main_prod.dart` → TestFlight Internal Testers for `com.mealvana.endurance`. Creates a Shorebird iOS release artifact. |
| `prod-android` | `shorebird release android --flavor prod --target lib/main_prod.dart --artifact=aab` → Play **Alpha** track. Creates a Shorebird Android release artifact. |

**When to use:** when a `release/vX.Y` branch has been cut for a candidate-for-production build. This is the quality gate before App Store.

**Version bump:** yes — bump `pubspec.yaml` to the target release version before the first push to `release/*`. If you re-push to an existing release branch, the build number in `pubspec.yaml` must increment, otherwise Shorebird will refuse the re-release.

### Automatic on `main` push → App Store + Play Beta (open)

| Workflow | What it does |
|---|---|
| `main-ios` | `shorebird release ios --flavor prod --target lib/main_prod.dart` → uploads to TestFlight AND submits to App Store review. `release_type: MANUAL` — Apple reviews it, then you press "Release This Version" manually in App Store Connect. |
| `main-android` | `shorebird release android --flavor prod --artifact=aab` → Play **Beta** track (open testing, since the app isn't released to Production yet). |

**When to use:** when `release/vX.Y` has passed TestFlight/Alpha testing and is ready to ship.

**Version bump:** yes — bump `pubspec.yaml` version+build number before the merge-to-main commit, because this flow creates **a new Shorebird release distinct from the one `release/*` created**. Same version → Shorebird errors. See [version bumping](#version-bumping) below.

### Manual: `prod-ci-ios` — prod-flavor smoke test on dev TestFlight

**When to use:** you want to dogfood prod-configured code (real Supabase prod endpoint, real Sentry, real TrainingPeaks production API) without going through a `release/*` branch. Maybe you're debugging a prod-only issue locally.

**How it's wired:** `--flavor dev --target lib/main_prod.dart`. The `dev` flavor gives you the `com.mealvana.endurance.dev` bundle ID and signing (Xcode-level). The `main_prod.dart` entry point loads `.env.prod.local` at runtime. So the binary identifies as the dev app but talks to prod services.

**How to trigger:** Codemagic UI → Start new build → pick `prod-ci-ios` → pick branch → Start. Or via API (see [triggering builds](#triggering-builds-via-api)).

**Version bump:** not required. This isn't a Shorebird release.

**Caution:** this build uploads to the dev TestFlight. Testers will see a dev-icon build but it's pointed at prod data. Label the TestFlight build notes accordingly so no one confuses it with a dev-flavor build.

### Manual: `prod-ios-patch` / `prod-android-patch` — Shorebird OTA

**When to use:** a Dart-only bug fix you want to push to users on an already-released version without another App Store / Play review cycle.

**Requirements for a valid patch:**
- No changes to native code (Swift, Kotlin, Objective-C, Java)
- No changes to `pubspec.yaml` dependencies (including transitive ones that bring native code)
- No changes to assets that aren't Dart-loadable
- No Flutter SDK version change

If any of those change, you need a fresh **release** (via `release/*` or `main`), not a patch.

**How to trigger:** Codemagic UI → Start new build → pick `prod-ios-patch` or `prod-android-patch`. Default targets the latest release; set the `RELEASE_VERSION` env var to patch a specific older version.

**Version bump:** do NOT bump the version. Patches target an existing release.

### Automatic on PR → validation

| Workflow | What it does | Fires on |
|---|---|---|
| `pr-validation` | `flutter analyze` + `dart format --set-exit-if-changed` + `flutter test` | Any PR |
| `integration-tests` | All of the above + `flutter test integration_test/` on an iOS simulator | PRs targeting `develop`, `feature/*`, `release/*` |

**How to tell which one failed:** `pr-validation` is fast (5-10 min). `integration-tests` is slow (30-45 min). Both block merges if they fail.

---

## Version bumping

**Only `pubspec.yaml` matters.** Its `version: X.Y.Z+N` field is what Shorebird, TestFlight, Play, and the App Store all key off.

### When to bump

| Situation | Bump? | Change what |
|---|---|---|
| Push to `develop` | No | — |
| First push to a new `release/vX.Y` branch | Yes | `X.Y.Z` to the target release version |
| Re-push same commit to `release/vX.Y` | No (won't trigger) | — |
| Additional commit pushed to existing `release/vX.Y` | **Yes** | Bump **only the `+N` build number** (e.g., `1.17.0+3` → `1.17.0+4`) |
| Merge `release/vX.Y` → `main` | **Yes** | Bump **at least `+N`** before the merge commit lands on main, otherwise `main-ios`/`main-android` will collide with the Shorebird release already created from `release/*` |
| Shorebird patch (OTA) | **No** | — |
| Emergency legacy build | No (but build number should still be unique to the store) | — |

### Why the main-vs-release collision exists

Shorebird tracks releases as `(flavor, flutter_version, pubspec_version)`. When `release/1.17` pushes and the build runs, Shorebird registers `prod / stable / 1.17.0+3` (or whatever). When `main` later pushes the exact same commit (after merging release/1.17 → main), `main-ios` tries to register the same tuple and Shorebird errors with "release already exists".

**Simplest practice:** after the `release/1.17` branch has created its Shorebird release and you've confirmed the TestFlight/Alpha build, open a PR back to `release/1.17` that bumps `+N` (e.g., `1.17.0+3` → `1.17.0+4`) and merge it before also merging to `main`. Now `main`'s Shorebird release is `1.17.0+4`, distinct from `release/*`'s `1.17.0+3`.

Alternative: bump the full version on merge-to-main (e.g., `1.17.0+3` on release → `1.17.1+1` on main). Less clean for comparing App Store vs TestFlight, but also valid.

### Where to bump

`/pubspec.yaml`:
```yaml
version: 1.17.0+4
#        ^^^^^^ ^
#        semver +build
```

After bumping, run `flutter pub get` locally to update `pubspec.lock`. Commit both.

---

## Standard release flow — feature branch → App Store

1. **Work in a feature branch.**
   - Branch from `develop` (e.g., `feature/new-onboarding`).
   - `pr-validation` runs on every PR push; `integration-tests` runs on PRs to `develop`/`feature/*`/`release/*`.

2. **Merge to `develop`.**
   - `dev-ios` + `dev-android` fire automatically → dev TestFlight + Play Internal.
   - Testers dogfood.

3. **Cut a `release/vX.Y` branch from `develop`** when ready to stabilize.
   - Bump `pubspec.yaml` to `X.Y.0+1`.
   - Push the branch. `prod-ios` + `prod-android` fire → prod TestFlight + Play Alpha (closed testing) with Shorebird releases.

4. **Stabilize on `release/vX.Y`.**
   - Bugfix commits go onto `release/vX.Y`. Each push bumps `+N` in `pubspec.yaml`.
   - Apply Shorebird **patches** (not full releases) via `prod-ios-patch`/`prod-android-patch` when you want to push a Dart-only fix to existing TestFlight/Alpha testers without a full rebuild.

5. **Promote to production.**
   - Bump `pubspec.yaml` `+N` once more (to avoid colliding with the Shorebird release on `release/*`).
   - Merge `release/vX.Y` → `main`.
   - `main-ios` + `main-android` fire → App Store submission (manual release gate) + Play Beta (open testing).
   - In App Store Connect, wait for Apple review. When approved, press "Release This Version" to actually ship to users.
   - In Google Play Console, the Beta track is already live to open testers.

6. **After release, if a bug surfaces:**
   - Dart-only fix: apply a Shorebird patch via `prod-ios-patch`/`prod-android-patch` targeting the released version.
   - Native fix: new `release/vX.Y.Z+1` branch → repeat steps 3–5.

---

## Triggering builds via API

Codemagic API token lives at `~/.codemagic/token` (chmod 600).

**List recent builds:**
```bash
curl -s -H "x-auth-token: $(cat ~/.codemagic/token)" \
  "https://api.codemagic.io/builds?appId=6929d76c3da87a6f81ddfab2&limit=10" \
  | jq '.builds[] | {id: ._id, workflow: .config.name, branch, status, msg: .message}'
```

**Start a build:**
```bash
curl -s -X POST -H "x-auth-token: $(cat ~/.codemagic/token)" \
  -H "Content-Type: application/json" \
  -d '{"appId":"6929d76c3da87a6f81ddfab2","workflowId":"prod-ci-ios","branch":"develop"}' \
  "https://api.codemagic.io/builds"
```

**Get a single build's detail (failure reason lives in `.build.message`):**
```bash
curl -s -H "x-auth-token: $(cat ~/.codemagic/token)" \
  "https://api.codemagic.io/builds/BUILD_ID" \
  | jq '{status: .build.status, message: .build.message, workflow: .build.config.name}'
```

**Cancel a build:**
```bash
curl -s -X POST -H "x-auth-token: $(cat ~/.codemagic/token)" \
  "https://api.codemagic.io/builds/BUILD_ID/cancel"
```

App ID, team ID, and variable-group IDs are in `/.claude/projects/.../memory/reference_codemagic.md` (local reference, not checked in).

---

## Env groups & secrets

**Where values live (Codemagic → Variable Groups):**

| Group | Used by | Key vars |
|---|---|---|
| `mealvana_dev` | dev-ios, dev-android, integration-tests, pr-validation, integration-test-quick | `DOTENV_ROOT`, `DOTENV_DEV_LOCAL` (full `.env.*` contents as single secure vars) |
| `mealvana_prod` | prod-ios, prod-android, prod-ios-patch, prod-android-patch, main-ios, main-android, prod-ci-ios, ios-build-legacy, android-build-legacy | `DOTENV_ROOT`, `DOTENV_PROD_LOCAL` |
| `shorebird_credentials` | all Shorebird workflows | `SHOREBIRD_TOKEN` |
| `firebase_config` | all Android workflows (writes `android/app/google-services.json`) | `GOOGLE_SERVICES_JSON` |
| `google_play_credentials` | dev-android, prod-android, main-android, android-build-legacy | `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` (service account JSON) |
| `android_signing_credentials` | all Android workflows (writes `android/app/keystore.jks` + `android/key.properties`) | `CM_KEYSTORE_B64`, `CM_KEYSTORE_PASSWORD`, `CM_KEYSTORE_KEY_PASSWORD`, `CM_KEYSTORE_KEY_ALIAS` |

**How `.env` files get to the build machine:** `codemagic.yaml` has a reusable script `&write_dotenv_files` that decodes `DOTENV_ROOT`, `DOTENV_DEV_LOCAL`, `DOTENV_PROD_LOCAL` from secure env into `.env`, `.env.dev.local`, `.env.prod.local` at the start of every workflow. Missing vars are written as empty stubs (so asset bundling doesn't error, but a dev build never sees prod secrets unless its group is configured to). Edit those secure vars (not anything else) to change runtime config.

**How the Android keystore gets there:** `&setup_android_signing` script decodes `CM_KEYSTORE_B64` → `android/app/keystore.jks` and writes a fresh `android/key.properties` that points at it. Matches what `android/app/build.gradle.kts` expects.

**Rotating a value:**
1. `curl -s -H "x-auth-token: $(cat ~/.codemagic/token)" "https://codemagic.io/api/v3/variable-groups/GROUP_ID/variables"` to list vars + their IDs
2. `curl -s -X DELETE ...` the old var
3. `curl -s -X POST ...` to bulk import the new value (body `{"secure":true,"variables":[{"name":"X","value":"..."}]}`)

Variable group IDs are in the non-checked-in memory reference.

---

## Troubleshooting

### `Codemagic.yaml references to unknown variable group(s): <name>`
The named group is either not attached to the app, or exists but has **zero variables** (empty groups trip the validator). Add at least one var.

### `No matching profiles found for bundle identifier "com.mealvana.endurance"`
Post-auth error from `xcode-project use-profiles`. The ASC API key is working, but:
- The API key's role in ASC is lower than **App Manager** → can't manage profiles. Fix: bump role in App Store Connect → Users and Access → Integrations.
- The bundle identifier isn't registered in ASC → Certificates, Identifiers & Profiles → Identifiers → verify.
- A distribution cert is missing → Codemagic auto-creates if the key has permission.

### `flutter analyze` fails in `pr-validation`
Code issue, not a CI issue. Run `flutter analyze` locally, fix lints, push.

### Android build fails with "Keystore file not found"
The `setup_android_signing` script didn't run, or `CM_KEYSTORE_B64` is unset. Check:
- Workflow has `android_signing_credentials` in `groups:`.
- Workflow has `*setup_android_signing` in `scripts:` after `*load_firebase_config`.

### Shorebird release errors with "release already exists"
Version collision. Another workflow already released this `(flavor, flutter_version, pubspec_version)` tuple. Bump `pubspec.yaml` `+N` and re-push. See [version bumping](#version-bumping).

### First Android Shorebird release
One Shorebird app (app_id `16f10ae3-5b24-4e65-81cd-917f904f50d6`, flavor `prod` in `shorebird.yaml`) serves **both** iOS and Android. No separate Android app or shorebird.yaml change is needed. The first successful run of `prod-android` or `main-android` creates the Android release artifact under the existing app. If that first run errors with "app does not support Android" or similar, create an Android-enabled app via [console.shorebird.dev](https://console.shorebird.dev) and update the `flavors.prod` entry — but this is not expected based on current account state.

### Dart code can't find an env value (`dotenv.env['X']` returns null)
The `.env*` file on the Codemagic machine is the stub version — meaning the matching `DOTENV_*` secret wasn't in any of the workflow's env groups. Two options:
- Add the DOTENV var to the group (`DOTENV_DEV_LOCAL` for dev builds, `DOTENV_PROD_LOCAL` for prod builds) — both flows already do this correctly.
- If you added a new var to `.env.prod.local` locally, you must re-upload it to Codemagic (the `DOTENV_*` vars are a frozen snapshot of the file contents, not a live mirror).

### `pod install` fails / iOS build can't find CocoaPods plugin
Run `pod repo update` at the top of the offending script, or bump `max_build_duration` — first-time pod installs can be slow.

### Build never starts, `.status: failed` with no `startedAt`
Validator-level failure. Read `.build.message` — it's usually an env group problem or a yaml syntax issue.

---

## Changelog

- **2026-04-24:** Rewrote branch-mapping (Phase 3). Added `main-ios`, `main-android`, `prod-ci-ios` workflows. `release/*` Android track changed `beta` → `alpha` (closed). `dev-*` workflows now auto-trigger on `develop` (previously manual). Android keystore + dotenv files now written from Codemagic secure vars at build time. `google_play_credentials` group populated with the Play service-account JSON.
- Before 2026-04-24: all workflows existed as manual (`events: []`) or triggered only on `release/*`; env groups `google_play_credentials` and `mealvana_dev` were empty, causing every recent `release/1.17` build to fail at validator stage.
