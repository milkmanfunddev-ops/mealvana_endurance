# 05: A Tester takes or chooses a photo

**What to build:** On the Meal photos page a Tester taps Take photo (camera) or Choose photo
(gallery), crops it to the picture's shape, previews exactly what athletes will see, optionally
adds a credit, and confirms. The app shrinks the photo and strips its location and other metadata
before anything leaves the phone. The photo is stored in our storage and shown to everyone.

**Blocked by:** 04

**Status:** ready-for-agent

- [x] A migration creates the public image bucket that photos are stored in, so prod can be built
      from migrations (it exists only in dev today, with no migration). It is idempotent against
      the existing dev bucket.
- [x] Take photo and Choose photo use `image_picker`. The crop step uses `crop_your_image`, locked
      to the recipe screen's picture aspect. Cancel at crop or preview changes nothing.
- [x] Preparation is a pure function: crop, long edge at most about 1600px, re-encode as JPEG
      with no EXIF (`image` becomes a direct dependency).
- [x] The edge function gains `add_upload`: it takes prepared bytes plus an optional credit,
      stores the file under a per-Meal photos folder with the service role, and records the
      storage path on the History row. It uses the same Tester check, transaction and response as
      `add_address`. It is deployed to dev.
- [x] Seam 2 test: an upload goes through the real notifier. A real JPEG fixture carrying GPS
      reaches the fake repository cropped to the aspect, within the size limit, and with no EXIF
      or GPS.
- [x] Seam 3 Deno test: `add_upload` stores the file in the fake storage, writes the History row
      with its storage path, and refuses a non-Tester.
- [ ] Checked on the simulator (gallery pick, since the camera isn't available there): the photo
      appears for a second account. The stored file has no GPS metadata.

## Comments

**2026-09-16 — implemented.** Everything but the simulator check is done and verified against
deployed dev.

- **Migration `20260916170000_meal_images_bucket.sql`** — the `meal-images` bucket, which has
  existed on dev since 09-08 by hand and was never written down. The values are dev's own, read
  from `storage.buckets`: public, 5 MiB, `image/jpeg|webp|png`. Applied to dev and confirmed a
  true no-op (the bucket is unchanged and matches the migration exactly). **No storage policies,
  deliberately**: reads need none because the bucket is public, and writes get none because only
  the function writes there, with the service role, after the Tester check. Prod can now be built
  from migrations.
- **`add_upload`** takes base64 in the same JSON body every action uses. It refuses on the
  *encoded* length before decoding, so an oversized payload is never materialised; checks the
  bytes really open with a JPEG SOI rather than trusting the app; stores under
  `photos/<mealId>/<uuid>.jpg`, a fresh name each time so replacing a photo never overwrites the
  file an older History row still points at; and **removes the file again if the row cannot be
  written**, so a failed add leaves no orphan in a public bucket. Storage reaches the handler as
  an injected port, so the Deno test drives a fake bucket with no network.
- **Preparation is a pure function on bytes** (`prepareDishPhoto`), called by the controller so
  nothing that can send can skip it. Two things it must do that are easy to get wrong:
  1. **Re-encoding does not strip EXIF.** `encodeJpg` writes an APP1 segment back out for
     whatever `image.exif` holds, and `decodeImage` fills that in from the file — so a naive
     round trip *keeps* the Tester's GPS. The strip is an explicit line, and the test asserts on
     the raw bytes, not on a decoder's opinion.
  2. **`decodeImage` throws on rubbish**, it does not return null: a short or malformed file walks
     the PSD sniffer off the end of its buffer. A Tester picking a PDF would have crashed the
     page. Found by the test, fixed before it ran anywhere.
- **The app:** `dish_photo_capture.dart` (picker + preparer seams), `dish_photo_cropper.dart`
  (crop seam, in presentation because pushing a screen needs a `BuildContext`),
  `MealPhotoCropScreen`, and the Take/Choose section on the Meal photos page. `image` is now a
  direct dependency, pinned to the version already vendored so a new direct dep does not drag
  `archive` and `printing` up with it.

**Verified live against deployed dev**, not only in tests: a real `add_upload` on **AD-001** stored
the file and answered a History row signed with the server's own id, account and clock. The stored
object is served publicly as `image/jpeg` and is **byte-identical** to what was sent. `meal_library`
points at it, the ticket-04 Pexels photo is still in History rather than lost, and the frozen
pipeline's columns are untouched. PNG bytes → 400 `not_an_image`; an unknown Meal → 404 **and no
orphan file** (exactly one object under `photos/`, for AD-001).

**Tests:** seam 3 20 Deno tests on the handler with a fake database and fake bucket; seam 2 through
the real notifier on a **real 2400x1800 JPEG carrying a real GPS IFD** (`fixtures/README.md` says
how to rebuild it, and the test asserts the fixture really carries GPS before asserting anything
else, so a bad rebuild fails loudly instead of making the real assertions vacuous). Plus the pure
function's own tests and 17 on the page. Deno meal_photo 20/20, full Deno suite 265/265.
Flutter suite **5121 pass / 8 skip / 2 fail** — the two failures are the same pre-existing,
unrelated pair ticket 04 recorded (`ci_config_contract_test`, and a manual-live TrainingPeaks
credential test), against its baseline of 5080.

**Six things `/code-review` caught, all fixed:**

1. **A hard FOA breach.** The crop seam sat in `application/` and imported `presentation/`,
   passing a `BuildContext` — the arrow CLAUDE.md calls non-negotiable, backwards. The crop seam
   now lives in `presentation/providers/`; the picker stays in application.
2. **The credit leaked between the two add flows.** `_credit`/`_creditUrl` are shared controllers
   and `_pick` cleared only the address, so a credit typed for an abandoned address was attached
   to an uploaded photograph without the Tester ever seeing it again. Caught by the Spec axis.
3. **Preparation blocked the UI isolate** — both reviewers, independently. It now runs off it.
   That needed a seam: a real isolate never resolves inside `pumpAndSettle`'s fake-async zone, so
   the widget tests run the very same function inline while the seam-2 tests go through the real
   isolate.
4. **The size guard ran after the full base64 decode**, materialising the payload it was about to
   refuse. It now bounds the encoded length first.
5. **A dead content string** (`photos_preparing`, never rendered) — deleted rather than shipped.
6. **Two duplications**: the EXIF byte-scan copied into two test files (now one shared helper),
   and `_confirm`/`_confirmUpload` being the same shape (now one `_publish`).

**Three things for your eye — two are deviations I chose, one is inherited:**

- **`too_large` is a new error code.** The spec fixes the set at "400 invalid input or
  not_an_image". A Tester whose photo is refused for size deserves to be told that rather than
  shown a generic refusal, so I added it — but it is a new contract term, not something the spec
  asked for.
- **One add at a time.** The page hides Take/Choose while an address is previewing, and starting
  one add discards the other's half-typed fields. The spec lists the two sections side by side and
  asks for no mutual exclusion. I did it so Confirm can never be ambiguous about what it publishes;
  say the word and it comes out.
- **`AsyncValue.guard()` is still unruled.** `addUpload` follows ticket 04's choice for the same
  reason, so **one ruling settles both paths** (and 06).

**The simulator check is NOT done** — the last box, and the one thing here no test can stand in
for. Dev is seeded ready: **AD-001** now carries an uploaded photograph, `607f9dd5` (test@test.com)
is the Tester and `37129f7e` is the ready-made non-Tester. What is left to see on a device is a
gallery pick (the simulator has no camera) going crop → preview → confirm, the photo appearing for
the second account, and the stored file carrying no GPS. The tests prove the bytes are clean when
they *leave the phone*; only a device proves the whole path.
