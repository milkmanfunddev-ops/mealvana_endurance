# 40: The content service initialises at startup (raw keys never show)

**Status:** done 2026-10-08 by the lead (`2b730018`, before the develop push): ContentDefaultsCache + bootstrap preload + provider start; the preload catch reports through the global Report (D9); full suite 5154 pass. Retest in ticket 48/49/50 (the raw-key screens).
**Labels:** fix, round:develop-2026-10, area:content
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** nothing. Runs FIRST in wave 4, alone (Lee, 2026-10-08): every ticket that adds a content key is retested through this fix.
**Next:** `/testing-wave develop-2026-10` (fix wave 4)
**Model:** opus

**What to build:** Restore the content half of mealplanning commit `07dbca24` ("fix(content,vana): two bugs from the simulator walkthrough"), which the branch split dropped. On develop-next nothing calls `ContentService.initialize()`, so `_cachedContent` stays null and every `getValue(key)` without a `defaultValue` returns the key itself. Line numbers are from code at `d7650d15`.

1. **The provider starts `initialize()` itself.** `contentServiceProvider` (`lib/features/content/application/content_service.dart:115-117`) returns `ContentService(ref)` and nothing else. `grep -rn "initialize()" lib` finds no caller of `ContentService.initialize()`; per Finding 32-001, the last caller went in `ab6c04ce` (2025-08-22). Replace the body with origin/develop's (`git show origin/develop:lib/features/content/application/content_service.dart`, last lines):
   ```dart
   final service = ContentService(ref);
   // Nothing else in startup awaits initialize(); start it here so every
   // consumer gets real values (cache → bundled defaults) without a caller
   // having to remember. main() has already preloaded the bundled defaults.
   unawaited(service.initialize());
   return service;
   ```
2. **`getValue` falls back to the bundled defaults.** Today `getValue` (`:71-75`) returns `_cachedContent?.getValue(key, defaultValue: defaultValue) ?? defaultValue ?? key`. Use origin/develop's order instead: active content (cache or remote) → bundled defaults → the call's `defaultValue` → the raw key. The code is `_cachedContent?.getValue(key) ?? ContentDefaultsCache.values?[key] ?? defaultValue ?? key`. This matters even after item 1. `initialize()` sets `_cachedContent` from `getActiveContent()` (`content_repository.dart:33-56`), and that call returns a SharedPreferences cache when one exists. A cache written before a key was added does not have the key (07dbca24's message: "a stale SharedPreferences cache outranked the bundled content_defaults.json"). Finding 31-001 shows the same symptom for the keys ticket 29 added.
3. **Add `ContentDefaultsCache` (from 07dbca24, unchanged in shape).** This is a static, flattened `Map<String, String>?` of `assets/config/content_defaults.json` with an idempotent `preload()`. Add a `@visibleForTesting static void debugReset()` so tests can start cold. `initialize()` also calls `unawaited(ContentDefaultsCache.preload())`. Keep develop-next's `Report` calls in `_checkForUpdatesInBackground` and `refreshFromBackend` (`:45-67`, `:83-91`). origin/develop lacks them, so copy only the hunks above, not the whole file.
4. **Preload before the first frame.** On origin/develop, `main.dart`, `main_dev.dart` and `main_web.dart` each `await ContentDefaultsCache.preload()` before `runApp`. On develop-next those files are one-line delegates to `bootstrap(AppFlavor.…)`, and the single `runApp` is in `_runMealvanaApp` (`lib/shared/core/bootstrap/bootstrap.dart:191-252`, `runApp` at `:238`). Add `await ContentDefaultsCache.preload();` once, just before `runApp`. Every flavor and the Sentry-disabled path (`:86-93`) pass through it. The reason it is awaited: a widget that reads a key in its one synchronous build (tab strips, headers) never rebuilds by itself.
5. **D9: the preload's catch writes down what it did.** 07dbca24's `preload()` ends in `catch (_) {}`. On this branch it runs in the startup chain (item 4), so a missing or corrupt bundled asset would leave every key-only lookup showing its key, with no record anywhere. In the catch, write `LaunchTrail.add('content defaults not preloaded: <type>')` (`lib/shared/services/launch_trail.dart:120`) and `SentryReport.global.fault(e, stackTrace: st, area: 'content', message: 'Bundled content defaults failed to load')`. This is a build fault, not weather. Keep the catch-all: `rootBundle` throws a `FlutterError` (an Error, not an Exception), and the future is unawaited from `initialize()`.

**Findings:** 30-001, 31-001, 32-001.

**Decisions:**
- Lee, 2026-10-08: fix ticket 40, runs FIRST in wave 4.
- The fix is the restore, not a new design. origin/develop and mealplanning both carry it (`07dbca24`). The lead verified the provider line on both branches.
- release/1.29.0 lacks the same `unawaited(service.initialize())` line (lead checked). The 1.29.x line therefore owes the same fix as a backport or patch. That is not this ticket: it needs its own cut and `/release-cut`.
- Test doubles stay as they are. 22 of the 25 test files that read `contentServiceProvider` override it with `testContentService` (`test/helpers/test_content.dart:48-50`), so the new `initialize()` call never runs there. The other three are the two content tests below and `test/smoke_tests/auth_misc_smoke_test.dart`, which the agent runs.

**Touches:** lib/features/content/application/content_service.dart, lib/shared/core/bootstrap/bootstrap.dart, test/features/content/content_service_test.dart, test/features/content/content_defaults_resolve_without_caller_test.dart (new). 4 files. No generated files: `contentServiceProvider` is a plain `Provider`, not `@riverpod`.

**Overlaps:** none in wave 4. 35, 36, 37, 42, 45 and 46 edit `content_keys.dart` and `content_defaults.json`. This ticket changes neither file; it only reads the JSON at runtime. 34 touches `root_app_widget.dart`, not `bootstrap.dart`. 41 touches no content file.

**Worktree note (2026-10-08, drafter):** while this ticket was being drafted, the worktree already held uncommitted edits to `content_service.dart`, `bootstrap.dart` and `content_service_test.dart`, plus an untracked `content_defaults_resolve_without_caller_test.dart`, all citing "ticket 40". The agent starts from them, checks them against items 1-5, and adds item 5 if it is missing (the uncommitted `preload()` still ends in a bare `catch (_)`).

No edge-function or schema change. Nothing to deploy.

- [ ] Seam test (`content_defaults_resolve_without_caller_test.dart`). The producer is the real bundled `assets/config/content_defaults.json`, read through `rootBundle`. It is not a map the test builds. The repository is mocked to say no active content and an offline refresh (the device after `clear-app.sh`; Finding 32-001: dev `app_content` has no active row). After `ContentDefaultsCache.preload()` (what bootstrap does), `container.read(contentServiceProvider).getValue(ContentKeys.settingsDeleteConfirmTitle)` is "Delete account?", the JSON's value, with no caller initialising anything. A second case without the preload awaits the provider's own `initialize()` and asserts the same for `settingsSignOutConfirmTitle`. A third case is a stale cache: `getActiveContent` returns an `AppContent` without the key, and the key still resolves to the bundled default.
- [ ] Unit: `getValue('no.such.key')` returns `'no.such.key'` (the bug signal stays). `getValue('no.such.key', defaultValue: 'x')` returns `'x'`.
- [ ] `content_service_test.dart`: the setUp stubs both repository calls (the provider now calls them on first read), calls `ContentDefaultsCache.debugReset()`, and keeps the existing `RecordingReport` assertions (`'Manual content refresh failed'`).
- [ ] Unit: a `preload()` whose asset load throws leaves `values` null, writes the LaunchTrail line, and reports one fault with area `content` (item 5).
- [ ] `flutter analyze` clean on touched files; run `test/features/content/` and `test/smoke_tests/auth_misc_smoke_test.dart`.
- [ ] Retest on device: wave 5 retest ticket 48 (Verify your email, the Settings rows, the Delete and Sign Out dialogs, Log In's error lines) and wave 5 retest ticket 50 (Timeline reconnect notice, Learn's Notify Me, Connected Apps). Fresh install, so no content cache exists.

Next: /testing-wave develop-2026-10 (fix wave 4)
