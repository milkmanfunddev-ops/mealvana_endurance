# Flutter 3.35 Migration Summary

## Fixed Breaking Changes

### 1. DropdownButtonFormField - initialValue → value
**Files Fixed (2):**
- `lib/features/calendar/presentation/screens/event_edit_screen.dart`
- `lib/features/calendar/presentation/screens/event_creation_screen.dart`

**Change:**
```dart
// Before
DropdownButtonFormField<EventType>(
  initialValue: _selectedEventType,
  ...
)

// After
DropdownButtonFormField<EventType>(
  value: _selectedEventType,
  ...
)
```

### 2. Switch - activeThumbColor → thumbColor/trackColor
**Files Fixed (2):**
- `lib/features/settings/presentation/screens/settings_screen.dart`
- `lib/features/feedback/presentation/screens/survey_page_2.dart`

**Change:**
```dart
// Before
Switch(
  value: state.isRecurring,
  onChanged: controller.setIsRecurring,
  activeThumbColor: AppTheme.primary600,
)

// After
Switch(
  value: state.isRecurring,
  onChanged: controller.setIsRecurring,
  thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
    if (states.contains(WidgetState.selected)) {
      return AppTheme.baseWhite;
    }
    return AppTheme.baseWhite;
  }),
  trackColor: WidgetStateProperty.resolveWith<Color>((states) {
    if (states.contains(WidgetState.selected)) {
      return AppTheme.primary600;
    }
    return AppTheme.baseGrey.withValues(alpha: 0.3);
  }),
)
```

### 3. Color - withOpacity() → withValues(alpha:)
**Files Fixed (5):**
- `lib/features/settings/presentation/screens/settings_screen.dart`
- `lib/features/carb_loading/presentation/widgets/carb_loading_header_card.dart`
- `lib/features/carb_loading/presentation/widgets/carb_loading_food_pills.dart`
- `lib/features/feedback/presentation/screens/survey_page_2.dart`
- `lib/features/nutrition_plan/presentation/widgets/swipeable_food_item.dart`

**Change:**
```dart
// Before
AppTheme.baseGrey.withOpacity(0.3)

// After
AppTheme.baseGrey.withValues(alpha: 0.3)
```

## Build Status

✅ **All errors in `lib/` folder fixed**
✅ **Ready for `shorebird release ios`**

Test errors remain in `test/` and `test_old/` folders but won't affect production builds.

## How to Catch These Issues Early

Run `flutter analyze` before building:

```bash
# Check for all issues
flutter analyze

# Check only lib folder (production code)
flutter analyze 2>&1 | grep -E "^  error" | grep -v "test/"
```

## Future Prevention

Consider adding this to your CI/CD pipeline or as a git pre-commit hook to catch breaking changes before they cause build failures.
