# Design SSOT — Surface: Vana Settings

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.** Prototype `routes/settings.tsx`; Dart
`vana_settings_screen.dart` (the cog on the conversations list). **Data:** `../../domain/memory.md`.

| # | Contract |
|---|---|
| VS-1 | **Batch cooking toggle** → `set_setting {batch_cooking}`; flipping it re-derives the active plan's sessions (MEM-7) and returns a `batch` part. The same row Vana writes from a conversation. |
| VS-2 | **Show macros toggle** → `set_setting {show_macros}`; default ON (⚖️ Q-4). |
| VS-3 | **Reminders toggle** (app) — device-side, OFF by default, ships dark (⚖️ Q-5): check-in 18:00 the evening before cook day, debrief 18:00 the closing Sunday. |
| VS-4 | **"What Vana knows" — the memory drawer:** every non-deleted memory as kind tag · fact · `source · date` (edge; the prototype shows "confirmed <date>" — D-12), with a Forget per row (`delete_memory`, soft). Empty: "Vana hasn't saved anything about you yet." |
| VS-5 | **A `memory_saved` part in chat reads "Saved to Settings · <fact>"** — the two doors are the same row (MEM-4). |

Conformance: widget `vana_settings_controller` tests; golden of the drawer with three kinds.
