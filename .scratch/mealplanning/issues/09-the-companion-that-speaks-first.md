# 09: The companion that speaks first — the pre-workout moment, end to end

**Status:** ready-for-agent
**Blocked by:** None
**Next:** `/mattpocock-skills:implement .scratch/mealplanning/issues/09-the-companion-that-speaks-first.md`

**Spec:** `docs/ssot/spec/design/components/vana-moment.md` (PROPOSED v1, authored app-side). Read
it first; this ticket builds its M-1 and every state and gesture M-1 needs. M-2 (recovery) and the
two-a-day cap are ticket 10.

**The ruling (Lee delegated it, 2026-09-11).** What makes Vana speak: **fuelling windows only**,
decided on the device. The meal-plan beats (cook check-in, debrief) are left for ticket 12, because
the server decides them and the launcher cannot know about them without a server call. "Planning…"
is not built.

**What to build.** An athlete with a run tonight opens the app as the pre-run window opens, having
eaten nothing since. The launcher rings once, a pill beside it says "Fuel tonight's run?" for four
seconds while the tab bar steps aside, and then it stays orange. Tapping it opens the sheet on Vana
naming the run, its time and the window, with two quick replies. Closing the sheet leaves it orange.
Answering retires it, and so does eating something or the run starting.

## Pieces

1. **The resolver (domain, pure).** In: now, today's activities, today's meal logs, and which
   moments have already rung. Out: at most one live moment. M-1: a planned, not-completed workout
   today where `windowOpensAt <= now < startsAt` and no meal log has `eatenAt ?? createdAt` at or
   after `windowOpensAt`. The window length comes from `defaultFuelingWindowMinutes` in
   `lib/features/nutrition_plan/domain/fueling_window_authority.dart`; read how the existing callers
   get its inputs and reuse that path. Never write a window number here. `scheduled_date_time` is
   local-naive wall clock (see memory), so compare it with local now.
2. **The controller (application).** `@riverpod` `AsyncNotifier`. It watches today's activities and
   meal logs, re-resolves on a timer (a minute is enough), and holds the phase
   (`ring → pill → tinted`) and whether the moment has been answered. "Rang for this workout and
   window" persists in SharedPreferences per user per day, so a restart does not ring again. Riverpod
   reuses the notifier across `invalidate`, so reset fields in `build`.
3. **The launcher's states (design widget).** In `lib/shared/widgets/kyle_design/navigation/`,
   citing `vana-moment.md` in the header: the ring (drop and trace), the pill, and the tint. The
   export has the numbers: the drop is `chDrop` (0.7 → 1.12 → 1 over 420 ms), the trace is three
   dashed strokes on the bubble path fading out after 1.5 s, the pill is 240 px, and the tinted fill is
   the tone with a cream top highlight and the mark in blackberry. Honour reduced motion.
4. **The tab bar steps aside while the pill shows.** The export collapses it to its home button
   (`navProgress` 1 while the pill is open). Find how the home shell drives the bar's collapse and add
   the pill as a second reason. The pill and the bar must not overlap at iPhone-SE width.
5. **The sheet opens on the moment (VM-1).** The server already writes a scripted opener into an
   existing conversation when it gets `opener: true` with a `conversation_id` (see `runChat` in
   `supabase/functions/_shared/vana/chat.ts`). Add a `moment` field to the chat body (kind and
   activity id). For a general conversation, the opener text names the session from the activity
   row, and the opener ends in an `askChoice` with two options. The client sends that opener when it
   opens the sheet on a live moment, even when the conversation already has turns.
6. **A moment starts a new exchange.** `VanaExchange` today treats everything before the athlete's
   first turn as the opening. The moment's turn has to open a new exchange, so its quick replies show
   and its chip reads `Fuel plan · to do` (orange), even mid-thread. Pass where the exchange starts
   rather than special-casing the moment.
7. **Retiring (VM-2, VM-3).** A dismissed sheet leaves the moment tinted, with no second ring. Any send
   in the moment's exchange answers it. A meal logged in the window, or the workout starting, retires
   it on the next resolve.

## Seams (TDD)

- **Resolver:** feed it producer-shaped rows. Build activities and meal logs the way the Drift
  repositories and the Supabase rows produce them, never from the resolver's own output. Cases:
  window not yet open; open with nothing logged (raised); open with a snack logged after it opened
  (not raised); a log from before the window (still raised); the workout started (retired);
  completed; already rang today.
- **Controller:** through the real notifier with a fake clock. It rings once, a restart does not ring
  again, the moment retires on a log, and it stays live after a dismiss.
- **Server:** Deno tests beside the Vana modules (Seam 1). The opener text for a moment names the
  session, a body with no moment is unchanged, and an opener with a conversation id writes into that
  conversation.
- **Widget:** RING → PILL → TINTED; the tab bar collapsed while the pill shows; VM-1 to VM-3 through
  `VanaCompanionHost` (the prior art is `test/features/meal_planning/presentation/widgets/vana_companion_test.dart`);
  reduced motion.
- **Goldens:** the launcher `TINTED` orange and `PILL`, light and dark, at iPhone-SE width.

## Rules that bite here

- Strings are content keys (the pill line, the opener's replies if client-side), never literals.
  Colours come from `lib/theme/` tokens.
- Before touching `supabase/`, read `docs/deployment/supabase-deploy-playbook.md`. Deploy the
  function to **dev only**. `~/.supabase/pat` is missing: deploy with `SUPABASE_MANAGEMENT_TOKEN`
  from `secrets/supabase_management_api.env`.
- Commit only this ticket's files. Other sessions keep uncommitted work in this tree, and `git stash`
  is off limits in this repo.

## Done when

- [ ] M-1 is raised and retired by the resolver, proven over producer-shaped rows
- [ ] It rings once per workout window, across restarts
- [ ] RING → PILL → TINTED on the launcher, the tab bar stepping aside for the pill
- [ ] Tapping opens the sheet on Vana naming the session, with two quick replies and an orange to-do chip, mid-thread included
- [ ] Dismissing keeps it tinted; answering, logging or the start retires it
- [ ] Server change deployed to dev and seen answering on the simulator: plan a workout starting
      within its window on the dev account, and nothing logged
- [ ] Goldens for the two launcher states

**Full history:** `../archive/issues-2026-09-10/13-companion-speaks-first.md` (the deferred version, with
the three candidate trigger sets).
