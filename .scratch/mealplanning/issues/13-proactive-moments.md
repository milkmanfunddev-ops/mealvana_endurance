# 13: The companion that speaks first — DEFERRED

**Status:** deferred
**Blocked by:** A decision from Lee — what makes Vana speak
**Next:** Nothing to run. The three candidate trigger sets are below for when you want to pick one.

**What the export draws:** Vana speaking unprompted. A traced ring around the launcher for about two
seconds, then a colour tint — orange when there is something to do, electrolyte when it is only news.
For an actionable moment, a short pill beside the launcher ("Fuel tonight's run?") that retires after
about four seconds and leaves the tint behind; the tab bar retracts while she speaks. For an
informational one, the ring and the tint and no pill. There is a minimized state too: a pulsing pill
reading "planning…" for work happening in the background.

Tapping the launcher while a moment is live opens the sheet on that moment, with its own opening
message and quick replies — in the export, "That's your fuel timeline behind me. Tonight's 90-minute
run is at 5:30, and the pre-run window opens at 4:30. Want me to walk you through fueling it?" with
"Walk me through it" and "I'll explore on my own". Dismissing returns the moment to the launcher
rather than clearing it.

## The question that has to be answered first

**What makes her speak?** Nothing has decided this, and it is the whole ticket. A companion that
interrupts on the wrong trigger is worse than one that waits, and the export hard-codes its two
moments for the demo rather than deriving them.

The candidates, cheapest first:

1. **Fuelling windows only.** A workout today whose pre-workout window is opening with nothing
   logged; a finished workout with no recovery logged. This is the export's own example and the
   narrowest thing that is obviously useful.
2. **Windows plus the plan beats that already exist.** The same, plus a cook session today or
   tomorrow and a finished week never debriefed — both of which `pickOpener` already decides
   server-side, so the logic exists and is tested.
3. **A `vana-moment` endpoint.** The server returns at most one moment for right now, or nothing, and
   the client only renders. Most flexible, most work, and it makes the trigger set server config
   rather than client logic.

Whichever is chosen, three things need answering with it: how often she may speak at most, whether a
moment survives moving between screens or belongs to the one that raised it, and whether "planning…"
reflects real background work or is aspirational.

When this is ruled it becomes its own component spec alongside `vana-sheet.md`, and this ticket gets
rewritten against it. The states are recorded here and in the spec's deferred section so the drawing
is not lost.
