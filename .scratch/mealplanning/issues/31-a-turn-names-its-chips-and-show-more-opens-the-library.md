# 31: A turn names its chips, and Show more opens the library

**Status:** in-progress (wave 6, 2026-09-16)
**Blocked by:** 15 (touches supabase/functions/_shared/vana/persona.ts), 26 (touches supabase/functions/_shared/vana/tools.ts), 27 (touches supabase/functions/_shared/vana/contracts.ts), 30 (touches supabase/functions/_shared/vana/tools.ts).
**Next:** `/implement-lee mealplanning`

**What to build:** When Vana's turn names the choices it expects next, those labels appear as the chips under the picker, drawn by the app; when it names none, the app's own set applies; tapping any chip sends its label. Show more under a picker raises a sheet with many more meals from the same search.

**Decisions:** mp-272, mp-230; approved as mp-309.

**Touches:** supabase/functions/_shared/vana/contracts.ts, supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/persona.ts, lib/features/meal_planning/presentation/widgets/picker_chips.dart, lib/features/meal_planning/presentation/widgets/meal_picker_carousel.dart, lib/features/meal_planning/presentation/widgets/vana_part_renderer.dart, lib/features/meal_planning/presentation/widgets/meal_catalog_browser.dart

- [ ] The picker part carries an optional chips list of two to four strings; more or fewer is clamped or dropped (contract test with the frozen fixtures).
- [ ] Named chips replace the app set; absent or empty falls back to it; a tap sends the label (widget test).
- [ ] Show more raises a sheet over the same search with many more meals; the tick adds, the tile opens detail.

Next: /implement-lee mealplanning
