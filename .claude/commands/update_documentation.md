# Documentation Update Command

Bring `/docs` and CLAUDE.md back in sync with the codebase. Accuracy against the
actual implementation beats preserving existing prose — verify before you write.

## 1. Establish what changed

- `git log --oneline --since="1 month ago"` (or since the last docs update) — note
  new features, removed features, schema changes, new integrations.
- List `lib/features/` and compare against what the docs claim exists.
- Check `schemaVersion` in `lib/shared/database/app_database.dart` and recent
  entries in `database_schemas/` for DB drift.
- Useful search tools: Serena (`mcp__serena__get_symbols_overview`,
  `mcp__serena__find_symbol`, `mcp__serena__find_referencing_symbols`) for code
  structure; Grep/Glob for patterns like `@riverpod` and `@DriftDatabase`.
- For external-library claims (Flutter, Riverpod, Drift, Supabase), verify with
  context7: `mcp__context7__resolve-library-id` → `mcp__context7__query-docs`.

## 2. Update each affected area

Work only the areas the changes touched — don't rewrite healthy docs:

| Area | What to check |
|---|---|
| `/docs/architecture/` | feature list vs `lib/features/`, FOA examples still match real code |
| `/docs/business_logic/` | algorithm docs vs actual calculation code |
| `/docs/database/` | schema version, new tables/migrations, relationships |
| `/docs/technical/` | integrations, config/env vars, deployment changes |
| `/docs/test/` | test status, new frameworks/procedures |

Keep formatting consistent with the surrounding docs. Never delete a doc outright
without flagging it — mark obsolete files "superseded by X" and list them for Lee.

## 3. Sync CLAUDE.md

- Docs Map links all resolve to real files.
- Non-Negotiable Rules still true (no stale bans or stale patterns).
- Project snapshot/stack reflects reality.
- CLAUDE.md stays a **concise routing guide** — detail belongs in `/docs`, and
  volatile facts (schema versions, counts) belong in code/docs, not CLAUDE.md.

## 4. Verify and report

- [ ] Every claim written was checked against current code
- [ ] All links resolve
- [ ] New features documented; removed features gone
- [ ] CLAUDE.md Docs Map current

Report: files changed and why, discrepancies found between docs and code, and
recommended deletions awaiting Lee's call.
