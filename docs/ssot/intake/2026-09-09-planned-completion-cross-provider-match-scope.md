> **RESOLVED 2026-09-10 (ruling desk 2026-09-10): planned completion is cross-provider by design, guarded per Q-INT21; 'other' refusal kept, revisit after the guard lands**
type: ruling-request
bundle:

## Why this matters
A pilot coach reports the same session appearing twice on her day. The ratified match key says
"same platform", but planned-completion is **cross-provider by construction** — Final Surge writes
the plan, Garmin completes it — so the ruled key cannot govern it as written. Q-INT4 asks only
which *window* applies; nobody has ruled what *scope* identifies the planned row when the plan and
the completion come from different providers. Until that is settled the matcher is running on an
app-side convention, and every miss ships the athlete a duplicate.

## The question
When a Garmin completion arrives and the athlete's planned row for that day came from a **different**
provider (Final Surge / TrainingPeaks / Runna / manual), what scope identifies the planned row it
completes?

Two sub-questions, both currently unruled:
1. **Provider scope.** The ruled key's clause (2) is "same platform AND same sport AND ±15 min".
   Planned-completion ignores provider entirely. Is provider-agnostic matching the intent for
   completion (and clause (2) therefore tombstone/dedup-only), or should completion carry its own
   stated scope?
2. **Sport vocabulary.** Matching is on **exact** `activity_type` equality across two independent
   transformer vocabularies. Where a provider cannot express our sport, the row is typed `other`,
   and the matcher **refuses `other` outright** — so such a plan can never be completed, and a
   duplicate is guaranteed rather than merely likely.

## What is already ruled / registered
- `spec/daily-macros/platform-resolution.md:215-219` — the match key, RULED 2026-08-14
  (platform id, else same platform + same sport + ±15 min), scoped to tombstone matching and
  re-sync dedup.
- `spec/integrations/lifecycle.md` L-3 — records the day-wide planned-completion divergence.
- `spec/integrations/OPEN-QUESTIONS.md` Q-INT4 — the **window** question (±15 min vs day-wide),
  OPEN. Home of `intake/2026-08-18-skipped-row-sync-match-window.md` (unstamped).
- Q-INT11 — `scheduled_date_time` semantics per provider, OPEN. Interacts: it decides which local
  day a session buckets into, and planned-completion's window is expressed in local-day bounds.

**This file is the provider-scope + sport-vocabulary facet, which Q-INT4 does not cover.** It
should be ruled together with Q-INT4, not separately.

## Observed behaviour (not ruled)
`app/supabase/functions/_shared/garmin/activity_completion.ts`, `findMatchingPlannedActivity`:
- keys on `user_id` + **exact** `activity_type` + `status IN ('planned','draft')` +
  `scheduled_date_time` within the same naive local day + `deleted_at IS NULL`, earliest first;
- does **not** filter on provider;
- returns null immediately when the mapped sport is falsy or `"other"`;
- **distance and duration play no part** — a completion that looks nothing like the plan still
  matches, and a plan that matches on sport+day always wins regardless of how different it is.

Interacting app-side fact: `app/lib/features/integrations/application/final_surge_transformer.dart:81`
declares `supportedTypes = ['Run','Walk','Bike','Swim']`; everything else maps to
`ActivityType.other`. Combined with the `other` refusal above, any Final Surge workout typed outside
those four can never be completed by a Garmin upload.

## Options
1. **Rule completion as provider-agnostic, sport+day scoped** (ratify today's behaviour). Simple,
   and it is what plan-then-complete means. Cost: two same-sport sessions on one day collapse into
   one — the second upload completes nothing and imports as new, or worse completes the wrong plan.
2. **Provider-agnostic but time-bounded** (day-wide replaced by a wider-than-±15 min window, e.g.
   ±4 h, or nearest-start-wins among same-sport planned rows). Keeps the "5:30 PM plan run at 3 PM"
   case working while letting a genuine second session survive. Needs the window named.
3. **Provider-agnostic + sport-class instead of exact equality.** Match on a normalised sport class
   so `other`-typed and vocabulary-mismatched rows still resolve. Requires a ruled sport-class map
   shared by every transformer — the largest change, and the only one that fixes the `other` hole.

## Recommendation
None strong on the window (that is Q-INT4's call). On scope: the `other` refusal is the part worth
ruling regardless of which window wins — it converts a mapping gap into a guaranteed duplicate, and
no option above works while it stands.

## Suggested spec home
`spec/integrations/lifecycle.md` L-3, folded into the Q-INT4 ruling, with the resulting key restated
once in `spec/daily-macros/platform-resolution.md` so the two cannot drift.

## Gates
The scope/window change in `findMatchingPlannedActivity` + Deno tests; possibly a shared sport-class
map across the provider transformers if option 3 wins. No vector regeneration expected — this is
resolution, not engine math.

## Evidence
- Coach Claudia McCoy (pilot), 2026-09-08 texts: same workout showing twice. She is on **Final
  Surge + Garmin**, not TrainingPeaks. Her screenshots show only one ride, so the duplicate itself
  is **not yet reproduced** and no Supabase read has been done — the mechanism above is code-derived,
  not observed.
- Correspondence + full state: `ops/emails/2026-09-08-claudia-progress-highlights.md`.
