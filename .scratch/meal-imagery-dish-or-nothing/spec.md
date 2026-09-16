# Meal imagery: a Dish photo or nothing

Status: ready-for-agent

Decision record: `docs/adr/0003-a-meal-shows-a-dish-photo-or-nothing.md`. Vocabulary: `CONTEXT.md`
(Meal imagery: Dish photo, Tester, Tile, Mosaic, Image mode, Verdict, Judge).

## Problem Statement

Most Meals in the library have no photograph of the dish. The app fills that gap with Mosaics: two
to four ingredient photos in one frame, followed by a credit line for each one. On a device they
don't look like the meal. The salmon, quinoa, asparagus and spinach salad shows raw salmon, a
tabbouleh bowl and a blurred jar of leaves, with three credits underneath. An athlete can't tell
what they'll eat, and the screen looks cluttered.

The team also can't fix a picture. Pictures come from an offline pipeline, so a tester who has just
cooked a recipe has no way to give it a real photo.

## Solution

A Meal shows one Dish photo or nothing. Mosaics, single ingredient Tiles and placeholder boxes are
no longer shown anywhere. Where a Meal has no Dish photo, the picture's space isn't drawn at all.

A Dish photo is one image address, pointing at our storage or at the web, with an optional credit
line. At switchover, a Meal keeps its current picture only if that picture is a Dish photo with an
`ok` Verdict. That's 170 Meals on dev.

Testers keep the photos. A Tester is anyone who turned on "Mark this device as internal" in Settings
(tap the version seven times). On the recipe screen, a Tester sees a small entry point that athletes
never see. It opens a Meal photos page where the Tester can:

- take or choose a photo, crop it, preview it and confirm it;
- paste a web address, preview it and confirm it;
- add a credit;
- remove the current photo;
- restore or delete a photo in the Meal's History.

The newest confirmed photo shows to every athlete, everywhere that Meal's picture appears.

The image pipeline is frozen. Its scripts are archived, and everything it wrote stays in the
database so Mosaics can come back later.

## User Stories

### Athletes seeing Meals

1. As an athlete, I want a Meal with a Dish photo to show it on its card, so that I can recognise
   the meal while scanning a list.
2. As an athlete, I want a Meal with no Dish photo to show no picture at all, no box and no icon,
   so that the list looks clean instead of broken.
3. As an athlete, I want the recipe screen of a Meal with no Dish photo to start with the meal's
   name, so that no empty space pushes the recipe down.
4. As an athlete, I never want to see a grid of ingredient photos standing in for a meal, so that
   what I see is what I'll eat.
5. As an athlete, I never want to see a single ingredient's photo standing in for a meal, so that a
   salmon fillet never passes for a salad.
6. As an athlete, I want at most one short credit line under a Dish photo, so that attribution
   doesn't crowd the recipe.
7. As an athlete, I want no credit line when a photo has none, so that the team's own photos show
   clean.
8. As an athlete, I want tapping a credit line that has a source link to open the source page, so
   that the photographer is properly credited.
9. As an athlete, I want a Dish photo that fails to load to leave no trace, so that a broken web
   link never shows a broken-image glyph.
10. As an athlete, I want the same Dish photo on the Meals tab, plan tiles, plan bar, review sheet,
    swap screen, shopping list, meal sheet and Vana's meal cards, so that a meal looks the same
    wherever I meet it.
11. As an athlete, I want a Meal I saved to mine, or one in my plan, to show the library Meal's
    current Dish photo, so that a photo added later reaches meals I already have.
12. As an athlete, I want a list mixing Meals with and without photos to stay aligned, so that
    names and macros line up even when some cards have no picture.
13. As an athlete, I want a new Dish photo to appear the next time the Meal is fetched, so that
    I see improvements without reinstalling.
14. As an athlete, I want to see no photo-editing controls, so that the recipe screen stays about
    cooking.
15. As a screen-reader user, I want a Dish photo's credit read out only when it exists, so that no
    empty label is announced.

### Testers adding photos

16. As a Tester, I want a small camera icon on a Meal's Dish photo, so that I can change it without
    it cluttering the screen.
17. As a Tester, I want an "Add photo" line where the picture would be on a Meal with no Dish
    photo, so that I can see which meals need one while I cook.
18. As a Tester, I want either entry point to open a Meal photos page, so that every photo action
    is in one place.
19. As a Tester, I want the Meal photos page to show the Meal's current Dish photo, or say there is
    none, so that I know what athletes see now.
20. As a Tester, I want to take a photo with the camera, so that I can snap what I just cooked.
21. As a Tester, I want to choose a photo from my phone's gallery, so that I can use a photo I took
    earlier.
22. As a Tester, I want to crop the photo to the picture's shape before it's used, so that it fits
    cards and the recipe screen without surprises.
23. As a Tester, I want to see a preview of exactly what athletes will see, so that I can check it
    before publishing.
24. As a Tester, I want to confirm before a photo goes live, so that nothing publishes by accident.
25. As a Tester, I want to cancel at crop or preview without changing anything, so that
    experimenting is safe.
26. As a Tester, I want the app to strip location and other metadata from a camera or gallery photo
    before upload, so that my home address never ships with a meal photo.
27. As a Tester, I want the app to shrink a large photo before upload, so that uploads are quick and
    athletes' cards load fast.
28. As a Tester, I want to paste a web address for an image, so that I can use a good photo I found
    online.
29. As a Tester, I want the page to load a pasted address and show a preview, so that I know the
    address really is the image I meant.
30. As a Tester, I want a clear message when an address isn't a loadable image, so that I don't
    publish a broken link.
31. As a Tester, I want to add an optional credit (text, plus an optional source link) to any
    photo, so that a web photo can name its source.
32. As a Tester, I want "Photo added" only after the server confirms, so that I never believe
    something published that didn't.
33. As a Tester with no signal, I want a clear failure and nothing queued, so that a photo never
    publishes later without me watching.
34. As a Tester, I want the new photo to replace the current one straight away, whatever it was, so
    that my choice is what athletes see.

### Testers changing and undoing

35. As a Tester, I want to remove the current Dish photo so the Meal shows nothing, so that I can
    take down a wrong or ugly photo.
36. As a Tester, I want removal to work on any photo, including ones the old pipeline chose, so
    that a photo the Judge passed but is wrong can go.
37. As a Tester, I want a History of every photo this Meal has shown, with who added it and when,
    so that I can see what happened.
38. As a Tester, I want to restore any photo from History as the current one, so that a mistake
    or vandalism is one tap to undo.
39. As a Tester, I want to delete a photo from History for good, so that an inappropriate image is
    really gone, file included.
40. As a Tester, I want a confirmation before deleting for good, so that I don't lose a photo by
    accident.
41. As a Tester, I want replacing a photo to keep the old one in History, so that nothing is lost
    by trying a new one.
42. As a Tester, I want removing the current photo to leave the Meal with nothing, not an older
    photo coming back, so that "remove" does exactly what it says.
43. As a Tester, I want no way to edit a live photo, only replace it, so that History stays an
    honest record.

### The team

44. As the team, I want every add, remove, restore and delete recorded with the account and time,
    so that we can find and undo vandalism by anyone who found the gesture.
45. As the team, I want the server to refuse photo changes from anyone who isn't a Tester, so that
    the button being hidden isn't the only protection.
46. As the team, I want the switchover to keep only Dish photos with an `ok` Verdict, so that the
    library starts from pictures that were already judged right.
47. As the team, I want every Meal's History to start empty at switchover, so that rejected pipeline
    pictures can't be restored with a tap.
48. As the team, I want the pipeline's data (Verdicts, the Tile bank, Tile lists, Image mode) left
    untouched, so that Mosaics can come back later without re-sourcing.
49. As the team, I want the pipeline scripts archived so nobody runs them, so that nothing
    overwrites a Tester's photo.
50. As the team, I want photos taken in the dev app to land in dev and photos taken in the prod app
    to land in prod, so that environments don't leak into each other.
51. As the team, I want the production cutover to copy only the storage files that shown photos
    point at, so that prod doesn't depend on dev storage.

## Implementation Decisions

- **The current photo is its own pair of fields, separate from the pipeline's.** `meal_library`
  gets `photo_url`, `photo_credit` and `photo_credit_url`, holding the current Dish photo, plus a
  pointer to its History row. The pipeline's image columns (`image_url`, `image_mode`,
  `image_tiles`, Verdicts and the rest) stay as they are and are no longer read by the app. This is
  how "freeze, keep the data" works without the new photos mixing with old data.
- **History is a new table, one row per photo a Meal has had.** Each row holds:
  - the Meal id and the address;
  - the credit text and credit link;
  - the storage path when the file is in our storage, null for a web address;
  - who added it and when.

  Removal and deletion are recorded as events in a second table: action (add, remove, restore,
  delete), the photo row, the account and the time. A deleted photo's row keeps its audit
  events. Its file is removed from storage and it no longer appears in History. Both tables have
  RLS on and no client policies. Only the server function writes them.
- **One edge function changes photos** (name to be settled in the ticket, e.g. `meal-photo`). It
  authenticates the caller and refuses anyone whose `users.is_internal` is not true. Actions:
  - `add_upload`: prepared JPEG bytes plus optional credit. Stored in the public image bucket
    under a per-Meal photos folder with the service role.
  - `add_address`: an https address plus optional credit. The server checks that the address
    answers with an image content type.
  - `remove`: clears the current photo.
  - `restore`: a History row becomes the current photo.
  - `delete`: a History row, with its file if stored, is removed for good. Deleting the current
    photo also clears it.
  - `history`: lists the Meal's History for the page.

  Each write updates `meal_library`'s current-photo fields and writes the event in one
  transaction, through an SQL function, and returns the Meal's new current photo. Errors:
  401 unauthenticated, 403 not_tester, 400 invalid input or not_an_image, 404 meal or photo not
  found.
- **Reads.** `search_meals` and the Vana `get_meal` return the current photo (address, credit,
  credit link) from the new fields. Plan meals carry no picture today; a plan meal stores its
  name, slot and icon key. So the plan read (plan tiles, plan bar, review sheet) joins each plan
  meal to its library Meal's current photo by meal id, and never copies it onto the plan row.
  This answers open question mp-324 in line with Lee's "everywhere" ruling, and the question
  stays open on the page for Lee to close. The Vana meal contract gains the same three fields. The old
  image fields may still be sent, but the app ignores them.
- **Where the rule lives in the app.** The domain `MealRef`/`MealDetail` picture is a single
  optional Dish photo (address, credit, credit link). `displayTiles` becomes that one photo or
  nothing. Every surface already goes through that choke point and the picture mapping, so the
  rule is implemented once:
  - When there is no photo, a surface lays out with no picture slot, not a placeholder.
  - The placeholder widget is deleted.
  - The shared `MealImageMosaic` design widget stays in `kyle_design` (capacity kept), but meal
    surfaces no longer build a Mosaic.
- **Failed loads draw nothing.** A Dish photo that fails to load collapses the same way as no
  photo, and draws no glyph.
- **Credit.** One line under the photo on the recipe screen, only when `photo_credit` is present.
  Tapping opens `photo_credit_url` when present. Cards keep the credit as the screen-reader label
  only.
- **Tester gate in the app.** The entry point and page are shown when `internalDeviceFlagProvider`
  is true, the 7-tap switch (ADR 0003). The server check is the real gate.
  - *Assumption:* the last round offered `users.is_admin` (hand-set, already RLS-enforced for the
    review box) as an alternative, and the answer didn't choose it. This spec keeps the 7-tap
    ruling.
  - *To switch:* change the app provider to `isAdminProvider` and the server check to
    `users.is_admin`. Nothing else changes.
- **Meal photos page.** A new screen pushed from the recipe screen for a library Meal, named with
  `routeSettings` (MaterialPageRoute pushes are invisible to the router otherwise). Its sections:
  - the current photo;
  - Take photo and Choose photo, each going to crop, then preview, then Confirm;
  - Paste address, going to load, then preview, then Confirm, with an optional credit on every
    add;
  - Remove;
  - History, each row with thumbnail, who, when, Restore and Delete (with confirmation).

  All strings go through the content system, and success and failure use `MealvanaSnackbar`.
- **Photo controller.** A new `@riverpod` `AsyncNotifier` for one Meal's photos holds the current
  photo and History:
  - Every write is remote-ack only (no local-first, no queue) and wrapped in `AsyncValue.guard()`.
  - On success it invalidates that Meal's detail and the catalog pages that contain it, so the new
    photo shows on the next fetch.
  - A failure leaves the state unchanged and surfaces to the screen.
- **Photo preparation.** Before upload the app:
  - crops the photo to the recipe screen's picture aspect;
  - scales it so the long edge is at most about 1600px;
  - re-encodes it as JPEG with no EXIF, which removes GPS.

  The crop step uses `crop_your_image` (pure Flutter, so it works on iOS, Android and web with no
  native setup; installed 2026-09-15). `image_picker` is already a dependency. The re-encode uses
  the `image` package, today only a transitive dependency; it becomes a direct one. The preparation step is a pure function the controller calls, so the fake
  repository sees prepared bytes.
- **Switchover migration**, run once per environment:
  1. For every active Meal whose `image_mode = 'dish'` and `image_verdict = 'ok'`, copy
     `image_url` into `photo_url`.
  2. Compose `photo_credit` from the structured fields, the same way the app's credit builder does
     today (creator, provider, licence), falling back to `image_credit`.
  3. Set `photo_credit_url` from `image_source_url`.

  No History rows are created: History starts empty, per ruling. Web addresses (Pexels, Wikimedia
  and 17 other hosts) are kept as they are, and nothing is copied.
- **Pipeline freeze.** `scripts/meal-images/` moves to an archive location, and the meal-images
  docs say it's frozen and point to ADR 0003. The pipeline's columns, `ingredient_images` and the
  compositor stay.
- **Cutover.** The meal-planning cutover runbook gains two steps: create the public image bucket
  in prod, and copy the dev storage files that `photo_url` points at (including Tester uploads),
  then rewrite their host. Web addresses need nothing. Prod `app_config` is untouched.
- **Rulings this changes.**
  - mp-145 was re-ruled by Lee on 2026-09-15: a meal with no photo shows nothing, with no
    placeholder box. mp-323, the placeholder's look, was rejected. Ticket 22 (done) built the
    placeholder, and this spec deletes it.
  - The design spec `meal-image-mosaic.md` lives in `docs/ssot/`, which is mirrored from the QA
    repo and must not be edited here. Its MIM-2 ("none draws nothing") already agrees. Its Mosaic
    rules stay valid for the kept capability.

## Testing Decisions

A good test here drives behaviour from the outside, with data shaped the way the producer sends
it:
- server-shaped rows into the real mapping and widgets;
- the real notifier with a recording fake behind it;
- the real function handler with the fake database.

Tests assert what an athlete or Tester would see and what the server stores. They don't assert
private widget structure or internal call order.

Three seams:

1. **What a Meal shows (existing seam).** Rows shaped like `search_meals` and `get_meal` go
   through the real mapping (`rowToMealRef`, the detail mapping) into `MealCard`, the recipe
   screen and the other surfaces. Cases:
   - a Meal with `photo_url` shows exactly one photo;
   - a Meal with none shows no picture slot (no placeholder, no Mosaic, no icon), even when its
     row still carries `image_mode` `mosaic` or `tile` with tiles, or a `weak` `image_url`;
   - the credit line appears only when present;
   - a failed load collapses;
   - the entry point shows only with the Tester flag on.

   Prior art: `meal_card_placeholder_test` (rewritten; its placeholder assertions invert),
   `meal_library_row_mapping_test` and `meal_detail_screen_test`.
2. **Meal photos write path, through the real notifier.** `ProviderContainer` plus the seeded
   controller pattern, with a recording fake photo repository. Cases:
   - each of add upload, add address, remove, restore and delete sends one request;
   - state changes only after the fake acks;
   - a thrown failure leaves state unchanged and reaches the screen;
   - an upload arrives prepared (cropped aspect, long edge within the limit, no EXIF/GPS, checked
     by feeding a real JPEG fixture that carries GPS).

   Prior art: the admin review tests in `meal_detail_controller_test`.
3. **The photo edge function.** A Deno test on the handler with the fake database and storage.
   Cases:
   - a non-Tester gets 403 and nothing is written;
   - add sets the current photo and writes one History row and one event with the account;
   - remove clears the current photo and writes an event, and History is unchanged;
   - restore makes a History row current;
   - delete removes the row and the stored file, and clears the current photo if it was current;
   - a non-image address is refused.

   Prior art: `supabase/functions/tests/vana/entitlement.test.ts` and `support/fake_db.ts` (Deno
   tests need `--allow-sys`).

The switchover migration is checked with a read-only verify query on dev after it runs: the count
of Meals with `photo_url` equals the count of `dish` and `ok` rows, and no History rows exist. No
unit test.

## Out of Scope

- New ways to source pictures (AI-generated, partners, photo shoots, athlete uploads). That's a
  separate grilling session.
- A "no photo yet" filter or queue for Testers.
- Bringing Mosaics back, or deciding the bar for a good enough Mosaic.
- A server-side allowlist of named uploaders beyond the Tester flag.
- Editing or re-cropping a live photo.
- Copying web-address photos into our storage.
- Deleting the pipeline's columns, the Tile bank or the Mosaic widget.
- Offline queuing of photo changes.
- Showing athletes who added a photo.

## Further Notes

- Anyone who finds the 7-tap gesture can change a photo every athlete sees. That risk is
  accepted (ADR 0003), and the event log is the safety net.
- Hotlinked photos can fail to load (Wikimedia rate-limits) or disappear upstream. Both collapse
  to no picture, and a Tester can replace them.
- The `meal-images` bucket exists only in dev with no migration. The photo function's ticket should
  add a migration creating the bucket, so prod can be built from migrations.
- Dev counts on 2026-09-15: 170 `ok` Dish photos, 109 in storage and 61 on the web (20 Pexels, 24
  Wikimedia, 17 other hosts). 1,752 Meals will show no picture at switchover.
- Run `/design-sync` if anything under `kyle_design/` changes (deleting the placeholder, or a
  credit-line change).
