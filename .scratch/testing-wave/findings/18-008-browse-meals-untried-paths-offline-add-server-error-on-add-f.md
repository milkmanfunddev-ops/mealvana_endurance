# 18-008 · Browse meals untried paths: offline Add, server error on Add, fast double tap, Browse meals under a picker, empty search, large text, Done with nothing added

- kind: followup-test
- status: open
- ticket: 18
- run: w16-20260924T2100Z
- screen: Browse meals
- decision: 

**Steps.**
1. Offline Add: netcut.sh on, then "+" on a card; expect the "needs connection" warning, no tick, no row.
2. Server error on Add (e.g. a meal removed from the library): expect the server-error toast and no tick.
3. Double-tap "+" fast: expect one pick_meals call (the _inFlight guard).
4. Reach Browse from "Browse meals" under a meal picker part (vana_part_renderer.dart) rather than the plus menu.
5. Search with no matches ("zzzz"): empty state.
6. Text scale 1.5+: card and header layout, Done still reachable.
7. Open Browse and tap Done with nothing added: chat unchanged, no write.
8. Browse in a brand-new planning conversation (plus in the chat header): first Add creates its draft.

**Expected.**
Each path behaves as described in step text; the console shows no Flutter error.

**Actual.**
Not run in w16 (ticket 18 covered each on-screen control once).

**Evidence.**
- runs/18/notes.md: which controls were tried.

**Decision quote.**
> 

**Triage.**

