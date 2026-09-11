# 10: The recovery moment and the two-a-day cap

**Status:** built 2026-09-11; the simulator check is still owed
**Blocked by:** 09
**Next:** `/mattpocock-skills:implement .scratch/mealplanning/issues/10-the-recovery-moment-and-the-cap.md`

**Spec:** `docs/ssot/spec/design/components/vana-moment.md`, M-2 and the Cadence section.

**What to build.** An athlete finishes a session and logs nothing. While the post-workout recovery
window is open, the launcher speaks once, the same way as for M-1: ring, pill ("Recovery fuel?"),
tint. Tapping it opens the sheet on Vana naming the session just done. On a day with a morning and
an evening session, the athlete hears from Vana at most twice. When a pre-workout window and a
recovery window overlap, the one that closes sooner speaks.

- [x] M-2 in the resolver. "Finished" means the activity is completed (its completion flag, or a
      matched Garmin/import). The recovery window's length comes from the fuelling SSOT under
      `docs/ssot/spec/fueling/`. **Find it there; do not invent a number.** If the SSOT names none,
      stop and put the question in this ticket rather than guessing.
- [x] One moment at a time: the one whose window closes sooner.
- [x] At most two rings a day, persisted with 09's rang-once record.
- [x] The server opener for `moment.kind = recovery` names the finished session.
- [x] Seams as in 09: resolver cases over producer-shaped rows (finished with nothing logged; logged
      after; window closed; overlap with a pre-workout window; third moment of the day suppressed),
      the controller through the real notifier, and one Deno test for the opener.
- [ ] Simulator: complete a session on the dev account and see the recovery moment.

## Notes (build, 2026-09-11)

- **The window, from `post-workout.md` (RATIFIED v1).** The SSOT names no single "recovery window".
  It names one variable (time to the next fuel-demanding session) and two branches, and the build
  reads the window off them: **urgent** (next fuel-demanding session under 8 h after the end,
  `POST_URGENT_THRESHOLD_H`) holds it for `POST_URGENT_DURATION_H`, 4 h; **relaxed** (8 h or more,
  or none known) holds it for `POST_PROTEIN_WINDOW_H`, 2 h, the one timed item both branches share.
  Only a fuel-demanding session raises it (§6 Q2): an endurance session of 60 min or more; the
  import-only catch-all (strength and the like) never does. Constants and the branch rule live in
  `lib/features/nutrition_plan/domain/recovery_window_authority.dart`. **For Lee / Xuan:** this is a
  reading, not a ruling. §6 Q2's "or any session the during-workout spec fuels" was not used: the
  during-workout bands fuel every non-swim session (15 g/h under 60 min), which would make the 60 min
  clause empty. The next session is read from the app's own calendar (planned rows, any day); §6 Q3's
  resolution ladder is still open.
- **"Finished"** is `status = completed` (mark-done or a Garmin/import match). It ended at its start
  (`actual_time`, else `scheduled_date_time`) plus its length (`actual_duration_minutes`, else
  `duration_minutes`). `completed_at` is not read: mark-done writes the planned start there and
  Garmin a UTC end.
- **One recovery per session.** Its key is `recovery:<activity id>`, with no time in it, so Garmin
  refining a marked-done session's start does not ring it again.
- **The cap.** A moment that has not rung is not raised at all once two have rung today (read off
  09's `rung` record). A moment that already rang stays live.
- **Clock.** The controller's minute tick now also runs while a finished session's recovery window
  is open, so the window closing retires it without a row changing.
- **Server.** `moment.kind = recovery` with `window_minutes` (after the end), `branch`
  (`urgent` | `relaxed`; anything else reads as relaxed), and `next_activity_id` when the next
  fuel-demanding session is under 24 h away. The opener names the session and when it finished.
  Urgent names the next session and "keep carbs coming through the next 4 hours, until …". Relaxed
  says there is no rush and gives no deadline, because the copy contract forbids presenting the ~2 h
  anchor as a window. With a session 8–24 h away it names that session and leans "earlier rather
  than later today" (§6 Q1). Both mention ~20–30 g of protein within a couple of hours. The server does not require the row to say
  `completed`, because mark-done uploads behind the local write. Deployed to dev (`vana-chat`,
  `jade-chat`); the tree's other uncommitted `_shared/vana/grocery.ts` edits went with them.
- **Open for Lee / Xuan (from the review).** (1) VM-1 says the opener names "the window". A
  relaxed recovery's opener does not, because post-workout.md forbids presenting it as one; the
  SSOT wins here. (2) A relaxed recovery still shows the orange to-do and "Recovery fuel?" as the
  component spec assigns M-2, while the SSOT's relaxed badge is "WITH YOUR NEXT MEAL". If that
  reads too urgent, relaxed could raise nothing, or raise news. (3) Mark-done places the end at the
  planned start plus planned length, so a session marked done long after its slot finds its window
  already shut.
