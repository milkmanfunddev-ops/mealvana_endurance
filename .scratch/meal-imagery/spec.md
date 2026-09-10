# Meal imagery: show the meal, or show nothing

Status: ready-for-agent
Created: 2026-09-10

## Problem Statement

An athlete opens the Meals tab to choose what to eat. Most Meals show a picture. A good number of
those pictures are not of that Meal.

"Bircher-style oats with peach, cherries & coconut" is a photograph of cherries. "Sprouted
multigrain porridge" is a photograph of clear water running over pebbles — one of fifteen Meals
represented by that same picture of water. A cherry ice cream would be shown as a cherry beside a
tub of ice cream, which describes the shopping list rather than the food. Judged against the Meals
they stand for, 47.5% of Mosaics are actively misleading and only 7.5% are good.

The library reports 94.5% image coverage, and that number is how the problem stayed invisible: it
counts a picture of water as a covered Meal. Only 36.8% of Meals have a Dish photo. The rest wear
ingredient Tiles, including 197 of the 247 Recipes — the very Meals most likely to have a real
photograph somewhere.

Nothing in the pipeline could have caught this. Vision verification asks "is this a cherry?" and a
good photograph of a cherry passes. Nothing has ever asked "does this picture represent this Meal?"

The athlete's cost is trust. A picture beside a name is a promise about what arrives on the plate,
and a Meal that breaks that promise makes every other picture in the list worth less.

## Solution

Stop measuring coverage and start measuring honesty.

Every Meal either shows an image that a judge, looking at the composed picture the app actually
draws, rates as representing that Meal — or it shows the icon and is flagged in the database for
someone to look at. No Meal shows a picture rated wrong.

Three things make that possible.

**A Meal is judged on what the athlete sees.** A new pass renders the Mosaic exactly as the app
composes it and asks whether that picture represents the Meal, rather than asking whether each Tile
matches its ingredient.

**Some Meals can never be told by their parts.** A Meal is *Separable* when its named components
stay individually recognisable in the finished dish, and *Transformed* when cooking, blending or
baking has made them stop looking like themselves. Only a Separable Meal may wear a Mosaic. This
cuts across Recipe and Assembly: a smoothie has no method steps and is Transformed; a grain bowl may
have a dozen and stays Separable.

**A Meal with nothing honest to show, shows nothing.** It keeps its icon so the row does not go
ragged, and it is flagged so the population is countable and shrinkable over time.

The athlete sees fewer pictures and can believe the ones that remain.

## User Stories

1. As an athlete browsing the Meals tab, I want the picture beside a Meal to be a picture of that
   Meal, so that I can choose food by looking rather than by reading every name.
2. As an athlete, I want a Meal with no honest picture to show a plain icon, so that I am not misled
   by a picture of something else.
3. As an athlete, I never want to see a photograph of an unrelated ingredient standing in for a
   whole Meal, so that "cherries" does not mean "Bircher oats with four other things in it".
4. As an athlete, I never want to see a photograph of water, salt or cooking oil representing a
   Meal, so that the list does not look broken.
5. As an athlete looking at a blended Meal, I want either a photograph of the finished drink or no
   picture at all, so that I am not shown its ingredients as though I would see them in the glass.
6. As an athlete, I want a Recipe to show the cooked dish wherever such a photograph can be
   obtained, so that I know what I am aiming at before I start cooking.
7. As an athlete, I want two different Meals in the same rail to not share one photograph, so that
   the list does not read as though it is repeating itself.
8. As an athlete scrolling a rail where several Meals have no picture, I want the icons to look
   deliberate, so that the rail reads as designed rather than as failing to load.
9. As an athlete, I want a Mosaic's cells to be ingredients rather than finished dishes, so that a
   four-cell grid reads as one Meal's parts rather than as four different Meals.
10. As an athlete on a slow connection, I want a Mosaic whose Tile fails to load to re-flow into the
    next legal grid, so that I never see a broken-image gap.
11. As an athlete, I want the photographer credited where the picture is shown at size, so that the
    people whose work this is are named.
12. As an athlete, I want to reach the photographer's page from the credit, so that I can find more
    of their work and so the licence is genuinely honoured.
13. As a maintainer, I want every Meal's current picture to carry a recorded verdict, so that I can
    ask how many Meals are showing something wrong without looking at them one by one.
14. As a maintainer, I want the Meals with nothing to show flagged in the database with a reason, so
    that I can work the list down instead of rediscovering it.
15. As a maintainer, I want to know which of those Meals are blocked because a Mosaic would lie and
    which because no Tile exists, so that I spend effort where it can actually help.
16. As a maintainer, I want the honesty measure to be a single number I can re-run, so that I can
    tell whether a change helped.
17. As a maintainer, I want a Separable/Transformed verdict stored per Meal rather than recomputed,
    so that it is auditable and I pay for it once.
18. As a maintainer, I want the ladder rules in one place I can read and test, so that a rule change
    is a code change rather than an archaeology exercise.
19. As a maintainer, I want to re-run the whole assignment from scratch at any time and get the same
    answer, so that a partial run never leaves the library in a half state.
20. As a maintainer, I want an ingredient whose photograph was rejected to be retried with a
    different candidate rather than left stuck, so that a bad first pick is not permanent.
21. As a maintainer, I want an ingredient that has been retried several times without success to
    stop being retried, so that a hopeless slug does not consume every future run.
22. As a maintainer, I want stock-photo searches to ask for the food rather than the bare word, so
    that "chicken" does not return a live bird and "salt" does not return a beach.
23. As a maintainer, I want the pictures judged before they are accepted rather than after, so that
    a bad picture never reaches the library in the first place.
24. As a maintainer, I want to know whether Dish photos are any good, so that I am not assuming the
    36.8% that already exists is fine.
25. As a maintainer, I want the strictness of the Tile bank to be a setting I can turn on after
    seeing the numbers, so that I trade coverage for honesty deliberately.
26. As a maintainer, I want the unlicensed blog hotlinks flagged rather than deleted while the
    library is a prototype, so that the debt is visible without costing effort now.
27. As a maintainer, I want a query that fails if unlicensed pictures still exist, so that they
    cannot reach production by being forgotten.
28. As a maintainer, I want the pipeline's cost per full run stated up front, so that I can decide
    whether to run it.
29. As a maintainer, I want each pass to be resumable and idempotent, so that a killed run costs
    time rather than correctness.
30. As a maintainer, I want the documentation to state the honest numbers, so that the next person
    does not inherit the 94.5% claim.
31. As a developer, I want the ladder rules covered by tests that need no network and no model, so
    that I can change a rule with confidence.
32. As a developer, I want the mapping from a library row to a renderable Meal covered by tests, so
    that image data cannot silently stop reaching the app again.
33. As a developer, I want a small set of hand-labelled Meals to run the judge against, so that a
    prompt change that makes it worse is visible.
34. As a developer, I want the picture the judge sees to be the picture the app draws, so that we
    are not paying to grade an artefact no athlete will ever see.

## Implementation Decisions

### The measure

The success measure is not coverage. It is: **every Meal either shows an image whose recorded
verdict is `ok`, or carries the blocked flag with a reason; and no Meal shows an image whose verdict
is `wrong`.** Coverage as previously reported counted a picture of water as a covered Meal and is
retired as a headline number.

### Schema

Already applied to dev, recorded in migrations, not yet on production:

- `meal_library.separability` (`separable` | `transformed`), with reason and timestamp.
- `meal_library.image_verdict` (`ok` | `weak` | `wrong`), with reason and timestamp.
- `meal_library.image_blocked` — the ladder found nothing honest to show. Reported, not rendered.
- `meal_library.image_unlicensed` — hotlinked from a food blog with no recorded licence.
- `ingredient_images.rejected_urls` and `attempts` — so a retry cannot re-pick a known-bad picture,
  and a hopeless slug eventually stops.

### The ladder

A Meal resolves to exactly one Image mode:

- **dish** — a Dish photo exists. Always wins; a Mosaic never beats a photograph of the Meal.
- **mosaic** — the Meal is Separable and two to four Tiles are available.
- **tile** — the Meal is Separable and genuinely *is* one ingredient. A single Tile for a Meal of
  several parts is not permitted: it looks like a picture of the Meal and is a picture of a fifth of
  it.
- **none** — everything else. The card keeps its icon; `image_blocked` is raised with a reason.

Seasonings, oils and liquids are excluded from Tile candidacy outright rather than ranked last.
Ranking them last still let them through when nothing else remained, which is how fifteen Meals came
to be represented by a photograph of water.

A Transformed Meal takes a Dish photo or nothing. It never takes Tiles.

### The passes

The pipeline is a resumable, idempotent sequence of numbered passes. Each is safe to re-run and
recomputes from scratch where it can.

- **Separability** classifies from name and ingredients only — no image is fetched and none is
  needed, because "cherry ice cream" tells you the cherries are gone. Batched, stored once.
- **Bank verification** looks at a Tile and asks whether it shows its ingredient. It gains a strict
  mode that fails a composed dish outright: a bowl of porridge is not a photograph of oats, and a
  cell showing a finished dish makes a grid read as several different Meals. Strict mode ships
  **off**; turning it on is a gated decision, because on sample it rejects roughly a quarter of the
  bank and the rejections are concentrated in its most-used Tiles.
- **Meal-image judging** renders the picture the app composes and rates it `ok` / `weak` / `wrong`
  against the Meal's name and ingredients. This is the measure; it is also the acceptance test for
  any newly sourced picture.
- **Retry** returns a rejected Tile to pending while recording the URL that failed.
- **Dish-photo sourcing** (new) searches licensed stock by *dish name* rather than by ingredient, for
  Meals a Mosaic cannot serve, and submits every candidate to the judge **before** accepting it.

### Ordering, and the gate

Measurement comes first. The full judging sweep runs over the whole library before any strictness
decision is taken, because the Dish photos have never been judged at all and the strategy depends on
whether they are good. The sweep's output — verdict counts per Image mode — is the input to a single
human decision: strict bank on or off. Work on the Tile bank is conditional on that decision; work on
Dish photos is not, and is the larger piece either way.

### Query construction

Stock-photo search is literal in a way the archives are not. Ingredient searches ask for the food,
not the bare word. Dish-photo searches use the Meal's name. Ranking continues to score candidate
titles against the plain ingredient or dish name, so the qualifier steers the search without skewing
the match.

### Models and spend

Judging runs on a frontier model because the judgement is subtle — the cheaper model's blind spot is
exactly this class of error. Bank verification stays on the cheap model, where the question is
narrow. A full library sweep is single-digit dollars; the fetch passes are bounded by provider rate
limits rather than by concurrency, and a few dozen ingredients take tens of minutes.

Nothing in this pipeline generates an image. Verification and selection only.

### Licensing

Per-provider mirroring rules are unchanged: archive material is mirrored into our own storage,
stock-photo providers are hotlinked because their terms require serving from their CDN. Attribution
travels with every picture. Credits become links naming both photographer and platform, which is
also the outstanding requirement for stock-provider production access.

The unlicensed blog hotlinks stay for now, flagged, with the production gate recorded beside them.

### Compositor parity

The judging pass renders Mosaics in a second language, mirroring the shared widget's grid geometry.
Nothing currently enforces that the two agree, and drift means paying to grade an artefact no athlete
sees. Recorded here as a known risk; the cheap mitigation is a shared geometry fixture both sides
assert against, and it is a decision rather than a default.

## Testing Decisions

A good test here asserts what a Meal ends up showing, not how the code got there. It should survive
renaming a function, moving a script, or swapping a provider. Tests that build the expected value
with the same call the code under test uses are equal by construction and cannot fail — the seam
rules in the testing README apply directly.

**Primary seam (new): the ladder decision.** The rules currently live inline in the assignment pass,
tangled with PostgREST reads and writes. Extract them into a pure function taking a Meal and the Tile
bank and returning the resolved mode, tiles, blocked flag and reason. Everything agreed in the design
becomes one assertion with no network, no model and no database:

- a Dish photo wins over any number of available Tiles;
- a Transformed Meal with Tiles available still resolves to none, blocked;
- a Meal whose only candidate is a seasoning, oil or liquid resolves to none, not to that Tile;
- a one-ingredient Meal with one Tile resolves to tile;
- a five-ingredient Meal with one Tile resolves to none, blocked, and says why;
- a Separable Meal with two to four Tiles resolves to mosaic, capped at four, in principal-ingredient
  order;
- re-running against the same inputs produces the same output.

**Existing seam (reuse): the library row to renderable Meal mapping.** Already covered by tests added
alongside this work. Extend rather than duplicate: a row carrying a Dish photo, a row carrying Tiles,
a row carrying neither, a row missing the image columns entirely, and a malformed Tile with no URL.
This is the seam where the mosaics-invisible bug lived — the columns were returned and never read —
so it earns permanent coverage.

**Not unit-tested: the model passes.** Separability, bank verification and Meal-image judging are
model calls. A unit test would assert the mock. Instead they get a small hand-labelled fixture set —
Meals and Tiles with known-correct verdicts, including the cases that motivated the design (a
smoothie, a cherry ice cream, a composed dish used as an ingredient Tile, a photograph of water) —
run on demand to catch a prompt change that makes the judge worse. This is an eval, not a seam, and
it is expected to be run by a person deciding whether a prompt edit helped.

**Prior art.** The seam rules and the producer-shaped-fixture discipline are in the testing README.
The mosaic widget already has component tests covering grid selection, cover-fit, failure re-flow and
attribution construction; the ladder tests are their data-side counterpart and should not duplicate
them.

## Out of Scope

- **Removing or replacing the unlicensed blog hotlinks.** Deliberately deferred while the library is
  a prototype. Flagged, gated for production, not actioned here.
- **Asking recipe sites for permission to use their photographs.** A business conversation, not a
  build. Until someone has said yes, sourcing draws on licensed stock only.
- **Generating images.** Selection and verification only.
- **Executing the production cutover.** The migrations exist and are dev-applied; sequencing
  production is the deploy playbook's job and a separate bundle.
- **The design spec's approval.** The Mosaic component spec remains PROPOSED pending review.
- **The missing-user-row blackout.** A signed-in athlete with no profile row currently sees no
  library Meals at all, because allergies are a hard filter and failing open would surface allergens
  to someone whose profile could not be read. A real problem, a separate decision, unrelated to
  imagery.
- **Redesigning the meal card or rail.** Beyond the no-duplicate-photo rule and the icon state.

## Further Notes

The gap between the reported 94.5% and the honest number is the work, not a regression. Applying the
ladder rules alone moved the library from 1,816 Meals "covered" to around 1,540 showing something
defensible, and that fall is the point: 244 Meals stopped claiming that a photograph of one
ingredient was a photograph of the Meal.

Two findings shaped this design and are worth carrying forward. The first is that the failure was
invisible to every check that existed, because each check was asking a narrower question than the one
that mattered. The second is that the biggest remaining population — Meals a Mosaic can never serve —
cannot be fixed by any amount of ingredient fetching. That is roughly 170 Transformed Meals plus the
Recipes still wearing Tiles, and it is the centre of gravity of the remaining work.

Retry rounds recover roughly two in five stuck ingredients, and the recovery rate did not improve
much when the search queries were corrected, which suggests the ceiling is the stock libraries
themselves rather than how we are asking. Plan on the Dish-photo path carrying more of the library
than the Tile path does.
