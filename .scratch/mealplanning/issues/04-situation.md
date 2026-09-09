# 04: Situation

**What to build:** An athlete on the fuel log for Saturday's ride asks Vana "what should I eat before this", and she answers about that ride. Each message from the client carries the route and, for screens with an entity in view, its id and date: Plan tab (date, plan), meal detail (meal), fuel log and current plan (activity), event screens (event), meal-log screens (date, slot), main tabs (date). The server resolves ids into one SITUATION sentence in the block. The Situation is never stored. Clients never send names or free text.

**Blocked by:** 03 General mode reads the Doll

**Status:** built, live eval not run (2026-09-09)

- [x] Server seam: each screen in the table resolves to its sentence from fixture rows; an unknown route resolves to route only; a missing entity resolves without error
- [x] Client seam: the Situation provider emits the right route, entity, and date for each screen in the table through the real provider
- [x] Nothing about the Situation is written to any table
- [ ] Live eval: from a fuel-log Situation, "what should I eat before this" names that session

**Notes (2026-09-09).** `_shared/vana/situation.ts` holds the screen table and the resolver;
`ChatBody.situation` carries `{route, entityId, date, slot}` and nothing else. The resolved sentence
becomes the block's SITUATION line, which appears only when the client sent one. Nothing is written:
the server seam test asserts an empty write log.

**The spec's screen table named the wrong route for two screens.** `/plan` and `/current-plan` are
both the activity detail screen — one session's fuel plan — so they resolve to an activity, not a
meal plan. The meal-planning Plan tab is `/food` (`?tab=plan`). The table in code is correct; the
spec's prose is not.

Client side: `VanaSituation` + `VanaScreen` (domain), `VanaSituationController` (kept alive), and
`VanaSituationScope`, a wrapper a screen puts round its Scaffold. Reporting happens after the frame,
never inside build. Leaving a screen does NOT clear the Situation — opening Vana means leaving the
screen you are asking about, and the Vana routes report nothing — so the last reported screen stands,
with a 30-minute staleness cut-off so an hour-old screen never speaks for the athlete.

Screens wired: the Plan tab, meal detail, cooking mode, fuel log, activity detail (both routes),
the race checklist, the events list, the main tab shell, and all six meal-logging screens.
Meal-log screens report their date; the slot is not one of their extras, so it is not sent yet.

Not done: the live eval line (case `situation` work is covered by `knows-tomorrow` and by hand).

