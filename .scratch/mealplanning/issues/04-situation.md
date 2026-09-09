# 04: Situation

**What to build:** An athlete on the fuel log for Saturday's ride asks Vana "what should I eat before this", and she answers about that ride. Each message from the client carries the route and, for screens with an entity in view, its id and date: Plan tab (date, plan), meal detail (meal), fuel log and current plan (activity), event screens (event), meal-log screens (date, slot), main tabs (date). The server resolves ids into one SITUATION sentence in the block. The Situation is never stored. Clients never send names or free text.

**Blocked by:** 03 General mode reads the Doll

**Status:** ready-for-agent

- [ ] Server seam: each screen in the table resolves to its sentence from fixture rows; an unknown route resolves to route only; a missing entity resolves without error
- [ ] Client seam: the Situation provider emits the right route, entity, and date for each screen in the table through the real provider
- [ ] Nothing about the Situation is written to any table
- [ ] Live eval: from a fuel-log Situation, "what should I eat before this" names that session
