# design-sync notes — Mealvana Endurance

Repo-specific facts a future sync needs. Governance: `docs/ssot/spec/design/source-authority.md`
(the Claude Design project is a **sink**; this repo's `design/ds/` is the React twin that feeds it;
`docs/ssot/spec/design/` + `renderings/` are the ratified truth the twin is checked against).

## Why a React package lives in a Flutter repo
- The converter bundles a JS component library; the app is Dart. `design/ds/` is a hand-maintained
  React twin of `lib/shared/widgets/kyle_design/`, seeded 2026-08-25 from the remote project's
  `ui_kits/mobile_app/components.jsx` (9 components) plus 9 ported from the Dart widgets.
- **Drift rule:** a Dart widget change under `kyle_design/` must be mirrored into `design/ds/src/`
  in the same PR, then `/design-sync` (CLAUDE.md rule). The twin has no generator.

## Build
- `cd design/ds && npm ci && npm run build` → `dist/index.es.js` + `dist/index.d.ts` + `dist/styles.css`.
  esbuild for JS (react external), `tsc --emitDeclarationOnly` for types.
- Converter deps live in `.ds-sync/` (gitignored); Playwright + Chromium installed into
  `~/.cache/ms-playwright` on 2026-08-25.

## Fonts
- Shipped from `assets/fonts/`: Apercu (`Apercu-*.otf`), Apercu Mono, Sansita Bold/BoldItalic.
- **Compadre ships as `Compadre-Demo-*.otf`** — demo/trial builds; licence unconfirmed (brand audit
  2026-08-25). The remote project holds non-demo `Compadre-*.otf`; swap when the licence is settled.
- The `Apercu Pro *.otf` duplicates in `assets/fonts/Apercu` are not used by the twin.

## Tokens
- `design/ds/src/styles.css` is derived from the remote kit's `colors_and_type.css` with corrections
  from the ratified `docs/ssot/spec/design/tokens.md`: `--me-yolk` added (RESERVED, Q-SA2); the
  web-app `oklch` macro colors (`--me-carbs/protein/fats`) dropped — not on Kyle's sheet and macro
  encoding is DEFERRED (Q-SA3). Card radius 15 px (Q-SA4).
- Icons: Font Awesome 7 Sharp is canonical; no licence on file. The twin uses inline SVG paths
  (no CDN — the artifact/design runtime may block remote fetches).

## Fidelity findings (2026-08-25, first sync)
- First preview pass was graded without a reference and missed the mark (light ground, generic
  SVG icons, wrong type scale). **Always measure against the ratified rendering first:**
  `docs/ssot/spec/design/renderings/macro-dashboard@v1.html` — screenshot it in the same Chromium
  and read computed fonts/colours. The app is **dark-first** (`ThemeMode.dark` default).
- Measured from the rendering: card fill `rgba(248,246,235,0.06)` + hairline `rgba(…,0.14)`;
  56 px filled icon chips (orange = food, electrolyte = activity); Apercu 11–13 px data,
  Sansita 19 section / 27 hero number; `BY WEEK` tabs in Compadre Wide caps; segmented filter =
  hairline pill track with a cream selected pill; "+ Add Food/Activity" = dashed outline pills.
- Compadre renders titles in caps in the rendering too — that is the face, not a demo-font bug.
- Icons: the app uses `font_awesome_flutter`; the twin ships `Icon` built from Font Awesome Free
  solid paths (`.ds-sync/node_modules/@fortawesome/fontawesome-free`, regenerate with the script
  in this repo's history if names are added). FA 7 Sharp Pro remains canonical when licensed.
- The rendering's data colours (carbs electrolyte, protein rgb(167,139,250), fat rgb(236,84,153))
  disagree with `tokens.md`'s `electrolyte` contract ("never intake"). Exposed as `--me-data-*`
  and labelled surface-level; not resolved here — belongs on the ruling desk with Q-SA3.

## Twin → Dart trace (screenshot-derived twin, 2026-08-25)
The twin was built from release screenshots IMG_8808–8815 **and** these Dart files, which are
feature-local today. The CLAUDE.md principle says each belongs in `lib/shared/widgets/kyle_design/`
under the twin's name; when promoted, re-sync recalibrates the twin from the library.

| Twin component | Dart source today |
|---|---|
| `ViewTabs` | `lib/features/calendar/presentation/widgets/calendar_view_toggle.dart + lib/features/fuel_timeline/presentation/widgets/fuel_timeline_day_header.dart` |
| `WeekStrip` | `lib/features/fuel_timeline/presentation/widgets/fuel_timeline_day_header.dart` |
| `NetBalanceCard` | `lib/features/macro_dashboard/presentation/widgets/energy_summary_card.dart` |
| `WorkoutCard` | `lib/features/macro_dashboard/presentation/widgets/workout_card.dart (spec: components/workout-card.md v3)` |
| `StatusPill` | `lib/features/macro_dashboard/presentation/widgets/workout_card.dart (status chip)` |
| `Timeline` | `lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart (rail + entries)` |
| `FoodRow` | `lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart (meal card) + lib/features/nutrition_plan/presentation/widgets/fuel_log/fuel_log_food_row.dart` |
| `TabBar` | `lib/shared/widgets/kyle_design/navigation/floating_action_buttons_bar.dart (already in library — verify)` |
| `SegmentedControl` | `lib/shared/widgets/kyle_design/buttons/segmented_control.dart (library) — the filter/Daily-Weekly/Planned-Actual variants are feature-local in macro_dashboard + daily_macros` |
| `SheetHeader` | `lib/features/macro_dashboard/presentation/widgets/breakdown_pager.dart` |
| `EquationCard` | `lib/features/macro_dashboard/presentation/widgets/breakdown_pager.dart + energy_summary_card.dart (spec: components/energy-card.md v1)` |
| `BreakdownTable` | `lib/features/macro_dashboard/presentation/widgets/breakdown_pager.dart` |
| `SourceDot` | `lib/features/macro_dashboard/presentation/widgets/breakdown_pager.dart (provenance glyphs; spec: platform-resolution.md chips)` |
| `SourceLegend` | `lib/features/macro_dashboard/presentation/widgets/breakdown_pager.dart` |
| `HeroNumber` | `lib/features/macro_dashboard/presentation/widgets/breakdown_pager.dart (Active Energy page)` |
| `StackedBar` | `lib/features/macro_dashboard/presentation/widgets/breakdown_pager.dart` |
| `EnergyRow` | `lib/features/macro_dashboard/presentation/widgets/breakdown_pager.dart` |
| `MacroDonut` | `lib/features/daily_macros/presentation/widgets/today_hero_card.dart + macro_summary_strip.dart` |
| `PagerDots` | `lib/features/macro_dashboard/presentation/widgets/breakdown_pager.dart` |
| `InfoIcon` | `lib/features/macro_dashboard/presentation/widgets/breakdown_pager.dart` |
| `DetailHeader` | `lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart` |
| `HeroImageCard` | `lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart (hero) — cf. kyle_design/cards/activity_hero_card.dart` |
| `ScheduleBlock` | `lib/features/nutrition_plan/presentation/widgets/activity_detail/activity_schedule_info.dart` |
| `Banner` | `lib/features/formula_kit/presentation/widgets/pin_status_banner.dart` |
| `PhaseCard` | `lib/features/nutrition_plan/presentation/widgets/fuel_log/fuel_log_section_widget.dart` |
| `MacroStat` | `lib/features/nutrition_plan/presentation/widgets/fuel_log/fuel_log_section_widget.dart (targets + range rail)` |
| `FuelStep` | `lib/features/nutrition_plan/presentation/widgets/fuel_log/fuel_log_section_widget.dart + domain/pre_workout_feeding_labels.dart` |
| `FuelItem` | `lib/features/nutrition_plan/presentation/widgets/fuel_log/fuel_log_food_row.dart` |

## Calibration (2026-08-25, second pass)
- Twin values were taken from the Dart, not the pixels, wherever the Dart existed:
  `workout_card.dart` → radius 14, 40 px chip, title 17 / detail 11 / fuel 10.5, status chip 9.5
  with `MeTokens.*Alpha` fills; `energy_summary_card.dart` → radius 18, 27 / 11; phase cards and
  fuel rows → radius 14; day header selected square → radius 15. Screenshots settled the rest.
- Composed screen previews (`Timeline.FuelTimelineScreen`, `SheetHeader.*Screen`,
  `PhaseCard.ActivityDetailsScreen`) are the fixtures used to compare against IMG_8808–8815; they
  are NOT what Claude Design builds with — the components are.
- Card harness width is ~380 px; screens are authored at `width: 100%; max-width: 428px`.

## Known render warns
- `[GRID_OVERFLOW]` on every component → all are `cardMode: column` (previews are 343 px phone
  columns by design). Expected on every re-sync; not new.

## Re-sync risks
- The twin is hand-maintained: any `kyle_design/` change not mirrored here ships stale to Claude Design.
- Compadre demo fonts may be replaced; re-check `extraFonts` paths after.
- `docs/ssot/spec/design/renderings/` is the pixel reference for the macro-dashboard surface only;
  components without a ratified rendering are graded on the absolute rubric, not against a reference.
