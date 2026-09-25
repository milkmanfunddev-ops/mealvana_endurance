# Probe result — TP structure hunt (C1): `Structure` is unreachable under our OAuth grant

**Run 2026-09-18. Xuan ran `scripts/tp-payload-probe.sh 2026-09-17 2026-09-19 3957938109
3957939645` immediately after syncing Lee's TP connection (token custody per the script's
security model — only the field audit entered the session).** Executes the structure hunt
written into the probe script on `qa/data-integrations-v1.1` ("NOT yet run" in
`runs/2026-09-17-tp-structure-shape-probe.md`) and closes the erratum's open `if_planned`
question (`intake/2026-09-17-tp-capture-columns-null-on-live-sync.md` §"Still open").
This file records evidence for the corpus bundle; every disposition it implies is Xuan's ruling.

## What the wire said
- Only row [0] (athlete `2687398`, Lee, refreshed 19:57Z) authenticated: list HTTP 200
  (3 workouts in range), by-id HTTP 200 on both probe ids. **Every other row — including
  athlete `1167912`, valid yesterday — returned 401** on prod and sandbox hosts.
  Short-lived tokens reconfirmed; `last_sync_status=success` still stands on rows whose
  token is dead. (The probe's SELECT is `limit=10`; the count-only audit's 11 active rows
  earlier today is not contradicted. Ops owns the duplicate-rows bug.)
- **By-id, with the OWNING athlete's token**, structured run `3957938109` and bike
  `3957939645`: `Structure` **ABSENT**. `IFPlanned`/`IF`/`TssPlanned`/`TssActual` present
  as keys, null in value — on the same workouts whose TP web UI shows IF 0.85/TSS 42 and
  0.63/21.
- **Structure hunt, same token, seconds after those 200s:**
  - `GET /v2/workouts/wod/file/{id}/?format=json` → **401 Unauthorized**
  - `GET /v2/workouts/wod/file/{id}/?format=mrc` → **401 Unauthorized**
  - `GET /v2/workouts/plan/{id}` → **405 Method Not Allowed**

## The C1 verdict
`Structure` is unreachable by our OAuth app on every route tried:
1. range endpoint — absent (2026-09-17);
2. by-id with a DIFFERENT athlete's token — 403, scoping (2026-09-17);
3. **by-id with the owning athlete's token — present-shaped payload, `Structure` absent
   (today; kills the wrong-athlete residual);**
4. file export — **401 = scope refusal, not expiry**: the same token returned 200 on
   `/v2/workouts` in the same run;
5. plan endpoint — 405 to GET.

**What this does NOT establish:** 401 means "not for this grant", not "does not exist" —
a file-export scope may be grantable by TP (provider-relations question, not engineering);
and 405 means our GET was the wrong method, not that `plan/{id}` is absent. Neither
residual is testable from our side today.

**Q-INT29 consequence** (per the 2026-09-17 run's own conditional): **no-op for TP** —
zones stay null by provider capability; sub-questions 1–3 stop being blockers; the
fabricating fallbacks (`_classifyIntensity` ≤1.5⇒%FTP, unknown-length⇒seconds) have no
legitimate TP input to misread and should be removed; the structure parser stays dormant
for Final Surge pending C5 (`json_fs_v1` detail — never seen). Disposition goes to the
ruling desk, not this file.

## `if_planned` null on the probe rows — CLOSED
Not athlete scoping (the 403 explanation is eliminated: the owner's token got 200 and
null), not casing (`IFPlanned` is correctly cased on both sides). TP holds the
builder-derived planned IF/TSS and does not expose them through `/v2/workouts` for this
(basic) account. **C2 — a coached/premium athlete's planned workout — is now the only
open route to a populated planned-load field**, and the casing fix's acceptance test
still has no live input (fix it because it is wrong, not because today's numbers change).

## New shape facts (C4 material — field audit, not payloads; no de-id gate applies)
| Fact | Evidence |
|---|---|
| First observed **TP Strength** variant | `'Strength Test - Mealvana'` id `3957368736`, `WorkoutType 'Strength'`, 47 keys, `TotalTimePlanned 0.75` |
| **Optional-key dropout** — key sets vary per instance | Strength carries `Description` (47 keys); run and bike LACK the key entirely (46 keys). TP omits at least this field rather than sending null |
| `TotalTimePlanned` unit is **decimal hours** | `0.53527…` = 32:07 (matches TP UI); `0.5333…` = 32:00; `0.75` = 45 min |
| `DistancePlanned` unit is **meters** | `7000.0` on the run = the builder's 3 km + 4×1 km |
| Load keys present-and-null | all three planned workouts, range AND by-id endpoints |

## Consequences for the corpus design (folded into the design correction, not decided here)
1. **Fingerprint-by-key-set is not stable across instances of one conceptual shape** —
   the `Description` dropout proves optional-key absence is a per-instance fact. The
   fingerprint function must handle presence-varying keys deliberately (normalize a
   known-optional set, or accept that convergence enumerates presence-variants). This is
   exactly the granularity knob the 2026-09-14 intake called "the sweet spot" from a
   ~15-key sample; the real object says the knob needs a rule, not a vibe.
2. Three planned TP variants (run / bike / strength) are now observed as field audits.
   Audits are key sets, not payloads — safe to hold pre-ruling; EXEMPLARS still require
   the Q1/Q3 de-identification ruling before anything lands in
   `vectors/integrations/samples/`.
