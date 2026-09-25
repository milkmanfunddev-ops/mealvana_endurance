# 35: The Shopping tab opens the confirmed plan's list

**Status:** done (wave 20, 2026-09-25)
**Blocked by:** 34 (touches supabase/functions/_shared/vana/actions.ts).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The list the Shopping tab opens by default is the list of the plan the Plan tab shows (the week's confirmed plan). A Draft's list (built by Browse or chat edits, which mp-244 allows) and an archived Draft's list never take its place, and a new hand-made list does not replace it as the default. With no confirmed plan, the tab shows its empty state or the athlete's most recent hand-made list.

**Findings:** 19-001, 18-002, 19-006 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** mp-244

**Touches:** supabase/functions/_shared/vana/shopping.ts, supabase/functions/_shared/vana/actions.ts

- [x] `getList` with no id returns the confirmed plan's list over newer draft, archived and hand-made lists (deno test).
- [x] Deleting the confirmed plan's list does not bring an archived Draft's list back as current.
- [x] Deployed to dev.
- [x] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
