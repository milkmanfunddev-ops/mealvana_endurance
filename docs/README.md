# Docs Index

Core, living documentation lives at this level. Historical feature build docs
live in `features/`. Superseded, one-off, or wrong material lives in
`_archived/` — nothing there should be trusted without re-verification.

Reorganized 2026-07-29; `CLAUDE.md` at the repo root is the routing guide.

## Core (living docs)

| Directory | What it is |
|---|---|
| `architecture/` | Architecture overview + point-in-time audits |
| `technical/` | Technical patterns and standards (FOA, sync, write consistency, content management, Sentry, Shorebird, responsiveness, Andrea init flow) |
| `business_logic/` | Nutrition systems and algorithm documentation |
| `database/` | Schema docs, Drift + Supabase migrations, load-bearing SQL (`apply_all.sql`, `meal_logging_jade_schema.sql`) |
| `test/` | Testing strategy + coverage status (`coverage-status-2026-07.md` = READ FIRST) |
| `deployment/` | Supabase + Vercel deploy hub (project refs, commands) |
| `ci-cd/` | Codemagic + GitHub Actions docs (`codemagic.yaml` points here) |
| `release/` | Release process, App Store screenshots, and **`prod-readiness-outstanding.md`** — the verified list of everything still blocking a production release |
| `integration/` | Training integrations: `api-exploration/` (Garmin/TP/FS/VDOT API reference), plus per-provider docs (`training_peaks/`, `final_surge/`, `tp_write/`, `vdot/`, `strava/` and Garmin brand assets) |
| `brick/` | Brick workouts (referenced from lib code) |
| `web_mode/` | Web platform specifics |
| `flavors/` | Build flavor / environment setup |
| `privacy/` | App Store privacy details + consent gate |
| `kyle/` | Design system of record (design tokens, standards) |
| `requirements/` | Product requirements (referenced from lib code) |
| `daily/` | Output of the `/daily` skill (daily work logs) |
| `dev_schema.txt` / `prod_schema.txt` | Live DB schema snapshots |
| `logs.txt` | Scratch sync-log dump location (see CLAUDE.md debugging tips) |

## `features/`

One directory per feature: the design briefs, specs, and build notes that got a
feature shipped. Useful history; not guaranteed current. Includes (among ~50):
`analytics/`, `formula-kit/`, `sodium_hydration/`, `new_macros/`,
`new_activity/` (fuel timeline spec — referenced from lib), `new_sync/`,
`food_templates/`, `revenue_cat/`, `public_events/`, `catalog/`, `coach_mode/`,
`onboarding-revamp/`, `app_startup_optimization/`.

## `_archived/`

Superseded or one-off material kept for history: old prototypes and design-brief
imports (`mealplanning_prototype/`, `carbshour/`, `recommended/`,
`nutrition_plan_zh/`, `uiux/`), shipped bug-fix writeups (`bugfixes/`, `fixes/`,
`bugs/`), the pre-2026-07 refactoring session logs (`refactoring/`), business
material (`business/` — pitch decks, grant applications), raw data dumps
(`data_dumps/`), loose screenshots, and retired configs (`coderabbit/`,
`ai_rules/`, `roadmap/`).
