# Review queue

Product questions waiting on a decision. Nothing here is in the SSOT. Lee answers his own one at a
time in the terminal (AskUserQuestion); Xuan's go to her as a list. An answered item becomes an
approved card or a ruling in the round's TRIAGE.md, and leaves this file. Rewritten 2026-10-08
(the old done and deploy logs are in git history, commit before this one).

## For Xuan (wording and design)

1. **Verify-your-email strings (VERIFY-COPY-001, develop-2026-10).** Three strings shipped on dev
   with Lee's interim approval (2026-10-08); rewrite if you want:
   - a code refused after a Resend: "That code isn't right, or it's from an earlier email"
   - `error_resend_failed`: the resend did not go out
   - `error_generic`: anything else
   A 429 from Supabase shows no text, only the resend countdown.
2. **Sign-up prefill and unit default (ONB-PREFILL-001, develop-2026-10).** The email typed on the
   personal-info page is not carried into the sign-up form; under en_GB the body page starts on
   Imperial. Prefill, and units by locale? Recommend yes to both.
3. **Energy card and month sheet (XUAN-TW-001, mealplanning-2026-09).**
   (a) CS-6 says the month sheet stays open on Today, fix 137 closes it: which?
   (b) light-theme accent colours measure ~1.3:1 on cream: change the tokens?
   (c) `validateDuringTotals` keeps a strict 1.1 cap inside the plan's own band: intended?
   (d) the override info icon needs a new server snapshot field: add it or drop the icon?
   (e) balance reads "0 kcal to target" when 1,570 kcal over; (f) a past day's Meals header reads
   INTAKE TODAY; (g) a past day's Workout card reads TODAY'S WORKOUT.
   Recommend (e)–(g): "1,570 kcal over", "INTAKE · SEP 23", "WORKOUT · SEP 23".
4. **Paywall trial and renewal lines (mp-513).** Final as drafted, or your rewrite?
5. **Glass paywall sheet (mp-590).** Grabber or not; top gap; slide-in timing.
6. **Lowered carb rate (mp-680).** When an athlete lowers their own carb rate, what does the
   during-run band show? Recommend: the band stays the engine's and the screen stops flagging
   their own rate as low.

## For Lee (decisions)

1. **Vana judging personas (VANA-PERSONA-001).** Run round 001 on judging-1 as is, persona
   mismatches as findings; spawn the four persona accounts only for Scenarios where the persona is
   load-bearing. Recommend yes.
2. **Codemagic Patrol lists (CI-001).** Delete the hand-kept Patrol target lists from the two
   disabled Codemagic workflows and let the contract test read the M1 workflow only. Recommend yes.
3. **RevenueCat Test Store (mp-656).** Swap it to the four `me_pro_*` products? Recommend yes.

## Tasks, not decisions

- Lee: the phone run of the store checks on both stores (paywall ticket 13).
- Lee: confirm the one item sent to the real Kroger cart on 09-10 arrived (kroger-delivery 02).
- QA repo (`../mealvana_endurance_qa`, hands-off from here): the seeder signs in as the athlete
  before writing `users` (Sentry DEV-4) and mints uuids for `integrations.id` (DEV-82); then
  resolve both in Sentry.
