# Design SSOT — Surface: Vana General Chat

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.** Prototype `routes/vana.tsx`
(`mode=general`); the app's `/jade` becomes "Vana · general". Reached from "Ask Vana anything →" on the Plan tab
and the Meals tab.

| # | Contract |
|---|---|
| VG-1 | **Starts empty, no server row, no opener.** Empty state: avatar, "Ask me anything", one line on what she can pull, three example questions ("What should I eat before tomorrow's session?", "How did I eat this week?", "What's in my plan?"). The conversation id arrives with the first reply and is pushed into the URL without remounting. |
| VG-2 | **No plan bar, no picker chips.** A `choices` part renders normally; "Start a meal plan" routes to a new planning conversation. |
| VG-3 | **Pre-tool narration is hidden live and dropped from the transcript** (C-8). |
| VG-4 | **Header "Vana" · "Ask anything — she pulls what she needs"; New conversation (+) and the conversations list (one kind at a time).** |
| VG-5 | **A `day_guidance` answer renders the DayCard** (label tag, workout, "At least Ng carbs", note, dinner + snack rows linking to the Meals detail). |

Conformance: widget `vana_chat_controller_test` (general path), fixture `general_turn.json`.
