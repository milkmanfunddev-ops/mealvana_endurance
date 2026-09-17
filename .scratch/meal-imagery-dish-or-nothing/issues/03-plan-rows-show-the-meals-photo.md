# 03: Plan rows show the Meal's photo

**What to build:** An athlete's plan tiles, plan bar and review sheet show the same Dish photo the
Meal shows on the Meals tab, or nothing. A photo added to a Meal later reaches plans already made,
because the plan looks the photo up from the library Meal. It is never copied onto the plan
row. This follows Lee's "everywhere" ruling and answers open question mp-324, which stays open on
the page for Lee to close.

**Blocked by:** 01

**Status:** done (2026-09-16) — simulator check owed

- [x] The plan read returns each plan meal's library Meal's current photo (address, credit,
      credit link), joined by meal id. No picture fields are added to plan meal rows, and add and
      swap paths are unchanged.
- [x] A plan meal whose Meal isn't in the library, such as a saved-only meal with no library
      link, shows nothing.
- [x] Plan tiles, the plan bar and the review sheet show the photo or no picture slot, with the
      same rule and collapse-on-failure as ticket 01.
- [x] Tests feed plan payloads shaped like the server's through the real mapping into the plan
      widgets, covering with photo and without. Plan goldens are regenerated.
- [ ] Checked on the simulator: a plan containing a Meal with an `ok` photo shows it on its tile.

## Comments

**2026-09-16 — implemented.** Everything but the simulator check is done and verified.

- A plan row's picture is its **library Meal's** current Dish photo, looked up by meal id and
  never copied onto the plan row. `meal_library` gained nothing; `plan_meals` gained nothing; the
  add and swap paths are untouched. The new read is one method,
  `MealLibraryRemoteDataSource.photosForMeals`, selecting only `id` and the three photo columns
  for the ids a plan actually holds.
- The join is a **second read, not a join inside the plan read**. The plan read is a local Drift
  watch (offline-first), so there is nothing server-side to join to. The spec's load-bearing half
  — "never copies it onto the plan row" — holds. Consequence worth your eye: **offline, a plan
  shows no photographs at all**, because nothing is mirrored locally. Story 10 says a meal looks
  the same wherever it is met; offline it looks like a meal with no photo.
- `planPhotoSlotsFor` (domain) answers one map, keyed by plan-meal id, that all three surfaces
  read, so a meal cannot differ between the tile, the bar and the review sheet. The three
  surfaces share one line — `ref.planPhotoSlots(meals)` — so the lookup lives in one place.
- A failure stays a failure: it rides in the `AsyncValue`, and the surfaces draw no picture until
  an answer arrives. The plan itself renders from Drift and never waits on the library, so an
  outage costs the pictures, not the plan. There is a test for exactly that.

**Two design decisions reversed by `/code-review`, both worth knowing:**

1. **The no-repeat rule is NOT applied to plan rows.** I first carried ticket 01's "two Meals in
   one list never wear the same photograph" across the plan. The Spec axis was right that this was
   never asked for and contradicts story 10 ("the same Dish photo on the Meals tab, plan tiles,
   plan bar, review sheet"). The case that settles it: a plan holding one Meal **twice** is
   ordinary — that is what batch cooking is — and suppression blanked the second row's photo.
   It was also order-dependent in a way nobody could predict: the review sheet resolves in plan
   order but renders grouped by cooking session, so the *visibly* first of two rows could be the
   blank one. Every row now shows its own Meal's photo. Two tests pin it.
2. **The lookup is no longer `keepAlive`.** With `keepAlive: true` and nothing invalidating it, a
   photo added mid-session never reached an open plan — story 13 ("a new Dish photo to appear the
   next time the Meal is fetched") was not satisfied, and each plan composition left a cache entry
   that was never disposed. It now lives while a plan surface watches it and is dropped when none
   does, so returning to a plan re-reads. **Owed by tickets 05/06:** the Tester's photo controller
   should invalidate `planMealPhotosProvider` on a successful write, so a Tester sees their own
   photo without leaving the screen.

**Verified:** `flutter analyze` clean on every touched file. 9 domain tests and 5 seam tests new
and green. Full suite **5041 pass / 4 skip / 2 fail** — both failures pre-existing and unrelated
(`create_flow_fueling_controls_conformance_test` CF-2, and `ci_config_contract_test`, which reads
only `codemagic.yaml` and the self-hosted workflow). The 23 meal-planning goldens pass
**unchanged**.

**Owed / for Lee:**

- **No golden pins a photo-bearing plan row.** The plan goldens provably cannot move: the frozen
  `contract-v1` plan fixtures carry no `library_meal_id` at all, and the golden host overrides
  only the content service, so the lookup has no photo source. Nothing needed regenerating, and
  all 23 pass. But that also means no golden covers what this ticket added; the widget test pins
  the layout instead (the photo-bearing row's name is inset past the rows without one). Adding
  such a golden means changing a frozen fixture — your call.
- **mp-324 stays open on the page**, as the ticket says. This build answers it in line with the
  "everywhere" ruling: plan rows show the library Meal's photo, joined by id, with no picture
  fields on the plan row.

**Committed `c714dae7`** (code and tests only; this ticket file and the feature's spec stay
untracked, as tickets 01 and 02 left them).

**The simulator check is NOT done, and the machine is why.** Two builds that were not this
session's held the Mac — a `flutter run` to Lee's physical iPhone with an `xcodebuild … -sdk
iphoneos … clean build`, and an `xcodebuild build-for-testing … PATROL_ENABLED` (Patrol). By the
time they died, swap was 23.6 GB of 24.6 GB used with ~15 MB of free pages and load average 21,
so starting an iOS build would likely have OOM-ed and taken Lee's own build with it. Not started.

**Dev is seeded so the check is one screen.** Plan `6e167344` (confirmed, week 2026-09-13 — the
current period for the dev athlete `607f9dd5`) now holds both halves:

| position | row | expected |
|---|---|---|
| 0 | Egg & Veggie Scramble — saved, `library_meal_id` null | **no picture at all**, row starts at the name |
| 1 | Thai peanut lentil-pasta salad — `L-041`, dish/`ok` | **the photo**, plus its credit on the recipe screen |

L-041's address was checked live: `HTTP 200`, `image/jpeg`, 681 KB. Its credit is "Photo on
featherstonenutrition.com" and it links the recipe page. D-048 Bolognese, the other photo-bearing
plan Meal on dev, is unusable here — its `excluded_diets` includes `vegetarian`, so `search_meals`
hard-filters it for this athlete.

To run it: `./scripts/run_dev.sh -d <booted-udid>` (dev flavour, `IS_INTERNAL=true`), then
`! scripts/sim-dev-login.sh`, then pull-to-refresh the Plan tab — the row was written server-side,
and the plan is offline-first, so it arrives on a sync. Do not pipe a `flutter run` through `tail`
in a background task: `tail` buffers to end-of-stream, so the log stays empty and nothing can
watch it (that cost this session a blind build).

Row `657c0888-100d-446d-bf2c-cb8200e44ca7` was inserted by hand for this check. Undo with
`delete from plan_meals where id = '657c0888-100d-446d-bf2c-cb8200e44ca7';` — it is left in place
so the check is ready to run.

**2026-09-17 — Lee's rulings.**

- **Offline, plan rows show no photos — accepted.**
- **No golden for a photo-bearing plan row — accepted.** The widget test pinning the layout is
  enough; the frozen `contract-v1` fixtures stay frozen.
- **mp-324 closed.** Lee asked for it to be closed: new card **mp-418** "Plan rows show the library
  Meal's photo" was added and approved in his name through `sync.mjs apply`, and `sync.mjs answers
  mp-324 mp-418` marked the question answered.
