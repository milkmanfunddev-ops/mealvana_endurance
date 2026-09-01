# Macro-dashboard reconciliation — worklist

**Working document (2026-08-13).** One row per actionable finding from
[`macro-dashboard-vs-daily-macros.md`](macro-dashboard-vs-daily-macros.md); we walk it top to
bottom. `☐ open · ◐ in discussion · ☑ ruled/dispatched`. Mock notes (F-01/02/04/05/06/08/09) are
non-blocking and not listed.

| | # | Owner | Item | Recommendation (short) |
|---|---|---|---|---|
| ☑ | F-03 | design + Q-014 | "Target" vs "TDEE" as two fields | **Q-014 RULED (Xuan, 2026-08-13): 30 %E cap, excess → carb, never dropped.** Redistribution preserves target ≡ TDEE, so the design fix stays two divergent states (fat-at-floor, pre-override) plus the corner case. Design prompt below |
| ☑ | F-07 | design | Recovery copy 30 vs 60 min | **Researched 2026-08-13: neither number survives — the copy must be CONDITIONAL on time-to-next-session.** <8 h to next quality session → urgent branch (1.0–1.2 g/kg/h × 4 h, Thomas 2016 Table 2 verbatim); ≥24 h (the recreational default) → "no rush — hit today's total; a normal meal with ~0.3 g/kg protein within a couple of hours." The 30-min window is real only as a *rate* penalty (Ivy 1988) that matters under the <8 h branch; as universal urgency it is the one claim the literature actively rejects (Aragon & Schoenfeld 2013; Thomas 2016 relaxes timing explicitly). Final design prompt below; numbers ratify via the F-16 spec draft |
| ☑ | F-10 | spec | Intraday proration | **Revised 2026-08-13: an upstream Notion "proration-proposal" existed and supersedes the draft's uniform smear.** §1 now distills it — per-component accrual (BMR clock / TEF intake / EAT atomic / NEAT measured-else-modeled), with the three data gaps filled by tagged estimates (sync-staleness bridge, wearable-only subtraction guard, 07:00–23:00 assumed waking window). **RATIFIED v1 (Xuan, 2026-08-13)** |
| ☑ | F-11 | spec | Net energy balance + copy bands | **Drafted: intraday-display.md §2** — bands ±200/±500; two safety rules hard-coded |
| ☑ | F-12 | spec | Planned-but-uneaten intake | **Drafted: intraday-display.md §3** — three definitions, actuals-only EA/net |
| ◐ | F-13 | spec | Sources → display chips | **Drafted: appended to `platform-resolution.md`** — total mapping, ZONE_DIST→estimated rationale |
| ☑ | F-14 | spec | Meal-level distribution | **Deferral recorded: intraday-display.md §4** |
| ☑ | F-15 | spec | Meal suggestion / swap engine | **Deferral recorded: intraday-display.md §4** — with the no-suitability-claims boundary; post-workout feeding the ratified exception |
| ☑ | F-16 | spec | Post-workout SSOT (absent) | **Drafted 2026-08-13: `spec/fueling/post-workout.md` PROPOSED v1** — conditional window (<8 h urgent / relaxed default), all numbers literature-tagged, §5 double-counting boundary with daily-macros, two §6 questions for Xuan (8–24 h band ruled `[design]`; "fuel-demanding session" definition proposed). **RATIFIED v1 (Xuan, 2026-08-13)** |
| ☑ | F-17 | spec | Tracking-off semantics | **Drafted: intraday-display.md §5** — gate never disabled; BLOCK/HARD render regardless |
| ☑ | F-18 | ruling | Multi-day carb ramp | **RULED (Xuan, 2026-08-13): no new formula**; fix only the Wednesday copy naming Saturday |
| ☑ | F-19 | ruling | EA safety UI absent | **RULED (Xuan, 2026-08-13): dashboard owns SOFT/HARD/BLOCK + `pre_override`**; SOFT treatment must avoid alert fatigue (persona runs: normal days land SOFT) |
| ☑ | F-20 | ruling | Sodium invisible | **RULED (Xuan, 2026-08-13): never a ruling gap — during-workout-sodium.md (RATIFIED, live engine) already computes sodiumRateMgph/sodiumTotalMg.** Ride plan wires the ratified outputs in; pre-workout absence stays correct |
| ☑ | F-21 | ruling | Phase/mode invisible | **RULED (Xuan, 2026-08-13): phase chip shown; mode stays internal** |

Full recommendations, evidence and the three design prompts: the walkthrough of 2026-08-13
(conversation) and the register. This file is the tracker; rulings land in the register / specs,
not here.

---

## F-03 notes — target vs TDEE, verified against the SSOT (2026-08-13)

Xuan's proposal: *fat should have a floor and a ceiling; between them target = TDEE; outside they
diverge.* Checked against `neat-tef.md` F15, `README` R3, invariants I8/I9:

- **Floor — confirmed.** `fat_floor = 0.8 × weight_kg`; `fat = max(residual, floor)`.
- **"Between the bounds target = TDEE" — confirmed** for the floor side: fat above floor → intake
  tracks TDEE exactly (I9's closed form).
- **Ceiling — does not exist in the SSOT.** Fat is unbounded above; the ratified worked examples
  reach **177 g** and **262 g** fat at 75 kg on big training days. Xuan's "above the ceiling"
  branch describes a rule the spec never wrote — now **[Q-014](../../spec/daily-macros/OPEN-QUESTIONS.md#q-014)**.
- **Today's divergence states are exactly two, both target > TDEE:** fat pinned at floor (intake
  fixed above TDEE — assembly calls it correct), and the EA override (`energy_basis =
  "pre_override"`). A ceiling would add the first target-**below**-TDEE state.
- **The decision Q-014 needs:** the ceiling value; where excess energy goes (dropped vs
  redistributed to carbs vs pro-rata — (b) matches practice but must order against the carb
  clamp); and that the cap must run **before** the EA gate so it cannot silently push an athlete
  into HARD_WARNING after the gate passed.

**RULED (Xuan, 2026-08-13): 30 %E cap, redistribute to carb.** Redistribution conserves energy,
so target ≡ TDEE survives the cap and the display contract keeps exactly the two pre-existing
divergence states (fat-at-floor, `pre_override`) plus the rare both-caps-saturated corner case.

**Final F-03 design prompt:**
> In the macro dashboard, "target kcal" and "projected total burn" are one quantity — display ONE
> number labelled as the target everywhere ("1,162 / 2,520", "on pace", macro rings), with the
> burn-breakdown total visibly equal to it. Two labelled exception states: (1) fat-at-floor —
> "target is slightly above projected burn to protect a minimum fat intake"; (2) safety override
> (`energy_basis: "pre_override"`) — "we raised today's target to protect your energy
> availability." No other state may show two different totals. Note the macro mix follows the
> spec's new fat cap: fat ≈ 30 % of the target, carbs carry the day-to-day variation — mock data
> should reflect that shape (e.g. big-ride day ≈ 723 g C / 130 g P / 162 g F at 75 kg).

---

## F-07 final design prompt (research-backed, 2026-08-13)

> Replace all post-workout copy with a two-branch conditional driven by `hours_to_next_session`:
>
> **Urgent branch (< 8 h to the next quality session, or a race tomorrow morning):** After-Ride
> badge "START NOW · refuel through the next 4 h"; card copy "Back at it within 8 hours — start
> refueling right away and keep carbs coming for the next 4 hours." (Engine supplies the g/kg/h
> figure once the post-workout spec ratifies.)
>
> **Relaxed branch (next session ≥ 24 h — the default for most users):** badge "WITH YOUR NEXT
> MEAL"; card copy "No rush — your next normal meal covers it. Aim for your carb total today and
> ~20–30 g of protein within a couple of hours."
>
> Delete every unconditional "within 30 minutes" / "within the hour" string. If
> `hours_to_next_session` is unknown, show the relaxed branch — urgency is the claim that needs
> evidence, not the absence of it. The 8–24 h middle band follows the urgent branch's direction
> softened ("refuel earlier rather than later today") pending the spec's ruling on that gap.

---

## Home-page iteration prompt — planned vs done, and the sync-delay confirmation (from the
platform-resolution rulings, 2026-08-13)

> On the fuel timeline, a workout card must visually distinguish three states: **PLANNED**
> (upcoming — outlined/dimmed treatment, planned-estimate chip), **DONE · verified** (Garmin
> synced — solid treatment, verified chip), and **DONE · confirmed** (athlete-confirmed, sync
> pending — solid treatment, self-reported chip, subtle "awaiting sync" glyph). Today the ride
> card looks identical before and after completion; that ambiguity is what this iteration removes.
>
> Add the confirmation affordance: once a workout's scheduled end time passes without a sync, the
> card offers a one-tap **"Mark as done"** (with optional duration adjust). Confirming keeps the
> workout's fuel in today's plan at the formula value instead of silently reverting the day to
> rest; a later Garmin sync upgrades the card to verified and re-runs the numbers. If neither sync
> nor confirmation arrives by end of day, the card lapses to "skipped?" state and the plan reverts
> — reversion is never silent while the athlete is still looking at the screen.
