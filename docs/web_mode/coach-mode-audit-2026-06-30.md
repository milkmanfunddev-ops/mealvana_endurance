# Coach Mode (Flutter Web) — Live Audit & Bug Findings — 2026-06-30

Environment: `flutter run -d web-server --web-port 8080 -t lib/main_web.dart`
(dev defines from `.env.web.local`, Supabase dev project `vlmtsdzpnjnavdgytcmi`).
Logged in as `test@test.com` — an **approved coach** with 7 athletes.

## What works (verified live via browser MCP)
- App boots cleanly on web → `/welcome` → email login → `/main`. Supabase init OK.
- Coach tab appears (web-only) → `/coach-portal` renders.
- Athlete list: 7 athletes, all "Active". Selecting one loads detail.
- Athlete detail tabs ALL render correctly:
  - **Profile** — personal info + training preferences populated.
  - **Targets** — Nutrition Target Overrides form (pre/during run-bike-swim/post), all default fields.
  - **Events (N)** — lists athlete events.
  - **Carb Loading** — empty-state + add.
  - **Activities (N)** — week/month calendar, per-day list, add (+).
  - **Chat** — real message history + working composer (loads with a brief offset/transition frame).
- **Reports** — FULLY FUNCTIONAL (table: Completed / Fuel Logs / Adherence / Last Completed / Next Event; This Week/Last Week/Custom; row drill-down works). The `portal_reports_placeholder.dart` "Coming Soon" stub is DEAD CODE — real `portal_reports_panel.dart` is wired in.

## BUGS FOUND

### P0 — `calculate-daily-macros` edge call fails on web + infinite retry storm
Symptom: on `/main` (Today) load, console floods with
`Error calling calculate-daily-macros: ClientException: Failed to fetch` — 172 messages
in an 8s burst, ~every 0.5s. Today view shows a perpetual spinner (daily macros never load on web).

Root cause (two compounding bugs):
1. **Client infinite loop** — `lib/features/daily_macros/presentation/providers/daily_macros_controller.dart:139`
   unconditionally calls `ref.invalidateSelf()` after `calculateWeek`. On web the call
   persistently fails and `daily_macro_service.dart` (`calculateWeek` catch, ~313-318) returns
   stale cache WITHOUT writing cache → next `build()` still sees `hasUncached==true` → calls again → loops forever.
   On native it terminates (call succeeds → days cached → loop ends). No backoff/debounce/cap.
2. **Edge response can lack CORS on error** — `supabase/functions/_shared/sentry.ts:103-109`
   `withSentry` fallback returns 500 WITHOUT `corsHeaders`. A runtime exception escaping the
   handler's try/catch → non-CORS 500 → browser reports "Failed to fetch" (no status).
   Confirmed live: OPTIONS preflight → 200; the POST never completes.
   (COEP/CORP ruled out: REST works under same COEP, and neither REST nor fn sends CORP.)

Fix direction:
- Client: only `invalidateSelf()` on SUCCESS (newly-cached days); have `calculateWeek` signal
  failure instead of silently returning stale cache; add attempt cap/backoff as defense-in-depth.
- Edge: add `corsHeaders` to the `withSentry` 500 fallback; confirm deployed fn matches repo + why it 500s for this user.
- NOTE: affects the whole web app (Today/daily macros), not just coach mode.

### P2 — minor visual glitches in portal
- Carb Loading tab: stray `>` card top-left + teal sliver bottom-right (layout artifacts).
- Chat tab: brief offset/half-width frame during load transition before settling.

### P3 — static analysis (coach_mode), all non-blocking
- `coach_reports_controller.dart:247` — 2× `unnecessary_non_null_assertion` (real warning).
- `create_carb_loading_dialog.dart:4` — unused import.
- ~20 deprecated `withOpacity` → `.withValues()`; deprecated `value:`→`initialValue:` (form field).
- Dead code: `portal_reports_placeholder.dart` (not used); `/coach` & `/coach/athlete/:id` redirect-only routes; `athlete_detail_screen.dart:675` TODO nav.

## Tests
- Existing `test/smoke_tests/coach_formula_smoke_test.dart` = 11/11 GREEN (8 coach screens + 3 formula).
  Still UNTRACKED in git.
- No widget tests for portal controllers, no integration/e2e for coach web flows.
