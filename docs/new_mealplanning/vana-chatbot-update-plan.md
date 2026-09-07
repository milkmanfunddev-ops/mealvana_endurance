# Vana chatbot update plan — closing the gap to Xuan's vision

**Written 2026-09-02.** Scope: the Vana chat surface only (`vana_chat_screen` + the
`vana-chat`/`vana-action` edge functions and `_shared/vana/`). Companion docs:
`ssot/spec/intent/vana-mealplanning-chatbot.md` (what Xuan wants, sourced),
`ssot/DEVIATIONS.md` (the gap register) and `figma/mealbuddy-figma.md` + `figma/*.png`
(Alex's "AI Assistant module" concept — reconciled in §4). This doc resolves the spec's Q-register with
**best-judgment interpretations** so we can build now; each interpretation is marked
⚖️ so Xuan can veto any of them cheaply later.

---

## 1. The vision, in one paragraph

Vana should feel like a **trusted dietitian who already did the homework and stays in
the relationship**. She opens by proving what she knows (race in 12 days, yesterday's
century, the week's anchor session), proposes a complete week confidently instead of
interviewing the athlete, asks exactly one question at a time with real trade-offs,
explains the *why* behind every recommendation, celebrates wins warmly, and — the part
we're missing most — **comes back**: a check-in before the shopping/prep day, a
debrief after the week, and the learnings folded into next week's proposal. The plan
stays a batch-cook meal collection ending in a shopping list; race fueling stays with
the deterministic engine.

## 2. Interpretive calls (⚖️ = my judgment where Xuan hasn't ruled)

| Q | Call | Rationale |
|---|---|---|
| Q-1 scope | ⚖️ Scenarios govern **mechanics/tone/loop only**. Domain stays weekly planning + in-the-moment suggestions. A race-week conversation may *present* the deterministic module's numbers, never generate fueling advice. | The 2026-06-17 decision is explicit and safety-motivated; the scenarios never revoked it. |
| Q-2 wizard | ⚖️ **No 6-step wizard in v1.** Keep the single chat door, but absorb the wizard's virtues: a contextual "what would you like to do" opener card for general-kind, and visible plan progress (plan bar already does this). | Testing showed users don't start with chat unprompted — the fix is guidance inside chat, not a second surface. Wizard is a later option for the first-ever plan. |
| Q-3 artifacts | ⚖️ v1 = in-app only: shopping list (exists) + **share/export via the OS share sheet** + **local notifications** for check-ins. No calendar/email APIs yet. | 90% of the felt value ("it saved things for me") at 10% of the cost. |
| Q-4 macros | **Numbers on by default**, tied to the daily target and framed as minimums; `show_macros` toggle stays as the opt-out. | Xuan herself conceded this on 5/20 ("runners want to see numbers"). Not really a judgment call anymore. |
| Q-5 cadence | ⚖️ Two touchpoints per plan cycle: **prep-day check-in** and **end-of-week debrief**, delivered as the opener of the next app-open, plus an optional push (OneSignal, off by default) once the opener version proves out. | "Proactive" must not mean "naggy"; opener-on-open is proactive with zero spam risk. |
| Q-6 tone | ⚖️ **Moment-dependent voice** (see §3). Terse while picking; warm and explanatory when presenting/refining/celebrating. Lift the blanket cheerleading ban for milestone moments; keep the emoji ban (Kyle-design iconography carries the visual warmth instead). | Splits the difference between Xuan's scenarios (exclamation-heavy) and the shipped clipped persona; the 2-sentence cap is the real blocker, not emoji. |
| Q-7 intro | ⚖️ Yes — a one-time, dismissible intro card on first Vana open (3 example taps, one line on what Vana knows). | Direct response to Test Theme 1. |

## 3. The persona & prompt rewrite (Phase 1's core artifact)

> **Opener reversal (Lee, 2026-09-03 evening).** The 08-31 "opener = frame + three dinners" decision is
> withdrawn. Xuan's unstructured scenario and her v5 prototype both open with context and a *question*
> ("Let's plan the week — starting with dinner. What sounds good?") and propose meals only after the
> athlete answers. The planning opener is now the dietitian's opening: 2–3 sentences of context (race /
> holiday / notable session / rest week / weather, and a LAST WEEK clause when a debrief exists) then ONE
> `askChoice` question with trade-off chips (Batch-cook staples · Quick weeknights · Something new · Use
> what I have; free text always). Rule 0 (THE INTERVIEW) allows at most one follow-up, then the first
> dinner picker shaped by the answer. The eval's `presenting` check and `lifecycle.ts` assert this shape.
> Also withdrawn the same day: the Phase 5 intro card ("Vana already did the homework") — removed
> from the screen and content; the question-first opener is the first contact now. `MealCard`/picker
> cards: tap = open the recipe detail, the tick = add (previously the whole card added).

Three places make Vana terse today, and all three must move together or nothing
changes on screen:

1. **`persona.ts`** — the "max TWO short sentences" rule in CORE.
2. **`chat.ts` `clampSentences()`** — planning turns are **mechanically clamped to 2
   sentences server-side** in `partsFromSteps()` (and the clamped text is what gets
   persisted). A prompt rewrite alone is invisible while this stands.
   **Decision (Lee, 2026-09-03): remove the mechanical clamp.** Brevity lives in the
   prompt instead (the PICKING register's ≤2 sentences) — which is also what saves
   output tokens, since a server clamp only trims text *after* it was paid for. Keep
   a single generous runaway guard (e.g. clamp at 8 sentences) so a Haiku loop never
   floods the transcript; it should never trigger on a well-behaved turn.
3. **`chat.ts` caps** — `MAX_OUTPUT_TOKENS = 400` and `stepCountIs(6)` for planning;
   the scripted `OPENERS.meal_planning` also demands "exactly two sentences".

### 3.1 The moment-based voice contract

Replace the flat cap with a **moment contract** in CORE (draft below — final wording at
build time, mirrored verbatim to the prototype repo per the "edit here AND there" rule):

```
VOICE — pick the register from the moment:
- PICKING (a meal picker or its chip follow-ups): at most 2 short sentences, then the
  widget. Never restate the athlete context.
- PRESENTING (the opener, a plan summary, a proposal): up to 4 sentences. Reference at
  least one concrete athlete fact (race in N days, yesterday's session, the week's
  anchor workout) — a real one from the context, never a generic line. Every proposed
  meal carries a one-line why tied to the training week.
- EXPLAINING (they ask why, or push toward something risky): no sentence cap. Explain
  both sides plainly, then: "My recommendation: … Want to keep it or revert?"
- MILESTONE (plan confirmed, a strong week at debrief, a race result): congratulate
  specifically — name what they did. One exclamation mark is allowed here. No emoji.
```

Keep unchanged in CORE: minimums framing, never weight/body talk, ED/medical
referrals, never invent meals/numbers, allergies enforced by tools, no narrating tool
calls, US spelling, no emoji anywhere.

### 3.2 Concrete edits, file by file

| File | Edit |
|---|---|
| `persona.ts` CORE | Flat 2-sentence rule → §3.1 moment contract. |
| `persona.ts` PLANNING_PROMPT | Rule 1: why-lines become mandatory and must name a training fact. Rule 4's coverage walk honors the new `coverage_scope` setting (Phase 1.6). Rule 7: after `confirmPlan`, a MILESTONE sentence, then chips. |
| `persona.ts` GENERAL_PROMPT | "≤4 short sentences" stays for answers; EXPLAINING moments exempt. |
| `persona.ts` OPENERS | `meal_planning`: "exactly two sentences" → "2–4 sentences (PRESENTING register)"; add the notable-recent-workout beat (Phase 2.2). |
| `chat.ts` | Remove the 2-sentence clamp from `partsFromSteps()` (per the 09-03 decision above); keep the narration-dropping behavior (general) and one generous runaway guard (~8 sentences). `MAX_OUTPUT_TOKENS` 400 → 700 for planning; revisit `stepCountIs` only if the eval shows starved turns. |
| Prototype repo | Mirror `persona.ts` verbatim (contract-v1). |

Tone changes are cheap for Xuan to veto (Q-6): each register is one block she can strike.

## 4. The MealBuddy gap (Alex's Figma concept)

Source: the Figma file **"AI Assistant module"**
(`fpXDAtEbcgv3cDXB9tE6Yg`, section "Chat V2", 27 screens / 28 frames), captured in
`figma/mealbuddy-figma.md` + `figma/*.png`. It is a **concept file, not a skin**: iOS-only
375×812 frames, a broccoli mascot called MealBuddy, a cream/navy palette, colored-outline
chips, placeholder copy, and a couple of mock errors (duplicate "Day 6", `1800kca`,
"Snap my fringe").

**Design-system guardrail (non-negotiable).** Nothing visual is adopted. Kyle tokens
(`lib/theme/kyle_design/`) stay the only token registry; `VanaAvatar` stays the avatar;
no mascot, no cream/navy, no color-coded chip outlines, no iOS-only chrome (this ships
iOS + Android + Web). Per CLAUDE.md, every **new design-bearing widget below is built once
in `lib/shared/widgets/kyle_design/`** under its spec name, with a
`docs/ssot/spec/design/components/<name>.md` written first and cited in the header
comment; feature folders compose, never redefine. What we take from Alex's file is
**interaction structure and widget inventory**, nothing else. The *visual* target for
every adopted pattern is the Kyle-styled prototype screens in
`design-screens/previews/` — compare side-by-side per the map in §8.

### 4.1 Screen-by-screen verdicts

| MealBuddy (screen) | What we have today | Verdict | Lands in |
|---|---|---|---|
| **S1** Welcome + 8 goal-category buttons (Athletic Performance, Budget, Health Issues, …) | General chats get a 3-chip empty state (`_EmptyState`); planning chats open straight into a dinner picker | **ADAPT** — a one-time intro card with 3–4 *Mealvana* intents, never a mandatory gate in front of the chat | Phase 5 |
| **S2–S4** Interview: training schedule → primary goal → dietary preferences/allergies | All three are already known (`getProfile`, context block: workouts, race, diet, allergies); the persona explicitly forbids asking what context answers | **REJECT** — an anti-feature; asking would undo "prove what you know" (spec §2.1) | — |
| **S5** Meal-prep style (Meal Prep vs Fresh daily) | The batch-cooking fork: `askChoice` once → `setSetting batch_cooking` (PLANNING_PROMPT rule 4) | **MET** | — |
| **S6** "Include breakfast?" | We walk dinner → lunch → breakfast → snack and never ask what the athlete wants covered | **ADOPT** (small) — a coverage-scope fork before leaving dinners | Phase 1 |
| Chip groups of 5–7 options (S2–S4, S9a) | `askChoice` is capped at `min(2).max(3)`; `ChoiceChips` renders a `Wrap` | **ADAPT** — cap goes to **4** (spec §2.3 says 2–4, each with a trade-off line); anything bigger is not a fork, it's a grid → `SelectableChipGrid` (Phase 7) | Phase 1 / 7 |
| **Edit / Delete** links under every past user answer | Nothing. A sent message is final; there is no rewind | **ADOPT** — the single biggest interaction gap in the file | **Phase 6** |
| **S8 / S9a** "Ingredients in your fridge?" → pantry chip grid + trailing `+` for a custom item | Nothing. `diagnoseStaples` is "what you usually eat", not "what is in the house". Shopping items carry a `have` flag — adjacent, not the same | **ADOPT** | **Phase 7** |
| **S9b–S11** Snap-my-fridge: action sheet → camera/crop → photo bubble → detected ingredients | `photo_capture_screen.dart` + the photo-AI surface exist in **meal_logging**, but nothing reaches Vana chat | **ADOPT** — reuse the existing capture + vision plumbing, new part for the result | **Phase 7** |
| Composer `+` attach | None | **ADOPT** | Phase 6 (shell) / 7 (payload) |
| Composer mic / voice input | None | **ADOPT**, low priority — platform speech-to-text into the text field | Phase 6 |
| **S13** Loading: % ring + mascot + "finding the best meals…" bubble; **S20** "gathering coupons…" named status beside a mini avatar | `VanaAvatar(isPulsing)` + one generic thinking line — `_statusLine()` deliberately ignores the tool name until copy exists | **ADAPT** — per-tool status copy beside a mini avatar (the S20 pattern); **no fake percentage** | Phase 1 |
| **S14** Three alternative *whole plans* in a carousel + Regenerate | We build **one** collection incrementally; "Other options" reruns the picker for the same type | **REJECT** the 3-plan carousel — but the underlying "complete proposal in one shot" beat is real Xuan vision (spec §2.2) and lands as the single trusted draft, `draftWeek` | Phase 2 |
| Plan/recipe card **macro pills** (Protein/Carbs/Fat/Fiber/Sugar) | `MealCard.showMacros` renders a plain text facts strip; `MealRef` carries kcal/carbs/protein/fat — **no fiber or sugar** | **ADAPT** — a `MacroPillRow` library component, kcal + P/C/F only, on by default per Q-4 | Phase 1 |
| **S15/S17** Plan-detail modal with collapsible `Day 1…Day 7` rows | `ReviewSheet` (the collection) **plus** a real Plan tab with day cards and slots (`planDay` / `setDaySlot` / `VanaDayPart` / `DayCard`) | **MET differently.** The "Mealvana has no day model" note in `mealbuddy-figma.md` §5 is now **stale** — we have one; what we reject is *generating* a day-slotted plan up front | — |
| **S16** Per-meal `⋮` → Regenerate / Remove | Swap + remove exist, but only from `MealSheet` / `PlanBar` — not from a card in the transcript or the plan list | **ADOPT** — overflow on the card itself (spec §2.4: card-scoped actions live on cards) | Phase 6 |
| **S18** Recipe detail (photo, ingredients, macros) | `meal_detail_screen.dart` + cooking mode with `method_steps`, thumbs, timers | **MET** — we are ahead of the mock | — |
| Recipe **price** ("$57.32") + "gathering coupons…" | No grocery pricing or coupon data source anywhere in the app | **REJECT** for v1 — this is D-7; stays stubbed and spec'd, not built | — |
| **S19–S20** Refinement that cites the weather and the weekend's training | The context block already carries weather, workouts, race, holidays, targets, memories | **MET** — and stronger than the mock | — |
| **S21** Suggestion cards with selection checkboxes | `suggestMeals` returns `multi: true`; `MealPickerCarousel` renders tick state from `pickedIds` | **MET** | — |
| **S22** "Selected Meals" tray pinned above the composer | `PlanBar` — minimizes on every turn, expands to tiles with `×` and servings steppers, Review button | **MET, better** — ours is the real draft plan (server-acked), not a scratch cart | — |
| **S23** Typed natural-language plan request | Free text is accepted at every turn | **MET** | — |
| **S25** "Do you want help planning the meals across the week?" after selection | `planDay` / `setDaySlot` exist; Vana **never offers** them | **ADOPT** — spec §1.4 says it outright: "dailies are an assignment layer on top". Collection first, day assignment as an optional second act | **Phase 8** |
| **S27** "Confirm & Add Plan" | Review sheet → Confirm (remote-ack `confirm_meal_plan`) | **MET** | — |
| Date divider ("Yesterday 12.05.2025") | The transcript has no dividers; resumed conversations run together | **ADOPT** (cheap) | Phase 6 |
| Header chrome; the hamburger / new-conversation / delete controls the Figma comments argue about | Back, avatar, title + subtitle, **New conversation**, **Conversations** list (with delete) | **MET** — the questions in those comments are already answered in code | — |
| Mascot, cream/navy palette, colored chip outlines, native iOS action sheet, iOS-only layout | Kyle tokens, `VanaAvatar`, `MealvanaSnackbar`, responsive shells | **REJECT** | — |

### 4.2 Net new UI

| Component | Home | Notes |
|---|---|---|
| `MacroPillRow` | `lib/shared/widgets/kyle_design/data/` | kcal + carbs/protein/fat pills; used by `MealCard`, `PlanTile`, `ReviewSheet`, `PlanSummary`, plan-bar tiles. Spec first. |
| `SelectableChipGrid` | `lib/shared/widgets/kyle_design/inputs/` | Multi-select wrap + trailing `+` for a custom entry. Serves the pantry grid and any future multi-pick surface. Spec first. |
| Choice "cards" | extend `choice_chips.dart` | When options carry `detail`, chips become full-width two-line rows (label + trade-off). |
| Card overflow menu | extend `MealCard.trailing` / `PlanTile` | Swap / Remove; no new component. |
| Editable user bubble | `vana_bubble.dart` | Edit affordance under the athlete's own turns. |
| Transcript date divider | feature-level in `vana_chat_screen.dart` | Not design-bearing. |
| Status row | feature-level (`vana_message_card.dart`) | Mini `VanaAvatar` + italic per-tool line. |
| Composer `+` / mic | feature-level (`_buildComposer`) | The round send button already exists (`VanaRoundButton`). |

### 4.3 Net new server surface

- `askChoice`: options cap 3 → **4**, each option gaining an optional `detail`
  trade-off line (spec §2.3).
- `draftWeek` tool — deterministic full-week draft (Phase 2.3).
- New `VanaPart` kind **`pantry`** (`{ items: [{name, selected}], allowCustom }`) +
  tool `askPantry`; `suggestMeals` gains `ingredientsOnHand: string[]`.
- Fridge photo: an ingredient-detection call reusing the existing photo-AI path,
  returning a `pantry` part. **Metered like every other AI surface** — never removed
  to save cost.
- Message edit: truncate `vana_messages` after the edited turn, then re-run — an
  explicit endpoint, not a client-side hack (history is server-owned in `runChat`).
- `setSetting`/`getSetting` gain the `coverage_scope` key (k/v settings row — no
  migration).
- Post-confirm day-assignment offer: prompt-level only; `planDay` already exists.

---

## 5. Phases — step by step

> **Status 2026-09-03 (evening): Phases 1–8 BUILT on `mealplanning` (uncommitted), server deployed to DEV, DDL applied to
> DEV by hand.** Per-phase notes are under each heading; the shared verification is `scripts/vana-eval/run.ts`
> (13 canned conversations, all green on their last run), `scripts/vana-eval/lifecycle.ts` (the Phase 3 loop end to end —
> the server half of the Patrol flow in 3.6, green), and `scripts/run-meal-planning-tests.sh all`. Xuan-facing items
> still open: the ⚖️ calls in §2, the two PROPOSED component specs (`macro-pill-row.md`, `selectable-chip-grid.md`),
> and `/design-sync` (Lee-invoked). Prod: the new migration rides the meal-planning cutover bundle
> (`supabase/migrations/cutover/meal_planning/README.md` addendum).

Ordered so each phase ships alone and the highest-leverage gap (tone) lands first.
Items marked **[MB]** come from the MealBuddy gap (§4); spec § citations are to
`ssot/spec/intent/vana-mealplanning-chatbot.md`. Reference screens for every phase: §8.

### Phase 1 — Voice, reasoning & the numbers (D-1, D-5, D-6 · spec §2.3, §2.6, §4.4, §6)

> **Status 2026-09-03: BUILT on `mealplanning`, deployed to dev, eval run.** Scope per Lee: the
> *planning* conversation only — `GENERAL_PROMPT` and the general opener are untouched (the
> §3.2 GENERAL_PROMPT row is deferred). What landed: `persona.ts` CORE moment contract +
> PLANNING_PROMPT rules 1/4/6/7 + planning opener (mirrored to the prototype); `chat.ts`
> clamp → 8-sentence runaway guard, `MAX_OUTPUT_TOKENS` 700; `askChoice` `{label, detail}`
> cap 4 → wire `details` (additive, fixture `choices_details.json` in both repos), Dart
> two-line choice rows; `MacroPillRow` (spec PROPOSED at
> `docs/ssot/spec/design/components/macro-pill-row.md`) in MealCard / PlanTile / plan bar /
> Review sheet, `show_macros` default ON both sides; per-tool status copy
> (`meal_planning.status_*`) with a mini avatar; `coverage_scope` setting (server enum +
> context line + `coverageOf(meals, scope)` → 7 dinner slots when `dinners`, Dart local
> recompute preserves the server denominator); `scripts/vana-eval/` (10 canned
> conversations, dev-only, bills spend — run by hand). Not done: the picker-carousel tile
> keeps kcal-only (188pt tile — pills would wrap; the prototype tile shows kcal only);
> `MealCard`'s pill row is dormant outside the plan surfaces until the Meals-tab hosts pass
> the setting; `/design-sync` is Lee's to run for the new library component.
1. **Prompts** — apply §3.2's file-by-file table: `persona.ts` moment contract,
   `chat.ts` clamp removal + token cap, opener register, prototype mirror.
   *The clamp removal is load-bearing: without it the persona rewrite is invisible.*
   The eval (step 7) is what enforces the PICKING ≤2-sentence rule now — prompt +
   eval, not a server trim.
2. **`askChoice` trade-offs [MB]** — `tools.ts`: `options` → objects
   `{label, detail?}` (cap 4), keep accepting bare strings for old rows;
   `contracts.ts` + `schemas.ts` updated; Dart `VanaChoicesPart` gains `details`;
   `choice_chips.dart` renders two-line full-width rows when any detail is present.
   Prompt: every fork option carries a one-line trade-off (spec §2.3).
3. **Why-lines** — `MealRef.why` already flows and `MealCard` renders it; the change
   is prompt + eval: every proposed meal's why must name a training fact, not a
   platitude ("anchors Thursday's hill repeats", not "great for athletes").
4. **`MacroPillRow` [MB]** — spec at
   `docs/ssot/spec/design/components/macro-pill-row.md`, component in
   `lib/shared/widgets/kyle_design/data/macro_pill_row.dart` (kcal · carbs · protein
   · fat pills, Kyle tokens only, both themes). Wire into `MealCard` (replacing the
   text facts strip when macros show), plan-bar tiles, `ReviewSheet`, `PlanTile`.
   Flip the `show_macros` **default to on** (server read + Dart fallback); "at
   least" framing lives in the surrounding copy, tied to the daily target
   (`mpTodayTargetLine` already exists). No fiber/sugar — `MealRef` doesn't carry
   them.
5. **Per-tool status copy [MB]** — new content keys (`mpStatusFindingMeals`,
   `mpStatusCheckingCombo`, `mpStatusBuildingList`, `mpStatusReadingWeek`, fallback
   `mpStatusThinking`) in `content_keys.dart` + `content_defaults.json`; map
   toolName → key in `_statusLine()`; render as mini `VanaAvatar` + italic line (the
   S20 "gathering coupons…" pattern). No percentage ring — we won't fake progress.
6. **Coverage-scope fork [MB]** — `coverage_scope` setting
   (`dinners` / `dinners_lunches` / `all`) via the existing k/v settings row;
   PLANNING_PROMPT rule 4 asks once (right where the batch fork lives) and honors
   the answer in the type walk; `PickerChips`' "Next:" progression and the coverage
   denominator follow it.
7. **Eval before ship** — `scripts/vana-eval` replaying ~10 canned conversations
   against dev edge, asserting: no emoji anywhere; why-lines present and
   training-anchored; fork options ≤4 and carrying details; picking turns ≤2
   sentences; presenting turns ≥1 concrete athlete fact; milestone turn after
   confirm. Run it in every later phase too.

### Phase 2 — Prove-what-you-know & the trusted draft (D-7 partial · spec §2.2, §3)

> **Built 2026-09-03.** `season.ts` static month table → `SEASON` context line (no region yet — no location on the profile); `weekly_budget_usd` setting (Vana records "keep it under $N", context `BUDGET` clause; no UI to set it); `RECENT` line = the notable session of the last 2 days, in the opener salience order after holidays; `draftWeek` tool (deterministic: dinners 3×2, lunches 2×3, +breakfast/snack for `all`) behind the client-drawn "Draft my whole week" chip on the first picker; `Memory.source` on the wire + `source · date` in the memory drawer (the `user_memories.source` column already existed). Grocery deals stay deferred (D-7).
1. **Context block** (`context.ts`): seasonal produce line (static region×month
   table — no API) and a budget line if the athlete ever set one. Grocery deals stay
   **deferred** — no data source; leave the stub and a note (spec §3.4 is the
   marquee moment, but it can't ship without data).
2. **Opener beat**: extend the salience order (race > holiday > rest-week > biggest
   session > weather) with **notable recent workout** (yesterday's long/hard session
   from `activities`) — the "you crushed a century yesterday" beat (spec §3.3).
3. **`draftWeek` — the one-tap complete week** (spec §2.2: "if you trust us, we
   decide for you"; SCEN-U lands a full draft after two questions). A
   "Draft my whole week" chip on the opener; the tool fills the coverage scope
   deterministically (repeated `searchMeals` by type/context + `plan.addMealById` —
   the LLM selects nothing) and returns the `batch` part; Vana PRESENTS it: 3–4
   sentences, a why per meal, "swap anything from the plan bar." Refinement then
   uses every existing mechanism. This is the propose-first door; the incremental
   picker remains the default.
4. **Memory provenance** (spec §3.1–3.2): `MemoryDrawer` already shows kind + date;
   add the **source** ("conversation" / "onboarding") — column on `vana_memories` if
   absent (dev schema bump), rendered as `source · date`, and available to the
   opener for provenance-cited preferences ("loves steak after hard days ·
   conversation · Apr 19").

### Phase 3 — The relationship loop (D-2, D-3 · spec §5) ← the big one

> **Built 2026-09-03.** Migration `20260903120000_meal_planning_relationship_loop.sql` (`checkin_done_at`, `debrief_done_at`, `plan_debriefs`; server-only, no Drift bump). `opener.ts` `pickOpener()` (pure, unit-tested): debrief wins for a finished undebriefed week ≤14 days old, then the check-in when a cook session (cook-sun = weekStart Sunday, +3, +5) is today/tomorrow — stamped so it never repeats. `recordDebrief` resolves the pending plan itself (the opener's synthetic message is never stored, so the context also carries a `DEBRIEF PENDING` line); learnings become `source: 'debrief'` memories; `LAST WEEK` context line + rule 1 makes the first proposal react. Local notifications: device-side toggle (shared_preferences) in Vana settings + `PlanReminderService` (check-in 18:00 the evening before cook day, debrief 18:00 on the closing Sunday) — ships dark (OFF) per Q-5. 3.6 is covered by `scripts/vana-eval/lifecycle.ts` rather than a Patrol flow (a simulator flow cannot time-travel the plan week; the script does).
1. **Plan lifecycle state** on `meal_plans`: `confirmed_at` exists; add
   `checkin_done_at`, `debrief_done_at` (migration, dev schema bump).
2. **Check-in opener**: confirmed plan + upcoming cook session within ~36h + no
   check-in yet → the opener becomes the check-in ("Sunday cook session tomorrow —
   3 meals planned. Shopped yet?") with chips (Ready / Swap something / Push it
   back). A new opener branch in `chat.ts` — no cron needed.
3. **Debrief opener**: confirmed plan's week ended + no debrief → open with the
   debrief ("Last week: how many of the 5 meals actually happened?"). New tool
   `recordDebrief` → `plan_debriefs` table + 1–3 distilled `rememberFact` memories
   ("skips fish on weeknights"). Debrief close is a MILESTONE moment when the week
   went well (spec §5.3 "celebrates outcomes").
4. **Learnings feed forward**: `context.ts` PLAN line gains a "last week" clause
   (completion %, top skip reason); PLANNING_PROMPT step 1 requires the first
   proposal to react to it ("kept the two you repeated, dropped the salmon that
   slipped twice").
5. **Local notification (opt-in)**: Vana settings toggle; schedule at
   check-in/debrief time via existing notification plumbing (OneSignal or
   flutter_local_notifications — decide at build time). Ships dark until the
   opener version proves out in dev (Q-5 ⚖️: opener-on-open first, push later).
6. **Patrol flow**: confirm plan → time-travel week → reopen → debrief chips → next
   plan references the debrief.

### Phase 4 — Artifacts & confirmation payoff (D-4 · spec §4.2–4.3)

> **Built 2026-09-03.** `ConfirmedCard` = the "you're set" summary (week, sessions, list size, Plan-tab / Shopping-tab rows), Share via the OS share sheet (`PlanShareService` plain text; the Shopping tab already shared the list), and the "Remind me the night before cook day" chip → `PlanReminderService.scheduleCheckin`.
1. **Confirmation moment upgrade**: `ConfirmedCard` becomes the "you're set"
   summary — plan name, cooking sessions, list size, *where everything lives* (Plan
   tab, Shopping tab) — the scenarios' "What's been added" beat.
2. **Share/export**: OS share sheet for the shopping list (text/markdown) from the
   ConfirmedCard and Shopping tab; plan summary share likewise
   (`mpShoppingShareTitle` already exists). No email/PDF/calendar APIs (Q-3 ⚖️).
3. **Offer-a-reminder chip** on confirm ("Remind me the night before cook day?")
   wiring into Phase 3's local notifications.

### Phase 5 — First contact (D-10 · spec §7.3, Q-7)

> **Built 2026-09-03, then REMOVED the same evening (Lee: "we don't need that block").** One-time intro card as the message-list header of a new planning conversation (`vana_intro_dismissed` shared-prefs flag), the what-Vana-knows line from the home payload's race/anchor, three example chips (Plan around my race week · Use what I have · Cheaper this week). Never a gate. Wizard (Q-2) still deferred.
1. One-time intro card on first Vana open: one line on what Vana already knows
   (naming the athlete's actual race/week), 3 tappable example prompts, dismiss
   forever. Client-side (shared-prefs flag).
2. **[MB]** Example prompts translated from MealBuddy's S1 categories into things
   this app can do — *Plan around my race week* · *Use what I have* (lights up in
   Phase 7) · *Cheaper this week* · *More variety*. A card the athlete can ignore;
   **never a gate**, never the 8-way decorative grid.
3. Revisit the wizard (Q-2) only after Phases 1–4 have user feedback.

### Phase 6 — Transcript & composer mechanics [MB] (spec §2.4–2.5)

> **Built 2026-09-03.** Edit under each athlete turn → composer + "Editing" strip → `rewind` action (server deletes from that message on and restores the draft from the `plan_snapshot` every assistant turn now stores in `vana_messages.metadata`; a rewind past the first turn empties the draft) → the edited text is sent normally. Per-card `⋮` Swap / Remove on transcript meal cards (only for picked meals) and plan tiles. Ingredient-level swap from the meal sheet (`IngredientSwap` parses the catalog's `swaps` strings; `swap_ingredient` creates a saved variant, swaps it in place, records it, shopping recomputes). Date dividers. Composer `+` (Snap my fridge / Choose a photo / Use what I have; web = no camera) and mic (`speech_to_text`, hidden on web). Not done: goldens for the composer row. **Added 2026-09-03 evening (Lee):** "Browse meals" from chat — a chip under every picker and the leading row of the `+` sheet open `/vana/browse?c=<conversation>` (the Meals-tab catalog extracted into `MealCatalogBrowser`) where every card carries an Add-to-plan tick that picks into the conversation draft (`pickMeals(conversationId:)`); the detail page gets "Add to plan" when opened with `?pick=`; the chat reloads its draft on return (`VanaChatController.refreshDraft`). v5's browse-sheet pattern, in our own Meals tab.
1. **Editable answers** — the file's best interaction idea. `Edit` under each
   athlete turn (extend `vana_bubble.dart`): tap → text returns to the composer;
   send → truncate-and-rerun. Server: an explicit rewind endpoint on `vana-action`
   (delete `vana_messages` after the edited turn — history is server-owned in
   `runChat`). **The hard part**: turns whose tools touched the draft plan must
   re-derive it, not leave orphaned picks — v1 rule: rewinding past a plan-touching
   turn resets the conversation draft to its state at that message (requires the
   plan events to be replayable or snapshotted; decide at build time and test it
   first).
2. **Per-card overflow** — `⋮` on transcript meal cards and plan-list tiles →
   **Swap** (reuses `SwapPicker`) / **Remove**. Today both live two taps deeper in
   `MealSheet` (spec §2.4: card-scoped actions on cards).
3. **Ingredient-level swap, scoped v1** (spec §2.5 — the D-6 half the plan
   previously dropped): from `MealSheet`/meal detail, "Swap an ingredient" using
   the library row's `swaps` suggestions + component list → creates a saved
   variant, swaps it into the plan via existing `swapMeal`, shopping list
   recomputes as it already does on plan change. Assemblies first (components are
   structured); recipes are stretch.
4. **Date dividers** when a conversation spans days.
5. **Composer `+`** (attach entry point; payload lands in Phase 7) and optional
   **mic** (platform speech-to-text into the field). Both degrade cleanly on web.
6. **Tests**: widget tests for edit-rewind incl. a plan-touching turn; goldens for
   the composer row and two-line choice cards.

### Phase 7 — Ingredients on hand [MB] (spec §1.1's in-the-moment intent, fed by what's in the house)

> **Built 2026-09-03.** `pantry` part + `askPantry` (seeded from 30-day logs, saved-meal components and last plan's have/checked items — never a generic list), `SelectableChipGrid` (spec PROPOSED at `docs/ssot/spec/design/components/selectable-chip-grid.md`), `suggestMeals.ingredientsOnHand` (search + overlap ranking; why-line "Uses your eggs, rice · …"), Snap my fridge = the meal-logging `meal-photos` upload + `pantry_photo` action (Haiku vision through the gateway, metered in `ai_usage` as `vana-pantry-photo`, no credit debit — Pro is the price) → a persisted `pantry` part; "Use these" → `set_pantry` (k/v setting `pantry_items`) → shopping `have`.
1. **`pantry` part + `askPantry` tool**: a `SelectableChipGrid` of likely on-hand
   items — seeded from the athlete's recent logs, saved meals and last week's
   shopping list, **not** a generic hard-coded list — with a trailing `+` for
   anything else.
2. **`suggestMeals.ingredientsOnHand`**: weights the search toward meals using
   those items; the picker's why-line says which on-hand items each meal uses.
3. **Snap my fridge**: composer `+` → photo source sheet → the existing
   `photo_capture_screen.dart` capture path → ingredient detection → a `pantry`
   part pre-ticked with what was detected, editable before use. Reuses the
   meal-logging photo-AI plumbing; **metered, never disabled** (standing
   AI-surfaces rule).
4. **Shopping-list feedback**: on-hand items land as `have` on `shopping_items` so
   the list stops asking for things already in the fridge.
5. **Cost**: one vision call per photo — meter in `ai_usage` like the other photo
   surfaces; confirm the credit price before prod.

### Phase 8 — Day assignment as a second act [MB] (spec §1.4: "dailies are an assignment layer on top")

> **Built 2026-09-03.** The post-confirm chips are now [Open shopping list · Lay it across the week · Adjust]; "Lay it across the week" → `planWeek` (7× the existing `planDay`, plan meals first) → a `week` part rendered as read-only day cards with "Open Plan tab". Athletes who ignore the chip keep exactly the old behavior.
1. After `confirmPlan`, Vana offers once: *"Want me to lay these across the
   week?"* → chips (Yes / I'll wing it). Yes runs `planDay` across the week from
   the confirmed collection.
2. Renders as existing `day` parts and lands on the Plan tab — no new plan model,
   no day-slotted *generation*, no per-day macros invented in chat.
3. Athletes who never answer keep exactly today's behavior.

---

## 6. Explicitly not doing (and why)
- **Race fueling in chat** — stays deterministic (2026-06-17 decision, spec §1.2).
- **A front-loaded interview** (MealBuddy S2–S4) — we already know all four answers;
  asking would contradict "already did the homework" (spec §2.1).
- **Three alternative whole plans with Regenerate** (S14) — one trusted draft
  (`draftWeek`, Phase 2.3) + "Other options" covers the intent at the right
  granularity.
- **Day-slotted plan generation** (S15/S17) — day assignment stays an optional
  second act (Phase 8).
- **Grocery cost + coupons** (S18/S20) **and the shopping-list cost estimate**
  (spec §4.2) — same missing data source; the deal moment stays spec'd and stubbed.
  Revisit if a static price table ever lands.
- **Fake progress percentages** (S13's 10% ring).
- **Fiber and sugar pills** — not carried by `MealRef`; we will not synthesize them.
- **Email/PDF/calendar-API integrations** — share sheet + local notifs cover v1 (Q-3 ⚖️).
- **6-step wizard** — deferred (Q-2 ⚖️).
- **Emoji in Vana's voice** — visual warmth belongs to Kyle components; the milestone
  register (§3.1) carries the celebration Xuan wants without emoji (⚖️ — one persona
  line for Xuan to reverse).
- **Anything from MealBuddy's skin** — mascot, palette, colored chip outlines,
  iOS-only chrome (§4).

## 7. Sequencing, cost, verification
- Value order stays **1 → 2 → 3**. MealBuddy phases slot in as: **6 and 7 after
  Phase 1** (chat-surface quality, independent of Phase 3's schema work), **8 after
  Phase 4** (needs the confirm moment).
- Rough shape: 1 + 2 are prompt/UI work (days; `draftWeek` adds ~2 server days).
  6 is a week — edit-rewind × draft-plan state is the risk, not the UI. 7 is a week
  and adds an AI cost line. 3 carries a schema change + new tool + opener branches
  (the week-scale chunk). 4, 5, 8 are small.
- Every phase: `scripts/vana-eval` (Phase 1.7) + `scripts/run-meal-planning-tests.sh`;
  Phase 3 adds the Patrol lifecycle flow; Phases 6–7 add widget tests/goldens and a
  Patrol pass over edit-rewind + the pantry grid. New library components need their
  design spec written first and `/design-sync` after landing (user-invoked).
- Persona changes verified in the simulator walkthrough (`walkthrough.md` v2 pass
  when Phase 1 lands).
- Before building Phase 3, show Xuan §2 (Q-5/Q-6 have the most product surface) and
  §4 (the REJECT rows are where Alex's design and this plan genuinely disagree).

## 8. Reference screens — compare as you build

Two visual sources, used differently: **MealBuddy frames** (`figma/NN-*.png`, or the
live file `figma.com/design/fpXDAtEbcgv3cDXB9tE6Yg`) show the *interaction* being
adopted; the **Kyle-styled prototype previews** (`design-screens/previews/*.html`,
tokens per `design-system/`) show what it should *look like* in our system. When they
disagree visually, the prototype wins, always.

| Phase | MealBuddy frames (interaction) | Kyle prototype / target (look) | Spec § |
|---|---|---|---|
| 1 prompts & chips | `03` (chip fork), `15`/`16` (macro pills), `21` (named status beside avatar) | `consult.html` (chat), `components.html` (repeatable widgets) | §2.3, §2.6, §4.4, §6 |
| 2 trusted draft | `15` (the "complete proposal" beat, minus the 3-plan carousel) | `step02.html` (Vana acts), `step05.html` (your week) | §2.2, §3.1–3.3 |
| 3 relationship loop | — (nothing in MealBuddy reaches past confirm) | `step07.html` (mid-week), `main.html` | §5 |
| 4 confirmation payoff | `28` (confirm moment) | `step06.html` (list ready), `shopping.html`, `step08.html` | §4.2–4.3 |
| 5 first contact | `01` (welcome categories → intro-card prompts) | `consult.html` empty state | §7.3 |
| 6 transcript mechanics | `03` (Edit link), `05` (Edit+Delete), `17` (per-card ⋮), `09` (date divider), `12` (composer + keyboard) | `consult.html`, `step03.html` (swap) | §2.4–2.5 |
| 7 ingredients on hand | `09` (pantry chip grid + `+`), `10`–`14` (snap-fridge flow) | `components.html` chip styles; capture UI = existing `photo_capture_screen` | §1.1, §3.1 |
| 8 day assignment | `26`–`28` (post-selection scheduling) | `step07.html`, `main.html` (Plan tab days) | §1.4 |
