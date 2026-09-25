# 98: Logging a barcode without a camera

**Status:** in-progress (wave 25, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** Lee's ruling on 28-004 (2026-09-25): all three parts.
1. Food search matches an 8, 12, 13 or 14-digit query against cached `nutrition_products.barcode`, or routes it to `lookup-product`, so typing a barcode finds the product.
2. When the camera is unavailable or denied, the scanner shows an app-written message (content system) with a link to search, instead of the package's English text.
3. The scanner has "Enter barcode": a numeric field that runs the same `lookup-product`, confirm and log path as a scan. This also lets a simulator run test that path end to end.

**Findings:** 28-004. Retest ticket 100 closes it.

**Decisions:** none dispute this. No page writes.

**Touches:** lib/features/barcode_scanning/presentation/barcode_scanner_screen.dart, the meal-logging search (lib/features/meal_logging/), supabase/functions/search-catalog/ if matching is server-side, assets/config/content_defaults.json

- [ ] Tests: a barcode-digit query returns the cached product; the no-camera state shows the app message and link; Enter barcode reaches the same confirm screen a scan does.
- [ ] `flutter analyze` clean; deno tests if a function changed.

Next: /implement-lee testing-wave
