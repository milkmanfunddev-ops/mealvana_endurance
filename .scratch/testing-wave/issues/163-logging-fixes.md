# 163: Logging fixes

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** Three rulings Lee made on 2026-09-28 about questions fixes 135 and 136 left open (`review-20260928-rulings.md` items 8 to 10):
1. **Servings survive an item edit (from 135).** Editing a 2-serving log's items (add or remove a food) keeps `servings` at 2, and the totals stay items × servings. Check the current code first (`edit_meal_log_screen.dart`, `meal_logging_service.dart`, `meal_log.dart`). If it already does this, add the test and say so.
2. **An existing favorite reads "In favorites" (from 136).** A logged meal that is already a favorite shows "In favorites" where "Save as favorite" was. Tapping it never saves a second copy (`meal_log_row.dart`, `meal_card.dart`, `macro_dashboard_screen.dart`, key `mealLogActionsSaveAsFavorite` and a new key beside it).
3. **Typed barcodes are 8, 12, 13 or 14 digits (from 136).** The entry sheet takes only those lengths. The hint (`barcode_scanner.enter_length`) and the error (`barcode_scanner.typed_invalid`) say "Barcodes are 8, 12, 13 or 14 digits" (`barcode_scanner_screen.dart`, `barcode_scanner_service.dart`).

**Findings:** none of their own. These are the product questions raised by fixes 135 and 136 (review items 14 to 16).

**Decisions:** Lee in the terminal, 2026-09-28.

**Touches:** lib/features/meal_logging/presentation/screens/edit_meal_log_screen.dart, lib/features/meal_logging/application/meal_logging_service.dart, lib/features/meal_logging/domain/meal_log.dart, lib/features/meal_logging/presentation/widgets/meal_log_row.dart, lib/features/macro_dashboard/presentation/widgets/meal_card.dart, lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart, lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart, lib/features/barcode_scanning/application/barcode_scanner_service.dart, lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json

- [ ] Seam test through the real notifier: an item edit on a 2-serving log keeps servings 2 and the scaled totals.
- [ ] Widget tests: an existing favorite shows "In favorites", and a tap adds no saved-meal row. The barcode sheet accepts 8, 12, 13 and 14 digits and rejects 9 to 11 with the new error.
- [ ] `flutter analyze` clean on touched files.
