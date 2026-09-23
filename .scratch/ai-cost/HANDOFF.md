# ai-cost handoff (2026-09-23, after wave 7)

This replaces the 09-21 handoff, which is out of date.

## How Lee wants the next session to go

Lee wants a **conversation in the terminal**, not the SSOT page. Do not send him to the page, and do not
start by running `/ssot` or any -lee skill. Talk the open questions through with him **one at a time**, in
plain words and short replies. Give your recommendation with each one and let him decide. He has said he
gets lost easily on this feature, so stay on one topic and keep each reply brief.

When he rules on something, record it yourself from the terminal so the record stays true, without asking
him to open the page. Use `node docs/ssot/decisions/_page/sync.mjs`:

- to close a question with a new decision, add a card to `.scratch/mealplanning/decisions.md` (id from
  `next-id`) and run `answers <question id> <decision id> <proposals> <record>`;
- to approve on his word, write a verdicts file (`{"verdicts":{"mp-NNN":{"verdict":"approve","by":"Lee"}}}`)
  and run `apply`.

PROPOSALS and RECORD for ai-cost are the mealplanning pair: `.scratch/mealplanning/decisions.md` and
`docs/ssot/decisions/mealplanning.md`. Pushing the changed cards to the page afterwards is fine; it is a record
for him, not somewhere he has to go.

Then agree the next steps with him (below). New tickets are approved in the terminal: list the breakdown and
wait for "good to go".

## Where things stand

- **All 14 ai-cost tickets are built, merged and tested.** Everything is live on **dev**; nothing is on
  production. Production waits for Lee's go.
- Wave 7 (ticket 12, picker chips) cut a scripted five-picker conversation on dev from 7 model calls and
  232,528 input tokens to 3 calls and 87,004.
- **Rulings from 09-23:**
  - 22 cost cards approved.
  - mp-523 (daily $1.50 Sentry alert on a cron job) rejected. Lee chose option (b), now **built and on dev**:
    a trigger on `vana_calls` reports an account the moment its cost for the day passes $1.50. There is no
    cron job. Migration `20260923160000_ai_cost_alert_on_charge.sql`, commit "the $1.50 daily alert fires on
    the charge that crosses it".
  - In the terminal Lee approved **mp-608** (new: Vana reads batch cooking and coverage from Vana settings and
    never asks them while planning; batch starts on, coverage starts on "Dinners only"). He also approved the
    rewrites of **mp-602** ("I like these" goes to Vana only for the wrap-up), **mp-593** (coverage becomes a
    control in Vana settings) and **mp-232** (batch cooking is never asked). mp-594 is answered by mp-608.
- **Not committed:** `.scratch/mealplanning/decisions.md` and `docs/ssot/decisions/mealplanning.md` hold those
  rulings, but the paywall session was editing the same two files at the same time, so they were left for
  whichever session commits next. Check `git diff` on both before doing anything with them, and stage only
  your own hunks.
- Pro and paywall are **not this session's business** (Lee: "don't worry about pro and paywall"). Its
  verdicts (mp-317, 553, 554, 556, 557, 558) are left queued for the paywall session.

## Next steps to agree with Lee

1. **Vana stops asking the two questions** (mp-608, mp-602, mp-232). Not built. It changes the server
   (`context.ts` treats unsaved batch as on and unsaved coverage as dinners only; `chips.ts`
   `pickerNextStep` loses its `ask` step), and it drops the two forced questions from rule 4 in
   `persona.ts`. It also makes the ticket 12 code simpler.
2. **Coverage control in Vana settings** (mp-593). Not built. A three-way choice beside the batch-cooking
   switch in `vana_settings_screen.dart`, saved as the same `coverage_scope` setting Vana reads.
3. **Owed checks:**
   - ticket 11's simulator check ("Draft my whole week", "Open shopping list" with no model call);
   - ticket 13's after-count for day notes (the query is in the ticket);
   - ticket 14's one unmet criterion, which is open question mp-518.
4. **The other cron jobs.** Lee said "minimize cron jobs". Two more run on dev:
   - `ai-log-retention-sweep`, daily, which keeps the call log to 90 days;
   - `ai-budget-release-stale`, hourly, which frees budget held by calls that never finished.

   Ask whether he wants those gone too. Only the alert was ruled on.
5. **Production rollout** of the whole ai-cost bundle, when he says go. Read
   `docs/deployment/supabase-deploy-playbook.md` first; migrations and function deploys go dev, then prod.

## The open questions (Cutting costs), with a lean for each

Recommendations are mine (the wave 7 lead); Lee decides.

| Id | Question | Lean |
|---|---|---|
| mp-606 | Does a meal type count as planned after one meal, or only once it fills the nights the plan covers? | Fill the nights. Most urgent now, because it decides when "I like these" reaches the wrap-up (a paid turn). |
| mp-607 | In a race week, should "I like these" go to Vana so she can suggest a race-eve meal? | Yes, only when a race is in the plan's week. Rare, and it matters most then. |
| mp-595 | Should fixed chips act at once only under the question they belong to? | Mostly moot after step 1 (Vana stops asking those questions); confirm and close. |
| mp-596 | "Open shopping list" opens Food on Plan instead of Shopping. Fix now or later? | Fix now, small ticket: it is the chip's only job. |
| mp-597 | While a no-model tap runs, the line says "Vana is thinking…". Change it to a neutral line? | Yes, a neutral line, e.g. "Working on it…". |
| mp-518 | Adding a saved meal waits inside Vana's turn for a helper model to write its ingredient list. Move it to the background? | Background, dish shown as one line until the list is ready. |
| mp-526 | Does a "not food" photo draw the athlete's budget? | Charge it: the budget exists to stop loops. |
| mp-552 | On production, should a Sandbox (tester) purchase add real budget? | Testers get the month but packs grant nothing. |
| mp-576 | The wallet row still reaches the phone in micro-dollars. Is "never sent a dollar figure" about the screen or the wire? | Screen only; the screen is done. No ticket. |
| mp-522 | Fill in unpriced calls from the budget's price table so the weekly cost is one number? | Yes, one number. |
| mp-527 | Pad meal-logging instructions so they can be cached? | No, not until the hit rate is measured. |
| mp-548 | Track picker cost per call or per model step? | Per model step. |
| mp-577 | Is the 80% cache target per turn or averaged over ten? | Averaged. |
| mp-578 | Name for the $0.99 test pack ("A sliver of a month of Vana")? | Hide it from the top-up sheet on production. |

Full context for each: `node docs/ssot/decisions/_page/sync.mjs questions .scratch/mealplanning/decisions.md docs/ssot/decisions/mealplanning.md`.

## Gotchas

- `sync.mjs refresh` for ai-cost pictures must be run with feature `mealplanning`, never `ai-cost`.
- Worktree `.env` files are empty; copy `.env` and `.env.dev.local` in before a device check.
- A dev deploy: `set -a; . secrets/supabase_management_api.env; set +a; export SUPABASE_ACCESS_TOKEN="$SUPABASE_MANAGEMENT_TOKEN"; ./scripts/deploy_dev.sh <fn>`.
  SQL on dev goes through the Management API `database/query`; send a large file as a JSON body from a file.
- The account hits its Fable usage limit; ask Lee before switching a ticket's model.
