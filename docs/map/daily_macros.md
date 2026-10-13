# Daily macros (engine client)

domain: 2 Your day · folder: `lib/features/daily_macros/` (18 files, no screens)

Works out each day's calorie, carb, protein and fat targets by calling the server engine
`calculate-daily-macros-v6` (Engine B in QA) with the profile and the week's sessions, and caches the result on the
phone so the Timeline's energy card can show targets at once. What the athlete sees is on the Timeline page
(`macro_dashboard.md`, "Read the day's energy" and "What the data means"), including the ambient rule: a target row
exists because the Timeline was opened, not because the athlete did something.

Reuse: `application/daily_macro_service.dart` (engine client; one week call per missing day set, collapsed by
`RevisionedSingleFlight`), `data/daily_macro_targets_repository.dart` (local cache keyed by local midnight; Supabase
upsert is write-only), `presentation/providers/daily_macros_controller.dart`, `domain/daily_macro_targets.dart`,
`domain/intraday_display.dart` (burned-so-far and net-balance maths; the band words), `application/macro_cache_invalidation.dart`,
`domain/enums.dart` (TrainingPhase, Lifestyle, EaStatus), `macro_palette.dart` (macro colours, shared with meal logging
and plans). Dead: every widget under `presentation/widgets/` (`today_hero_card`, `daily_summary_card`, `macro_summary_strip`,
`weekly_overview_chart`, `periodization_bottom_sheet`, `energy_source_breakdown`, `ea_warning_banner`, `macro_breakdown_row`,
`date_navigation_header`), `periodization_analysis_service`, `DailyMacroService.calculateForDate`,
`DailyMacroTargetsRepository.getWeekRange`, `DailyMacrosController.refresh`.

Gap for the gardening pass: `macro_cache_invalidation.dart` compares `scheduledDateTime` only, while the engine
places a workout by actual ?? planned ?? scheduled, so a change to `actual_time` or `planned_time` alone does not
invalidate the week. qa: `spec/daily-macros/*`. ops: bugs `dashboard-prices-distance-sessions-at-flat-60min`,
`archived-brick-legs-double-feed-daily-macros`, `brick-priced-as-one-conservative-session`,
`daily-macros-v6-accepts-unknown-sport`, `macros-v6-validator-rejects-f4a-sports`, `profile-save-macro-cache-stale`,
`daily-macro-targets-tojson-drops-calculation-input`, `loading-day-daily-macros-split-parked-bundle-now-due`.
