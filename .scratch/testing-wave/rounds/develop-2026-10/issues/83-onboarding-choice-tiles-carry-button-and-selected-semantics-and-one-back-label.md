# 83: Onboarding's choice tiles are buttons that report selected, and the app-bar back arrow is named "Back" once

**Status:** in-progress (wave 8, 2026-10-09)
**Labels:** fix, round:develop-2026-10, area:onboarding, area:accessibility
**Branch:** `develop-next` (fix-wave worktree)
**Source:** Finding 67-001 (the retest of 48-006); TRIAGE.md rulings of 2026-10-09
**Blocked by:** nothing.
**Next:** `/testing-wave develop-2026-10` (fix wave 8)
**Model:** opus

Line numbers are from code at `84615131`. The change is to labels and semantics only. No onboarding body copy changes, because that copy is Xuan's (an accessibility label is not body copy), and nothing is redrawn.

Lee, 2026-10-09: "the tiles get `Semantics(button: true, selected: …)` (or the library component's semantics: if a tile is a `lib/shared/widgets/kyle_design/` component, fix it there once), and the duplicated back label is fixed once in the shared app bar/back control. VoiceOver itself stays a device check (ticket 51)."

## Findings

- **67-001 · Onboarding choice tiles are StaticText with no selected state, and app-bar back arrows read "Back Back".** Signed out, Build My Plan, walking onboarding (23:11Z), `idb ui describe-all` before and after tapping MALE. Every single-choice tile lists as `StaticText` with traits `["StaticText", "Scrollable"]` and no selected value, even though the screen draws MALE as selected:
  - Tell us about yourself: `'MALE'`, `'FEMALE'`, `'NON-BINARY'` (`runs/67/ui-10-personal-info.txt`; after the tap, `runs/67/ui-10b-personal-info-male-selected.txt`; picture `runs/67/67-10-personal-male.png`).
  - Basic body composition: `'Imperial'`, `'Metric'` (`runs/67/ui-11-body-composition.txt`).
  - Nutrition Settings: `'LOW\n0.7×'`, `'MODERATE\n1.0×'`, `'HIGH\n1.2×'`, `'LIGHT\n0.85×'`, `'MEDIUM\n1.0×'`, `'HEAVY\n1.2×'` (`runs/67/ui-12-nutrition-settings.txt`, `runs/67/67-12-ob-nutrition-settings.png`).

  Sports, goals and pitfalls already list as `CheckBox … '0'/'1'`. The top-left back arrow lists as `Button 'Back\nBack'` on Sign Up with Email, Settings and Connected Apps. Onboarding's own back circle and the Log In choice screen read `Button 'Back'`.

## Fix

**Where the tiles live (the library rule).** From code: none of the three tiles is a library component. Each is a private widget in its screen's file: `_GenderCard` (`lib/features/onboarding/presentation/screens/personal_info_screen.dart:683-741`), `_UnitSegment` (`lib/features/onboarding/presentation/screens/body_composition_screen.dart:395-431`) and `_SegmentChip` (`lib/features/onboarding/presentation/screens/nutrition_settings_screen.dart:301-355`). None is under `lib/shared/widgets/kyle_design/`. No spec under `docs/ssot/spec/design/components/` describes them: `selectable-chip-grid.md` is a multi-select toggle grid, not a single-choice tile. Each gets its semantics where it lives. Moving them into the library is not this ticket (Decisions).

**The pattern.** From code: it is already in the app and tested. Profile & Preferences' gender, units, gut and sweat options (`lib/features/settings/presentation/screens/preferences_screen.dart:723-733`, pinned by `test/features/settings/presentation/screens/preferences_accessibility_test.dart:93-120`) use `Semantics(container: true, button: true, selected: isSelected, label: <name>, child: GestureDetector(onTap: …, child: ExcludeSemantics(child: <visuals>)))`. The `GestureDetector`'s tap action lands on the container node. `ExcludeSemantics` drops the inner `Text`, which is today's StaticText.

1. **Gender tiles (Tell us about yourself).** `_GenderCard.build` (`personal_info_screen.dart:699-740`): wrap the `GestureDetector` (`:705-707`) in `Semantics(container: true, button: true, selected: isSelected, label: gender.displayName, …)`, and wrap its `Container` child in `ExcludeSemantics`. `gender.displayName` ("Male", "Female", "Non-binary"; the enum is at `lib/features/auth/domain/user_preferences.dart:720`) is what the tile already shows, upper-cased at `:722`. The key `cardKey` stays on the `GestureDetector`, so `personal_info_screen_test.dart:70`'s tap by key is unchanged.
2. **Imperial / Metric (Basic body composition).** `_UnitSegment.build` (`body_composition_screen.dart:409-430`): the same wrap around the `GestureDetector` (`:410-412`), with `label: label` ("Imperial" / "Metric", passed at `:241` and `:247`) and `ExcludeSemantics` around the `AnimatedContainer`. `segmentKey` stays on the `GestureDetector`.
3. **Gut training and sweat rate (Nutrition Settings).** `_SegmentChip.build` (`nutrition_settings_screen.dart:306-354`): the same wrap around the `GestureDetector` (`:312-314`), with `selected: spec.isSelected` and `label: '${spec.label}, ${spec.multiplier}'`. That gives "Low, 0.7×" and "Light, 0.85×", the same two lines the tile shows (`spec.label` from `_gutLabel`, `:113-122`, or `SweatRateCat.displayName`, `:170`; `spec.multiplier` at `:155`/`:171`), joined with a comma so VoiceOver pauses between them. `spec.key` stays on the `GestureDetector`, so `nutrition_settings_screen_test.dart:77`/`:97` are unchanged.
4. **"Back" once, in the shared control.** From code: `CustomAppBarBackButton` (`lib/shared/widgets/custom_app_bar_back_button.dart:76-105`) wraps its `InkWell` in `Tooltip(message: 'Back')` (`:87-88`) and its icon in `Semantics(button: true, label: 'Back')` (`:92-94`). Flutter's `Tooltip` adds its message to the semantics tree, and the two merge into one node, which iOS reads as `'Back\nBack'`. The three screens in the Finding all mount this control: `email_signup_screen.dart`, `settings_screen.dart` and `connected_apps_screen.dart` (grep). Onboarding's back circle is a separate widget, already one "Back" (`onboarding_accessibility_test.dart:94-111`).
   - Set `excludeFromSemantics: true` on that `Tooltip`. The long-press tooltip still shows, and the `Semantics` label stays the one name. This is one change in one place. Its 45 users in `lib/` (grep `CustomAppBarBackButton`) do not change, because no constructor changes.
   - The literal `'Back'` (two places in this file) is not moved to the content system here. It is the control's existing name, not new copy, and this ticket changes only what the screen reader hears.

**Decisions.**
- The tiles stay private to their screens. They carry an onboarding look and a selected state, which by CLAUDE.md's rule could make them library candidates. Moving them is a component port that needs a spec and `/design-sync`, which is out of scope for a semantics fix. The ruling only says to fix them in the library if they are already there, and they are not.
- `selected`, not `checked`: these are single-choice groups. The sports and pitfalls tiles are multi-select and correctly use `checked` (`onboarding_multi_select_step.dart:320-324`). This matches Profile & Preferences' options.
- Other onboarding selectables are not in the Finding and are not touched: the allergy cards (`FigmaCheckboxCard`, `allergies_screen.dart:330-350`) and the plan-preview tabs (`daily_plan_preview_screen.dart:286-330`). A later run can describe them.
- Async paths: none. The change adds semantics and no state.

## Touches

lib/features/onboarding/presentation/screens/personal_info_screen.dart
lib/features/onboarding/presentation/screens/body_composition_screen.dart
lib/features/onboarding/presentation/screens/nutrition_settings_screen.dart
lib/shared/widgets/custom_app_bar_back_button.dart
test/features/onboarding/onboarding_accessibility_test.dart
test/shared/widgets/custom_app_bar_back_button_test.dart

6 files. No annotated file changes, no codegen, no content keys, no Drift change, no edge function.

**Overlaps.** None with 81 or 82 (checked against their Touches), and none with 70-73: 71 changes onboarding's allergy/diet data, not these three screens (grep of its file). `custom_app_bar_back_button.dart` is mounted by screens that 81 and 82 edit (`buy_credits_screen.dart`, `connected_apps_screen.dart`, `meal_review_screen.dart`), but those tickets do not change the file.

## Tests

- [ ] Widget (`onboarding_accessibility_test.dart`, new cases; the `PersonalInfoScreen` harness is already in the file (import `:23`); for the other two screens, use the pump helpers from `test/features/onboarding/body_composition_screen_test.dart` and `nutrition_settings_screen_test.dart`), with `tester.ensureSemantics()`:
  - Tell us about yourself: `getSemantics(find.byKey(ValueKey('personal_info.gender_male')))` is `isSemantics(label: 'Male', isButton: true, hasSelectedState: true, isSelected: false, hasTapAction: true)`. After tapping it, `isSelected: true`, and Female reads `isSelected: false`. Non-binary is named "Non-binary".
  - Basic body composition: `body_comp.units_imperial_button` and `body_comp.units_metric_button` are buttons named "Imperial" / "Metric" with a selected state that follows a tap.
  - Nutrition Settings: `nutrition_settings.gut_moderate` is a button named "Moderate, 1.0×", selected by default. Tap `gut_high`: it is selected and Moderate is not. The same for one sweat tile.
  - Each case ends with `await expectLater(tester, meetsGuideline(labeledTapTargetGuideline))`, as `:136` does.
- [ ] Widget (`custom_app_bar_back_button_test.dart`, new case): `tester.ensureSemantics()`. The node at `find.byType(CustomAppBarBackButton)` is `isSemantics(label: 'Back', isButton: true, hasTapAction: true)`, and its label is exactly `'Back'` (it fails today with "Back\nBack"). `find.byTooltip('Back')` still finds one widget.
- [ ] `flutter analyze` clean on touched files.
- [ ] #116: before committing, `grep -rl` under `test/` for `PersonalInfoScreen`, `BodyCompositionScreen`, `NutritionSettingsScreen`, `CustomAppBarBackButton` and the tile keys (`personal_info.gender_`, `body_comp.units_`, `nutrition_settings.gut_`/`sweat_`), and run every file named: at least `personal_info_screen_test.dart`, `body_composition_screen_test.dart`, `nutrition_settings_screen_test.dart`, `onboarding_overflow_test.dart`, `onboarding_step_alignment_test.dart`, `onboarding_autofill_in_init_state_test.dart`, `back_button_fallback_test.dart`, `edit_meal_log_guard_test.dart`, `review_remove_undo_and_discard_test.dart`, `buy_credits_back_and_copy_test.dart` and `formula_kit_content_test.dart`. Run the onboarding golden suites too, if `grep -rl` finds goldens for these screens. The semantics wrap draws nothing, so the goldens must not move.
- [ ] #117: no Report helper and no catch, so `test/shared/source_guard/` is not needed.

## Deploy

None. Client only.

## Retest

Next test wave, on a simulator, with `idb ui describe-all`:
- **67-001 (tiles):** Tell us about yourself. MALE / FEMALE / NON-BINARY each list as `Button` (not StaticText). After tapping MALE, Male carries the selected value or trait and the others do not. Basic body composition: Imperial / Metric are Buttons, and the chosen one is selected. Nutrition Settings: the six tiles are Buttons named like "Moderate, 1.0×", and the default (Moderate, Medium) is selected.
- **67-001 (back):** the top-left back arrow on Sign Up with Email, Settings and Connected Apps lists as `Button 'Back'`, one "Back", not `'Back\nBack'`.
- VoiceOver's spoken output stays ticket 51's device check.

## Questions for Lee
