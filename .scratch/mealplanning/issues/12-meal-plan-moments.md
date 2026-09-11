# 12: Meal-plan moments (cook check-in, week debrief)

**Status:** needs-grilling (not ready for an agent)
**Blocked by:** 10
**Next:** `/mattpocock-skills:grill-with-docs` on this ticket once 09 and 10 have been lived with for a
while, then rewrite it.

**The idea.** The second half of the trigger set Lee first leaned toward: Vana speaks first when a
cook session is today or tomorrow and there has been no check-in, or when last week's plan finished
and was never debriefed. `pickOpener` in `supabase/functions/_shared/vana/opener.ts` already decides
both, and is tested.

**Why it is separate.** The server decides these, so the launcher can only learn of them from a
server call. That means a small endpoint returning "the moment for now, or nothing" that reuses
`pickOpener`, merged with the device's fuelling moments under the same cadence rules. Questions to
settle first: how often to ask the server, what happens offline, and whether a plan moment may take
one of the day's two rings.
