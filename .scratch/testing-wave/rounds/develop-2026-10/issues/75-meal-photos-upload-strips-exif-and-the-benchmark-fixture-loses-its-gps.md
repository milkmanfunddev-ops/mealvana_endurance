# 75: Meal photos are uploaded without EXIF; the benchmark fixtures lose their GPS

**Status:** landed (wave 8, 2026-10-09, develop-next `4b146f27`); open until its retest passes in test wave 9 (retest tickets 85-87)
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

- [x] **Seam test through the real service** (`meal_photo_exif_seam_test.dart`). The fixture `test/fixtures/meal_photos/gps_orientation6.jpg` is written once with PIL, not with the `image` package the code uses: 64×48 pixels, Orientation 6, a GPS IFD at the neutral point run 68 used (40°44'30"N, 73°59'15"W), Make "Apple", Model "iPhone 14 Plus", DateTime. That is the shape image_picker hands over. Use the mocked storage pattern of `meal_logging_business_logic_test.dart:1826-1856`, capture the bytes `uploadBinary` receives, and stub `functions.invoke` with an analysis answer. Assert on the captured bytes:
  - no `Exif\0\0` APP1 segment (scan the JPEG markers);
  - re-decoded, the image is 48×64, the rotation applied;
  - the upload path ends `.jpg`, the content type is `image/jpeg`;
  - the same through `analyzePhoto(File(fixture))`, and through `analyzePhotoBytes` with `extension: 'png'` on a PNG fixture.
  Red before the fix (the bytes go up unchanged).
- [x] Unreadable bytes: `analyzePhotoBytes(Uint8List(0))` throws `MealAiException(serverError)`, records one `degraded` in `meal_logging`, and `uploadBinary` is never called.
- [x] `meal_logging_business_logic_test.dart:1826-1856`: the StorageException case feeds `Uint8List(0)`, which now fails before the upload. Give it the fixture's bytes so it still reaches `uploadBinary` and still expects one `fault` with a `StorageException`.
- [x] Call `stripPhotoMetadata` directly in the tests, or through the service in a plain `test()`. Never under `pumpAndSettle`: `compute` does not resolve there (memory, "Tests").
- [x] #116: `grep -rl` under `test/` for `MealAiService`, `analyzePhoto`, `analyzePhotoBytes`, `_analyzeBytes`, `stripPhotoMetadata`, `mealAiServiceProvider`; run every file named. Known: `meal_logging_business_logic_test.dart`, `meal_ai_service_credits_test.dart`, `describe_back_keeps_analysis_test.dart`, `describe_not_food_test.dart`, `describe_error_lines_wrap_test.dart`. Fakes of `MealAiService` are unaffected (no signature change).
- [x] The new `degraded` uses the existing `Report`; no new reporting helper or silent catch, so `source_guard.dart` is unchanged. Run `test/shared/source_guard/` anyway (#117).
- [x] Async paths, written in the fix notes: (i) Analyze tapped twice: two uploads of two sanitized copies under two UUIDs, as today (Describe already guards a second tap); (ii) the screen leaves while the isolate runs: the service holds no `ref`, the result is dropped by the caller as today. No retry or timeout added.
- [x] Fixtures: after the one-off, `python3 -c` over `images/img-*.jpg` prints an empty EXIF for all ten (paste the output into the fix notes, with no coordinates).
- [x] `flutter analyze` clean on the touched Dart files.

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

## Fix notes

Commit `97f9cabf0` on `testing-wave/develop-2026-10/75`.

**What changed.**
- `lib/features/meal_logging/application/meal_photo_sanitizer.dart` (new): `stripPhotoMetadata(Uint8List)` decodes with the `image` package, runs `bakeOrientation`, sets `exif = ExifData()` and encodes JPEG at quality 90. Empty or undecodable input throws `MealPhotoUnreadable`. Finding while testing: `image` 4.5.4's JPEG decoder already applies the Orientation tag itself and drops it; `bakeOrientation` stays for the other formats (WebP/TIFF carry orientation through `exif`).
- `meal_ai_service.dart`: `_analyzeBytes` calls one named helper, `_sanitizePhoto(bytes, extension:)`, before the upload (`compute(stripPhotoMetadata, bytes)`). The upload path is always `<uid>/<uuid>.jpg` with `image/jpeg`. Any failure in the sanitize (not only `MealPhotoUnreadable`, since an error can also come back across the isolate) records `_r.degraded(…, area: 'meal_logging', message: 'meal photo could not be re-encoded; not uploaded', extra: {extension, bytes})` (D9: Sentry warning, PROD-readable) and throws `MealAiException(serverError, 'Could not read that photo. Please try another one.')`. Nothing is uploaded and there is no fallback to the original bytes. `_mimeFromExtension` was deleted (now dead); `_extensionFromPath` stays, feeding the report's `extension`. The StorageException fault's `bytes` extra is now the sanitized length. No signature or caller change.
- `pubspec.yaml`: `image: ^4.5.4` added; `pubspec.lock` changes one line (`image` transitive → `direct main`, same 4.5.4 / sha).
- Fixtures (written once with PIL 12.1, not with the `image` package): `test/fixtures/meal_photos/gps_orientation6.jpg` (64×48 stored, Orientation 6, GPS 40°44'30"N 73°59'15"W, Make Apple, Model iPhone 14 Plus, DateTime 2025:07:19 11:13:21, red block top-left) and `gps_orientation6.png` (same pixels plus an `eXIf` chunk with the same tags). The PNG is one file more than Touches listed; the checklist's PNG case needed it.
- Benchmark: `images/img-01.jpg` … `img-10.jpg` rewritten with the ticket's one-off (`ImageOps.exif_transpose`, quality 80, ICC profile kept, no `exif=`). `originals/` and git history untouched (Q1 ruling). README manifest: all ten now 3024×4032 (img-04 was already portrait, Orientation 1; the manifest had it wrong before); a note on the rewrite; the size line updated (~0.9–1.6 MB; the rewrite roughly halves each file, likely PIL's default 4:2:0 subsampling at q80).

**Fixture verification (no coordinates).** Before: nine of ten Orientation 6, img-04 Orientation 1, all ten with a GPS IFD. After, PIL per file: size (3024, 4032), `getexif()` = `{}`, ICC kept; byte scans find no `Exif` and no `xmpmeta`. Pixels kept: mean absolute difference against `exif_transpose(original)` per RGB channel 1.0–1.7 of 255 for every file:
```
img-01.jpg (3024, 4032) exif {} icc True mean|diff| [1.38, 1.34, 1.55]
img-02.jpg (3024, 4032) exif {} icc True mean|diff| [1.47, 1.42, 1.61]
img-03.jpg (3024, 4032) exif {} icc True mean|diff| [1.22, 1.14, 1.32]
img-04.jpg (3024, 4032) exif {} icc True mean|diff| [1.28, 1.2, 1.54]
img-05.jpg (3024, 4032) exif {} icc True mean|diff| [1.14, 1.09, 1.21]
img-06.jpg (3024, 4032) exif {} icc True mean|diff| [1.02, 1.0, 1.19]
img-07.jpg (3024, 4032) exif {} icc True mean|diff| [1.16, 1.14, 1.23]
img-08.jpg (3024, 4032) exif {} icc True mean|diff| [1.51, 1.42, 1.58]
img-09.jpg (3024, 4032) exif {} icc True mean|diff| [1.58, 1.51, 1.71]
img-10.jpg (3024, 4032) exif {} icc True mean|diff| [1.36, 1.31, 1.48]
```
The seam test file also checks every benchmark JPEG for an `Exif` APP1 segment (eleven tests: ten files plus "all ten present").

**#77, async paths.**
- Two photos picked back to back, or Analyze tapped twice: each call runs its own `compute` and uploads its own sanitized copy under its own UUID, as before (Describe already guards a second tap). The sanitizer is a pure function with no shared state, so two runs at once cannot mix bytes.
- The screen leaves or refreshes while the isolate runs: the service holds no `ref`; the isolate finishes, the upload and analysis carry on, and the caller drops the result as it did before. No retry or timeout added.
- A sanitize that fails: one `degraded` in `meal_logging` (Sentry warning), a `MealAiException(serverError)` the screen shows as "Could not read that photo. Please try another one.", and nothing uploaded. Twice at once gives two degradeds and no upload.

**Tests run** (only the files for this change; no full suite):
- `test/features/meal_logging/meal_photo_exif_seam_test.dart`: 17 passed (fixture guard; analyzePhotoBytes JPEG: no Exif APP1, 48×64, red block top-right, `.jpg`, `image/jpeg`; analyzePhoto(File); PNG with `extension: 'png'`; unreadable bytes → serverError, one degraded, `uploadBinary` never called; garbage bytes → `MealPhotoUnreadable`; 11 benchmark checks). Red before the fix: run against the pre-fix `meal_ai_service.dart`, the service tests failed, and the benchmark checks failed before the rewrite.
- `test/features/meal_logging/meal_logging_business_logic_test.dart`: 95 passed (StorageException case now feeds the JPEG fixture and still expects one `StorageException` fault).
- `test/features/meal_logging/meal_ai_service_credits_test.dart`: 4 passed.
- `test/features/meal_logging/describe_back_keeps_analysis_test.dart`: 5 passed.
- `test/features/meal_logging/describe_error_lines_wrap_test.dart`: 2 passed.
- `test/features/meal_logging/describe_not_food_test.dart`: 3 passed.
- `test/shared/source_guard/`: 20 passed (unchanged; the new degraded goes through the existing `Report`).
- #116 grep (`MealAiService`, `analyzePhoto`, `analyzePhotoBytes`, `_analyzeBytes`, `stripPhotoMetadata`, `mealAiServiceProvider`, `MealPhotoUnreadable`) named exactly the six meal_logging files above. #76: only those two files stub `uploadBinary`.
- `flutter analyze` on the four touched Dart files: no issues in the new or changed code. Two older `unused_local_variable` warnings in `meal_logging_business_logic_test.dart` (lines 1381 and 1969) sit outside this diff and were left alone.

No codegen (no annotated file changed). No deploy.

**Lead, at the close (2026-10-09).** Review fix `4b146f27`: the unreadable-photo line moved out of the service into a content key (`meal_log.describe.photo_unreadable`, `MealAiFailureKind.photoUnreadable`); the screen shows it.
