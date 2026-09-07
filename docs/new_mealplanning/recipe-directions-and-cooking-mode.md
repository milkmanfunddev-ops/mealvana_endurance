# Recipe directions, media, feedback + cooking mode

_2026-09-01. Covers the `meal_library` directions backfill, the thumbs up/down signal, and
cooking mode in the prototype. The Flutter port is tracked at the bottom._

## 1. What the sources actually contained

`meal_library` cites **433 unique URLs** across 1,922 meals. They were fetched once
(`mealplanning-prototype/packages/web/scripts/fetch_recipe_sources.mjs`), cached to `.cache/source-pages/` (gitignored) and parsed
for schema.org `Recipe` objects and `og:image`.

| | result |
|---|---|
| URLs fetched | 401 ok / 32 dead or blocked |
| pages carrying schema.org recipe steps | 39 |
| recipes (of 247) whose cited page had machine-readable steps | **14** |

The headline finding: **the library's `source` field is mostly attribution, not recipes.** These
are athlete "what I eat in a day" features, forum threads and nutrition explainers that *mention*
a food. They are good provenance and bad recipes. Any future work that assumes "we have 433
recipe pages" is starting from a false premise.

The same is true of images. 367 pages have an `og:image`, but on a "Fuel Like a Pro" article that
image is a photo of the athlete, not the dinner. Only images tied to a matched schema.org `Recipe`
object were taken — hence 40 images, not 367. **Do not bulk-import `og:image` here.**

## 2. How the 1,922 meals got directions

A cascade, most-authoritative first. `meal_library.directions_origin` records which rung each row
landed on, so any subset can be redone later without re-scraping.

| origin | rows | meaning |
|---|---:|---|
| `source` | 59 | lifted from the page the meal already cited |
| `alt_source` | 14 | lifted from a different real recipe page an agent found |
| `ai_generated` | 197 | written by us from name + ingredients + prep. **UI shows a badge.** |
| `assembly_simple` | 1,651 | 2-4 assemble-and-serve steps for no-recipe meals |

`directions_verbatim` (49 rows) is the narrower claim: *these are the publisher's own words.* An
agent that adapted wording to match our ingredient list kept `origin='source'` but dropped
`verbatim` to false. That distinction is the thing to trust when deciding what is safe to
reproduce — `origin` says where an idea came from, `verbatim` says whose sentences these are.

Mechanics: `mealplanning-prototype/packages/web/scripts/export_direction_batches.mjs` splits the work into per-agent batches,
31 agents (Sonnet for recipes with a capped web-search budget, Haiku for assemblies) write JSON
into `docs/new_mealplanning/direction-results/`, and `mealplanning-prototype/packages/web/scripts/apply_agent_directions.mjs`
validates and writes. The validator rejects a whole batch on a bad `origin`, a missing
`sourceUrl` on a sourced row, or malformed steps, and skips rows that already have steps unless
`--overwrite`. All three scripts are idempotent and safe to re-run.

### Known soft spots
- Agents repeatedly found that WebSearch returns a *synthesis across sites*, not one page's text.
  Several correctly refused to tag `alt_source` on that basis and fell back to `ai_generated`
  with the technique baked in. That is the right call, and it is why `alt_source` is only 14.
- 197 `ai_generated` rows are unreviewed by a human. They are badged in the UI, but they are the
  obvious target for a quality pass.

## 3. Schema

`supabase/migrations/20260901120000_recipe_directions_media_feedback.sql` (applied to DEV):

- `meal_library`: `source_url` / `source_urls` (parsed out of the free-text `source`; 1,501 rows
  populated), `image_url` / `image_source_url` / `image_credit`, and the directions provenance
  columns above. Images stay **remote/hotlinked** by decision — copying into Storage is a later job.
- `meal_feedback`: one thumb per user per meal, RLS-owned. Written **only** through
  `set_meal_feedback()` — the uniqueness is a *partial* index, so a PostgREST upsert on those
  columns would 42P10 (see CLAUDE.md). Passing the same vote twice clears it.
- `search_meals()`: gains `my_vote` in the result set and `p_include_disliked`. A thumbs-down is
  **filtered out of suggestions**; browsing (`/food/meals`) passes `p_include_disliked: true` so
  you still see it with the thumb lit. A thumbs-up adds +0.10 to score.

## 4. Cooking mode (prototype)

`packages/web/src/routes/food.cook_.$id.tsx` → `/food/cook/$id`.

Overview (image, ingredients, AI badge) → one big step per screen → done screen that asks for the
thumb. Navigation is swipe, oversized invisible tap zones on the left/right quarters, on-screen
Back/Next, and arrow keys. Timers are parsed out of the step text itself
("for 25 mins" → a "Start 25 mins timer" chip); a range takes the upper bound. Several can run at
once, they survive step changes, and they pause/resume/cancel. The alarm is a WebAudio triple blip
plus `navigator.vibrate` — no audio asset — and the AudioContext is armed on the Start tap
because iOS leaves it suspended otherwise. `navigator.wakeLock` keeps the screen on and is
re-acquired on `visibilitychange`.

**No wave-to-advance on web.** The reference implementation is the *old Mealvana consumer app*
(`~/development/clean_directory/mealvana-frontend/lib/widgets/cooking_mode/`, ~2,600 lines) — NOT
this repo, which has never had a cooking mode. That one waved via `proximity_sensor`. Browsers
expose no proximity API, so the same job is done here with oversized tap zones. Wave comes back
only when this is built in Flutter.

Gotcha worth remembering: the tap zones are absolutely-positioned siblings, so they paint *above*
static content and silently swallow taps on the timer chips. The step content carries
`position: relative; z-index: 1` for that reason — don't remove it.

## 5. Images

**708 of 1,922 meals (37%) have a photo.** 40 came from a matched schema.org `Recipe` on the meal's
own cited page; the other 668 from **Wikimedia Commons**, which was chosen over Openverse because
Openverse caps anonymous callers at **200 requests/day** — unusable for 1,900 lookups without a
registered token. Commons is keyless, uncapped in practice, and hands back machine-readable licence
metadata. Everything stored is openly licensed: 318 CC0/public-domain, the rest CC-BY/CC-BY-SA,
with `image_license`, `image_creator` and a linked credit rendered on the card — CC-BY *requires*
visible attribution, so the caption is load-bearing, not decoration.

`mealplanning-prototype/packages/web/scripts/find_meal_images.mjs`. The whole difficulty is query reduction and precision:

- "Steel-cut oats with peanut butter & blueberries" matches nothing; "Steel cut oats" matches
  plenty. Queries step down: full name → head phrase before "with"/"&" → last two content words →
  primary component. The winning query is stored in `image_match_query`, because **a wrong photo
  is almost always a wrong query.**
- Matching is deliberately strict, and each rule below exists because of a real false positive:
  every content word must appear in the **file title** (not the description — "Overnight oats,
  plain" matched a photo of a grassy *plain*), **in order and within 3 words** ("Cream of Wheat"
  matched "Honey **Wheat** Bread with **Cream** Cheese"), the file must read as food somewhere, and
  scans/artwork/adverts are excluded ("Cream of Wheat (1907) (ADVERT 446)").
- Photo reuse is a ranking **penalty, not a veto**. A hard cap of 6 was tried first and cost ~330
  meals, which got nothing at all once a generic "toast" photo was used up. A slightly-repeated
  correct photo beats a blank card.

The 1,214 meals with no photo are mostly assembly combinations that simply have no Commons
equivalent ("Rice cakes with cottage cheese & tomato"). **All 1,214 already have an `icon`**, so no
card is ever blank — and pushing a vaguer photo would be worse than the icon. Raising coverage
further realistically means a licensed stock API (an Openverse token, or a paid source), not more
scraping.

## 5b. Flutter port — not started, and bigger than it sounds

Cooking mode and the thumbs exist only in the prototype. A survey of `lib/` found that the port is
**not** "move a widget across":

- There is **no meal/recipe/assembly detail screen in the Flutter app at all.** The nearest thing
  is a log-a-recipe bottom sheet (`recipe_picker_screen.dart`) showing name + scaled macros, which
  does not even render `Recipe.ingredients` / `.instructions` although the model carries them.
- **No Dart code reads `meal_library`.** `grep meal_library|search_meals|library_meal_id lib/`
  is empty. The whole library is remote-only; `saved_meals` is the only meal table with a Drift
  mirror and sync wiring.
- `wakelock_plus`, `proximity_sensor`, an audio package and `vibration` are all **absent** from
  `pubspec.yaml`. Drift is at `schemaVersion = 17`.
- `Recipe.isFavorite` exists but is hardcoded `false` — a dead MVP stub, not a mechanism. A port
  must decide explicitly whether the thumb rides on the new `meal_feedback` table (a quality
  signal) or the existing `saved_meals` favourite (a save-to-relog action). They are different
  things and should not be conflated.

So the Flutter work is: a meal_library repository (+ maybe a Drift table and a schema bump), a
detail screen built from scratch, cooking mode, and four new packages. That is a feature surface,
not a port — and it would freeze the prototype's still-moving design into the shipping app.
Worth doing deliberately, as its own piece of work.
