# 02: Fix the red guardrails test (pantry photo budget refund)

**What to build:** The deterministic Vana guardrail suite is red at HEAD: one test fails
because the budget hold taken for a pantry photo is never released when the turn is refused by
the rate limiter — the settle call never happens, so the hold leaks. Make the refusal path
settle the hold (refund), so the test passes and the suite is green again. This is a plain
server-code fix at the existing deno test seam; nothing about the judging system depends on
the fix, but the suite being green is the regression net for ticket 06's deletion.

**Blocked by:** None (can start immediately).

**Status:** in-progress (wave 1, 2026-09-26)

- [ ] The failing guardrails test (pantry photo through the shared module) passes
- [ ] The full Vana deno test suite is green
- [ ] The fix is its own commit, separate from any judging-system work
