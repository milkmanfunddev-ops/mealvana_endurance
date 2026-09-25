# 101: FinalSurge completions stay done, and a draft's list goes with its draft

**Status:** in-progress (wave 26, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Lee's rulings after wave 25 (2026-09-25, in the terminal):
1. A workout FinalSurge reports completed (`completion_type = 'provider'`) cannot be undone by the athlete: its card offers no Undo / mark-undone, the same as a Garmin-verified card. Today Undo flips it to planned and the next sync completes it again. Also stop the upload from turning `'provider'` back into `'manual'`: `completion_type ?? 'manual'` in `activity_mapper.dart` (two places) and `activity_sync_handler.dart` can overwrite a server `'provider'` from a device whose local row is still null after the v23 migration. Never send `'manual'` over a server `'provider'` (for example, send the local value only when it is set, and check how the bulk upsert fills a missing key before choosing).
2. When a draft plan is archived or replaced, its shopping list is deleted with it. Only confirmed plans' lists and hand-made lists stay in Previous lists. Existing lists of archived drafts are cleaned up by an idempotent migration (`20260925170100_drop_archived_draft_lists.sql`) that deletes only lists whose plan is archived AND was never confirmed. Write the SELECT that counts them on dev into the report. The lead reviews the migration before applying it; it never runs on prod in this wave.
3. Update `docs/ssot/spec/integrations/final-surge-completion.PROPOSED.md` (app-authored, awaiting Xuan) with rule 1: a provider completion is final for the athlete.

Kept as built (Lee, same day): conversation titles "No plan yet" and "Archived" (ticket 97), and the Previous plans sheet closing itself when this week's plan changes underneath it.

**Findings:** 29-002 (follow-on to ticket 99), 19-002 (follow-on to ticket 96). Retest ticket 100 covers them.

**Decisions:** mp-244 (the server builds and rebuilds the plan's list), mp-241 (confirm archives the week's other plans). No page writes.

**Touches:** lib/features/macro_dashboard/ (the workout card's Undo), lib/features/activities/ (mark-undone guard), lib/features/activities/data/activity_mapper.dart, lib/shared/services/sync/entity_sync/activity_sync_handler.dart, supabase/functions/_shared/vana/ (archive/replace paths in plan.ts, shopping.ts), supabase/migrations/20260925170100_drop_archived_draft_lists.sql, docs/ssot/spec/integrations/final-surge-completion.PROPOSED.md

- [x] Widget test: a provider-completed card shows no Undo; a mark-done card still does.
- [x] Controller/repository test: mark-undone on a provider-completed activity is refused.
- [x] Mapper/sync test: an upload of a row with null `completion_type` never sends `'manual'` over `'provider'`.
- [x] Deno test: archiving or replacing a draft deletes its list; confirming a plan keeps its list; a hand-made list is untouched.
- [x] `flutter analyze` clean on touched files, deno tests for touched functions. SQL and deploy: wave lead.

Next: /implement-lee testing-wave

**Build notes (wave 26 agent):** a deleted draft (`delete_plan`, which has Undo) keeps its list; the ruling covers archive and replace only. Dev count of archived never-confirmed plans' lists before the migration: 6.
