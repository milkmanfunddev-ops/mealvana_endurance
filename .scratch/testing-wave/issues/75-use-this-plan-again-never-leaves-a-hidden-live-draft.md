# 75: Use this plan again never leaves a hidden live draft

**Status:** in-progress (wave 24, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** When Use this plan again makes this week's draft, it archives any earlier conversation-less draft for the same week first, so the week never holds a live draft the athlete cannot reach. Drafts that belong to a conversation are left alone (mp-241: every conversation builds its own Draft).

**Findings:** 73-001 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** mp-675 (Use this plan again), mp-241 (a conversation keeps its own Draft).

**Touches:** supabase/functions/_shared/vana/plan.ts

- [ ] A deno test: two Use this plan again in a row leave one live conversation-less draft; a conversation's draft is untouched.
- [ ] Deployed to dev.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
