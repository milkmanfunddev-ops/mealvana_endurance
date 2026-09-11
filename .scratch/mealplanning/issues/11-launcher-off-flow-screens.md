# 11: The launcher stays off flow screens

**Status:** ready-for-agent
**Blocked by:** None (independent of 09 and 10)
**Next:** `/mattpocock-skills:implement .scratch/mealplanning/issues/11-launcher-off-flow-screens.md`

**Ruled (Lee, 2026-09-11):** hide the launcher on flow screens rather than giving each screen a
clearance inset. Found on the device in 06: the launcher covers the right end of full-width bottom
buttons ("Generate Plan" on the new-activity screen) and the right edge of the pre-workout card on
the session screen.

**What to build.** A flow screen is one whose job ends in a full-width bottom action: creating or
editing something, a wizard step, a form. On those, the launcher has no node, the same way it has
none on auth or the paywall (VS-6). Browsing screens keep it.

- [ ] Survey the router for screens with a full-width bottom CTA. List them in this ticket, with
      the reason for each.
- [ ] Add them to the rule in `lib/features/meal_planning/domain/vana_launcher_rule.dart`, as a
      named set beside the existing exclusions, not as scattered checks.
- [ ] The VS-6 router test covers the new set: no launcher node on each, one on a browsing screen.
- [ ] The session screen's pre-workout card: if the screen is a browsing screen, say so in this
      ticket and leave it for Q-VS4 rather than hiding the launcher there.
- [ ] Simulator: "Generate Plan" is fully visible on the new-activity screen.
- [ ] Add a line to `vana-sheet.md` ("Where the launcher does not appear") naming flow screens.
