# Shorebird Patching — How To

An over-the-air Dart patch. Ships in minutes, no App Store review.

## What a patch can and cannot ship

| Can | Cannot |
|-----|--------|
| Dart code changes | New/updated native plugins (a new pubspec dep with platform code) |
| Copy, logic, UI, bug fixes | Changes to `ios/` or `android/` native code, entitlements, Info.plist |
| | New assets (patches do **not** ship assets) |

Anything in the right column needs a full store release. This is why the
`is_internal` work could never be patched — it added `flutter_secure_storage`.

## ⚠️ Two traps. Read both before you patch.

**1. A patch replaces the ENTIRE Dart snapshot. It is not a diff.**

Whatever branch you patch from becomes the code every user runs. `develop` is
far ahead of what is in the store. Patching prod from `develop` would ship the
whole unreleased batch — including DB migrations — to production users.

> **Always branch from the release branch, backport the fix there, patch from there.**
> Never patch prod from `develop`.

**2. Don't take `--release-version` from the App Store listing. Take it from Shorebird.**

Shorebird matches a patch to a release by the version compiled into the binary
(`CFBundleShortVersionString` + `CFBundleVersion`). The version string shown on
the App Store listing is a separate field in App Store Connect, and **in this app
the two do not currently agree**: the listing reads **1.20.1**, while the build
behind it is **1.20.0+9**.

`1.20.0+9` is the value that matters — it is what the Shorebird runtime reports,
and it is what you pass to `--release-version`.

Also: **one cut = TWO releases with consecutive build numbers** — prod-ios and
prod-android each bump the same counter, so e.g. 1.26.0 registered as
`1.26.0+109` (iOS) and `1.26.0+110` (Android). Patch each platform against ITS
number; the console's Releases tab shows the platform icon per row. Go looking for a "1.20.1"
release and you will not find one, and will wrongly conclude the patch channel
is broken.

```bash
# THE source of truth for --release-version. Just use this.
shorebird releases list --app-id=16f10ae3-5b24-4e65-81cd-917f904f50d6
```

To confirm which binary is actually live, walk the relationship in App Store
Connect rather than reading the listing string (or `itunes.apple.com/lookup`,
which returns the listing string too):

```
GET /v1/apps/6751113738/appStoreVersions   -> the live version, and its build
GET /v1/appStoreVersions/<id>/build        -> CFBundleVersion  (e.g. 9)
GET /v1/builds/<id>/preReleaseVersion      -> CFBundleShortVersionString (e.g. 1.20.0)
```

If a store build genuinely was cut with plain `flutter build` instead of
`shorebird release`, it has no Shorebird runtime and no patch will ever reach
it. Confirm a matching release exists before spending 20 minutes on a patch
nobody will receive.

## App IDs

| Flavor | Shorebird app_id | Ships via |
|--------|------------------|-----------|
| prod | `16f10ae3-5b24-4e65-81cd-917f904f50d6` | App Store / TestFlight |
| dev  | `d25496f9-4335-4332-81e7-e108e3f48eaa` | TestFlight |

Separate IDs, so a dev patch can never be served to a prod build.

## The easy way: Codemagic (do this)

`prod-ios-patch` and `dev-ios-patch` are **manual** workflows that patch
**whatever branch you start them on**. That branch selection is the whole game.

1. Create the backport branch off the release branch and cherry-pick your fix:
   ```bash
   git fetch origin
   git checkout -b fix/my-patch-1.20 origin/release/1.20
   git cherry-pick <sha>          # or re-implement; 1.20 may differ from develop
   git push -u origin fix/my-patch-1.20
   ```
2. Codemagic → **Start new build** → workflow `prod-ios-patch` → **branch = `fix/my-patch-1.20`**.
3. Set `RELEASE_VERSION` to the exact version from `shorebird releases list`
   (e.g. `1.20.0+9`). Do **not** leave it as `latest` — "latest" is whatever
   Shorebird thinks is newest, which is not necessarily what users have.

> **A patch is bound to ONE release version.** Patching `1.21.1+100` does
> nothing for anyone still on `1.21.1+99`. If testers are spread across builds,
> either patch each release separately or have them take the newest TestFlight
> build. Check who is where before assuming one patch covers everyone.

Note that pushing to `develop` also auto-triggers the `dev-ios` **release**
workflow, which cuts a *new* build (e.g. `+101`) with your change compiled in.
So a dev change usually reaches testers two ways: natively in the next
TestFlight build, and OTA via the patch for whoever hasn't updated. The patch is
what saves them a reinstall — it isn't redundant.

Dev is the same, using `dev-ios-patch` off `develop`.

## The hard way: local CLI — iOS ONLY

Fully viable for iOS since 2026-09-11 (patches #1–#3 on 1.26.0+109 all shipped
this way). The old heads-up — the IPA export dying on
`OneSignalLocation.framework.dSYM` — is **obsolete**: pass `--no-codesign` and
the export step (where that failure lived) never runs at all. A patch ships no
IPA, so nothing is lost, and no distribution certificate is needed in the
local keychain either.

> **Android can NOT go local.** The prod flavor hard-requires the release
> upload keystore (`android/key.properties`), which exists ONLY in Codemagic's
> `CM_KEYSTORE_B64` env group, and `shorebird patch android` has no
> `--no-codesign`. Android patches run via the `prod-android-patch` workflow —
> pin `RELEASE_VERSION` in `codemagic.yaml` ON the backport branch (grep the
> 1.26.0 patch branch for the precedent) rather than trusting a UI field.

**Auth:** `SHOREBIRD_TOKEN` from an API key (console → Account → API Keys;
the support@mealvana.io account owns the org). The current key lives in
`secrets/shorebird.env` — `set -a; source secrets/shorebird.env; set +a`.
No `shorebird login` needed.

Every one of these has cost someone an hour.

```bash
shorebird upgrade          # DO THIS FIRST — see below

git worktree add --detach /tmp/wt-126 <backport-branch-tip-sha>
cd /tmp/wt-126
cp /path/to/repo/.env /path/to/repo/.env.dev.local /path/to/repo/.env.prod.local .
flutter pub get

# ALWAYS dry-run first (validates + shows asset/native diffs, uploads nothing):
set -a; source /path/to/repo/secrets/shorebird.env; set +a
CI=true nohup shorebird patch ios --flavor prod --target lib/main_prod.dart \
  --release-version 1.26.0+109 --no-codesign --dry-run > patch_dry.log 2>&1 &

# READ the reported diffs (see the --allow-asset-diffs bullet), THEN ship:
CI=true nohup shorebird patch ios --flavor prod --target lib/main_prod.dart \
  --release-version 1.26.0+109 --no-codesign --allow-asset-diffs > patch.log 2>&1 &

tail -f patch.log
```

A patch is a FULL Dart snapshot, not a delta on earlier patches: build it from
a tree carrying EVERY fix that should be live (the backport branch), and
devices jump straight to the newest patch number.

- **`shorebird upgrade` first.** An out-of-date CLI fails at the *very last
  step* ("Creating patch ✗") after build, verify and diff have all succeeded.
- **`CI=true`** — otherwise it tries to prompt and dies with "No terminal
  attached to stdout".
- **Detach it.** The AOT link alone takes ~7.5 min, the whole patch ~15. Any
  wrapper timeout shorter than that kills it mid-flight. Log to a file; piping
  to `tail` buffers everything and you see nothing.
- **Copy the `.env*` files in.** They're gitignored, and the build fails without
  them ("No file or variants found for asset: .env").
- **`--allow-asset-diffs` suppresses a real warning — read every diff before you
  use it.** The known-inert set (1.20 and 1.26 precedents): the copied `.env*`
  files, and Xcode toolchain version stamps inside `Assets.car` when the local
  Xcode differs from Codemagic's. Patches do **not** ship assets, so any asset the patched Dart code
  actually depends on will be missing at runtime. Only pass this flag once you
  have looked at each reported diff and confirmed it is inert. In the 1.20
  backport they were: the `.env*` files you copied in to make the worktree
  build, and local Xcode metadata in `Assets.car` — neither is read by the
  patched code, and prod keeps its originally bundled env. A **native** diff is
  never inert. Stop and investigate if you see one.
- Shorebird rewrites `ios/Runner.xcodeproj` during the build. `git checkout` it
  afterwards.

## Verify it landed

```bash
shorebird patches list --app-id=<app_id> --release-version=1.20.0+9
```

Check the **release's** patches, not the app's `latest_patch_number` — that
tracks the newest release across *all* platforms, so it reads `None` even when
your iOS patch shipped fine.

Patches apply on the **next app restart**, not immediately.

## Source of truth

`shorebird.yaml` · `codemagic.yaml` (workflows `*-ios-patch`) · `pubspec.yaml`
