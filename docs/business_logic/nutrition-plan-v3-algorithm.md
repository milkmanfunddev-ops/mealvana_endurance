# Generate Nutrition Plan V3: Algorithm Flow

> Current implementation map for `generate-nutrition-plan-v3`, verified against the source on July 21, 2026.

## What this function does

`generate-nutrition-plan-v3` is a **food-selection algorithm**. It does not calculate the athlete's macro targets. The normal app flow is:

```text
generate-macros-v4  ->  macro targets + pre-workout selections
                              |
                              v
generate-nutrition-plan-v3  ->  actual foods for before, during, and after
```

The plan generator consumes:

- target ranges for carbs, protein, sodium, and fluid;
- workout type, duration, and gut-training level;
- diet, allergies, and liked/willing/disliked foods;
- user foods and Formula Kit pins; and
- brick segments and transition targets, when applicable.

## Main flowchart

```mermaid
flowchart TD
    A["Receive PlanInputV2"] --> B{"Required input valid?"}
    B -- "No" --> C["Return HTTP 400"]
    B -- "Yes" --> D["Apply user-overridden target ranges"]
    D --> E{"Brick workout?"}

    E -- "Yes" --> BRICK["Run the brick flow"]
    BRICK --> R2["Return brick plan"]

    E -- "No" --> P["Fetch Before, During, and After pins"]
    P --> PAR["Generate all three phases in parallel"]

    PAR --> BF["BEFORE<br/>Use macro-v4 selections when supplied;<br/>otherwise run Algorithm C"]
    PAR --> DU["DURING<br/>Personal formula -> template solver<br/>-> rule solver"]
    PAR --> AF["AFTER<br/>Personal formula -> recovery template<br/>-> LP fallback"]

    BF --> V["Validate final foods against target ranges"]
    DU --> V
    AF --> V
    V --> W{"Anything outside a range?"}
    W -- "Yes" --> WARN["Attach non-fatal warnings / shortfalls"]
    W -- "No" --> RESP["Build response"]
    WARN --> RESP
    RESP --> LOG["Write best-effort plan-generation ledger"]
    LOG --> R["Return plan, targets, metadata, and pin decisions"]
```

The three single-sport phases run concurrently. A failure in a phase throws the whole request; a phase that merely misses a target range still returns a plan with warnings or shortfall metadata.

## Before-workout flow

```mermaid
flowchart TD
    A["Before targets"] --> B{"All targets are zero?"}
    B -- "Yes" --> Z["Return an empty Before phase"]
    B -- "No" --> C{"macro-v4 supplied pre_run_selections?"}

    C -- "Yes" --> S["Reuse those selected templates"]
    C -- "No" --> T["Load food, drink, and electrolyte templates"]
    T --> AC["Algorithm C splits targets across active slots"]
    AC --> PICK["For each slot: honor an in-scope template pin,<br/>or score, stack, and fill from eligible templates"]
    PICK --> S

    S --> F["Load every selected template component"]
    F --> U["Find compatible user-food substitutions"]
    U --> X["Explode composite templates into individual foods"]
    X --> O{"Pinned personal formula matches a slot?"}
    O -- "Yes" --> PF["Replace that slot, scale to its carb target,<br/>and backfill fluid / sodium if needed"]
    O -- "No" --> KEEP["Keep the algorithmic slot"]
    PF --> OUT["Return meal / snack / top-up slots"]
    KEEP --> OUT
```

Active slots depend on `hours_before`:

| Time available | Slots produced |
|---|---|
| `>= 2.5 hours` | meal, snack, top-up |
| `>= 1 hour` | snack, top-up |
| `< 1 hour` | top-up |

Important details:

- The live app normally sends `pre_run_selections` already chosen by `generate-macros-v4`. V3's own Algorithm C call is the fallback for a direct call or regeneration without those selections.
- Diet and allergies are hard filters for normal selection. User likes, willingness, and dislikes influence free-form selection. An explicit in-scope pin wins over those filters by design.
- A pinned personal formula overlays only its matching active slot; the other slots stay algorithmic.

## During-workout flow

```mermaid
flowchart TD
    A["During targets"] --> SW{"Swimming?"}
    SW -- "Yes" --> EMPTY["Return no during-workout foods"]
    SW -- "No" --> PP{"In-scope pinned personal formula?"}

    PP -- "Yes" --> PFR["Render components and scale to carb target"]
    PFR --> PFB["Backfill fluid / sodium when needed"]
    PFB --> PS["Compute honest shortfalls<br/>(no system carb gap-fill)"]
    PS --> OUT["Return foods + path + pin decision + shortfalls"]

    PP -- "No" --> LOAD["Load templates and one shared constrained food pool"]
    LOAD --> READY{"Positive duration and usable templates / foods?"}
    READY -- "Yes" --> TS["Rank candidates and try the template solver"]
    TS --> OK{"Template rendered and validated?"}
    OK -- "Yes" --> CLOSE["Closing pass"]
    OK -- "No" --> RULE["Run deterministic rule solver on the same pool"]
    READY -- "No, but pool has foods" --> RULE
    READY -- "No foods" --> NOFOOD["Return empty foods with shortfalls"]
    RULE --> CLOSE
    CLOSE --> GAP["Append carb gap-fill when below 90% of target,<br/>limited by gut-training caps"]
    GAP --> SHORT["Compute shortfalls from final totals"]
    SHORT --> OUT
    NOFOOD --> OUT
```

The key invariant after the July 21 refactor is:

> A During phase cannot leave the generator under target without reporting why in `shortfalls`.

The template solver, rule solver, and carb gap-fill all use the same food pool. There is no During-phase LP fallback and no server-side by-hour scheduling; the server returns `by_hour_data: null` and the client handles placement.

## After-workout flow

```mermaid
flowchart TD
    A["After targets"] --> PP{"In-scope pinned personal formula?"}
    PP -- "Yes" --> PFR["Render components, scale to carb target,<br/>and backfill fluid / sodium"]
    PFR --> OUT["Return recovery foods + pin decision"]

    PP -- "No" --> LOAD["Load active recovery templates and all required foods"]
    LOAD --> FILTER["Keep templates compatible with activity,<br/>diet, allergies, and food availability"]
    FILTER --> PIN{"In-scope system template pin?"}
    PIN -- "Yes" --> PICKPIN["Pinned candidates win; rank multiple pins by priority"]
    PIN -- "No" --> RANK["Rank by travel friendliness, then prep effort;<br/>randomly break an exact top tie"]
    PICKPIN --> RENDER["Render the template's canonical servings"]
    RANK --> RENDER
    RENDER --> OK{"Complete template rendered?"}
    OK -- "Yes" --> OUT
    OK -- "No" --> LP["Run After-phase LP solver"]
    LP --> SOLVED{"LP found a plan?"}
    SOLVED -- "Yes" --> CHECK["Validate; optionally retry without imported user foods"]
    SOLVED -- "No" --> GREEDY["Use greedy fallback"]
    GREEDY --> CHECK
    CHECK --> OUT
```

The normal recovery-template path deliberately uses the template's authored serving sizes. It does not scale the portion to hit the macro targets. Macro targets are used when scaling a pinned personal formula and by the rare LP fallback.

## Brick-workout branch

```mermaid
flowchart TD
    A["Brick request"] --> B["Generate one shared Before phase"]
    B --> LOOP["For each sport segment"]
    LOOP --> D["Run the normal During flow with that segment's targets"]
    D --> MORE{"Another segment follows?"}
    MORE -- "Yes" --> T["Read T1 / T2 targets from the macro payload"]
    T --> T0{"All transition targets are zero?"}
    T0 -- "Yes" --> TE["Return an empty transition"]
    T0 -- "No" --> TT["Try transition template 0"]
    TT --> TOK{"Rendered?"}
    TOK -- "No" --> TLP["Transition LP -> greedy fallback"]
    TOK -- "Yes" --> NEXT["Continue to next segment"]
    TLP --> NEXT
    TE --> NEXT
    NEXT --> LOOP
    MORE -- "No" --> AFTER["Generate After foods with LP -> greedy fallback"]
    AFTER --> V["Validate non-fatally and return segment,<br/>transition, and shortfall data"]
```

Brick-specific differences:

- Formula Kit pins are not currently passed through the brick handler.
- Transition targets come from the macro payload. If they are missing, the safety fallback is zero targets rather than hard-coded duration tiers.
- Brick After uses the LP path directly rather than the normal recovery-template selector.

## Selection precedence and safety rules

1. **Personal formula pin:** highest priority; rendered as authored and scaled to the relevant carb target.
2. **Pinned system template:** wins when it is in scope for the phase, activity, and duration.
3. **System template:** preferred normal path.
4. **Rule solver:** During fallback only.
5. **LP, then greedy:** After fallback, and transition fallback for bricks.

Across the algorithm:

- user-overridden target bands are adjusted before selection;
- normal template pools enforce diet and allergy compatibility;
- pin decisions and skipped-pin reasons are returned for client explanation;
- final range validation is non-fatal; and
- the single-sport response ledger is best-effort and cannot block plan delivery.

## Source map

| Responsibility | Source |
|---|---|
| HTTP orchestration, parallel phases, response, ledger | [`index.ts`](../../supabase/functions/generate-nutrition-plan-v3/index.ts) |
| Before orchestration and personal-formula overlay | [`before-phase.ts`](../../supabase/functions/generate-nutrition-plan-v3/before-phase.ts) |
| Before component expansion | [`before-phase-explosion.ts`](../../supabase/functions/generate-nutrition-plan-v3/before-phase-explosion.ts) |
| Before user-food substitution | [`before-phase-substitution.ts`](../../supabase/functions/generate-nutrition-plan-v3/before-phase-substitution.ts) |
| Algorithm C selection and target splitting | [`pre-workout.ts`](../../supabase/functions/generate-macros-v4/pre-workout.ts) |
| During orchestration and closing-pass invariant | [`during-phase.ts`](../../supabase/functions/generate-nutrition-plan-v3/during-phase.ts) |
| During template solver | [`during-template-solver.ts`](../../supabase/functions/_shared/nutrition/during-template-solver.ts) |
| During rule fallback | [`during-rule-solver.ts`](../../supabase/functions/_shared/nutrition/during-rule-solver.ts) |
| During carb gap-fill | [`during-gap-fill.ts`](../../supabase/functions/_shared/nutrition/during-gap-fill.ts) |
| After orchestration | [`after-phase.ts`](../../supabase/functions/generate-nutrition-plan-v3/after-phase.ts) |
| Recovery-template selection and rendering | [`post-template-solver.ts`](../../supabase/functions/_shared/nutrition/post-template-solver.ts) |
| After LP fallback | [`lp-phase.ts`](../../supabase/functions/generate-nutrition-plan-v3/lp-phase.ts) |
| Brick segments and transitions | [`brick-handler.ts`](../../supabase/functions/generate-nutrition-plan-v3/brick-handler.ts) |
| Non-fatal phase validation | [`validation.ts`](../../supabase/functions/generate-nutrition-plan-v3/validation.ts) |
| Analytics ledger | [`plan-generation-log.ts`](../../supabase/functions/generate-nutrition-plan-v3/plan-generation-log.ts) |
