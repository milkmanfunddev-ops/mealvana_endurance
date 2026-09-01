# CLAUDE.md — terminal prototype

- **Source URL:** https://app.notion.com/p/35ae3fdb754c81379b9fd3a12c4aa1c1
- **Snapshot date (as fetched):** 2026-05-08T03:13:33.476Z
- **Icon:** 💻
- **Ancestor path:** Homepage › [unnamed] › [unnamed] › Features › Technical and Product Documentation › (data source: Technical and Product Documentation) › AI Assistant › **CLAUDE.md — terminal prototype**

## How to use this

Create a new directory for the project. Copy everything below the divider into a file named `CLAUDE.md` at the project root. Then run Claude Code in that directory — it will pick up `CLAUDE.md` automatically and you can ask it to scaffold the prototype.

---

# MealBuddy — terminal prototype

A terminal-based conversational agent that demonstrates the MealBuddy planning experience for endurance athletes. The LLM (Claude, via the Anthropic API) drives the conversation. Backend "intelligence" — training schedule, weather, seasonal produce, recipe matching, deals, residual macro budget — is **mocked** with hardcoded return values that simulate what the real proprietary stack would return.

This prototype proves the conversation feel and the tool-use pattern, not production behavior. Single user (Caroline). No database. No real APIs. Just Python + the Anthropic SDK + a small terminal UI.

---

## What this IS and ISN'T

**Is:**
- Python 3.11+ CLI that runs in the terminal
- A REPL: user types → Claude responds (with tool calls) → user types again
- Claude has access to ~10 tools that return realistic mocked data
- ASCII representations of cards (meal, deal, cooking sessions, lock) when surfacing structured output
- Should support the 7-turn Caroline arc described below, but not deterministically — the LLM has freedom

**Isn't:**
- A real backend. All data is hardcoded.
- A web or mobile UI.
- A copy of the Mealvana app — we're testing the conversation pattern only.
- Performance nutrition / fueling. Out of scope (separate product).
- Breakfast or snacks. Out of scope.
- Authentication, persistence, multi-user.

---

## Tech stack

- Python 3.11+
- `anthropic` (official SDK) for Claude API calls
- `rich` (optional, for nicer terminal output — colors, panels)
- Standard library otherwise

## File structure

```
mealbuddy_terminal/
├── CLAUDE.md          # this file
├── README.md          # short user-facing instructions
├── main.py            # entry point: REPL loop
├── llm.py             # Anthropic client wrapper, tool-execution loop
├── tools.py           # tool definitions in Anthropic format + dispatch table
├── mocks.py           # the mocked backend functions
├── data.py            # hardcoded profile, training week, recipes, deals, weather presets
├── ui.py              # terminal rendering (ASCII cards, prompts, formatting)
└── prompts.py         # system prompt
```

A single-file `main.py` is also fine if simpler. Split when files exceed ~200 lines.

---

## Configuration

The API key comes from the `ANTHROPIC_API_KEY` environment variable. Fail fast with a clear error if it's missing.

```python
import os, sys
api_key = os.environ.get("ANTHROPIC_API_KEY")
if not api_key:
    sys.exit("ERROR: set ANTHROPIC_API_KEY in your environment.")
```

Use the latest available Claude Sonnet model. Sonnet, not Haiku — the conversation reasoning needs the larger model. Check Anthropic's docs for the current model identifier.

---

## The conversation loop

```
user types
  ↓
append {"role": "user", ...} to history
  ↓
client.messages.create(history, system, tools)
  ↓
if response.stop_reason == "tool_use":
   for each tool_use block:
     execute tool against mocks.py, capture result
   append all tool_result blocks as a single user message
   loop back to messages.create
else:
   print assistant text via ui.py
   loop back to user prompt
```

Use the Anthropic tool-use API. The tool loop continues until the model returns `end_turn`. Encourage parallel tool calls — at the start of a planning conversation the model should fetch profile + training + weather + seasonal + residual budget in **one** parallel batch, not five sequential ones.

---

## State and scenarios

### Session state

The prototype keeps a lightweight in-memory `SessionState` for the duration of one terminal session. It is NOT a database — it lives as long as the process runs and resets on restart (or when the user types `reset`).

Put it in `state.py`:

```python
from dataclasses import dataclass, field
from typing import Dict, List

@dataclass
class SessionState:
    scenario_id: str = ""
    proposed_meals: List[dict] = field(default_factory=list)   # meals find_meals returned
    confirmed_meals: List[str] = field(default_factory=list)   # meal_ids in the locked plan
    meal_servings: Dict[str, int] = field(default_factory=dict)
    meal_swaps: Dict[str, Dict[str, str]] = field(default_factory=dict)
    shopping_list: List[str] = field(default_factory=list)
    locked: bool = False

SESSION = SessionState()  # module-level singleton, fine for single-user prototype

def reset():
    global SESSION
    SESSION = SessionState()
    # caller will then re-pick a scenario; see below
```

The mocks in `mocks.py` read and write `SESSION` as needed:
- `find_meals` writes to `SESSION.proposed_meals` so deals can later stitch back to them
- `update_servings` updates `SESSION.meal_servings` (next call sees the new count)
- `swap_component` (when applied) updates `SESSION.meal_swaps`
- `lock_meal_plan` sets `SESSION.confirmed_meals` and `SESSION.locked = True`
- `add_to_shopping_list` appends to `SESSION.shopping_list`
- `get_grocery_deals(current_meal_ids=None)` falls back to `SESSION.confirmed_meals` when not passed

The LLM still tracks the conversation via message history. State is just for tools to give consistent answers across calls within a session.

### Scenarios — randomized starting context

To keep demos from feeling identical across runs, pick one of 3-5 scenarios at session start. A scenario bundles a coherent set of context: weather, training week, seasonal produce, active deals, current date, recovery priority.

Define them in `data.py`:

```python
SCENARIOS = {
    "heat_wave_brick": {
        "summary": "Hot week, brick on Sunday, peaches just hit peak",
        "weather_preset": "heat_wave",
        "training_week": "brick_focus",        # key into TRAINING_WEEKS dict
        "seasonal": ["summer squash", "tomatoes", "peaches", "corn", "basil"],
        "deals": ["peaches_25_off", "asparagus_peak"],
        "current_date": "2026-07-14",
        "recovery_priority": "high",
    },
    "cool_spring_recovery": {
        "summary": "Cool spring, recovery week, strawberries arriving",
        "weather_preset": "cool_rainy",
        "training_week": "recovery_week",
        "seasonal": ["asparagus", "spring greens", "strawberries", "peas", "rhubarb"],
        "deals": ["strawberries_30_off", "asparagus_peak"],
        "current_date": "2026-04-22",
        "recovery_priority": "moderate",
    },
    "late_summer_race_prep": {
        "summary": "Late summer, race prep taper, corn and melons in",
        "weather_preset": "pleasant",
        "training_week": "race_prep_taper",
        "seasonal": ["corn", "watermelon", "tomatoes", "peppers", "summer squash"],
        "deals": ["corn_5_for_2", "tomatoes_peak"],
        "current_date": "2026-08-26",
        "recovery_priority": "low",
    },
}
```

Pick a scenario at session start in `main.py`:

```python
import random, os
forced = os.environ.get("SCENARIO")
SESSION.scenario_id = forced if forced in SCENARIOS else random.choice(list(SCENARIOS.keys()))
```

Each tool reads the active scenario via `SESSION.scenario_id`:
- `get_weather_forecast` → the preset named by the scenario
- `get_training_week` → the training week named by the scenario
- `get_seasonal_produce` → the seasonal list from the scenario
- `get_grocery_deals` → the deals listed in the scenario
- `compute_residual_budget` → uses scenario's recovery_priority to vary residual context

For dev/QA, force a scenario via env var:

```bash
SCENARIO=heat_wave_brick python main.py
```

Normal runs are randomized; this is the override.

### Don't over-engineer

Variations should feel different but coherent. The LLM already adds plenty of natural variation — the point of scenarios is to swap out the scaffolding so consecutive demos don't feel like reruns of the same script. Three scenarios is enough. Coherence within a scenario beats randomness within a tool.

---

## System prompt

This is the most important file in the repo. Put it in `prompts.py` as `SYSTEM_PROMPT`. Don't paraphrase — the wording matters.

```
You are MealBuddy, the meal-planning assistant inside Mealvana Endurance — a
nutrition planning app for endurance athletes. You're talking to Caroline, an
already-onboarded triathlete training for the NYC Marathon.

## Your role

You help Caroline plan dinners for the week. You use the proprietary
intelligence available through tools: her training schedule, weather, seasonal
produce, this week's grocery deals, her household, her budget, her learned
preferences, and the macro residual budget computed by the V5 pipeline.

You are NOT responsible for:
- Performance nutrition / fueling templates / race-day gels (separate product)
- Breakfast, snacks, or anything outside dinner planning (out of scope)
- Computing macros yourself — always use compute_residual_budget

## Three principles

1. **Macro-number-free.** Never show grams, calories, or macro percentages
   to Caroline. Direction comes through training context ("Thursday
   post-hill recovery"), sensory cues ("won't sit heavy", "cold sides after a
   long brick"), and seasonal language ("peaches just hit peak"). You compute
   and reason about macros internally via tools, but they don't surface in
   replies.

2. **Card-scoped actions live on cards.** When you surface structured items
   (meal cards, deal cards), describe them so Caroline can act on each one
   directly. The cards have built-in actions: serving editor, swap component,
   add-to-list. Don't ask "would you like me to add the peaches?" — present
   the deal card with [+ Add to list] visible and let her act on it.

3. **Proactive, not reactive.** Open with training-aware framing. Surface
   deals contextually mid-flow, after meals are confirmed. Stitch deals back
   into already-confirmed meals when relevant.

## Conversation arc

A week-of-dinners planning conversation roughly follows this shape:
1. Opener that ties weather + training + season + recovery
2. Caroline says what she's craving (or you suggest)
3. You propose a meal anchored to a hard-training day
4. You propose 2 more meals, each tied to its training context
5. Caroline locks them in
6. You organize into cooking sessions (her preferred rhythm)
7. You surface deals that fit the plan
8. You confirm the lock and shopping list

Don't follow this rigidly — Caroline can ask anything. Adapt.

## Tone

Direct, warm, not bubbly. Treats Caroline as a knowledgeable adult athlete.
Short sentences. Sensory and concrete. No emoji. Exclamation marks only when
genuinely warranted (rare). Use italics sparingly.

## How to use tools

At the start of a planning conversation, fetch context in **parallel**:
get_user_profile, get_training_week, get_weather_forecast, get_seasonal_produce,
compute_residual_budget. Don't ask Caroline questions you can answer from tools.

When proposing meals, call find_meals with the user's craving + training day.
When Caroline wants to swap, call swap_component. When she changes servings,
call update_servings. When organizing the week, call get_cooking_sessions.
When surfacing deals, call get_grocery_deals — but only AFTER meals are
confirmed, so deals can be stitched into the existing plan.

## Card rendering

When showing a meal card, deal card, cooking sessions, or final lock card,
output an ASCII representation with clear borders inline in your response.
The terminal renderer will handle styling. Use the formats shown in tools.py
docstrings as a reference. Keep cards under ~50 columns wide.
```

---

## Tools

Define each tool in `tools.py` using the Anthropic tool-use format. Dispatch to functions in `mocks.py`. Tool descriptions should be detailed — the model uses them to decide when to call.

### `get_user_profile()`

Returns Caroline's profile.

```python
{
  "name": "Caroline",
  "diet": "omnivore",
  "avoids": ["cilantro"],
  "household": {
    "size": 2,
    "members": [
      {"name": "Caroline", "note": "NYC Marathon prep, triathlete"},
      {"name": "Wes", "note": "partner, eats anything"}
    ]
  },
  "budget_per_week_usd": 85,
  "zip": "35242",
  "stores": ["Publix", "Aldi"],
  "cooking": "intermediate, prefers 3 cooking sessions/week",
  "gut_training": "intermediate (60-80g carbs/hr)",
  "training_source": "TrainingPeaks",
  "goals": ["recovery-aware fueling", "eat with the season"],
  "learned_preferences": [
    {"fact": "Loves steak after hard training days", "source": "conversation", "date": "Apr 19"},
    {"fact": "Prefers meal-prep over daily cooking", "source": "conversation", "date": "Mar 02"},
    {"fact": "Drawn to peaches and stone fruits in summer", "source": "conversation", "date": "May 04"}
  ]
}
```

### `get_training_week()`

```python
[
  {"day": "Mon", "focus": "Easy run", "duration_min": 45, "intensity": "low"},
  {"day": "Tue", "focus": "Swim 1500m intervals", "duration_min": 60, "intensity": "moderate"},
  {"day": "Wed", "focus": "Easy bike", "duration_min": 60, "intensity": "low"},
  {"day": "Thu", "focus": "Hill repeats 6x400m", "duration_min": 50, "intensity": "high"},
  {"day": "Fri", "focus": "Rest", "duration_min": 0, "intensity": "rest"},
  {"day": "Sat", "focus": "Long ride", "duration_min": 180, "intensity": "moderate"},
  {"day": "Sun", "focus": "Brick: 2hr ride + 45min run", "duration_min": 165, "intensity": "high"}
]
```

### `get_weather_forecast(zip: str)`

Returns a 7-day forecast matching the active scenario. The scenario specifies which preset to return; presets are defined in `data.py`.

```python
# Preset A — heat wave
{
  "summary": "Hot and humid through Wednesday, then cooling.",
  "by_day": [
    {"day": "Mon", "high_f": 92, "low_f": 74, "condition": "hot"},
    {"day": "Tue", "high_f": 94, "low_f": 76, "condition": "hot, humid"},
    {"day": "Wed", "high_f": 91, "low_f": 73, "condition": "hot"},
    {"day": "Thu", "high_f": 82, "low_f": 65, "condition": "pleasant"},
    {"day": "Fri", "high_f": 80, "low_f": 64, "condition": "clear"},
    {"day": "Sat", "high_f": 84, "low_f": 67, "condition": "sunny"},
    {"day": "Sun", "high_f": 86, "low_f": 70, "condition": "sunny"}
  ],
  "notable": ["Heat wave Mon-Wed", "Pleasant by Thu"]
}

# Preset B — cool and rainy
{
  "summary": "Cool and rainy most of the week.",
  ...
}

# Preset C — pleasant
{
  "summary": "Mild and clear all week — peak summer.",
  ...
}
```

Define 3-4 presets in `data.py`. The active scenario picks one via `weather_preset`.

### `get_seasonal_produce(zip: str)`

```python
[
  {"item": "summer squash", "peak": True},
  {"item": "tomatoes", "peak": True},
  {"item": "peaches", "peak": True, "note": "just hit peak"},
  {"item": "corn", "peak": True},
  {"item": "basil", "peak": True},
  {"item": "cucumbers", "peak": True},
  {"item": "berries", "peak": True}
]
```

### `compute_residual_budget(date: str)`

The V5 residual: total daily macros minus performance nutrition allocation. Mocked but realistic.

```python
{
  "date": "2026-05-12",
  "total_target": {"calories": 2850, "carbs_g": 380, "protein_g": 142, "fat_g": 78},
  "performance_nutrition_allocated": {"calories": 520, "carbs_g": 130, "protein_g": 18, "fat_g": 8},
  "meal_planning_budget": {"calories": 2330, "carbs_g": 250, "protein_g": 124, "fat_g": 70},
  "context": {"recovery_priority": "high", "next_day_demand": "long ride"}
}
```

**The LLM never shows these numbers to Caroline.** They're for internal reasoning only.

### `find_meals(craving: str = None, training_day: str = None)`

The lego solver. Returns 1-3 candidate meals. Each meal is a composition pattern with filled component slots. Mock with a small library of pre-baked options in `data.py`. **Writes the returned meals to `SESSION.proposed_meals`** so subsequent tools (especially `get_grocery_deals`) can stitch deals back to the active plan.

```python
[
  {
    "id": "meal_ribeye_summer",
    "title": "Grilled ribeye + summer salad",
    "subtitle": "peach, tomato & basil salad on the side",
    "composition_pattern": "grill + cold side",
    "training_context": "Thursday · post-hill recovery",
    "components": [
      {"slot": "main", "name": "Grilled ribeye + chimichurri"},
      {"slot": "side", "name": "Peach + tomato salad"},
      {"slot": "sauce", "name": "Chimichurri"}
    ],
    "rationale_internal": "Anchors Thursday hills (high intensity). Uses peak-season peaches/tomatoes. Cold side keeps kitchen cool given heat wave.",
    "macros_internal": {"calories": 720, "carbs_g": 32, "protein_g": 52, "fat_g": 38},
    "servings_default": 2
  }
]
```

Maintain a library in `data.py` of ~8-12 pre-baked meals covering: ribeye, salmon, chicken thighs, tofu, shrimp, pasta, bowl, salad. Each tagged with training_day fitness so `find_meals` can filter sensibly.

### `swap_component(meal_id: str, slot: str)`

Returns 4 substitution candidates for a slot.

```python
[
  {"name": "Grilled tofu + chimichurri", "note": "lighter, vegetarian"},
  {"name": "Shrimp skewers + chimichurri", "note": "faster cook"},
  {"name": "Chicken thighs + chimichurri", "note": "leaner option"},
  {"name": "Tempeh + chimichurri", "note": "plant-based, hearty"}
]
```

### `update_servings(meal_id: str, new_servings: int)`

Recomputes ingredients for the new serving count.

```python
{
  "meal_id": "meal_ribeye_summer",
  "servings": 4,
  "ingredient_changes": [
    "ribeye: 14 oz → 28 oz",
    "tomatoes: 2 cups → 4 cups",
    "peaches: 2 → 4"
  ],
  "macros_internal": {"calories": 1440, "carbs_g": 64, "protein_g": 104, "fat_g": 76}
}
```

### `get_cooking_sessions(meal_ids: list)`

Groups confirmed meals into 3 cooking sessions (Caroline's preferred rhythm).

```python
[
  {
    "label": "Sunday afternoon",
    "meals": [
      {"id": "meal_ribeye_summer", "title": "Grilled ribeye + chimichurri", "context": "Thursday · post-hill recovery"},
      {"id": "side_summer_veg", "title": "Roasted summer vegetable medley", "context": "in-season"}
    ]
  },
  {
    "label": "Monday evening",
    "meals": [
      {"id": "meal_chicken_quinoa", "title": "Lemon herb chicken thighs", "context": "Tuesday · swim day"}
    ]
  },
  {
    "label": "Saturday morning",
    "meals": [
      {"id": "meal_salmon", "title": "Baked salmon w/ capers", "context": "Sunday · brick recovery"},
      {"id": "side_greek_salad", "title": "Greek cucumber salad", "context": "bright, hydrating side"}
    ]
  }
]
```

### `get_grocery_deals(zip: str, store: str = None, current_meal_ids: list = None)`

Returns this week's deals (sourced from the active scenario). If `current_meal_ids` is provided, the `fits_meal` and `why` fields are populated to stitch deals into already-confirmed meals. **If `current_meal_ids` is not provided, falls back to `SESSION.confirmed_meals`** — so after `lock_meal_plan` has been called, deals automatically reference the locked plan.

```python
[
  {
    "item": "Local peaches",
    "deal": "25% off — just dropped at Publix",
    "store": "Publix",
    "fits_meal": "meal_ribeye_summer",
    "why": "Already in Thursday's salad — bump for grilled side too"
  },
  {
    "item": "Asparagus",
    "deal": "peak season — best price of summer",
    "store": "Publix",
    "fits_meal": "meal_salmon",
    "why": "Top up for Saturday's salmon prep"
  }
]
```

### `add_to_shopping_list(item: str)`

Mock. Returns success.

```python
{"success": True, "item": item, "list_size_now": 12}
```

### `lock_meal_plan(meal_ids: list)`

Mock. Confirms the plan and "syncs" the shopping list.

```python
{
  "success": True,
  "plan_id": "plan_2026_05_12",
  "shared_with": ["Wes (household)", "nutrition coach"],
  "shopping_list_synced": True,
  "store": "Publix"
}
```

### `update_memory(fact: str, source: str = "conversation")` *(optional)*

Adds a new learned fact. Returns the updated memory list. Skip for v1 if it adds scope.

---

## Reference conversation (for QA, not script)

The prototype should be able to support an arc like this. The LLM has flexibility — these aren't deterministic outputs.

```
You: hi

MealBuddy: [parallel calls: get_user_profile, get_training_week,
get_weather_forecast, get_seasonal_produce, compute_residual_budget]

Hey Caroline. Heat wave through Wednesday, then cooling. Your brick on
Sunday means recovery's the theme. Summer squash, tomatoes, peaches
just hit peak. What sounds good?

You: something with steak but i want it to feel summery

MealBuddy: [find_meals(craving="steak", training_day="Thursday")]

Grilled ribeye with chimichurri, paired with a peach and tomato
salad. Anchors Thursday's hill repeats and keeps the heat outside the
kitchen — grill night.

╭─ Meal ────────────────────────────────────────╮
│ Grilled ribeye + summer salad                 │
│ peach, tomato & basil salad on the side       │
│                                               │
│ Components:                                   │
│   • Grilled ribeye + chimichurri (main)       │
│   • Peach + tomato salad (side)               │
│   • Chimichurri (sauce)                       │
│                                               │
│ Tag: Thursday · post-hill recovery            │
│ Servings: 2  [+ to bump]  [⇄ swap]            │
╰───────────────────────────────────────────────╯

You: bump to 4 — wes invited a friend

MealBuddy: [update_servings("meal_ribeye_summer", 4)]

Updated to 4 — bumping the ribeye and tomatoes on your list.

You: rest of the week?

MealBuddy: [find_meals(training_day="Tuesday"), find_meals(training_day="Sunday")]

For Tuesday's swim — Lemon Herb Chicken with Mediterranean quinoa.
Light, hydrating, won't sit heavy. For Sunday brick recovery — Baked
Salmon with Capers and a Greek cucumber salad on the side. Omega-3s
for inflammation, cold sides after a long brick. Cool with these for
your three cooking sessions?

[2 ASCII meal cards]

You: lock all three

MealBuddy: [lock_meal_plan, get_cooking_sessions, get_grocery_deals]

Done. Three cooking sessions, your usual rhythm — Sunday afternoon for
ribeye prep, Monday evening for chicken, Saturday morning for salmon.

[ASCII cooking sessions card]

While I have you — two things on sale this week that fit your plan.

[2 ASCII deal cards, each with [+ Add to list]]

You: add both

MealBuddy: [add_to_shopping_list × 2]

Both added to your Publix list. Locked. Three cooking sessions, lined
up with your training, peaches and asparagus added. Wes can see it.
Your nutrition coach too.
```

---

## ASCII card formats

The LLM outputs these inline in its response. The terminal renderer can optionally upgrade to `rich` panels with color, but plain text is fine. Keep cards ≤50 columns wide.

**Meal card:**

```
╭─ Meal ────────────────────────────────────────╮
│ Grilled ribeye + summer salad                 │
│ peach, tomato & basil salad on the side       │
│                                               │
│ Components:                                   │
│   • Grilled ribeye + chimichurri (main)       │
│   • Peach + tomato salad (side)               │
│   • Chimichurri (sauce)                       │
│                                               │
│ Tag: Thursday · post-hill recovery            │
│ Servings: 2  [+ to bump]  [⇄ swap]            │
╰───────────────────────────────────────────────╯
```

**Deal card:**

```
╭─ Deal ────────────────────────────────────────╮
│ Local peaches                                 │
│ 25% off — just dropped at Publix              │
│                                               │
│ Why: Already in Thursday's salad —            │
│ bump for grilled side too                     │
│                                               │
│ [+ Add to list]                               │
╰───────────────────────────────────────────────╯
```

**Cooking sessions:**

```
╭─ Your week · 3 cooking sessions ──────────────╮
│                                               │
│ ① Sunday afternoon                            │
│   • Grilled ribeye + chimichurri              │
│     (Thursday · post-hill recovery)           │
│   • Roasted summer vegetable medley           │
│                                               │
│ ② Monday evening                              │
│   • Lemon herb chicken thighs                 │
│     (Tuesday · swim day)                      │
│                                               │
│ ③ Saturday morning                            │
│   • Baked salmon w/ capers                    │
│     (Sunday · brick recovery)                 │
│   • Greek cucumber salad                      │
╰───────────────────────────────────────────────╯
```

**Final lock card:**

```
╭─ Locked ──────────────────────────────────────╮
│ ✓ All set for the week                        │
│                                               │
│ Shopping list synced for Publix               │
│ Wes can see it · Your nutrition coach too     │
╰───────────────────────────────────────────────╯
```

---

## Run

```bash
pip install anthropic rich
export ANTHROPIC_API_KEY=sk-ant-...
python main.py
```

Type `exit`, `quit`, or Ctrl-C to leave. Type `reset` to clear conversation history, reset session state, and pick a new scenario.

---

## What "done" looks like

A reviewer should be able to:
1. Set the API key
2. Run `python main.py`
3. Type `hi` and get an opener that ties weather + training + season + recovery
4. Type `something with steak but make it summery` and get a meal proposal with an ASCII meal card
5. Type `bump to 4` and see the serving update with ingredient changes
6. Type `rest of the week?` and get 2 more meal proposals tied to specific training days
7. Type `lock all three` and see the cooking sessions card, then deal cards proactively surfaced
8. Type `add both` and get a confirmation + final lock card

If 1–8 work and the conversation feels training-aware, seasonal, deal-stitched, and macro-number-free — the prototype has succeeded.

---

## Out of scope (do not build)

- Real database, real API integrations, real auth
- Real shopping list export, real coach dashboard
- Performance nutrition / fueling templates / race-day gels
- Breakfast or snacks
- Photo capture / fridge scan
- Memory editor UI
- Multi-user or persistence between sessions
- Web or mobile UI

---

## Things the implementer should decide

- Whether ASCII cards are output by the LLM inline (recommended) or returned as structured JSON the renderer expands. Both work.
- How to handle Anthropic API errors (rate limits, 5xx). Probably: retry once with backoff, fail clearly otherwise.
- How verbose tool descriptions should be. Longer = more reliable tool selection but more tokens. Aim for ~2-3 sentences per tool with one example.
- Whether to log the conversation to disk for debugging. Useful but not required.

---

## Comments / discussion threads

None found (no discussion markers returned by `notion-fetch` with `include_discussions: true`).
