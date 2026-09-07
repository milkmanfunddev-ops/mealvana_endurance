# Meal Planning — Open Questions Register

Everything that needs Xuan's call. Two sources: her own artifacts' contradictions (Q-1..Q-7, raised 2026-09-02,
each carrying the ⚖️ interim call that shipped on 2026-09-03 so building could continue — she can veto any of
them cheaply), and the questions the 2026-09-03 record surfaced (Q-WC…, Q-SL…, …). **These are spec-vs-spec
or spec-vs-observed problems; code-vs-SSOT findings belong in [`DEVIATIONS.md`](DEVIATIONS.md).**

This stays a **single index**, deliberately unlike the QA repo's per-family `<family>.OPEN-QUESTIONS.md` split
(README.md states this difference; it isn't silently converging with the QA repo's shape). Every ⚖️ interim call
below that Xuan still needs to rule on also has a standalone, atomic ruling-request file under
[`intake/`](intake/README.md) — a drop folder in the QA repo's `intake/` shape, adapted for this app-side SSOT
(no separate ops repo to route product-lifecycle items to). Use the index below for the state of a call at a
glance; use the matching `intake/2026-09-03-*.md` file when actually working the ruling.

| ID | Family | Subject | Status |
|---|---|---|---|
| [Q-1](#q-1) | intent | scope of the AI Scenarios (race fueling stays deterministic?) | ⚖️ interim: mechanics only |
| [Q-2](#q-2) | intent | the structured 6-step wizard door | ⚖️ interim: no wizard in v1 |
| [Q-3](#q-3) | intent | artifact depth (calendar / email / PDF) | ⚖️ interim: share sheet + local notifications |
| [Q-4](#q-4) | intent | macros shown by default? | ⚖️ interim: ON (Xuan's 05-20 concession) |
| [Q-5](#q-5) | intent | proactive cadence and channel | ⚖️ interim: opener-on-open; push dark |
| [Q-6](#q-6) | intent | tone: warmth vs terseness | ⚖️ interim: moment-based registers; emoji ban kept |
| [Q-7](#q-7) | intent | first-run intro | ⚖️ interim: intro card built 2026-09-03, then REMOVED same evening — see [D-021](DEVIATIONS.md#d-021--q-7-intro-card-built-then-removed-the-same-evening) |
| [Q-8](#q-8) | agent / planning | opener shape: question-first vs. frame + three dinners | ⚖️ interim (2026-09-03 evening): question-first — see [D-020](DEVIATIONS.md#d-020--opener-reversal-question-first-supersedes-the-08-31-frame--three-dinners-decision) |
| Q-DT1 | planning | the 0.55 lunch+dinner share of the meal budget (25 / 20 breakfast / snacks) is uncited | open |
| Q-AC1 | planning | extract the context arithmetic into a pure module so it can be vectored | open (conformance) |
| Q-AC2 | planning | weather needs a location; the profile has none — race location only | open |
| Q-WC1 | planning | week character is volume-weighted; one hard 60-min session reads "easy / recovery" | open |
| Q-WC2 | planning | `RACE_PATTERN` misses "triathlon" and ignores `intensity_level = race` | open — tripwire vector |
| Q-WC3 | selection | a race from an activity title never yields carb-load tags without an `events` row | open — tripwire vector |
| Q-DG1 | planning | extract the day-guidance decision table into a pure function | open (conformance) |
| Q-CS1 | planning | cook day is fixed to Sunday / Wednesday / Friday; the athlete's real cook day is not modelled | open |
| Q-CS2 | planning | extract the batch re-derive so it can be vectored | open (conformance) |
| Q-CS3 | planning | a saved meal is treated as `batch = true` on re-derive | open |
| Q-SL1 | planning | ALWAYS_HAVE is exact ("sea salt" is bought); pantry `have` is a substring ("rice" owns "rice cakes") | open — tripwire vectors |
| Q-SL2 | planning | aisle keyword collisions (kombucha → Pantry, ice cream → Dairy) | open — tripwire vectors |
| Q-MI1 | planning | every "dal" renders the soup glyph | open — tripwire vector |
| Q-MS1 | selection | `attributionShort` leaves a leading "by" after stripping "Reported" | open — tripwire vector |
| Q-SG1 | selection | extract on-hand re-ranking so SG-4 can be vectored | open (conformance) |
| Q-ML1 | domain | who reviews the 197 `ai_generated` direction rows | open |
| Q-ML2 | domain | should approximate library macros ever show on assemblies | open |
| Q-AG1 | agent | vana-eval has no body-talk check for H7 | open (conformance) |
| Q-AG2 | agent | `updateBatch add` lets the model add a meal "the athlete named" — is the description guard enough for H5 | open |
| Q-WP1 | agent | rate limits have no unit test | open (conformance) |
| Q-TK1 | design | slot colours borrow three meaning-bound tokens for a categorical purpose | open — D-019 until ruled |
| Q-DS1 | design | no `conformance/design/*.yaml` manifests for this family yet | open (conformance) |
| Q-MP1 / Q-MP2 | design | macro pill short form; fat on compact tiles | in `docs/ssot/spec/design/components/macro-pill-row.md` |
| Q-SCG1 / Q-SCG2 | design | check glyph on selected chips; clear-all | in `docs/ssot/spec/design/components/selectable-chip-grid.md` |

---

## Q-1
### Scope of the AI Scenarios
The scenarios are race-day fueling conversations; the 2026-06-17 decision keeps race fueling deterministic and
outside the assistant. **⚖️ Interim (2026-09-03):** scenarios govern mechanics / tone / loop only; a race-week
conversation may *present* the deterministic module's numbers, never generate fueling advice
(`spec/agent/guardrails.md` H10; day guidance's "Race day" row carries no carb number).

## Q-2
### The structured wizard door
**⚖️ Interim:** no 6-step wizard in v1; the wizard's virtues land inside chat (intro card, plan bar progress).
Revisit after Phases 1–4 have user feedback.

## Q-3
### Artifact depth
**⚖️ Interim:** in-app only — the shopping list, the OS share sheet (plain text), local notifications for the
check-in / debrief. No calendar, email or PDF integrations.

## Q-4
### Macros by default
**Interim (barely a judgment call):** ON by default, framed as minimums tied to the daily target; `show_macros`
stays as the opt-out. Xuan, 2026-05-20: "runners want to see numbers."

## Q-5
### Proactive cadence and channel
**⚖️ Interim:** two touchpoints per plan cycle — the prep-day check-in and the end-of-week debrief — delivered as
the opener of the next app open (`spec/planning/opener-selection.md`); local notifications exist, ship dark (OFF).

## Q-6
### Tone
**⚖️ Interim:** moment-dependent registers (`spec/agent/voice.md`): terse while picking, up to four sentences
when presenting, uncapped when explaining, one exclamation mark at milestones; the emoji ban stays. Each
register is one block Xuan can strike.

## Q-7
### First-run intro
**⚖️ Interim (revised 2026-09-03 evening):** originally "yes — a one-time dismissible intro card with three
example chips; never a gate" (2026-09-03 daytime). Built the same day, then **removed** that evening once the
question-first opener (Q-8) took over the "prove what Vana knows" job the card's first line duplicated. Ruling
request: [`intake/2026-09-03-q7-intro-card-reversal.md`](intake/2026-09-03-q7-intro-card-reversal.md).
DEVIATIONS: [D-021](DEVIATIONS.md#d-021--q-7-intro-card-built-then-removed-the-same-evening).

## Q-8
### Opener shape: question-first vs. frame + three dinners
The opener now writes 2–3 context sentences then asks ONE question (`askChoice`: "What sounds good for dinners
this week?") before proposing any meal — reversing the 2026-08-31 decision that the opener present a frame plus
three concrete dinners immediately. **⚖️ Interim (Lee, 2026-09-03 evening):** question-first stands, citing
Xuan's own SCEN-U source ("Let's plan the week — starting with dinner. What sounds good?"); `draftWeek`
("Draft my whole week" chip, Phase 2) is the zero-question door that still satisfies spec §2.2's "confident
proposal first," just not as the opener's own default. This is the newest and least-settled call in this
register — see [`intake/2026-09-03-opener-question-first-reversal.md`](intake/2026-09-03-opener-question-first-reversal.md)
and [D-020](DEVIATIONS.md#d-020--opener-reversal-question-first-supersedes-the-08-31-frame--three-dinners-decision).
