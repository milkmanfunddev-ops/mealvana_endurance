# Triage: develop-2026-10

## Wave log

One line per wave: number, base sha, tickets, start time, who led it.

- wave 1 · base `1c254461` · tickets 01, 02, 08 · 2026-10-07T10:56Z · lead: Claude (Fable), test wave
- wave 2 · base `a69b226b` · ticket 29 alone (sequential Opus agents by area in one worktree), then 21–28 · 2026-10-07T13:40Z · lead: Claude (Fable), fix wave
- wave 2b · base (29 merged) · tickets 21+22 (one agent), 24, 26+27 (one agent), 28; then 23 after 26+27 merges · 2026-10-07 · lead: Claude (Fable), fix wave

## Rulings

One line per Finding decision, made with Lee in the terminal: id, decision, who and when.
- 01-001 · wontfix · Lee: Xuan's copy, never changed by us anywhere; develop has no paywall, so no paywall tickets are needed · Lee, 2026-10-07
- 01-002 · triaged · fix ticket: a wrong code gets its own message; expired stays for expired · Lee, 2026-10-07
- 01-003 · triaged · fix ticket, scoped: Lee rules there is no anonymous-upgrade path going forward (it is being removed), so its resend failure goes away with it; fix every other Resend problem on Verify your email (the plain signup resend must send a new email) · Lee, 2026-10-07
- 01-004 · triaged · fix ticket: the client writes that send naive local time as created_at send UTC or let the server default · Lee, 2026-10-07
- 01-005 · triaged · fix ticket: expected signup outcomes become breadcrumbs, not Sentry errors; real auth failures tagged area auth · Lee, 2026-10-07
- 01-006 · triaged · fix ticket: a transient that resolves under its threshold is a breadcrumb, not a Sentry error · Lee, 2026-10-07
- 02-001 · triaged · fix ticket: develop's token model must work as intended end to end (Lee): tokens start at 50 and go down to 0, one per describe-meal, photo and formula-kit call, the pill shows the real balance, the wall at 0, token packs purchasable; the usd_micro skew with mealplanning's wallet is resolved as part of it, not studied further · Lee, 2026-10-07
- 02-002 · triaged · fix ticket: develop's token model must work as intended end to end (Lee): tokens start at 50 and go down to 0, one per describe-meal, photo and formula-kit call, the pill shows the real balance, the wall at 0, token packs purchasable; the usd_micro skew with mealplanning's wallet is resolved as part of it, not studied further · Lee, 2026-10-07
- 02-003 · triaged · fix ticket: the AI note is saved to meal_logs.notes (meal-logging ticket with 02-005) · Lee, 2026-10-07
- 02-004 · triaged · fix ticket: edge-function logs are read through the Supabase MCP's query_logs (ClickHouse SQL on the logs table) from now on; runbook step 6 and the other callers switch to it and scripts/edge_logs.sh is deleted so nothing passes silently again (Lee) · Lee, 2026-10-07
- 01-013 · triaged · fix ticket: edge-function logs are read through the Supabase MCP's query_logs (ClickHouse SQL on the logs table) from now on; runbook step 6 and the other callers switch to it and scripts/edge_logs.sh is deleted so nothing passes silently again (Lee) · Lee, 2026-10-07
- 02-005 · triaged · fix ticket: quantity and per-portion base stay separate on an edited item; reopen shows the quantity over the original base (meal-logging ticket with 02-003) · Lee, 2026-10-07
- 08-010 · triaged · fix ticket (orphans): comment out the routes and move the screens to _archived, never delete (Lee): /pro, /settings/sport-settings, /settings/food-preferences-consolidated, /settings/food-preferences/add-food, the five standalone /meal-log/* screens, plus the never-built classes. Carefully: mealplanning and a paywall are coming, so /pro will likely be needed again · Lee, 2026-10-07
- 08-011 · triaged · fix ticket (orphans): comment out the routes and move the screens to _archived, never delete (Lee): /pro, /settings/sport-settings, /settings/food-preferences-consolidated, /settings/food-preferences/add-food, the five standalone /meal-log/* screens, plus the never-built classes. Carefully: mealplanning and a paywall are coming, so /pro will likely be needed again · Lee, 2026-10-07
- 08-012 · triaged · fix ticket (orphans): comment out the routes and move the screens to _archived, never delete (Lee): /pro, /settings/sport-settings, /settings/food-preferences-consolidated, /settings/food-preferences/add-food, the five standalone /meal-log/* screens, plus the never-built classes. Carefully: mealplanning and a paywall are coming, so /pro will likely be needed again · Lee, 2026-10-07
- 08-014 · triaged · fix ticket (orphans): comment out the routes and move the screens to _archived, never delete (Lee): /pro, /settings/sport-settings, /settings/food-preferences-consolidated, /settings/food-preferences/add-food, the five standalone /meal-log/* screens, plus the never-built classes. Carefully: mealplanning and a paywall are coming, so /pro will likely be needed again · Lee, 2026-10-07
- 08-003 · triaged · fix ticket (orphans): comment out the routes and move the screens to _archived, never delete (Lee): /pro, /settings/sport-settings, /settings/food-preferences-consolidated, /settings/food-preferences/add-food, the five standalone /meal-log/* screens, plus the never-built classes. Carefully: mealplanning and a paywall are coming, so /pro will likely be needed again · Lee, 2026-10-07
- 08-005 · triaged · fix ticket (orphans): comment out the routes and move the screens to _archived, never delete (Lee): /pro, /settings/sport-settings, /settings/food-preferences-consolidated, /settings/food-preferences/add-food, the five standalone /meal-log/* screens, plus the never-built classes. Carefully: mealplanning and a paywall are coming, so /pro will likely be needed again · Lee, 2026-10-07
- 08-004 · triaged · fix ticket (orphans): comment out the routes and move the screens to _archived, never delete (Lee): /pro, /settings/sport-settings, /settings/food-preferences-consolidated, /settings/food-preferences/add-food, the five standalone /meal-log/* screens, plus the never-built classes. Carefully: mealplanning and a paywall are coming, so /pro will likely be needed again ; /buy-credits and the meal-log screens' Back: see the orphan ticket; /buy-credits itself is ruled separately below · Lee, 2026-10-07
- 08-001 · triaged · fix ticket (archive Jade): comment out /jade, move lib/features/ai_coach to _archived, move the shared thinking-status widget to lib/shared/widgets, rename the jade_calls logging and the JADE_MODEL alias in the functions, leave the dev-only tables; Vana replaces the chat at Phase B (Lee). Meal logging and formula kits are not Jade and stay · Lee, 2026-10-07
- 08-002 · triaged · fix ticket (archive Jade): comment out /jade, move lib/features/ai_coach to _archived, move the shared thinking-status widget to lib/shared/widgets, rename the jade_calls logging and the JADE_MODEL alias in the functions, leave the dev-only tables; Vana replaces the chat at Phase B (Lee). Meal logging and formula kits are not Jade and stay · Lee, 2026-10-07
- 08-006 · triaged · fix ticket (archive Jade): comment out /jade, move lib/features/ai_coach to _archived, move the shared thinking-status widget to lib/shared/widgets, rename the jade_calls logging and the JADE_MODEL alias in the functions, leave the dev-only tables; Vana replaces the chat at Phase B (Lee). Meal logging and formula kits are not Jade and stay · Lee, 2026-10-07
- 08-013 · triaged · NOT archived (Lee): Coach Messages is reachable when the athlete is linked to a coach; the test account was not paired. Retest in ticket 19 (coach pairing) checks the entry appears once paired; no code navigates to /athlete/feedback by grep, so if 19 finds no entry this comes back as a bug · Lee, 2026-10-07
- 08-015 · closed · covered by ticket 12 (the pill, the Out-of-credits dialog, Get credits, a pack purchase are all wired in code: token_pill.dart, insufficient_credits_paywall.dart); no separate retest · Lee, 2026-10-07
- 08-007 · triaged · fix ticket (guards batch): the launch-trail guard matches a real notification payload only and the dialog shows once per process; unit test on the guard · Lee, 2026-10-07
- 01-011 · triaged · fix ticket (guards batch): the launch-trail guard matches a real notification payload only and the dialog shows once per process; unit test on the guard · Lee, 2026-10-07
- 08-008 · triaged · fix ticket (guards batch): the Events list's bottom padding clears the floating tab bar; retest taps New Event · Lee, 2026-10-07
- 08-009 · triaged · fix ticket: the deferred.notifications timer excludes the time the OS permission prompt is up; the four thresholds stay; ticket 17's retest on a lone simulator decides whether the other three are real · Lee, 2026-10-07
- 08-025 · triaged · fix ticket (backports): the mealplanning round's fixes to code develop shares (about 25 of its 71, Garmin ticket 138 = 63c269c2 included) are extracted from their mealplanning landing commits onto develop-next with their tests; the wave-1 re-finds (01-002, 08-008, 08-021, 02-011) close through it (Lee) · Lee, 2026-10-07
- 01-009 · triaged · fix ticket: public.users.email is normalised to lowercase at write, plus a one-off dev SQL for existing rows; the personal-info prefill is Xuan's onboarding behaviour and goes to the review queue · Lee, 2026-10-07
- 01-008 · wontfix · Lee: the unit default is Xuan's onboarding call · Lee, 2026-10-07
- 02-013 · closed · IMPROVEMENTS entry: the mobile MCP helper fails to start on a wave simulator; idb-first is the runbook's fallback and carried a full run · Lee, 2026-10-07
- 01-010 · triaged · retest ticket 30 (retest: auth and account), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 01-014 · triaged · retest ticket 30 (retest: auth and account), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 01-015 · triaged · retest ticket 30 (retest: auth and account), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 01-016 · triaged · retest ticket 30 (retest: auth and account), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 01-017 · triaged · retest ticket 30 (retest: auth and account), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 01-018 · triaged · retest ticket 30 (retest: auth and account), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 02-006 · triaged · retest ticket 31 (retest: meal logging), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 02-007 · triaged · retest ticket 31 (retest: meal logging), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 02-008 · triaged · retest ticket 31 (retest: meal logging), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 02-009 · triaged · retest ticket 31 (retest: meal logging), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 02-010 · triaged · retest ticket 31 (retest: meal logging), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 02-011 · triaged · retest ticket 31 (retest: meal logging), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 02-012 · triaged · retest ticket 31 (retest: meal logging), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 08-016 · triaged · retest ticket 32 (retest: startup, tabs, deep links), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 08-017 · triaged · retest ticket 32 (retest: startup, tabs, deep links), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 08-018 · triaged · retest ticket 32 (retest: startup, tabs, deep links), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 08-019 · triaged · retest ticket 32 (retest: startup, tabs, deep links), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 08-020 · triaged · retest ticket 32 (retest: startup, tabs, deep links), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 08-021 · triaged · retest ticket 32 (retest: startup, tabs, deep links), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 08-022 · triaged · retest ticket 32 (retest: startup, tabs, deep links), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 08-023 · triaged · retest ticket 32 (retest: startup, tabs, deep links), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 08-024 · triaged · retest ticket 33 (retest: cross-device and leftovers), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 01-012 · triaged · retest ticket 33 (retest: cross-device and leftovers), wave 3 (Lee: all 27 followups into four retest tickets) · Lee, 2026-10-07
- 01-007 · triaged · rewritten into retest ticket 30: the consent screen is reached by failing the geo lookup (netcut) or a strict-country answer, not by setting the locale (Lee) · Lee, 2026-10-07
- 29 (rulings) · predecessors: bring the mealplanning predecessor tickets along (t42, t99, t101, t76, t102, t103, t79, t81, t83, t98, t44, 31-004, t94, t65, t68, t95), shared paths only · Drift: v23 (t99) then v24 (servings), same numbering as mealplanning · Lee, 2026-10-07
- 23 (ruling) · the dev wallet conversion SQL (item 1) runs now on dev; mealplanning's Vana on dev is refused until Phase B, which owns it · Lee, 2026-10-07
- 27 (ruling, item 7) · jade-chat's source moves to the archive; the dev deployment stays as it is · Lee, 2026-10-07
