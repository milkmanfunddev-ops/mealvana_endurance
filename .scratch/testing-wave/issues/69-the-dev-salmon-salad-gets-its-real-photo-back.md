# 69: The dev salmon salad gets its real photo back

**Status:** in-progress (wave 22, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** Dev data only. `meal_library` AD-001 still carries meal-imagery ticket 05's striped test photo, credited "Photo by Lee (ticket 05 live check)". Put back the photo it had before (from `meal_photo_history`), or clear it so the normal image pipeline applies. One idempotent SQL, dev only, read first.

**Findings:** 09-003 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; dev data.

**Touches:** dev database only (a committed SQL file under scripts/)

- [ ] AD-001's photo and credit on dev are the pre-test ones (SELECT before and after).
- [x] The SQL file is committed.

Next: /implement-lee testing-wave
