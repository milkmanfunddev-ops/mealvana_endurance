# 51: Controls VoiceOver cannot name get labels

**Status:** ready-for-agent
**Blocked by:** 34 (touches lib/features/meal_planning/presentation/widgets/meal_add_button.dart), 50 (touches lib/features/meal_logging/presentation/screens/log_meal_screen.dart), 44 (touches lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** `KyleSheetHeader`'s close button has a label (every sheet using it gains one). A ticked Add in Browse is still an element, labelled as added; the filter menu marks the active filters as selected, not by colour only. The Log search bar's barcode and search buttons, and the scanner's flash, Reset and Switch, are labelled buttons. The water-bottle checkbox exposes its checked state.

**Findings:** 08-002, 18-005, 28-006, 31-002 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/shared/widgets/kyle_design/sheets/kyle_sheet_header.dart, lib/features/meal_planning/presentation/widgets/meal_add_button.dart, lib/features/meal_planning/presentation/screens/vana_browse_screen.dart, lib/features/meal_logging/presentation/screens/log_meal_screen.dart, lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart, lib/features/settings/presentation/screens/preferences_screen.dart

- [ ] Semantics tests for each control.
- [ ] `/design-sync` run for the kyle_design change.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
