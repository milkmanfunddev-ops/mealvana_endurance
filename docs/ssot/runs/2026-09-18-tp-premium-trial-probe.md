# Probe — TP premium trial: planned IF/TSS ARE on the wire; Structure isn't, for anyone

**Run 2026-09-18 (evening). Two-part live probe of a fresh TP PREMIUM TRIAL account
(athlete `6635555`, 14-day trial, created by Xuan; specimens built by Claude in Chrome on
Xuan's instruction; Xuan ran `scripts/tp-payload-probe.sh` twice, 20:44Z and ~21:05Z,
token custody per the script). Completes C2, C7, C8; re-tests C1 under premium.**

## The four specimens (built to isolate one variable each)
| Specimen | Id | Design | Wire result (list AND by-id) |
|---|---|---|---|
| premium structured run | `3959342191` | replica of Lee's 2026-09-17 run (3 km warm-up + 4×1 km threshold-pace ramp) | `IFPlanned` **0.85** · `TssPlanned` **67.7** |
| premium duration FTP bike | `3959343759` | replica of Lee's bike — TP UI derived 0:32:00/21/0.63, DIGIT-IDENTICAL to Lee's | `IFPlanned` **0.63** · `TssPlanned` **21.1** |
| premium manual TSS run | `3959345736` | NO structure; auto-calc OFF; hand-typed 1:00:00 / TSS 55 / IF 0.80 | `IFPlanned` **0.8** · `TssPlanned` **55.0** — stored values delivered byte-exact |
| premium future structured run | `3959345039` | Sep 25 (a day basic accounts cannot plan), builder defaults | `IFPlanned` **0.98** · `TssPlanned` **123.6** |

Also populated on a real athlete: `4297587` (21 training-plan workouts in the window,
synced 20:24Z), every one carrying decimal `IFPlanned`/`TssPlanned` — 48-key objects with
`Description` + `PreActivityComment`. **Not a trial-account quirk.**

## The exposure matrix (all owner-token, all `/v2/workouts` list or by-id)
| Athlete | Account state | Planned IF/TSS on wire |
|---|---|---|
| `2687398` (Lee) | basic | **null** (2026-09-17 list + 2026-09-18 19:57Z by-id, owner token — TP UI shows 0.85/42) |
| `6635555` (trial) | premium trial, `IsPremium: false` on the wire | **populated** (20:44Z + ~21:05Z) |
| `4297587` | training-plan athlete | **populated** (20:44Z) |
| `1167912` | coached | planned null on window seen (possibly plain workouts); completed `IF`/`TssActual` populated (2026-09-17) |

## What this establishes
1. **C2 ANSWERED — Q-INT26 §6.2 is achievable.** `/v2/workouts` DOES expose planned
   IF/TSS, in `TssPlanned` casing, decimal-valued (UI shows rounded 68; wire carries 67.7).
   The 2026-09-17 claim "TP … does not expose them to our OAuth app through /v2/workouts"
   was true of Lee's basic account only; the same-day correction "whether the athlete is
   basic or premium is not what decides it; the API surface is" is **FALSIFIED** — account
   state does decide it (erratum for `runs/2026-09-17-tp-structure-shape-probe.md` +
   the capture erratum's provider-capability paragraph; both qa-33's branch, flagged to them).
2. **The casing bug is now live data loss, not a dormant defect.** Athlete `4297587`'s 21
   populated workouts synced to prod TODAY and the parser reads `TSSPlanned`, so every one
   stores null. "Fix it because it is wrong, not because it changes today's numbers" no
   longer holds — it changes today's numbers. DI-17 (IF/TSS → F22 ladder) is unblocked by
   the casing fix alone. Ops bug priority flagged to ops-87.
3. **`IsPremium` is NOT a usable predicate.** The trial account is premium-FEATURED
   (future planning unlocked, values on the wire) yet reads `IsPremium: false`, same as
   Lee. The capture contract must not gate on the flag; capture-what-arrives is the only
   sound posture, with basic-athlete nulls staying legitimate nulls (DI-13).
4. **C1 outcome is TIER-INDEPENDENT: `Structure` is unreachable under our OAuth grant,
   full stop.** Premium by-id: `Structure` ABSENT on all four (including both structured
   builds); `wod/file?format=json|mrc` → 401 and `plan/{id}` → 405 with the SAME premium
   token that had just 200'd on list and by-id. Identical refusals to Lee's basic token.
   The Q-INT29 disposition reverts from "maybe a tier question" to a pure scope/grant
   question — the residuals (grantable file-export scope; other method on plan) are
   provider-relations, unchanged.
5. **C7 ANSWERED — `/v1/athlete/profile/zones` works under the existing grant** (200 on
   both athletes). Shape: `{HeartRate,Power,Speed}Zones` → per-sport substructures →
   `{Threshold, WorkoutType, Zones[{Label,Minimum,Maximum}]}`. **Substructure varies per
   athlete** (trial: Default only; Lee: HR Default+Bike+Run, Speed Default+Run+Swim; zone
   counts 5–7 vary) — a corpus stratum fact. This is the conversion input Q-INT29 sub-q 1
   / Q-INT19 / Q-INT28 needed.
6. **C8 shape captured, with a type surprise:** `/v2/events/next` returned a full event
   object on Lee (`EventDate, EventType, Goals[3]{GoalType,Unit,Value}, WorkoutIds…`) and
   a BARE STRING on the trial account — same endpoint, different top-level JSON TYPE by
   state. Producer-shape vectors for events must cover both.
7. **`metrics:read` is scope-refused** (401 on both athletes, same-second-valid tokens):
   TP `/v2/metrics` stays NOT-FETCHABLE under the current grant — now evidence, not doc-read.
8. **Access-token lifetime bracketed:** valid at 20 min (trial, second run), expired by
   ~40 min (`4297587`, synced 20:24, dead ~21:05). Consistent with ~30 min. Probe windows
   must stay inside that.
9. Key-set spread now **46/47/48** on one endpoint (Description, PreActivityComment
   drop in and out per instance) — reinforces the three-state alphabet + optional-collapse
   rule (corpus intake Addendum 2 §1).

## Corrections these facts require elsewhere (not self-applied; owners flagged)
- `runs/2026-09-17-tp-structure-shape-probe.md` — the "basic or premium is not what
  decides it" line (qa-33's branch; message sent).
- `intake/2026-09-17-tp-capture-columns-null-on-live-sync.md` — "strongest form of the
  provider-capability claim" paragraph narrows to basic accounts; the fix queue's
  "correct-but-inert" framing is dead (qa-33's branch; message sent).
- Ops casing-bug report — priority: live loss on prod (ops-87's file; message sent).
- `intake/2026-09-18-q-int29-tp-disposition.md` — premium outcome recorded: refusals
  tier-independent, option A wording stands (this branch, done in this commit).

## What is still unknown
- A payload where TP's own UI derives planned load on a BASIC account and any wire field
  carries it: none exists in our evidence; basic-athlete planned loads appear simply not
  exposed. (No further probe planned; capture-what-arrives covers it.)
- Whether a COACH-set planned TSS behaves like our manual one (coached write path still
  unobserved — C2's residue, minor).
- `TssCalculationMethod`'s value range (key present everywhere, value not audited).
- FS structured detail (C5) — untouched by all of this.

---

## Final pass — 22:05Z, post-reconnect: the same-hour control and the events matrix

Xuan refreshed both connections (Lee's via disconnect→reconnect, which INSERTED yet another
row for athlete `2687398` while the older rows stay `active=true`/`success` — a fourth dated
confirmation for the ops duplicate-rows report). One probe run, both tokens fresh
(22:05:47 / 22:02:02), window 2026-09-17..2026-10-04.

### The same-hour basic-vs-premium control (the strongest form this evidence can take)
| | Lee `2687398` (basic, fresh token 22:05Z) | Trial `6635555` (premium trial, 22:02Z) |
|---|---|---|
| planned load on `/v2/workouts` | **null** on all three workouts (both structured specimens + Strength) | **populated** on all four (0.85/67.7 · 0.63/21.1 · 0.8/55.0 · 0.98/123.6) |

Same endpoint, same probe, minutes apart. **Per-ACCOUNT exposure is now same-hour
verified.** Still open (specimen not created this pass): the hand-typed planned-TSS
workout on Lee's basic calendar — the named test for whether STORED values leak through
for basic accounts. Goes to the brief as the one open experiment, unchanged.

### The events endpoints, fully characterized (all four cells + the earlier no-event state)
| Endpoint | Athlete HAS event | Athlete has NO event |
|---|---|---|
| `/v2/events/next` | **object** (Lee, both runs; trial 22:02 after "QA probe event" created) | **bare string** (trial, 20:44, pre-event) |
| `/v2/events/{date}` | **list, 1 item** (both athletes) | **list, 0 items** (both athletes) |

So: the type-varies-by-state hazard is confined to `/v2/events/next` — whose only reader
(`getNextEvent`, `as Map`) is DEAD CODE (qa-33's `intake/2026-09-18-tp-events-response-type-assumptions.md`,
main `fdeec59`). The LIVE path (`getEventsForDate`, `as List`) is type-safe on every
observation: `/events/{date}` returned a list in all four cells. The silent-no-import risk
is therefore latent-in-dead-code today, and the producer-shape vector for `/events/next`
must carry BOTH the object and the bare-string variant. `Goals` cardinality varies 0–3
per event; the event object shape is otherwise identical across athletes.

### Replications (third/fourth distinct tokens)
Zones and profile sweeps byte-consistent with 20:44 (per-athlete zone substructure
variance confirmed stable); `/v2/metrics` **401 scope-refused on both fresh tokens again** —
the grant limitation is now observed on four tokens across two hours.

---

## The last open experiment — CLOSED (22:2xZ): stored values are withheld for basic too

Xuan hand-built the mirror specimen on LEE's basic calendar ('QA zone probe — basic manual
TSS run', id `3959432682`, auto-calc off, typed 1:00:00 / TSS 55 / IF 0.80 — the identical
flow that produced the trial's `3959345736`). The wire, same still-valid token:

| | basic (Lee) | premium trial |
|---|---|---|
| typed 1:00:00 / TSS 55 / IF 0.80 | `TotalTimePlanned: 1.0` ✓ · `TssPlanned` **null** · `IFPlanned` **null** | `TotalTimePlanned: 1.0` ✓ · `TssPlanned` **55.0** · `IFPlanned` **0.8** |

**Exposure is per-ACCOUNT, full stop** — not per-workout-source, not derived-vs-stored.
The typed duration arriving proves the workout saved; the load fields are gone for the
basic account even when the athlete typed them.

**Mechanism caveat (DI-13c discipline applied to our own experiment):** from the wire
alone, "TP withholds at the API surface" and "TP silently drops the typed TSS/IF at SAVE
time for basic accounts" are indistinguishable. One glance at Lee's calendar card settles
it: if the card shows "55 TSS", it saved and the API withholds; if the card shows no TSS,
the save itself is tier-gated. **Either way the capture consequence is identical: a basic
account's connection delivers no planned load, ever** — the capture contract wording is
per-account regardless; only the mechanism footnote differs. [Card check: PENDING Xuan's
one glance — recorded whichever way it lands.]

With this, every named experiment in the corpus C-list's TP wing is answered or has a
recorded negative. The events matrix, the same-hour control, and this stored-value cell
give the ruling desk a brief with zero generalisations standing in for observations.
