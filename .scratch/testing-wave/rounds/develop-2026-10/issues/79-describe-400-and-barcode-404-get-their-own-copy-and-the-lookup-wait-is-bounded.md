# 79: Describe's too-long 400 and the barcode 404 get their own words and count as expected; the lookup wait is bounded

**Status:** ready (round develop-2026-10, fix wave 8)
**Labels:** fix, round:develop-2026-10, area:meal-logging, area:barcode
**Branch:** `develop-next` (fix-wave worktree)
**Source:** Findings 68-002, 68-007, 68-018; TRIAGE.md rulings of 2026-10-09.
**Blocked by:** nothing in code. Shares `content_keys.dart` and `content_defaults.json` with 72 and 73 (see Overlaps).
**Next:** `/testing-wave develop-2026-10` (fix wave 8)
**Model:** opus

**What to build:** Lee, 2026-10-09:
- describe-meal's 400 "too long" and lookup-product's 404 "not found" each get their own message through the content system (CLAUDE.md: no hardcoded user-facing strings).
- Both count as `expected_failure`, never `error_reported`.
- lookup-product gets a shorter client timeout with one retry. It is a read and safe to repeat (see Fix 4).
- Describe gets a client-side length cap before the call. The server's limit is known: 2,000 characters.

The pattern is ticket 55's for expected outcomes: key on a server flag, `Report.noteExpected` with a tracker the service holds, and a typed exception the screen branches on. Line numbers are from code at `84615131`.

## Findings

- **68-002 · Retest of 49-007: Describe text over 2,000 characters shows "The AI service returned an error" instead of saying the text is too long, and reports a degraded error.** Run 68, 23:22:18Z. 2,149 characters were pasted into "What did you eat?", then Analyze. describe-meal answered POST 400 at 23:22:19.691 with no model call and no ledger debit. The app showed the snackbar "The AI service returned an error. Please try again." The console had `meal_ai_failed {error_type: serverError}` and `error_reported {severity: degraded, area: meal_logging, exception_type: FunctionException}` (Sentry `ef33efa7…`). The field has no cap or counter, and "try again" repeats the same 400. The same 400 also shows in another run's window (67-006).
  Evidence: `runs/68/06a-long-text-pasted.png`, `runs/68/06b-long-text-result.png`, `runs/68/edge-check6-long-text.txt`, `runs/68/db-ledger-after-check6.txt`, `runs/68/console-redacted.log` (18:22:19 local).
- **68-007 · Barcode Enter with an unknown code: the server answers 404 not found, the app says "Unable to connect to product lookup service" and reports a fault.** Run 68, 23:43:00Z, Log a Meal → Scan barcode (camera off) → Enter → `98765432109871` → Look it up. lookup-product answered POST 404 at 23:43:02.438 after "No product found". The app showed the dialog "Error / Unable to connect to product lookup service" with Try Again / Cancel / Create Manually. Two `error_reported` were sent: degraded `ProductDetailException`, and fault `FunctionException` in area `barcode_scanning` (Sentry `83cdf137…`). `barcode_lookup_failed` went out with `reason: error`, not `not_found`.
  Evidence: `runs/68/12k-unknown-barcode-made-up.png`, `runs/68/edge-check12-barcode.txt`, `runs/68/console-redacted.log` (18:43:02 local).
- **68-018 · First barcode lookup of 12345670 timed out on the client after 30 s with no request reaching the server** (filed by the wave lead). At 23:41:08Z the first lookup hung for about 30 s. It ended in `ClientException with SocketException: Operation timed out (errno = 60) … uri=…/functions/v1/lookup-product` (console 18:41:37 local), showed the same "Unable to connect" dialog and sent two `error_reported`. The wave's edge extract has no lookup-product line at 23:41Z. The retry at 23:42:31Z answered 200 in under 1 s ("McEnnedy Double burger").
  Evidence: `runs/68/notes.md` check 12, `runs/lead-wave7/edge-wave7-2305-0000.txt`, `runs/68/12h-unknown-barcode-result-later.png`, `runs/68/console-redacted.log` (18:41:08–18:41:38).

**Why, from code.**

- **Describe (68-002).**
  - describe-meal refuses `description.length > 2000` (`MAX_DESCRIPTION_LENGTH`, `supabase/functions/describe-meal/index.ts:55`, check at `:130-134`) through `validationError` (`_shared/responses.ts:65-67`). That is a 400 whose body carries only `error`, with no flag.
  - The client sends the trimmed text (`log_meal_screen.dart:1828`, `_ctrl.text.trim()` → `describe_analysis_controller.dart:123` → `MealAiService.describeMeal`, `meal_ai_service.dart:176-212`).
  - `supabase.functions.invoke` throws `FunctionException` on a non-2xx. `_mapFunctionException` (`:369-414`) then calls `_r.degraded` for every status but 402 (`:389-396`) and returns `serverError` with the hardcoded "The AI service returned an error. Please try again." (`:409-413`). The Describe tab's catch (`log_meal_screen.dart:1915-1946`) shows `e.userMessage` in a snackbar for every kind except text-only not-food.
  - The field's only validator is the minimum (`describeMinChars = 5`, `:1718`; validator `:2150-2159`). Server and client both measure UTF-16 code units (JS `string.length`, Dart `String.length`), so a client cap on the trimmed text's `length` matches the server's check exactly.
- **Barcode (68-007, 68-018).**
  - lookup-product answers an unknown code with 404 and `{success: false, error: 'Product not found in Open Food Facts database', message: …}` (`supabase/functions/lookup-product/index.ts:245-258`). That 404 is the function's only one.
  - `ProductDetailService.getProductDetails` (`lib/features/barcode_scanning/application/product_detail_service.dart:21-116`) invokes with no timeout (`:52-55`). The `status != 200` branch (`:66-80`) is dead for errors, because `invoke` throws on non-2xx. Both the 404's `FunctionException` and the socket timeout fall into the catch-all (`:105-115`), which faults (the fault `error_reported`) and throws `ProductDetailException('Unable to connect to product lookup service')`.
  - `SupabaseBarcodeService.lookupBarcode` (`supabase_barcode_service.dart:38-49`) reports that again as `degraded` (the second `error_reported`) and returns `BarcodeResult.error`. The scanner screen then tracks `reason: error` and shows `_showError` (`barcode_scanner_screen.dart:356-377`, `:665-…`).
  - The "Product Not Found" dialog (`:517-…`, with Try Another / Cancel / Create Manually) is reached only for `BarcodeResult.notFound`. That comes only from a null product (`supabase_barcode_service.dart:30-37`), which `getProductDetails` never returns. Its title (`:538`) and body (the service's hardcoded "Product not found in nutrition databases", `:35`) are not content.
  - The 30 s wait was the OS TCP connect timeout (errno 60), not anything the app set.

## Fix

1. **describe-meal flags its too-long answer.** In `describe-meal/index.ts:130-134`, answer with `errorResponse(\`description is too long (max ${MAX_DESCRIPTION_LENGTH} characters)\`, 400, undefined, { too_long: true, max_length: MAX_DESCRIPTION_LENGTH })` instead of `validationError(...)`. The status and `error` text stay the same; only the extra fields are new. Update the mirrored validator in `describe-meal/index.test.ts:45-55`, and add a case that the too-long result carries `too_long: true` and `max_length: 2000`. **For the lead:** deploy `describe-meal` to dev at the close. A 400 without the flag (an older deployment) stays `degraded` until then, as 55 did for not-food.
2. **The client maps it to its own kind, as an expected outcome.**
   - Add `MealAiFailureKind.tooLong` (`meal_ai_service.dart:24-34`).
   - Add `@visibleForTesting static bool isTooLongAnswer(FunctionException e)`: true when `status == 400` and `e.details` is a map with `too_long == true`.
   - In `_mapFunctionException`, before the 402/degraded branch (`:388`) and beside the not-food branch (`:377-386`): `await _r.noteExpected('$functionName: description too long', area: _area, reason: 'description_too_long', analytics: _analytics, data: {'status': 400, 'max_length': e.details['max_length']})`, then return `MealAiException(kind: MealAiFailureKind.tooLong, userMessage: '', debugMessage: …)`. The screen does not show `userMessage` for this kind, so no new hardcoded sentence lands in the service.
   - `meal_logging` is not a promoted area (`report.dart:45-50`), so `noteExpected` is allowed. `_analytics` is already held by the service (ticket 55, `:115-117`, `:88`).
3. **Describe caps the text before the call.**
   - Add `const describeMaxChars = 2000;` next to `describeMinChars` (`log_meal_screen.dart:1718`), with a comment that it mirrors describe-meal's `MAX_DESCRIPTION_LENGTH`.
   - Extend the Describe validator (`:2150-2159`): if `v.trim().length > describeMaxChars`, return `ContentKeys.format(content.getValue(ContentKeys.mealLogDescribeTooLong), {'n': describeMaxChars})`. The line wraps (ticket 66's `errorMaxLines: 3`).
   - With a photo attached the validator is skipped (`:1850`), and analyze-meal-photo already slices the description to 2,000 server-side (`analyze-meal-photo/index.ts:129-132`), so the photo path needs no cap.
   - In the `MealAiException` catch (`:1935-1946`), a `tooLong` answer sets the same field error as the not-food case does (`_notFoodError`, renamed `_describeError` if the agent prefers), with the same `too_long` line. No snackbar. This covers a server whose limit is below the client's.
   - `meal_ai_failed` keeps `error_type: e.kind.name`, so it reads `tooLong`.
   - New content key `meal_log.describe.too_long` (`ContentKeys.mealLogDescribeTooLong`, beside `too_short` at `content_keys.dart:68`; `content_defaults.json` under `meal_log.describe`, `:382-386`). Default: "That's more than {n} characters. Keep it to what you ate and how much."
   - No `maxLength` on the field: a hard cap would silently cut a paste, and the athlete would not see what was dropped.
4. **lookup-product: one bounded attempt, one retry, both on transport failures only.**
   - In `ProductDetailService.getProductDetails`, wrap the invoke (`:52-55`) in a private `_invokeLookup(requestBody)`. It runs `_supabase.functions.invoke('lookup-product', body: …).timeout(const Duration(seconds: 10))`. On `TimeoutException`, `SocketException` or `http.ClientException` (the console shows the socket error wrapped in `ClientException`) it records `_report.breadcrumb('lookup-product attempt 1 failed; retrying once', category: 'barcode_scanning', data: {'error': e.runtimeType.toString()})` and tries once more with the same timeout. It never retries a `FunctionException`: an HTTP answer, 404 or 500, is final.
   - Worst-case wait drops from the OS's ~30 s to about 20 s, and a cold socket that fails once (68-018) gets a second chance. Successful lookups in run 68 answered in 0.4–0.9 s (`edge-check12-barcode.txt`), so 10 s is ample.
   - **Writes a repeat covers (RUNBOOK after-the-wave step 3, #82).** lookup-product writes no user data and debits nothing (no ledger call in `lookup-product/index.ts`, by grep). A repeat of a request that did reach the server repeats two writes:
     - `cacheNutritionProduct` (`_shared/food_sources/cache.ts:88-115`): an upsert on `barcode`, which is a full unique constraint (`nutrition_products_barcode_key`, `docs/dev_schema.txt:3970`). Safe to repeat.
     - The cache-hit counter (`cache.ts:42`, `hit_count + 1`): not idempotent. A timed-out first try that did land adds one extra hit to a popularity counter. Harmless; accepted.
     - No idempotency key is needed.
5. **The 404 is "not found", an expected outcome.**
   - Add `class ProductNotFoundException extends ProductDetailException` and `class ProductLookupUnavailableException extends ProductDetailException` in `product_detail_service.dart` (`:129-137`). Every existing `on ProductDetailException` catch (`food_search_controller.dart:459`, `supabase_barcode_service.dart:38`, the archived screen) still catches both.
   - Give `ProductDetailService` an optional `AnalyticsTracker? analytics`, passed by the provider (`:139-143`) as `ref.read(appExternalDepsProvider).analytics`, as 55 did for `MealAiService`.
   - In `getProductDetails`, add `on FunctionException catch (e)` before the catch-all (`:105`). When `e.status == 404` and `e.details` is a map with `success == false`: `await _report.noteExpected('lookup-product: not found', area: 'barcode_scanning', reason: 'barcode_not_found', analytics: _analytics, data: {'status': 404})`, then throw `ProductNotFoundException`. Any other `FunctionException` keeps today's fault.
   - When both attempts fail on transport (step 4): `await _report.faultUnlessWeather(e, stackTrace: st, area: 'barcode_scanning', message: 'lookup-product unreachable after one retry', analytics: _analytics)`. Offline and timeout become a `barcode_scanning.weather` breadcrumb plus one count; anything else faults. Then throw `ProductLookupUnavailableException`.
   - `barcode_scanning` is not a promoted area.
6. **The barcode path stops re-reporting and shows the not-found dialog with content words.**
   - In `SupabaseBarcodeService.lookupBarcode`, add `on ProductNotFoundException` → `BarcodeResult.notFound(barcode: …, message: '')`, and `on ProductLookupUnavailableException` → `BarcodeResult.error(…, message: e.message)`. Neither reports: the service already did. Both go before the generic `on ProductDetailException` (`:38-49`), which keeps its `degraded` for anything else.
   - The scanner screen's `_showLookupResult` (`barcode_scanner_screen.dart:356-377`) already tracks `barcode_lookup_failed {reason: not_found}` and opens `_showNotFoundResult` for a not-found result.
   - In `_showNotFoundResult` (`:517-…`), take the title (`:538`, "Product Not Found") and the body from content and ignore `message`. New keys under `barcode_scanner` (`content_keys.dart:290-309`, `content_defaults.json:353-366`): `not_found_title` "Product Not Found" (today's words), and `not_found_body` "This barcode isn't in our food databases yet. Create the food manually, or try another barcode."
   - The service's "Product not found in nutrition databases" literal (`supabase_barcode_service.dart:35`) is no longer shown. Leave it as the result's debug message.
   - `_showError`'s own words ("Error", "Try Again") are not part of this ruling and stay (Questions).
7. Check whether `test/shared/source_guard/` flags the new `on FunctionException` catch, whose only report is `_report.noteExpected(`. `.noteExpected(` is not in `reportCalls` today (`source_guard.dart:91-106` lists `.faultUnlessWeather(` but not it). If the guard flags it, add `'.noteExpected('` to `reportCalls` with a comment in the same commit (#117).

## Touches

- supabase/functions/describe-meal/index.ts
- supabase/functions/describe-meal/index.test.ts
- lib/features/meal_logging/application/meal_ai_service.dart
- lib/features/meal_logging/presentation/screens/log_meal_screen.dart (the Describe validator, `describeMaxChars`, the `tooLong` branch in the `MealAiException` catch)
- lib/features/barcode_scanning/application/product_detail_service.dart
- lib/features/barcode_scanning/application/supabase_barcode_service.dart
- lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart (`_showNotFoundResult` only)
- lib/features/content/domain/content_keys.dart
- assets/config/content_defaults.json
- test/features/meal_logging/describe_too_long_test.dart (new)
- test/features/barcode_scanning/lookup_product_not_found_and_retry_test.dart (new)
- test/features/barcode_scanning/presentation/barcode_scanner_not_found_dialog_test.dart (new)
- test/shared/source_guard/source_guard.dart (only if item 7 needs it)

No codegen: `mealAiService` and `productDetailService` keep their provider signatures (only constructor arguments change), so no `.g.dart` changes. No Drift change, no migration.

**Call sites read, not changed** (they call `getProductDetails` and keep catching `ProductDetailException` or everything): `log_meal_screen.dart:709-…` and `:764-…` (resolve a search result by barcode or OFF id), `build_meal_screen.dart:855`, `:903`, `food_preferences_screen.dart:462`, `carb_loading_food_selection_controller.dart:702`, `swap_food_screen.dart:525`, `food_search_controller.dart:454-…` (typed-barcode search; it notes `ProductDetailException`, which now also covers the two subclasses), `shared_food_search_service.dart:91`. Each gains the 10 s bound and the one retry. A 404 there now arrives as `ProductNotFoundException` with one `expected_failure` count instead of a service fault, and the caller's own catch still reports what it reported before. The archived `photo_capture_screen.dart` switches on `MealAiFailureKind` without a default, but nothing imports it (`app_router.dart:94` is commented out) and analysis excludes `lib/features/_archived/**`, so `tooLong` does not break the build.

**Overlaps:** 72 and 73 both list `content_keys.dart` and `content_defaults.json`. They cannot run beside 79 in one wave unless the lead gives the three content edits to one agent or runs them in sequence (#63). No other ticket in fix wave 8 lists `log_meal_screen.dart`, `meal_ai_service.dart` or the barcode files (the lead checks 74–77 and 80 at the wave's start).

## Tests

- [ ] **Seam, through the real service and the real screen** (`describe_too_long_test.dart`, on `describe_not_food_test.dart`'s harness: real `LogMealScreen` → Describe, mocked `FunctionsClient`, `RecordingReport`, `RecordingAnalyticsTracker`). Producer-shaped server answer: `FunctionException(status: 400, details: {'success': false, 'error': 'description is too long (max 2000 characters)', 'too_long': true, 'max_length': 2000})`, as `errorResponse` builds it.
  - Type 2,001 characters and tap Analyze. The field shows the `too_long` line with `n` 2000, wrapped, and `invoke` was never called.
  - Type 2,000 characters plus surrounding spaces. The call is made (the trimmed text is exactly at the limit).
  - With the server stubbed to the flagged 400 (a client that skips the cap, driven through `MealAiService.describeMeal` directly): the result is `MealAiFailureKind.tooLong`, one `expected_failure {area: meal_logging, reason: description_too_long}` reaches the tracker, and the report has no `degraded`/`fault`. On the screen, no snackbar and the field shows the line.
  - A 400 **without** the flag stays `serverError` with one `degraded`.
- [ ] **Unit** (`lookup_product_not_found_and_retry_test.dart`, mocked `FunctionsClient`; the 404 body is copied from `lookup-product/index.ts:248-252`):
  - The 404 throws `ProductNotFoundException`, sends one `expected_failure {area: barcode_scanning, reason: barcode_not_found}` and no fault. `SupabaseBarcodeService.lookupBarcode` returns `BarcodeResultNotFound` and reports nothing more.
  - The first `invoke` never completes (fake async) and the second answers 200: two calls, a product, one retry breadcrumb, no report. The timer is cancelled inside the test body (#110).
  - Two `SocketException`s: exactly two calls, `ProductLookupUnavailableException`, a `barcode_scanning.weather` breadcrumb and a count, no fault. `lookupBarcode` returns `BarcodeResultError` with no second `degraded`.
  - A 500 `FunctionException`: one call (no retry) and today's fault.
- [ ] **Widget** (`barcode_scanner_not_found_dialog_test.dart`, on `barcode_scanner_manual_entry_test.dart`'s harness with `testContentService`): Enter → `98765432109871` with the scanner service returning `BarcodeScanResult.notFound`. The dialog shows the `not_found_title` and `not_found_body` content values, Try Another / Cancel / Create Manually, and `barcode_lookup_failed {reason: not_found}`.
- [ ] Deno: `deno test --allow-all supabase/functions/describe-meal/index.test.ts` (RUNBOOK fix-wave step 5: `--allow-all`, never `--allow-sys`).
- [ ] `flutter analyze` clean on touched files.
- [ ] #116, #76: `grep -rl` under `test/` for `MealAiService`, `mealAiServiceProvider`, `MealAiFailureKind`, `describeMeal`, `LogMealScreen`, `describeMinChars`, `ProductDetailService`, `productDetailServiceProvider`, `ProductDetailException`, `SupabaseBarcodeService`, `BarcodeScannerScreen`, `ContentKeys` and `content_defaults`, and run every file named (today that includes `meal_ai_service_credits_test.dart`, `meal_logging_business_logic_test.dart` around `:1631-1870`, `describe_not_food_test.dart`, `describe_error_lines_wrap_test.dart`, `describe_back_keeps_analysis_test.dart`, `food_search_barcode_query_test.dart` (it mocks `ProductDetailService`), `barcode_scanner_service_analytics_test.dart`, the content-defaults guard tests).
- [ ] #117: run `test/shared/source_guard/` (item 7).
- [ ] #118: no expected outcome is written into notifier state. `DescribeAnalysisController` already keeps failures out of state (`describe_analysis_controller.dart:100-108`).
- [ ] Async paths, written down in Fix notes: Analyze tapped twice on a too-long text (the validator stops both; no call); the scanner closed while the retry runs (the loading dialog pop and `_showLookupResult` are guarded by `mounted`, `barcode_scanner_screen.dart:333-336`, `:349-352`; the late answer is dropped); a timed-out first request that lands on the server after the retry already answered (two server runs, one result shown; see Fix 4's write list).

## Deploy

No SQL. Functions: `describe-meal` to dev (`./scripts/deploy_dev.sh describe-meal`), by the lead at the close, from the merged tree. lookup-product is unchanged.

## Retest

On a simulator, in the retest ticket after fix wave 8, as test@test.com:

- **68-002:** Paste 2,149 characters into Describe and tap Analyze. The field shows "That's more than 2,000 characters…" (the content line) under the text, with no snackbar and no describe-meal request in the edge logs. No `error_reported` and no `token_ledger` row; `meal_ai_validation_failed` fires. Trim to under 2,000 and Analyze: the call goes out.
- **68-007:** Scan barcode → Enter → `98765432109871` → Look it up. The "Product Not Found" dialog shows the content body, with Try Another / Cancel / Create Manually. One lookup-product 404 in the edge logs. `barcode_lookup_failed {reason: not_found}` and `expected_failure {area: barcode_scanning, reason: barcode_not_found}` fire; no `error_reported`. Create Manually opens the create-food screen.
- **68-018:** This is hard to force on a simulator. Look up `12345670` once on a normal network: one request, a product in about 1 s. Then turn the simulator host's network off (or use Network Link Conditioner "100% Loss") and look it up again. The "Unable to connect" dialog appears after about 20 s, not 30 s. The console shows the retry breadcrumb, and there is no `error_reported`, only a `barcode_scanning.weather` breadcrumb and an `expected_failure` count.

## Questions for Lee

1. The "Error / Unable to connect" dialog's Try Again (`barcode_scanner_screen.dart:704-708`) goes back to the scanner instead of looking the code up again (68-007 notes it). After a typed code that means typing it again. Should Try Again re-run the lookup of the same code? Recommended: yes. One line in `_showError`'s action (re-call `_lookupBarcode(_lastScannedBarcode)`), added to this ticket if ruled before the wave.

Next: /testing-wave develop-2026-10 (fix wave 8)
