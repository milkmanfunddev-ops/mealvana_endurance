# 20-002 · Offline, the Shopping tab gives no sign it is offline: a failed tick is undone without a message, and the offline copy looks like the real list with Shop with Kroger still offered

- kind: bug
- status: triaged
- ticket: 20
- run: w10-20260924T1614Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
1. With the live list on screen, cut the app's network (runs/20/notes.md, "Offline method") and tick three rows (16:22:32-34Z).
2. Cold restart offline and open Food > Shopping (16:23:3xZ).

**Expected.**
A failed tick says so (the app's error snackbar, as other shopping edits do through `_guard`), and an offline list says it is offline or read-only, so the athlete in the store knows ticks will not be kept.

**Actual.**
- Step 1: each tick was rolled back silently. The screen does not await `setChecked` (`shopping_tab.dart` `onToggleChecked`), so the rethrown error reaches no snackbar; the console shows only the transport error, and no "Unhandled exception" line either.
- Step 2: the offline copy is headed "Shopping list" with no date and no row menus, but it still shows "Shop with Kroger" and the Share button, and has no offline notice. Its boxes can be ticked; the ticks look saved and are thrown away (20-001). The Timeline also opened offline with no notice.

**Evidence.**
- runs/20/13-offline-ticks-8s.png — after three offline taps: no change, no message.
- runs/20/console-excerpts.log — sections A and B: transport errors and "shopping list read failed; showing the plan mirror", nothing surfaced to the screen.
- runs/20/16-offline-shopping-13s.png — the offline copy: "Shopping list", Shop with Kroger, no offline notice.
- runs/20/14-offline-cold-restart-landing.png — Timeline offline, no notice.

**Decision quote.**
> 

**Triage.**
Fix ticket 36 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 110 when 90 was split (Lee, 2026-09-25).
