# 75: Meal photos are uploaded without EXIF; the benchmark fixtures lose their GPS

**Status:** in-progress (wave 8, 2026-10-09)
**Labels:** fix, round:develop-2026-10, area:meal-logging, area:privacy
**Branch:** `develop-next` (fix-wave worktree)
**Source:** Findings 68-004, 68-005; TRIAGE.md rulings of 2026-10-09
**Blocked by:** nothing. No file shared with 74, 76 or 77, or with 71-73.
**Next:** `/testing-wave develop-2026-10` (fix wave 8)
**Model:** opus

Line numbers are from code at `84615131`.

## Findings

- **68-004 · A gallery meal photo's GPS location is uploaded to meal-photos unchanged (retest of 49-007).** Run 68 added a scratch copy of `img-01.jpg` carrying a neutral GPS point, picked it from the gallery (the iOS picker's default "Location Is Included"), typed a description and tapped Analyze. Object `meal-photos/607f9dd5-…/b1ccbabe-….jpg` (320,708 bytes, 1333×1000) carries the full GPS IFD of the source, plus Make "Apple", Model "iPhone 14 Plus" and DateTime "2025:07:19 11:13:21". image_picker re-encoded the pixels and copied the metadata. Evidence: `runs/68/exif-uploaded-meal-photo.txt`, `runs/68/db-meal-photos-object.txt`, `runs/68/08a-picker-location-included.png`, `runs/68/edge-check8-photo.txt`.
- **68-005 · The committed benchmark photo `img-01.jpg` carries a real GPS location (idea).** The file holds an iPhone 14 Plus GPS IFD with a real latitude, longitude, altitude, speed and heading. Run 68 overwrote it in a scratch copy, so nothing real was uploaded. Evidence: `runs/68/notes.md` (check 8; coordinates left out on purpose).

## Fix

**Ruling (2026-10-09):** strip ALL EXIF client-side before the storage upload, with the orientation applied to the pixels. Rewrite the committed fixture without GPS in the same ticket.

How the upload works (from code): Describe (`lib/features/meal_logging/presentation/providers/describe_analysis_controller.dart:120-150`) and Edit Meal's rescan (`lib/features/meal_logging/presentation/screens/edit_meal_log_screen.dart:246-259`) call `MealAiService.analyzePhoto` (file, `lib/features/meal_logging/application/meal_ai_service.dart:141-153`) or `analyzePhotoBytes` (web, `:159-171`). Both reach `_analyzeBytes` (`:214-…`), which uploads the bytes as they came (`uploadBinary`, `:227-237`). The picker is called with `imageQuality: 85, maxWidth: 1000` (`log_meal_screen.dart:1988-1992`, `edit_meal_log_screen.dart:221-225`). Run 68's object is 1333×1000 pixels from a 4032×3024 source: `maxWidth` applied to the displayed width, so the stored pixels are landscape and the EXIF Orientation tag turns them upright. Nine of the ten benchmark JPEGs carry Orientation 6 (read with PIL). Dropping EXIF without rotating would hand the model a sideways photo; hence the ruling's "orientation applied to pixels".

1. **A metadata-free re-encode.** New `lib/features/meal_logging/application/meal_photo_sanitizer.dart`: a top-level `Uint8List stripPhotoMetadata(Uint8List bytes)` on the pure-Dart `image` package (4.5.4, in `pubspec.lock` today as a transitive dependency). `decodeImage(bytes)` → `bakeOrientation(image)` → clear `image.exif` → `encodeJpg(image, quality: 90)`. The output holds no APP1/EXIF segment, so there is no GPS, Make, Model, DateTime or Orientation tag. PNG, WebP and GIF input decode the same way and come out as JPEG (PNG `eXIf` chunks go too). An undecodable input (empty bytes, HEIC on web) throws a `MealPhotoUnreadable` exception from the same file.
2. **Every upload goes through it.** In `_analyzeBytes`, before the upload (`:221`), `final clean = await compute(stripPhotoMetadata, bytes);` (off the UI isolate; on web `compute` runs inline). Upload `clean` with extension `jpg` and `image/jpeg` whatever the picker named (`_extensionFromPath` `:484-487` and the web callers' `ext` no longer decide the upload). `analyze-meal-photo` takes the type from the path's extension (`supabase/functions/analyze-meal-photo/index.ts:187-193`), so `.jpg` → `image/jpeg` matches. `MealPhotoUnreadable` → `_r.degraded(…, area: 'meal_logging', message: 'meal photo could not be re-encoded; not uploaded', extra: {'extension': extension, 'bytes': bytes.length})` and `MealAiException(kind: serverError, userMessage: 'Could not read that photo. Please try another one.')`. Nothing is uploaded: the ruling forbids unstripped bytes, so there is no fallback to the original. `analyzePhoto`/`analyzePhotoBytes` keep their signatures; no caller changes.
3. **Direct dependency.** Add `image: ^4.5.4` to `pubspec.yaml` dependencies (`depend_on_referenced_packages`); `flutter pub get` moves it to `direct main` in `pubspec.lock`. Pure Dart: no pod or Gradle change.
4. **Rewrite the benchmark JPEGs without EXIF.** All ten `benchmarks/ai-model-benchmark-2026-07/images/img-01.jpg` … `img-10.jpg` carry a 15-tag GPS IFD (read with PIL; `img-11.png` has none). The ruling names `img-01`; the other nine carry the same kind of data and get the same one-off. Run once from the worktree root (PIL 12.1 is on the machine), never committed as a script:
   ```python
   from PIL import Image, ImageOps
   import glob
   for p in sorted(glob.glob('benchmarks/ai-model-benchmark-2026-07/images/img-*.jpg')):
       im = ImageOps.exif_transpose(Image.open(p))      # orientation into pixels
       icc = im.info.get('icc_profile')
       im.save(p, 'JPEG', quality=80, icc_profile=icc)  # no exif= → no EXIF written
   ```
   Quality 80 matches how `images/` was made (`benchmarks/ai-model-benchmark-2026-07/README.md`, "Layout"). Check afterwards: `Image.open(p).getexif()` is empty for all ten, and each is upright (portrait images 3024×4032 after the transpose). Update the README manifest's Dimensions column where the transpose swaps them.
   - The benchmark's outputs do not depend on EXIF or on the file bytes (from code): `run_benchmark.py` base64-encodes `_derived/{compressed,uncompressed}/*.jpg` (`:116-120`, `:234-255`), which the harness makes from `images/`; `_derived/` holds past model answers (`results*.json`, `*.md`), not expected values. No file under `benchmarks/` hashes an image (grep for `sha`, `md5`, `hash`: none in `run_benchmark.py` or `analyze.py`).
   - `originals/*.HEIC` (ten files) carry GPS as well (`mdls` reports a latitude for each). The README calls them "Provenance; do not edit". Left as they are pending Question 1.

## Touches

lib/features/meal_logging/application/meal_photo_sanitizer.dart (new)
lib/features/meal_logging/application/meal_ai_service.dart
pubspec.yaml
pubspec.lock
benchmarks/ai-model-benchmark-2026-07/images/img-01.jpg
benchmarks/ai-model-benchmark-2026-07/images/img-02.jpg
benchmarks/ai-model-benchmark-2026-07/images/img-03.jpg
benchmarks/ai-model-benchmark-2026-07/images/img-04.jpg
benchmarks/ai-model-benchmark-2026-07/images/img-05.jpg
benchmarks/ai-model-benchmark-2026-07/images/img-06.jpg
benchmarks/ai-model-benchmark-2026-07/images/img-07.jpg
benchmarks/ai-model-benchmark-2026-07/images/img-08.jpg
benchmarks/ai-model-benchmark-2026-07/images/img-09.jpg
benchmarks/ai-model-benchmark-2026-07/images/img-10.jpg
benchmarks/ai-model-benchmark-2026-07/README.md
test/fixtures/meal_photos/gps_orientation6.jpg (new)
test/features/meal_logging/meal_photo_exif_seam_test.dart (new)
test/features/meal_logging/meal_logging_business_logic_test.dart

18 files. No annotated file changes, so no codegen. No caller of `analyzePhoto`/`analyzePhotoBytes` changes (`describe_analysis_controller.dart:134, :140`, `edit_meal_log_screen.dart:256, :258`, `_archived/…/photo_capture_screen.dart:103, :105`).

## Tests

- [ ] **Seam test through the real service** (`meal_photo_exif_seam_test.dart`). The fixture `test/fixtures/meal_photos/gps_orientation6.jpg` is written once with PIL, not with the `image` package the code uses: 64×48 pixels, Orientation 6, a GPS IFD at the neutral point run 68 used (40°44'30"N, 73°59'15"W), Make "Apple", Model "iPhone 14 Plus", DateTime. That is the shape image_picker hands over. Use the mocked storage pattern of `meal_logging_business_logic_test.dart:1826-1856`, capture the bytes `uploadBinary` receives, and stub `functions.invoke` with an analysis answer. Assert on the captured bytes:
  - no `Exif\0\0` APP1 segment (scan the JPEG markers);
  - re-decoded, the image is 48×64, the rotation applied;
  - the upload path ends `.jpg`, the content type is `image/jpeg`;
  - the same through `analyzePhoto(File(fixture))`, and through `analyzePhotoBytes` with `extension: 'png'` on a PNG fixture.
  Red before the fix (the bytes go up unchanged).
- [ ] Unreadable bytes: `analyzePhotoBytes(Uint8List(0))` throws `MealAiException(serverError)`, records one `degraded` in `meal_logging`, and `uploadBinary` is never called.
- [ ] `meal_logging_business_logic_test.dart:1826-1856`: the StorageException case feeds `Uint8List(0)`, which now fails before the upload. Give it the fixture's bytes so it still reaches `uploadBinary` and still expects one `fault` with a `StorageException`.
- [ ] Call `stripPhotoMetadata` directly in the tests, or through the service in a plain `test()`. Never under `pumpAndSettle`: `compute` does not resolve there (memory, "Tests").
- [ ] #116: `grep -rl` under `test/` for `MealAiService`, `analyzePhoto`, `analyzePhotoBytes`, `_analyzeBytes`, `stripPhotoMetadata`, `mealAiServiceProvider`; run every file named. Known: `meal_logging_business_logic_test.dart`, `meal_ai_service_credits_test.dart`, `describe_back_keeps_analysis_test.dart`, `describe_not_food_test.dart`, `describe_error_lines_wrap_test.dart`. Fakes of `MealAiService` are unaffected (no signature change).
- [ ] The new `degraded` uses the existing `Report`; no new reporting helper or silent catch, so `source_guard.dart` is unchanged. Run `test/shared/source_guard/` anyway (#117).
- [ ] Async paths, written in the fix notes: (i) Analyze tapped twice: two uploads of two sanitized copies under two UUIDs, as today (Describe already guards a second tap); (ii) the screen leaves while the isolate runs: the service holds no `ref`, the result is dropped by the caller as today. No retry or timeout added.
- [ ] Fixtures: after the one-off, `python3 -c` over `images/img-*.jpg` prints an empty EXIF for all ten (paste the output into the fix notes, with no coordinates).
- [ ] `flutter analyze` clean on the touched Dart files.

## Deploy

None (client only; `analyze-meal-photo` is unchanged).

## Retest

Next test wave, meal-logging retest ticket, on a simulator:
- **68-004:** make a scratch JPEG with Orientation 6 and a neutral GPS point (as run 68 did), `simctl addmedia`, pick it from the gallery with "Location Is Included" left on, Analyze. Download the `meal-photos` object read-only: PIL reads no EXIF at all (no GPS IFD, no Make/Model/DateTime, no Orientation), the pixels are upright (portrait), and the analysis still names the food. Repeat once from the camera path on Edit Meal's rescan.
- **68-005:** `git show HEAD:benchmarks/ai-model-benchmark-2026-07/images/img-01.jpg` read with PIL has no GPS IFD (a desk check; the lead can run it at the close).

## Questions for Lee

1. The ten HEIC files in `benchmarks/ai-model-benchmark-2026-07/originals/` carry the same GPS, and the earlier versions of all ten JPEGs stay in git history. The README says the originals are "Provenance; do not edit". Options: (a) leave the originals and the history as they are (the repo is private; waves upload only `images/` copies); (b) delete `originals/` from the tree, keeping `images/` as the source; (c) rewrite history to purge them (a force push of every branch that carries them). Recommended: (b) in this ticket, not (c).

**Rulings (Lee, 2026-10-09, wave 7 close).**
- Q1: keep `originals/` as it is; rewrite only the ten JPEGs; no history rewrite.
