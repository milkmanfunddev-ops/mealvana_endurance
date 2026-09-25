# 39: A code redemption outlives the account that made it

**Status:** in-progress (wave 19, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** mp-535: a giveaway works once in total unless its row allows more. Deleting an account keeps its `code_redemptions` rows (the user reference is nulled, or the rows are otherwise kept), so per-code counts do not fall back and a spent giveaway stays spent.

**Findings:** 11-012 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** mp-535

**Touches:** supabase/migrations/, supabase/functions/redeem-code/handler.ts

- [ ] A new idempotent migration; after deleting a user, its redemptions still count toward the code's total (SQL check on dev).
- [ ] deno test: a giveaway at its limit refuses a new account even after the redeeming account was deleted.
- [ ] Applied to dev only; prod waits for the playbook.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
