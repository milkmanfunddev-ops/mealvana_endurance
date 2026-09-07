---
name: drive-device
description: Low-level recipe for driving the dev app on an iOS simulator, the Android emulator, or hardware — boot/install/launch, logging in as a test account, tapping/typing/scrolling programmatically, and capturing screenshots/recordings/frames as evidence. Use it whenever a task needs the running UI (design review, bug repro, sweep, demo capture). The /device-sweep skill layers the full matrix proofread on top of this.
---

# Drive a device

Every hard-won mechanic for operating the app's UI from the terminal, on both
platforms. The traps below each cost real iteration time once; don't rediscover
them.

## Resolve devices at runtime — never hardcode UDIDs

```bash
xcrun simctl list devices | grep "<device name>"     # iOS sims by name
~/Library/Android/sdk/platform-tools/adb devices      # Android
~/Library/Android/sdk/emulator/emulator -list-avds    # AVDs
```

Rad (Xuan's iPhone) has its own skill: `/install-rad`.

## Build + install + launch

- iOS sim: `flutter run -d <udid> --flavor dev -t lib/main_dev.dart --machine`
  **in the background, stdout to a log file**. Wait for `"event":"app.started"`
  in the log. The app persists after the flutter process dies — relaunch any
  time with `xcrun simctl launch <udid> com.milkman.mealvanaendurance.dev`.
- Android emulator: boot the AVD (background), `adb wait-for-device`, then poll
  `adb shell getprop sys.boot_completed` for `1`. Same flutter run with
  `-d emulator-5554`. Relaunch:
  `adb shell am start -n com.milkman.mealvanaendurance.dev/com.milkman.mealvanaendurance.MainActivity`.
- Never pipe flutter output through `head`/`grep` directly (SIGPIPE kills the
  build) — log to a file, grep the file.
- Hot reload is `kill -USR1` on the flutter process, hot restart `-USR2`.
  Constants captured in `initState` (e.g. animation durations) need the
  **restart**, not reload.

## THE coordinate trap

- `xcrun simctl io <udid> screenshot` produces **pixels**; `idb ui tap/swipe`
  takes **points**. Convert every coordinate you read off a screenshot:
  `pt = image_coord × (device_pt_dimension / image_dimension)`. Getting this
  wrong taps the wrong widget and silently derails the flow.
- Android is uniform: `adb exec-out screencap -p` and `adb shell input tap`
  are both **pixels** — no conversion.
- After any downscale (`sips -Z`) recompute from the file you actually read.

## Logging in as a test account

- The shared keychain account only: `scripts/sim-dev-login.sh` (booted sim,
  detects only the email FORM — walk welcome → "I already have an account" →
  "Log in with email" first if needed).
- Any other account (seeded athletes etc.): walk the same three screens, then
  type credentials. Password comes from `secrets/integration_test.env`
  (`INTEGRATION_TEST_PASSWORD`) — parse it with the same regex
  `qa/scripts/seed-athletes.mjs` uses (a loose shell grep once extracted 44
  chars for an 18-char password and burned three login attempts). Never echo
  it, never screenshot the field right after typing (the last char shows).
- `idb ui text` sends the string verbatim as one argument. If a typed field
  looks wrong, **restart the app to reset the form** — clearing via backspace
  keyevents is unreliable (cursor position).
- `adb shell input text` needs escaping: spaces → `%s`, and backslash-escape
  shell specials for the on-device shell.

## Test data and sync behavior

- Accounts: `node qa/scripts/seed-athletes.mjs` (profiles only).
  Populated month (timeline cards, calendar dots, planned/verified/skipped):
  `node qa/scripts/seed-activities.mjs [email]` — idempotent, deterministic
  ids, tag `qa-seed-home-shell`.
- Getting server rows onto a device: a **fresh login always full-pulls
  activities**; an already-logged-in app re-pulls only after the 1h staleness
  window (`flutter.<repo>_last_sync` keys in the app's prefs plist — delete
  via `xcrun simctl spawn <udid> defaults delete`, with the app terminated).
- **Known gap (2026-09-07): meal_logs never download** — `sync-all-data`
  omits them and no client path pulls. If a demo needs meal history/tint,
  mirror the server rows into the sim's local Drift DB
  (`get_app_container ... data` → `Documents/mealvana_endurance_db.sqlite`,
  `INSERT OR REPLACE` with the server row's id, DateTimes as **epoch
  seconds**, `needs_upload=0`). Same-id rows are harmlessly overwritten by a
  later real sync.

## Capturing evidence

- Downscale before Reading a screenshot (`sips -Z 700`) — full-res wastes
  context.
- Motion: `xcrun simctl io <udid> recordVideo` / `adb shell screenrecord`,
  pull, then `ffmpeg -vf "crop=...,fps=8"` to frames; read a handful, not all.
- Verifying an animation detail: temporarily multiply the relevant duration
  ~10x, hot **restart**, record, revert.
- iOS release/profile builds don't surface Dart prints in `log show`; debug
  overflow banners render on-screen — screenshot them, then reproduce the
  exact error in a widget test at that logical size for the real widget chain.

## Resource hygiene

- macOS **killed the Android emulator** when it ran beside four booted iOS
  sims. Boot only what the task needs; `xcrun simctl shutdown <udid>` when
  done (sim disk state, logins, and local DBs persist across shutdown).
