# Mealvana Endurance — Comprehensive Testing Strategy (2026-06-23)

The authoritative strategy. Synthesizes recent (2025-2026) best practices with this
repo's actual state. Companion docs: `testing-build-plan-2026.md` (the sequenced
checklist) and `testing-roadmap-2026.md` (the Patrol/edge-fn coverage map).

---

## 0. The core problem, stated plainly

We've been building **top-down** (Patrol E2E first) and we have **no CI gating**.
The current shape is an *inverted pyramid* — heavy, slow, device-bound tests; a thin
fast base. Industry consensus (2025-2026) is the opposite, and the guiding rule is
**"push tests downward, always."** Most of what you want verified (macro values across
activity types, distances, intensities, diets; hydration; sodium) belongs in **fast,
deterministic unit/property/contract tests**, not in 10-minute device runs.

Patrol is necessary (proves a user *can do* the flow across native boundaries) but it
is the *tip*, not the base. One representative Patrol case per flow + a parity check;
the exhaustive matrix lives below.

---

## 1. Target test pyramid

| Layer | Target share | Speed budget | CI gate | Tooling |
|---|---|---|---|---|
| Unit (logic, formulas, mappers) | 60-70% | < 30s total | every PR | `flutter test` |
| Widget | 20-25% | < 2 min | every PR | `flutter test` |
| Golden / visual | 5-10% | < 1 min | every PR (Linux/Ahem) | **alchemist** |
| Integration / Patrol | ~5% | nightly | nightly + staging | Patrol |
| E2E smoke | 1-3% (≤10 tests) | < 10 min | post-deploy | Patrol on Test Lab |

`golden_toolkit` is **dead** — use **alchemist** (Betterment). `flutter_driver` is
removed — integration = `integration_test` + Patrol.

---

## 2. Test types — what we have, what to add

### Have
- Unit (nutrition_plan domain/data, hydration parity ±5%, pin decisions).
- Some widget tests.
- Patrol flows: smoke, onboarding, auth, integrations launch-boundary, **events CRUD ✅**, **activities CRUD ✅** (this session).
- Direct edge-fn HTTP tests (Python 20-scenario range checks; Deno 6600-LOC ±5%; dart e2e behind `@Tags(['e2e'])`).

### Add — ranked by ROI for this app
1. **Property-based tests (`glados`)** for the deterministic macro formulas. Assert
   *invariants* across the whole input range: carbs ≤ sport ceiling (run 70 / bike 120 / swim 0 g/hr), fluids > 0, output scales monotonically with duration. This is the single best fit — formulas are pure math, and one property replaces dozens of example tests. **This is where the "verify the numbers" ocean should mostly live.**
2. **Contract / repository tests (`mock_supabase_http_client` + `mocktail`)** for
   `activities_repository`, `personal_formulas`, sync code — no live Supabase, runs in
   the unit gate. Keep the *live* edge-fn HTTP tests for nightly.
3. **Golden tests (`alchemist`, CI/Ahem mode, Linux only)** for design-critical
   surfaces: Planned/Eaten/Left macro table, macro_palette, nutrition cards, formula editor.
4. **Accessibility assertions** — zero new deps, built into `flutter_test`:
   `meetsGuideline(textContrastGuideline / androidTapTargetGuideline / labeledTapTargetGuideline)`
   on nutrition inputs, macro cards, Jade chat.
5. **Performance/jank timeline tests** — `binding.traceAction` + `missed_frame_build_budget_count`
   on the Daily Macros scroll, formula editor, activities list. No new deps. (Not on web.)
6. **Mutation testing (`dart_mutant`)** — quarterly, on the formula logic only, to find
   assertion gaps. Too slow for per-PR.
- **Skip fuzz testing** — `glados` covers the same ground for numeric code; Dart has no real app-level fuzzer.

---

## 3. Flutter Web testing (faster/cheaper for a big slice)

The win is **structural cost**, not raw speed: web runs on **`ubuntu-latest` (≈10× cheaper than the macOS runners iOS needs)** and needs no device farm. (Plain unit tests on Chrome are ~3.6× *slower* than the Dart VM — don't route unit tests through Chrome.)

- **Patrol 4.0 (Dec 2025) added web support** (Playwright/Chromium). Our pinned
  `patrol 4.6.1` already has it — `patrol test -d chrome --web-headless true`. Node.js
  is a CI prerequisite. New `$.platform.web` API. Chromium only.
- **Do NOT gate on `flutter drive` for web** — bug #129041 prints "All tests passed"
  and exits 0 even on failure. Use **`flutter test -d chrome`** (propagates exit codes).
  Linux runners only (macOS web runs hit a 20-min hang, #155019).
- **Stays on device:** biometrics (`local_auth`), IAP, platform channels, OAuth
  (`ASWebAuthenticationSession` + web redirect teardown). Use session-token injection
  for auth in web suites. Note `kIsWeb` is `false` under `flutter test` (#139009) — abstract it.
- **Browser automation (Playwright) only for browser-level smoke** (URL reachable, no
  JS console errors, 200s). Flutter paints to `<canvas>` — no DOM, so widget-level
  Playwright/Cypress selectors don't work on CanvasKit/Skwasm builds.
- **Web goldens are separate** from mobile (CanvasKit ≠ mobile Skia). `goldens/web/`, generated on Linux-x64.

**Use web for:** fast pure-Dart UI/navigation/form regression + browser smoke, per-PR on Linux.
**Use device (Test Lab) for:** native-plugin flows, OAuth, the release smoke suite.

---

## 4. Firebase Test Lab + CI (the leverage multiplier — nothing is gated today)

Patrol officially supports Test Lab. **Build on Codemagic, *execute* on Test Lab / emulator.wtf** (Codemagic's own docs advise against running Patrol on its machines).

- Android: `patrol build android` → `gcloud firebase test android run --type instrumentation --use-orchestrator`. iOS: `patrol build ios` → zip → `gcloud firebase test ios run`.
- **Robo crawler does NOT work with Flutter** (can't see the widget tree) — instrumentation/XCTest only.
- **Sharding `--num-uniform-shards` is broken for Flutter** (#101296) — use `gcloud beta`, **Flank**, or **emulator.wtf**.
- Pricing: Spark free (10 virtual/5 physical runs/day); Blaze 60 min/day virtual free then $1/hr virtual, $5/hr physical. Use **virtual for nightly**, physical only for pre-release smoke.
- Gotchas: enable Cloud Tool Results API; service account needs Editor; iOS 18+ has no video; xctestrun iOS version must match the device flag.

### Three-gate CI model
- **Per-PR (< 5 min):** `dart analyze --fatal-infos`, `dart format --set-exit-if-changed`,
  `flutter test --coverage` (unit+widget), golden (Linux/Ahem), coverage floor 70%→80%.
  Optional fast Patrol-web smoke on Linux. Cache Flutter SDK + pub-cache; `cancel-in-progress`.
- **Nightly:** full Patrol suite on Test Lab/emulator.wtf (flagship + mid-range) + the
  live direct edge-fn matrix + un-gated `dev_cloud_e2e` (`--tags e2e`). Slack on failure.
- **Post-deploy smoke (≤10 tests, < 10 min):** login, create plan, log activity — on real
  devices, blocks promotion to prod.
- **Flake policy:** weekly review of top-5 flakiest; fix/delete within a week; no
  `skip:'flaky'` without a ticket; `--num-flaky-test-attempts 1` only for infra flakiness.

---

## 5. AI-assisted testing (the skills/workflows/routines you asked about)

Calibration first: LLMs reliably produce **compilable** tests ~70-90% of the time, but
**mutation scores hover ~40%** — generated assertions catch fewer real bugs than they
appear to. **AI scaffolds; humans verify assertions.** Treat vendor "% faster" claims as
unverified.

### Adopt (highest leverage for *our* Claude Code setup)
1. **Patrol MCP** (LeanCode, Mar 2026) — purpose-built so Claude can write/run/debug
   Patrol tests *interactively* with a live native tree + screenshots. Supports Claude
   Code natively. This replaces the manual mobile-mcp "walk → codify" loop I did by hand
   for events/activities. **Wire this up next.**
2. **`anthropics/claude-code-action`** — PR-triggered test generation/review for changed
   files (path-filter out test files to avoid regen loops; guard `actor != 'claude[bot]'`).
3. **Claude Code hooks** — `PostToolUse(Edit|Write)` runs `flutter test` after edits;
   `Stop` hook blocks finishing while tests are red. Local guardrail.
4. **Codecov** — LCOV coverage-gap visibility in PRs (Dart-validated).

### Our own skills/routines to build (this repo)
- **`/test-walk` skill** — drive a screen (Patrol MCP), capture keys, emit a Patrol test.
- **Nightly `/schedule` routine** — run suites on Test Lab, AI-triage failures (regression
  vs flaky vs selector drift), open a summary PR.
- **Self-healing pass** — on a missing/changed key, re-walk the screen and patch the finder.
- **Coverage-gap workflow** — fan agents across `lib/features/*`, report untested screens
  into the build-plan TODO.
- **Instrumentation agent** — add missing `ValueKey`s (precondition for Patrol coverage).

### CLAUDE.md additions (empirically necessary)
Add a testing section so AI-generated tests fit this codebase:
- **Mocktail, NOT Mockito.** Don't over-mock (agents mock ~95% of the time; be explicit
  about using real collaborators where cheap).
- **Riverpod patterns:** use `ProviderContainer` + `addTearDown`, not direct Notifier
  instantiation (`LateInitializationError`); `isA<AsyncLoading>()` not `AsyncLoading<void>()`;
  `AsyncData<void>(null)`; Riverpod's retry can time out error-state tests.
- Macro/value assertions go in property/unit tests; Patrol asserts flow + rendering.

---

## 6. CodeRabbit — fix (broken today)

**Root cause:** a stray `.github/workflows/coderabbit.yml` uses the **deprecated
`coderabbitai/ai-pr-reviewer@latest`** action, missing its required `OPENAI_API_KEY` →
red ❌ on every PR. The modern CodeRabbit is a **GitHub App** that reads the (already-good)
`.coderabbit.yaml` server-side and needs **no workflow**.

**Fix:** delete `.github/workflows/coderabbit.yml`; verify the GitHub App is installed
on the repo. Optionally add `path_filters` to `.coderabbit.yaml` to skip `**/*.g.dart`,
`**/*.freezed.dart`; remove the workflow snippet from `docs/technical/coderabbit.md`
(lines ~721-739) so it isn't re-introduced.

---

## 7. Sentry — accurate bug reporting (better than feared; real gaps remain)

The feared gap (guarded errors never reaching Sentry) is **already solved**:
`lib/shared/services/sentry/sentry_provider_observer.dart` bridges `providerDidFail →
Sentry.captureException`, wired into every `ProviderScope`. Nav breadcrumbs, user
context, `SentryHttpClient`, replay-on-error, tracing all present. Prioritized gaps:

- **P0 — Unsymbolicated release crashes.** `SENTRY_AUTH_TOKEN` is never set, so
  `sentry_dart_plugin` **never uploads debug symbols / source maps**. Release crashes
  arrive unreadable. *Fix:* add `SENTRY_AUTH_TOKEN` to Codemagic + run the plugin post-build.
- **P0 — ~32 of 35 edge functions are dark.** Only `generate-macros-v4`,
  `generate-nutrition-plan-v3`, `garmin-push` wrap `withSentry`. *Fix:* wrap the rest;
  confirm `SENTRY_DSN`/`SENTRY_ENVIRONMENT` Supabase secrets are set (helper no-ops without DSN).
- **P0 — Explicit uncaught handlers.** Set `FlutterError.onError` and
  `PlatformDispatcher.instance.onError` in each `main_*.dart` (belt-and-suspenders over SDK defaults; gives `fatal` leveling).
- **P1 — Stale release tag.** No `options.release`/`dist`; `app_startup_service.dart:321`
  hardcodes `appVersion '1.1.0+8'` while pubspec is `1.20.0+1` — every event is mis-tagged,
  breaking grouping/symbolication. *Fix:* set release/dist from `PackageInfo`; remove the hardcode.
- **P2 — `beforeSend` blanket-drops `TimeoutException`** (hides real outages); regular-session
  replay rate 0 (cost choice); verify `sentry_drift` executor is actually wrapped.

---

## 8. Adoption sequence (folds into `testing-build-plan-2026.md`)

- **Quick wins (hours):** delete CodeRabbit workflow; add Sentry `SENTRY_AUTH_TOKEN` +
  release/dist + uncaught handlers + fix stale version; add CLAUDE.md testing section.
- **P0 (foundations):** shared Patrol helpers; Android picker fix; event-delete fix; wire
  the three-gate CI (per-PR unit/widget/golden first).
- **P1:** property tests for formulas (`glados`); repository contract tests
  (`mock_supabase_http_client`); golden tests (`alchemist`); activity-type Patrol breadth.
- **P2:** Patrol MCP + `claude-code-action` + hooks; Test Lab nightly via Codemagic;
  wrap remaining edge functions in Sentry; Patrol-web smoke on Linux.
- **P3:** direct edge-fn matrix (the big numeric coverage); accessibility + perf tests.
- **P4:** Patrol↔edge parity; full nightly matrix (iOS+Android Test Lab); mutation testing quarterly; Codecov gating.

---

## Key sources
Patrol 4.0 web (leancode.co/blog/patrol-web-support), Patrol MCP (leancode.co/blog/patrol-mcp-release),
Firebase Test Lab Flutter (firebase.google.com/docs/test-lab/flutter), alchemist (github.com/Betterment/alchemist),
glados (pub.dev/packages/glados), mock_supabase_http_client (supabase-community), claude-code-action (github.com/anthropics/claude-code-action),
Claude Code hooks (code.claude.com/docs/en/hooks). Full citation lists in the three research agent transcripts (this session).
Empirical: ULT benchmark arXiv 2508.00408 (LLM test accuracy 41.3%), over-mocking arXiv 2602.00409.
