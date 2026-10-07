# Archived edge functions

Source kept for a later restore. The underscore prefix keeps this folder out of
`supabase functions deploy` and out of `_shared/sentry_coverage.test.ts`.

- `jade-chat/` and `_shared/ai_coach/` (archived 2026-10-07, round develop-2026-10,
  ticket 27). The app no longer calls jade-chat: its client (`/jade`,
  `lib/features/_archived/ai_coach/`) was archived the same day. The function stays
  deployed on dev as of 2026-10-07, with no caller. Imports were repointed so the
  files still type-check from here; to restore, move both folders back and change
  `../../_shared/` to `../_shared/` (and `../../../_shared/` to `../`).
  `_shared/ai/credits.ts` still prices `'jade-chat'`.
