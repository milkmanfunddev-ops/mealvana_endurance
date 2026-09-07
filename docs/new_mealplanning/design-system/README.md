# Mealvana Kyle Design System - HTML/CSS kit

A web reproduction of the Flutter app's "Kyle" design system, lifted value-for-value from
`lib/theme/kyle_design/` and `lib/shared/widgets/kyle_design/` (plus the handful of feature
widgets the new meal-planning design reuses). It exists so that Claude Design / browser mockups
render with the same hex, px, weights, radii, paddings, heights, borders and shadows as the app.

```
docs/new_mealplanning/design-system/
  tokens.css        CSS custom properties for every AppColors / AppSpacing / AppRadius / AppShadows /
                    AppIconSizes / AppSizes / AppTextStyles constant, plus the dark + light ColorScheme
  kyle.css          component classes (uses ONLY tokens.css variables)
  previews/*.html   one self-contained page per group (both CSS files inlined), dark-first with a
                    light variant wherever the Dart widget defines one
  README.md         this file
```

Default theme is **dark** (`AppTheme.darkTheme`, `scaffoldBackgroundColor: AppColors.blackberry`).
Put `data-theme="light"` on any ancestor to switch a subtree to `AppTheme.lightTheme`.

## Fonts

The app bundles Sansita, Apercu and Compadre from `assets/fonts/`. In this kit:

| Dart family | CSS stack | Notes |
|---|---|---|
| `AppTextStyles.sansita` | `"Sansita", Georgia, serif` | loaded from Google Fonts via `<link>` in every preview |
| `AppTextStyles.apercu` | `"Apercu", "Helvetica Neue", Helvetica, Arial, sans-serif` | **not web-licensed here; falls back** |
| `AppTextStyles.compadre` | `"Compadre", "Archivo", sans-serif` | **not web-licensed here; falls back** to Archivo (Google Fonts) |

Sizes, weights, `height` (line-height) and `letterSpacing` are exact even where the face falls back.

## Class to widget map

| CSS class | Dart widget / file | Key values (from source) |
|---|---|---|
| `.k-btn-primary` (`--small`, `--icon`) | `KylePrimaryButton` / `primary_button.dart` | h 56 (small 40); bg `Colors.orange` **#FF9800** (not AppColors.orange); fg #381633; disabled bg orange 0.4; radius 100; padding 12 24; Sansita 16/700; icon 20 + gap 8; icon button 48 circle #F78B14 |
| `.k-btn-secondary` (`--blackberry`, `--light`, `--small`, `--icon`) | `KyleSecondaryButton` / `secondary_button.dart` | h 56 (small 44); transparent; border 2 orange #F78B14 / textLight #381633 / onSurface; disabled fg 0.4 (border stays); radius 100 |
| `.k-btn-tertiary` (`--underlined`, `--small`, `--icon`) | `KyleTertiaryButton` / `tertiary_button.dart` | fg dragonfruit #DC2597; disabled 0.4; radius 12; padding 8 12; Apercu 14/500; small: padding 4 8, 12/500, icon 16 |
| `.k-btn-add-food` | `KyleAddFoodButton` / `add_food_button.dart` | border 2 `Colors.orange` #FF9800; radius 100; padding 12 16; plus 20 + gap 12; buttonPrimary bold |
| `.k-btn-circular` | `CircularActionButton` / `circular_action_button.dart` | 42 circle, icon 20, icon cream / blackberry |
| `.k-segmented` / `.k-segmented__item` | `KyleSegmentedControl` / `segmented_control.dart` | outer padding 8; item margin 0 1, padding 12 16, border 2 cream (dark) / blackberry, radius 15; selected fill cream; Sansita 12/700 |
| `.k-selection` (`--icon`), `.k-selection-group` | `KyleSelectionButton` / `selection_button.dart` | padding 16 12 (icon: 12 8); border 2 fg / fg 0.3; radius 15; bodyMedium w600 fg 0.7; icon 28 + smallLabel 9px w700 |
| `.k-choice[.is-selected/.is-disabled]` | `_ChoiceButton` / `ai_coach_choice_buttons.dart` | padding 8 16; radius 999; border 1; selected electrolyte / blackberry w700; enabled electrolyte 0.6 border, 0.1 bg (light 0.07), text electrolyte (light electrolyteDark) w500; disabled cream 0.15 border, cream 0.3 text |
| `.k-prompt-chip` | `_PromptChip` / `ai_coach_chat_screen.dart` | padding 8 16; border electrolyte 0.7; bg electrolyte 0.12 (light 0.08); bodySmall |
| `.k-slot-chip` | `_SlotChip` / `ai_coach_meal_card.dart` | padding 4 8; bg electrolyte 0.15; border 0.5 electrolyte 0.4; radius 999; 11px w600 electrolyteDark |
| `.k-slot-chip--log` (`--breakfast/--lunch/--dinner/--snack`) | `_SlotChip` / `meal_log_row.dart` + `slot_palette.dart` | padding 2 7; bg slotColor 0.18; radius 6; 11px w700; orange / electrolyteDark / #8E6FD8 / dragonfruit |
| `.k-slot-select` | `_SlotSelector` / `ai_coach_meal_card.dart` | padding 6 16; selected electrolyte + blackberry w700; else electrolyte 0.1 bg, 0.3 border, electrolyteDark w500 |
| `.k-filter-chip`, `.k-filter-chip-row` | `_Chip` / `filter_chip_row.dart` | row h 40, gap 12; padding 8 12; radius 999; selected electrolyte 0.25 + border electrolyte w600; else surfaceContainerHighest + outlineVariant border w500; 13px |
| `.k-phase-tab`, `.k-phase-tabs` | `PhaseTabBar` / `phase_tab_bar.dart` | gap 12, padding 12 16, radius 999; active orange + `Colors.white` w600; else surfaceContainerHighest + onSurface w500 |
| `.k-tab-pill` / `.k-tab-pill__item` | `_TabBar` / `log_meal_screen.dart` | h 38; track white12 (light black 0.07); radius 20; item margin 3, radius 17, selected cream/blackberry; 12.5px w700 / w500; unselected fg 0.7 (light 0.6) |
| `.k-type-chip` | `_TypeChip` / `log_meal_screen.dart` | padding 5 12; radius 20; selected electrolyte + blackberry w700; else white12 + white |
| `.k-preset-chip`, `.k-preset-chips` | `IntensityPresetChips` / `intensity_preset_chips.dart` | padding 12 16; radius 999; selected orange 0.15 bg, border 2 orange, text orange w700; else border 1 fg 0.4; disabled 0.2 / 0.3 |
| `.k-card` (`--elevated-N`, `--themed`) | `BaseCard` / `base_card.dart`; theme `cardTheme` | surface; radius 15; padding 16; shadow black 0.1 blur 2N offset N; themed: border #333333 / #E0E0E0, margin 8 0 |
| `.k-hero-card` (`--today`, `--completed`), `.k-event-icon`, `.k-date-badge` | `ActivityHeroCard` / `TodaysActivityCard` / `UpcomingEventCard` / `activity_hero_card.dart` | padding 20 (today 16); border outline 0.2 (completed electrolyte 0.3); icon 36 + gap 16; subtitle style title; badge electrolyte 0.1 radius 15 |
| `.k-meal-card`, `.k-macro-row`, `.k-log-it`, `.k-confirm`, `.k-sheet-handle` | `AiCoachMealCard` / `ai_coach_meal_card.dart` | bg blackberryLight; border electrolyte 0.25; padding 16; name sectionTitle 15px; desc bodySmall fg 0.6; macro labels 12px w500 fg 0.75, fire 11; Log it padding 6 16 electrolyte radius 999 buttonPrimary 13px; Confirm h 48 |
| `.k-meal-row` | `MealLogRow` / `meal_log_row.dart` | Card margin 4 0, border #333333, radius 15; padding 12 10 4 10; icon 40; name bodyMedium w600; kcal 14 w700 white; macros 12 w600 electrolyteDark / #8E6FD8 / dragonfruit; star 20 |
| `.k-macro-tile`, `.k-macro-strip` | `_MacroTile` / `macro_summary_strip.dart` | h 68; gap 6; tint 0.18 (light 0.13); radius 10; padding 6; 19px w800 / 10px w600 ls 0.3 / 9px fg 0.45 |
| `.k-macro-table` | `MacroTargetsTable` / `macro_targets_table.dart` | border 1 outline; radius 15; header padding 12 sectionTitle + info 20 dragonfruit; cells padding 12, borders outline 0.3; data dataNumber 15px |
| `.k-nutrition-card`, `.k-macro-summary`, `.k-macro-item`, `.k-food-row` | `NutritionSectionCard` / `nutrition_section_card.dart` | border outline 0.2; header padding 16 activityTitle; summary electrolyte 0.1 radius 15; item dataNumber 20; food row padding 12 border outline 0.1 radius 15, pen `Colors.orange`, trash dragonfruit |
| `.k-food-card`, `.k-facts`, `.k-quantity` | `FoodItemCard` / `food_item_card.dart` | header padding 16; facts bg surfaceContainerHighest 0.3 radius 12; values dataNumber 20 orange/electrolyte/dragonfruit/onSurface; quantity border 2 `Colors.orange` radius 100 |
| `.k-input` | `KyleInputField` / `kyle_input_field.dart` | h 48; bg #5A3366; radius 12; no border in any state; inputText cream; hint cream 0.5; padding 16 14; suffix lowercase cream 0.4 |
| `.k-text-field` (`.is-error`, `.is-disabled`, `:focus-within`) | `KyleTextField` / `KyleSearchField` / `text_field.dart` | border 1 outline; focus `Colors.orange` 2; error dragonfruit 1 (focused 2); disabled outline 0.3; radius 15; padding 16 16; hint onSurface 0.5; icons 20 |
| `.k-switch` (`.is-on`, `.is-disabled`) | `KyleSwitch` / `kyle_switch.dart` | thumb white (disabled 0.65); on electrolyte (light electrolyteDark); off onSurface 0.32 (light 0.26); disabled 0.45 of off; outline transparent |
| `.k-stepper` | `KylePlusMinusControl` / `plus_minus_control.dart` | buttons 36 circle border 2 `Colors.orange`, icon 20 cream (light AppColors.orange), disabled 0.4; gap 24; value dataNumber 20 w700; label descriptor w700 |
| `.k-pill-slider` | `TwoOptionPillSlider` / `two_option_pill_slider.dart` | h 46, radius 23, thumb inset 2 radius 21, 220ms; w700/w500 labels; disabled opacity 0.6 (colours are constructor params) |
| `.k-dropdown` | `KyleDropdown` / `kyle_dropdown.dart` | padding 4 16; bg blackberry 0.3 (light cream); border 2 fg; radius 15; value dataNumber 32/600; chevron 24 |
| `.k-outline-btn` | `_OutlineButton` / `log_meal_screen.dart` | padding 12 0; border 1.5 white24 / black12; radius 16; icon 24; bodySmall w600; disabled opacity 0.5 |
| `.k-snackbar--success/error/warning/info/loading` | `MealvanaSnackbar` / `mealvana_snackbar.dart` | radius 16; border textColor 0.2; margin 20 16; padding 16; icon 20 + gap 12; bodyLarge w600 lh 1.3; bg electrolyte / dragonfruit / orange / cream / cream |
| `.k-food-icon` (`--pref --avoid/--dislike/--neutral/--like/--love`, `--40`) | `KyleFoodIcon` / `KyleFoodPreferenceIcon` / `food_icon.dart` | 36 circle electrolyte, icon 18 textLight; pref border 2 |
| `.k-activity-icon` (`--unselected`) | `KyleActivityIcon` / `KyleActivityTypeSelectorIcon` / `activity_icon.dart` | 36 circle; unselected electrolyte 0.2 + border 2 electrolyte |
| `.k-nav-pill` / `.k-nav-pill__btn` | `FloatingActionButtonsBar` / `floating_action_buttons_bar.dart` | h 43; padding 0 4; radius 25; bg blackberry 0.35 + blur 8; border 1 cream; buttons 42, gap 8; active bg cream |
| `.k-section-header` | `SectionHeaderText` / `section_header_text.dart` | Sansita 17/700/1.2; padding 24 16 12 |
| `.k-large-stat` (`--single`), `.k-compact-stat` | `LargeStatDisplay` / `SingleLargeStat` / `CompactStatDisplay` / `large_stat.dart` | padding 20; border outline 0.2; icon 48; smallLabel bold; value dataNumberLarge 28 (single 48); compact value dataNumber 24 |
| `.k-avatar` (`--28`, `--64`, `.is-pulsing`) | `AiCoachAvatar` / `ai_coach_avatar.dart` | circle electrolyte; shadow electrolyte 0.35 blur 8 (0,2); "M" Sansita 700 size*0.42 clamp 12..40; pulse 1.0 to 1.12 |
| `.k-bubble-user`, `.k-bubble-ai` (`--has-parts`), `.k-typing` | `_UserBubble` / `_AssistantBubble` / `_TypingIndicator` / `ai_coach_chat_screen.dart` | padding 12 16; user electrolyte radius 20/20/8/20, lh 1.5; ai blackberryLight radius 8/20/20/20, lh 1.6; dots 6px gap 4 fg 0.5 |
| `.k-input-bar`, `.k-send`, `.k-streaming`, `.k-retry` | `_buildInputBar` / `_SendButton` / `_StreamingIndicator` / `_RetryButton` / `ai_coach_chat_screen.dart` | bar padding 16 12 12 16, top border 0.5 fg 0.2; field radius 20, border 0.5, focus electrolyte 1.5, padding 12 16, max-h 140; send 44 circle; retry padding 12 20 |
| `.t-*` | `AppTextStyles.*` / `app_text_styles.dart` | one utility per named style |

## Copied exactly vs approximated

**Copied exactly (from source):** every hex, alpha, px, weight, line-height, letter-spacing,
radius, padding, gap, border width, shadow, and every enabled / selected / disabled / loading /
error / focused state that the Dart widget defines. Where a widget uses a Flutter Material literal
instead of `AppColors` (for example `Colors.orange` #FF9800 in `KylePrimaryButton`), the literal is
kept, not "corrected" to the brand orange.

**Approximated (called out in the CSS comments and preview captions):**

- **Fonts** - Apercu and Compadre fall back (see above). Metrics are exact, the face is not.
- **Icons** - the app uses FontAwesome and Material icons; the previews use simple inline SVG
  strokes at the same pixel size. Icon *glyphs* are placeholders, icon *sizes and colours* are exact.
- **`KyleSwitch` geometry** - the Dart file only sets colours; track/thumb size (52x32, 16/24 thumb)
  is Flutter's Material 3 default and is reproduced from that spec, not from the repo.
- **`KyleTextField` height** - `AppSizes.inputHeight = 46` is declared but the widget is sized by
  `contentPadding` + text, so the CSS is content-sized too (comment in `kyle.css`).
- **Snackbar elevation 8** - rendered with Material's elevation-8 shadow recipe; Flutter computes it.
- **Ink splashes / pressed ripples** and the `AnimatedContainer` / `AnimatedAlign` timings are
  reproduced only as CSS `transition` durations (200ms, 180ms, 150ms, 220ms) - no ripple.
- **`TwoOptionPillSlider` colours** are constructor parameters; the preview picks representative values.
- **`colorScheme.outlineVariant`** is never set in `app_theme.dart`; Flutter falls back
  `outlineVariant -> onBackground -> onSurface`, so `--theme-outline-variant` = onSurface.
- No hover state is defined in Flutter, so none is styled.

## Syncing with the app

1. Edit the Dart source first (`lib/theme/kyle_design/*`, `lib/shared/widgets/kyle_design/*`).
2. Mirror the change into `tokens.css` (constants) or `kyle.css` (widget anatomy), quoting the new
   value in the comment block above the class. Never round.
3. Rebuild the previews so the inlined CSS is fresh: the preview HTML files are the two CSS files
   inlined into a shell plus the per-group body. Regenerate by re-inlining (each preview's `<style>`
   is `tokens.css` + `kyle.css` + a small preview-chrome block), and keep the first line
   `<!-- @dsCard group="<Group>" -->` intact - Claude Design uses it to card the page.
4. Push to Claude Design with the DesignSync tool: `list_projects` -> project
   "Mealvana Kyle Design System" (create if missing) -> `finalize_plan` with
   `localDir = docs/new_mealplanning/design-system`, `writes = ["**/*.html", "**/*.css", "README.md"]`
   -> `write_files` with `localPath` for every file.
5. Groups: Colors, Type, Spacing, Buttons, Chips, Cards, Inputs, Feedback, Navigation, Chat.
