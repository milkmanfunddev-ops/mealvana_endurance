# 10: The recovery moment and the two-a-day cap

**Status:** ready-for-agent once 09 is done
**Blocked by:** 09
**Next:** `/mattpocock-skills:implement .scratch/mealplanning/issues/10-the-recovery-moment-and-the-cap.md`

**Spec:** `docs/ssot/spec/design/components/vana-moment.md`, M-2 and the Cadence section.

**What to build.** An athlete finishes a session and logs nothing. While the post-workout recovery
window is open, the launcher speaks once, the same way as for M-1: ring, pill ("Recovery fuel?"),
tint. Tapping it opens the sheet on Vana naming the session just done. On a day with a morning and
an evening session, the athlete hears from Vana at most twice. When a pre-workout window and a
recovery window overlap, the one that closes sooner speaks.

- [ ] M-2 in the resolver. "Finished" means the activity is completed (its completion flag, or a
      matched Garmin/import). The recovery window's length comes from the fuelling SSOT under
      `docs/ssot/spec/fueling/`. **Find it there; do not invent a number.** If the SSOT names none,
      stop and put the question in this ticket rather than guessing.
- [ ] One moment at a time: the one whose window closes sooner.
- [ ] At most two rings a day, persisted with 09's rang-once record.
- [ ] The server opener for `moment.kind = recovery` names the finished session.
- [ ] Seams as in 09: resolver cases over producer-shaped rows (finished with nothing logged; logged
      after; window closed; overlap with a pre-workout window; third moment of the day suppressed),
      the controller through the real notifier, and one Deno test for the opener.
- [ ] Simulator: complete a session on the dev account and see the recovery moment.
