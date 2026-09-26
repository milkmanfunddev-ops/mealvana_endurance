type: ruling-request
driver: usability/functional
area: onboarding insight engine — app `lib/features/onboarding/application/training_insight_service.dart`, `plan_preview_service.dart`, `domain/training_insights.dart`; calc SSOT (NEAT/TDEE inputs); a new AI narration surface
reporter: Claude (with Xuan)
found: 2026-09-13

# Onboarding Insight Engine v2 — design spec + ratification asks

> ## ⚠ AMENDMENT 2026-09-14 — the Garmin-history premise is infeasible; ASK A + ASK C do not apply to onboarding
>
> Live probing on 2026-09-14 (dev, Xuan's account + a sim walk) showed the core
> premise of this spec — folding **Garmin completed history** into the digest *during
> onboarding* — cannot work in the current architecture. Two independent, verified
> blockers:
>
> 1. **The Garmin token isn't on the server during onboarding.** Onboarding's Garmin
>    connect writes the OAuth token to the app's **local Drift DB only** (verified: sim
>    local DB held the token under anon user `c2c7e005`; no server `integrations` row
>    existed for that user until "continue without signing in" uploaded it post-account).
>    `garmin-backfill` runs **server-side** and reads the token there — so backfill, and
>    therefore any Garmin history, **cannot run until after registration.** The reveal
>    even renders it: *"connected your Garmin Connect account, but found no scheduled
>    sessions to read yet."*
> 2. **Backfill delivery is ~an hour, not seconds.** A controlled post-registration probe
>    (Sync Now triggers at 17:52 / 17:56 / 17:59 UTC) saw wellness data land **~55 min
>    later** (18:53–18:54), and the requested `activities` / `body_composition` /
>    `user_metrics` produced **nothing** within ~1.5 h. Garmin's push-only backfill queue
>    is far outside any onboarding-usable window (Xuan's own bar: ">1 minute and it's not
>    worth it").
>
> **Consequence for the asks:**
> - **ASK A (4-week window + NEAT/normalization over Garmin history): MOOT for the
>   pre-registration digest** — there is no Garmin history at onboarding to window. The
>   windowing/normalization work is only meaningful **post-registration**, where history
>   accumulates on its own (organic wellness ≈ 160 pushes/day; activities as the watch
>   syncs). It is not a change to make to the *onboarding* digest.
> - **ASK C (async-backfill wait / re-digest during onboarding): WITHDRAWN** — you cannot
>   wait, mid-onboarding, for a backfill that structurally cannot run pre-registration and
>   takes ~an hour when it does.
> - **ASK B (AI narration): unchanged in principle**, but it can only narrate the data
>   that actually exists at the moment it runs (see repoint).
>
> **Repoint — where the insight should live:** the onboarding moment should use only the
> **synchronous** signals available at connect — **body composition** (fetched inline
> during the Garmin OAuth) and the **forward-looking FS/TP/Runna/VDOT planned calendars**
> (synchronous pulls). Garmin **training-history** enrichment relocates to the **first
> session after registration / next app open**, when the backfill has landed. So the
> per-sport-matrix / 28-day-window digest changes below are **retargeted to a
> post-registration context**, not the onboarding digest. Absent the token-sync +
> async-delivery work (a separate, larger change — flagged, not scoped here), "edit the
> onboarding digest algorithm to fold in Garmin history" no longer makes sense.
>
> Everything below is preserved as the original 2026-09-13 record; read it through this
> amendment. Evidence trail: this session's Garmin-latency probe + the local-only-token
> finding; capture-gap specifics live in `2026-09-14-real-payload-test-corpus.md`.

## Why this exists
The onboarding insight engine digests a user's imported training (Garmin
completed history and/or TP/FS/Runna/VDOT planned calendars) and uses it to
personalize the first plan. Today it is a blunt, deterministic tally with no
per-sport breakdown, no windowing/priority, a 90-day-back / 366-day-forward
sweep, and no generative message. This spec proposes a richer, windowed,
per-sport digest plus an AI narration layer, keeping a hard line between
**numbers** (deterministic, ratifiable) and **narration** (generative).

Motivating context: with Garmin "Historical Data" off (its default), the
digest is empty and the plan is generic — so the value of any richer engine
is gated on the primer (app a6f20390) actually getting data in.

---

## Current behavior (verified 2026-09-13, for the baseline)
`TrainingInsightService.digest(activities)`:
- Reads ONE undifferentiated window (now−90d … now+366d); does not
  distinguish forward (planned) from backward (completed).
- Computes: total minutes → `weeklyDurationHours` (normalized to 7 days),
  `minutesByWeekday` (ALL sports combined), longest run, longest ride,
  heavy/light weekday pattern, training-day count.
- Gate `isReliable` = window ≥ 7 days AND (≥3 sessions OR one long session
  [run ≥90 min / ride ≥120 min]).
- `weeklyDurationHours` feeds `DailyBaselineCalculator.calculateNeat` →
  NEAT → TDEE → **calorie baseline** (RATIFIED calc path).
- **No AI.** Personalization is template interpolation (InsightSession
  descriptor, e.g. "your 15-mile long run").
- No per-sport-per-weekday matrix; no 4-week cap; no explicit "no pattern"
  output.

---

## Proposed shape (v2)

### 1. Window selection — target 4 weeks (28 days), forward-first
Assemble the analysis window to cover **up to 28 days**, preferring
forward-looking plan data, then filling with recent history:
1. If forward planned sessions exist (TP/FS/Runna/VDOT calendars), take them
   from today forward, up to 28 days.
2. If that yields < 28 days of coverage, fill **backward** with Garmin (and
   any completed) history, most-recent-first, until reaching 28 days OR the
   history runs out — whichever first. Backward fill is capped so stale data
   (>28 days from today) never enters.
3. Result is one of: purely-forward, mixed (partial forward + partial
   backward), or purely-backward.
4. If the assembled window is < 28 days, use what exists (do not pad).

RATIFICATION ASK A (calc SSOT): this changes the window and therefore
`weeklyDurationHours` → NEAT → calories. The 28-day cap and forward/backward
assembly must be ratified, and the NEAT vectors regenerated. Recommendation:
28 days because recent load is more representative than a 90-day sweep and
the cap prevents an old block of heavy training from inflating today's
targets. Open sub-question: should forward planned volume and backward
completed volume be weighted equally when both are present, or should
forward (intent) win where they overlap a weekday? (Recommend: equal minutes,
no double-count of the same calendar day.)

### 2. Structured digest — per-sport × per-weekday
Add a matrix: minutes per weekday (Mon..Sun) **broken down by sport**
(run / bike / swim / other-endurance). Derived, additive fields:
- `minutesByWeekdayBySport[weekday][sport]` and per-weekday totals.
- Per-sport weekly totals and the dominant sport per heavy day.
- `heavyWeekdays` / `lightWeekdays` retained (now derivable from the matrix).
- `hasPattern` (bool): true only when the window covers
  `minWeekdaysForPattern` (currently 4) distinct weekdays AND the
  heavy/light split is non-degenerate; false otherwise.

This matrix is ADDITIVE — it does not change any existing ratified number;
it is new intelligence for the narration and (optionally) the plan's
day-shape. No ratification needed for the matrix itself, only for anything
that feeds it back into calories.

### 3. Reliability gate — unchanged in spirit
Keep `isReliable` (≥7-day span AND ≥3 sessions OR a long session). Note the
window can now be as short as the available data; `isReliable=false` still
routes to the generic (non-personalized) preview.

---

## Numbers vs narration — the architecture

**Numbers are deterministic and computed in Dart.** The digest (window
assembly, per-sport-per-weekday matrix, weekly volume, pattern flags) is
pure code, traceable, and unit-tested. An AI model MUST NOT compute or
restate these numbers, and MUST NOT do the tallying via tool-calling —
hallucinated arithmetic is the failure mode, and it would break number
traceability.

**Narration is generative.** A new AI layer receives the *already-computed*
structured digest and produces the personalized insight **message** only.

### AI narration layer — contract
- INPUT: the structured digest (window provenance [forward/mixed/backward,
  span, session count], per-sport-per-weekday matrix, weekly volume, longest
  sessions, heavy/light days, `hasPattern`).
- OUTPUT: one short personalized message grounded strictly in the digest
  (e.g. "You train hardest on Saturdays with a long run, and Wednesdays are
  your bike day — I've built your carb load around that.").
- GUARDRAILS: the model may reference only numbers present in the digest; it
  may not invent sessions, paces, or targets; a validation pass rejects any
  numeric claim not in the digest and falls back to the template.
- WHERE IT RUNS: an edge function (server-side; keeps keys off-device and
  lets us swap models). Onboarding calls it with the digest; a timeout/error
  falls back to the deterministic template.

### Fallback ladder (deterministic, always available)
1. AI message (when reliable digest + model available).
2. Template message from the digest (today's descriptor style) when the
   model is unavailable/rejected.
3. `hasPattern == false` → an explicit honest line: "I don't see a clear
   weekly pattern yet — your plan starts from your totals and will sharpen
   as you log." (COPY-REGISTER ASK B: ratify this no-pattern copy.)
4. Empty/`isReliable=false` → today's generic preview (no insight line).

RATIFICATION ASK B (design/copy): the AI narration is a new copy surface.
Ratify the register (tone, that it never states a number absent from the
digest), the no-pattern line, and the fallback ladder. The AI message is
generative so it can't be pinned pixel-for-pixel; pin the guardrail
behavior (grounding, fallback) as assertable rows instead.

---

## The async-backfill timing risk (must be handled)
Garmin backfill is asynchronous (202 Accepted; data pushed later). The
onboarding digest runs when the plan-preview builds. If backfilled history
hasn't landed yet, the digest is empty even for a user who granted
Historical Data. v2 must define the wait/re-digest behavior: e.g. the
preview shows a brief "reading your training…" state and re-digests when the
import lands (bounded by a timeout, then falls to generic). RULING ASK C:
confirm the acceptable wait and the re-digest trigger.

---

## What each ask gates (app-side)
- Ask A (window/normalization) → gates the v2 digest + NEAT vector
  regeneration; blocks implementation of the window change.
- Ask B (AI narration copy + guardrails) → gates the AI layer; the
  deterministic digest + template fallback can ship without it.
- Ask C (async-backfill wait) → gates a Garmin-only user reliably getting a
  personalized (not generic) plan.

## Suggested spec homes
- Numeric/window/matrix: a new `spec/domain/training-insights.md` (or under
  daily-macros, since it feeds NEAT) with the window algorithm + the digest
  contract as assertable rows; NEAT vectors under `vectors/`.
- AI narration + no-pattern copy + fallback ladder: `spec/design/` surface
  (copy register + guardrail rows); the message is generative so no pixel
  rendering.

## Recommendation
Split the build: (1) ship the deterministic v2 digest (per-sport matrix,
28-day forward-first window, `hasPattern`, template narration) once Ask A is
ratified; (2) add the AI narration layer behind Ask B once the copy register
is ratified. Keep numbers in code throughout.
