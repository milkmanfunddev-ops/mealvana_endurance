# 06: The grace month, granted on flip day

**Status:** in-progress (wave 2, 2026-09-22)
**Blocked by:** 01.
**Next:** `/implement-lee paywall`
**Model:** opus

**What to build:** Lee runs one script on flip day. Its dry run prints every registered account created before the flip and the count; with the write flag it grants each 30 days of `pro` and sets `founding_member`, skipping anyone already granted. Run on dev first.

**Decisions:** mp-455, mp-429; approved as mp-485.

**Touches:** scripts/grace-grant.mjs, supabase/functions/_shared/grace

- [x] The dry run lists accounts and a count and writes nothing.
- [x] The write run grants 30 days and sets `founding_member`; a second run grants nobody (selection tested with a fake database).
- [ ] Run on dev; a granted dev account opens the app and its row is active.

Next: /implement-lee paywall
