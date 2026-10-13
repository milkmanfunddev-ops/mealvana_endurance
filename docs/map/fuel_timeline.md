# Fuel timeline

domain: 2 Your day · folder: `lib/features/fuel_timeline/` (13 files, one live)

The earlier version of the home feed, replaced by the Timeline (`macro_dashboard.md`). The only thing an athlete
still sees from here is the **brick row** on the Timeline: "BRICK · n legs · min", the legs in a bracket, "Pre ·
During · Recovery fuel", and the "⋯" menu with "Ungroup legs" / "Delete brick". Tapping the row or any leg opens the
combined brick's plan (the form if it has no plan yet); the outline turns solid once the brick is done.

Reuse: `presentation/widgets/timeline_brick_tile.dart`, `fuel_timeline_type.dart` (text styles). Everything else is
dead and not to revive: `day_timeline_assembler`, `day_energy_summary`, `timeline_node`, `fuel_timeline_filter`,
`fuel_timeline_controller`, `fuel_timeline_view_state`, `timeline_node_tile`, `energy_dashboard_card`,
`energy_breakdown_sheet`, `weekly_fuel_chart`, `fuel_filter_row`. Stale: `timeline_brick_tile.dart:32-33,51` ("tap
one leg for its fuel detail"; every tap opens the combined brick). qa: `spec/domain/brick.md`. ops: bugs
`brick-during-pins-invisible-and-tri-scope-unreachable`, `brick-swim-pace-baked-against-unseen-distance`.
