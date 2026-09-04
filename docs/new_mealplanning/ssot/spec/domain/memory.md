# SSOT — Memory (what Vana knows, and settings as memories)

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.**
**Owners in code:** `user_memories` (`20260827090000`; partial unique `user_memories_setting_key`), RPC
`recall_memories`; prototype `server/vana/memory.ts`, edge `_shared/vana/memory.ts` (ahead: `SETTING_DEFAULTS`,
`coverage_scope`, `weekly_budget_usd`, `pantry_items`, `source` — D-12); Dart `user_memory_repository.dart`.

## Definitions

- **Memory** — `{id, kind, key, fact, value, confidence, lastConfirmedAt, source?}`.
- **Kind** — `preference · constraint · pattern · episode · setting`.
- **Setting** — a memory with `kind = setting` and a `key`; **one row per key** (select-then-update, never an
  upsert on the partial unique index).
- **Source** (provenance, edge) — `conversation · onboarding · settings · debrief`.

## Rules

- **MEM-1 · Vana remembers only what was stated or repeated.** `rememberFact` is called for an explicit
  statement or a repeated behaviour, never a guess (persona hard rule). Confidence default 0.8; settings 1.0.
- **MEM-2 · Memory is visible and deletable.** The settings screen lists every memory with kind, fact and
  `source · date` (edge) and a per-row forget (`delete_memory` → `is_deleted = true`, never a hard delete).
- **MEM-3 · Recall is relevance ∪ recency.** Per turn: the latest user text is embedded and `recall_memories`
  returns up to 6 by cosine score (rows without an embedding score 0.3; expired rows excluded), then the 10 most
  recently confirmed are appended, deduped, capped at 10; 8 render in the MEMORIES line.
- **MEM-4 · Settings and their meaning when never chosen.**

| Key | Type | Default when absent | Who asks |
|---|---|---|---|
| `batch_cooking` | bool | **true** — but "never chosen" is visible (`batchKnown`) so the persona asks once | rule 4(a); Settings toggle |
| `show_macros` | bool | **true** (⚖️ Q-4, 2026-09-03; was false before) | Settings toggle |
| `coverage_scope` | `dinners · dinners_lunches · all` | **null** — never chosen is what makes the persona ask once; an unknown stored value reads as never chosen | rule 4(b) |
| `weekly_budget_usd` | number 0–2000 | null | the athlete saying "keep it under $N" |
| `pantry_items` | string[] (≤ 40) | [] | `set_pantry` ("Use these") |

- **MEM-5 · A setting's `fact` is fixed copy**, e.g. `batch_cooking = false` → "Cooks most nights — no batch
  cooking"; `coverage_scope = dinners` → "Plans dinners only"; `pantry_items` → "Has on hand: …". The drawer
  shows the fact, not the raw value.
- **MEM-6 · Debrief learnings are `pattern` memories with `source = debrief`**, ≤ 3 per debrief, and they feed
  the LAST WEEK / MEMORIES lines so the next proposal reacts (`../planning/opener-selection.md`).
- **MEM-7 · `batch_cooking` set from either door re-derives the plan's sessions**; `set_pantry` rebuilds the
  active plan's shopping list; other settings have no side effect on the plan.

## Invariants

1. At most one non-deleted `setting` row per `(user, key)`.
2. `getSetting` returns null (never a default) — defaults live in `SETTING_DEFAULTS` and are applied by the reader.
3. Forgetting is soft and the row stops rendering, recalling and counting as "chosen".

## Deviations

- **D-12** — prototype `setSetting` accepts only `batch_cooking` / `show_macros` (boolean); no
  `SETTING_DEFAULTS`, no provenance on the wire.

## Conformance

Fixtures (`memory_saved` part in `batch.json`/`confirm_plan.json` flows), Dart `user_memory_repository_test`,
vana-eval's fork conversations (batch / coverage asked once — `--keep-settings` proves the "never chosen" gate).
No pure vectors: MEM-4's defaults table is the contract; a table test over `SETTING_DEFAULTS` is the cheap guard.
