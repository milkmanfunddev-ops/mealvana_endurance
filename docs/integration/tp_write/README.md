# TrainingPeaks Write-Back: Nutrition Plan Integration

## Overview

Push Mealvana nutrition plans to upcoming TrainingPeaks workouts so athletes see their fueling strategy directly in their training calendar.

**Goal**: Ultra-concise, non-intrusive, fully manageable nutrition annotations on TP workouts.

**Trigger**: Automatic after nutrition plan generation (user can toggle off in settings).

---

## API Capabilities We Have

| Scope | Endpoint | Method | Status |
|-------|----------|--------|--------|
| `workouts:plan` | `/v2/workouts/plan/{workoutId}` | PUT | Granted |
| `workouts:details` | `/v2/workouts/{athleteId}/id/{workoutId}/comment` | POST | Granted |
| `workouts:read` | `/v2/workouts/{startDate}/{endDate}` | GET | In use |
| `nutrition:write` | `/v1/athletes/{athleteId}/nutrition` | POST | In use |

### Critical API Constraint

**PUT on workouts is full object replacement.** Any field sent as `null` overwrites the existing value. We MUST read the full workout object first, merge our changes, then PUT back.

### Comment Limitation (Confirmed via API Discovery)

TP comments are **append-only**. Confirmed by probing all endpoint patterns (see [`api_discovery_results.md`](api_discovery_results.md)):
- **POST** (create): Works
- **GET** (read): Endpoint exists (returns 401 without auth)
- **PUT/PATCH** (update): **Does not exist** (404 on all patterns)
- **DELETE** (remove): **Does not exist** (404 on all patterns)

This means we cannot edit or remove comments once posted. If a plan changes, stale comments would accumulate with no way to clean them up.

---

## Recommended Approach: Description Field (Delimited Block)

Given the comment API limitation, we use the **workout description field** with a clearly delimited, compact nutrition block appended to the end.

### Why Description Over Comments

| | Description Field | Workout Comments |
|---|---|---|
| Create | Yes (PUT) | Yes (POST) |
| Update | Yes (read-merge-PUT) | No |
| Delete | Yes (read-strip-PUT) | No |
| Risk | Must preserve existing content | No risk to existing content |
| Visibility | Inline with workout | Separate comment thread |

**Description wins** because the user requirement is: "if the nutrition plan changes, we need to edit/delete/add." Comments can't do this.

### Safety Protocol (Preserving Coach Content)

```
1. GET /v2/workouts/{startDate}/{endDate}  → read full workout object
2. Extract existing Description field
3. Find Mealvana block (between delimiters) if present
4. Replace block OR append new block at end
5. PUT /v2/workouts/plan/{workoutId}       → send COMPLETE object with ALL original fields preserved
```

**Delimiter format:**
```
\n---\n[Mealvana Fuel Plan]\n{content}\n[/Mealvana]\n
```

This is:
- Easy to parse programmatically
- Clearly branded so coaches know the source
- Self-contained (everything between delimiters is ours)

---

## Format Design: Ultra-Concise

### What Fuelin Gets Wrong (Per User Feedback)

Coaches report Fuelin writes verbose, paragraph-style nutrition instructions that clutter workout descriptions. Athletes don't need a wall of text - they need numbers at a glance.

### Our Format: Compact Table Style

**Example - 90min Easy Run:**
```
---
[Mealvana Fuel Plan]
Pre: 60g carb, 16oz water (2h before)
During: 45g/h carb, 20oz/h water, 1 salt cap/h
Post: 30g protein, 60g carb within 30min
[/Mealvana]
```

**Example - 3h Long Run:**
```
---
[Mealvana Fuel Plan]
Pre: 80g carb, 16oz water (2-3h before)
During: 60g/h carb, 24oz/h water, 1 salt cap/h
Post: 40g protein, 80g carb within 30min
[/Mealvana]
```

**Example - Short Run (<60min):**
```
---
[Mealvana Fuel Plan]
Pre: 40g carb, 12oz water (1h before)
During: Water only
Post: Optional - 20g protein
[/Mealvana]
```

### Format Rules

1. **3 lines max** (Pre / During / Post) - never more
2. **Numbers first** - lead with grams and ounces, not food names
3. **No food names** - just macro targets (the app has the details)
4. **Rate format for during** - always per-hour (g/h, oz/h)
5. **Timing cues only when actionable** - "(2h before)", "within 30min"
6. **Respect units** - use athlete's preferred units (g/kg, oz/ml) from TP profile or Mealvana settings
7. **Skip phases that don't apply** - if no during fueling needed, just show Pre and Post

### What We Intentionally Exclude

- Specific food item names (too verbose, changes often)
- Calorie totals (athletes think in macros, not calories)
- Scientific explanations (save for the app)
- Hydration schedules broken down by time segment
- Supplement details beyond salt/electrolytes

---

## Data Flow

```
Nutrition Plan Generated
        |
        v
Is TP connected? ──No──> Done
        |
       Yes
        |
        v
Is TP write-back enabled? ──No──> Done
        |
       Yes
        |
        v
Does this activity have a TP workout ID?
        |                          |
       Yes                        No──> Done
        |
        v
GET workout from TP (full object)
        |
        v
Extract Description field
        |
        v
Has existing [Mealvana] block?
        |                    |
       Yes                  No
        |                    |
        v                    v
    Replace block      Append block
        |                    |
        v                    v
PUT full workout object back to TP
        |
        v
Store write-back metadata locally:
  - workout_id
  - last_pushed_at
  - plan_hash (to detect changes)
```

### On Plan Update

```
Plan regenerated for same activity
        |
        v
Compare plan_hash with stored hash
        |              |
    Same ──> Skip    Different
                        |
                        v
                  Run write-back flow
                  (replaces existing block)
```

### On Plan Deletion

```
User deletes nutrition plan
        |
        v
Has write-back metadata? ──No──> Done
        |
       Yes
        |
        v
GET workout from TP
        |
        v
Strip [Mealvana] block from Description
        |
        v
PUT cleaned workout back to TP
        |
        v
Delete local write-back metadata
```

---

## Settings

### User-Facing Toggle

**Location**: Settings > Integrations > TrainingPeaks

```
TrainingPeaks Write-Back
[ Toggle: ON/OFF ]

When enabled, your nutrition plan summary is
automatically added to your TrainingPeaks workouts.
```

Default: **OFF** (opt-in to avoid surprising users)

### Stored Preferences

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `tp_writeback_enabled` | bool | false | Master toggle |
| `tp_writeback_unit_system` | enum | auto | auto (from TP profile), metric, imperial |

---

## Local Storage

### Write-Back Tracking Table (Drift)

```sql
CREATE TABLE tp_writeback_log (
  id TEXT PRIMARY KEY,           -- UUID
  user_id TEXT NOT NULL,
  activity_id TEXT NOT NULL,     -- Our local activity ID
  tp_workout_id INTEGER NOT NULL,-- TP's workout ID
  plan_hash TEXT NOT NULL,       -- Hash of the nutrition summary we pushed
  pushed_at TEXT NOT NULL,       -- ISO8601 timestamp
  status TEXT NOT NULL,          -- 'active', 'removed', 'failed'
  UNIQUE(user_id, tp_workout_id)
);
```

This table lets us:
- Know which workouts have our content (for cleanup)
- Detect when a plan changed (hash comparison)
- Track failures for retry
- Clean up on disconnect (remove all Mealvana blocks)

---

## Edge Cases

### Coach Edits Description After We Write

Our block is at the END of the description. If a coach edits the description (above our block), our delimiters remain intact. On next update, we find our block by delimiters and replace only our section.

### Workout Gets Deleted in TP

PUT will return 404. We log the failure, mark the write-back record as stale, and move on. No retry needed.

### User Disconnects TrainingPeaks

On disconnect, we should:
1. GET all workouts with active write-back records
2. Strip Mealvana blocks from each
3. PUT cleaned workouts back
4. Delete all write-back records

This is a courtesy cleanup - not blocking the disconnect if it fails.

### Rate Limiting

TP API rate limits are not publicly documented. We should:
- Batch write-backs (don't push every plan individually)
- Add 500ms delay between consecutive PUTs
- Max 10 write-backs per sync cycle
- Retry failed writes on next app open

### Premium-Only Constraint

Basic TP athletes cannot have planned workouts modified (403 error). We should:
1. Attempt the write
2. On 403, disable write-back for this user
3. Show info message: "TP write-back requires a Premium account"

---

## Implementation Phases

### Phase 0: API Discovery - COMPLETED (2026-03-01)

Tested all comment CRUD endpoint patterns against production API. Full results: [`api_discovery_results.md`](api_discovery_results.md)

**Findings:**
- `POST /v2/workouts/{athlete}/id/{workout}/comment` - **Works** (create)
- `GET /v2/workouts/{athlete}/id/{workout}/comment` - **Exists** (401 = needs auth, returns comments)
- `PUT` on any comment path - **404** (does not exist)
- `DELETE` on any comment path - **404** (does not exist)
- `PUT /v2/workouts/plan/{workoutId}` - **Exists** (for description updates)

**Decision: Use Description field approach.** Comments are append-only (no edit/delete), making them unsuitable for nutrition plans that change. The description field gives us full CRUD via the workout plan PUT endpoint.

**Discovery script** at `tools/tp_comment_discovery.dart` is available for authenticated testing when a fresh token is available (will confirm GET response structure and test Description PUT end-to-end).

### Phase 1: Core Write-Back (MVP)

- [ ] Add `tp_writeback_log` Drift table
- [ ] Create `TrainingPeaksWriteService` with read-merge-write logic
- [ ] Implement delimiter-based block parsing (add/replace/strip)
- [ ] Wire into nutrition plan generation flow
- [ ] Add settings toggle (default OFF)
- [ ] Handle 403 (premium check)

### Phase 2: Lifecycle Management

- [ ] Plan update detection (hash comparison)
- [ ] Plan deletion cleanup (strip block from TP)
- [ ] TP disconnect cleanup (strip all blocks)
- [ ] Retry logic for failed writes
- [ ] Rate limiting

### Phase 3: Polish

- [ ] Unit preference sync from TP profile
- [ ] Batch operations for multiple upcoming workouts
- [ ] Analytics: track write-back usage
- [ ] Coach mode: allow coaches to push plans for athletes

---

## Open Questions

1. **What happens to our block if TP truncates long descriptions?** - Need to test max description length.

2. **Should we write to ALL upcoming workouts with plans, or only the next N?** - Recommend: next 7 days of workouts with plans.

3. **Metric vs Imperial** - TP profile may specify units. Should we match, or always use the athlete's Mealvana preference?
