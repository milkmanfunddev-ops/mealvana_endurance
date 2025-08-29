# Adjust Macros Screen — Technical Specification

## Overview
This screen allows runners to review and adjust recommended macros returned by the `generate-macros` edge function, view scientific rationale, and proceed to AI-powered nutrition plan generation.

## Navigation Flow

### Entry Flow
```
distance_pace_gut_entry_screen
  → [Submit button pressed]
  → Show loading spinner
  → Call generate-macros edge function
  → Store results in repository/domain layers
  → Navigate to adjust_macros_screen
  → [User adjusts values if desired]
  → [Create plan button pressed]
  → Call generate-ai-nutrition-plan
  → Navigate to plan_screen
```

### Back Navigation
- **Back button**: Returns to `distance_pace_gut_entry_screen`
- **Behavior**: User must press Continue again to progress (re-calls edge function)
- **Data persistence**: Adjustments are lost on back navigation

### Error Handling
- **Primary**: Call `generate-macros` edge function
- **Fallback**: If edge function fails, use offline calculation algorithm
- **UI**: Show loading spinner during API calls
- **Failures**: Display error via snackbar, allow retry

---

## Architecture & Data Flow

### Data Models (Domain Layer)
```dart
// New models to create:
class MacroTargets {
  final PreRunMacros preRun;
  final DuringRunMacros duringRun;
  final PostRunMacros postRun;
  final RunMetrics metrics;
  final String calculationRule;
  final DateTime timestamp;
}

class PreRunMacros {
  final double carbsG;
  final double proteinG;
  final double fatCapG;
  final double fluidsMl;
  final double sodiumMg;
}

class DuringRunMacros {
  final double carbRateGPerH;
  final double carbTotalG;
  final double fluidRateMlPerH;
  final double fluidTotalMl;
  final double sodiumRateMgPerH;
  final double sodiumTotalMg;
}

class PostRunMacros {
  final double carbsG;
  final double proteinG;
  final double fluidsMl;
  final double sodiumMg;
}

class RunMetrics {
  final double distanceMi;
  final double durationH;
  final double paceMinPerMile;
  final double caloriesGrossKcal;
  final double met;
}
```

### Repository Layer
- Store macro data in Drift database
- Update existing `nutrition_plans` table or create new `macro_targets` table
- Handle API calls and offline fallback
- Integrate with existing `run_parameters` model

### Controller (Presentation Layer)
```dart
@riverpod
class AdjustMacrosController extends _$AdjustMacrosController {
  @override
  FutureOr<MacroTargets> build() async {
    // Load cached macros from repository
    return _repository.getCachedMacros();
  }
  
  Future<void> updateMacroValue({
    required MacroSection section,
    required MacroField field, 
    required double newValue,
  }) async {
    // Update specific field and recalculate linked values
    // Validate against ranges
    // Store to Drift
  }
  
  Future<void> createNutritionPlan() async {
    // Call generate-ai-nutrition-plan with adjusted values
    // Navigate on success
  }
  
  void resetToRecommended() {
    // Reset to original API values
  }
}
```

---

## UI Components & Behavior

### Screen Layout
1. **Header Summary**
   - Duration (HH:MM format)
   - Distance (miles)
   - Pace (min/mi)
   - Total calories (kcal)

2. **Contextual Banner**
   - For runs ≤ 1 hour: "For this duration, during-run carbs are optional"
   - For runs > 1 hour: "Target at least {during_total_g}g carbs during your run"

3. **Macro Adjustment Cards** (Collapsible sections)
   
   **Pre-Run Section** (default: expanded)
   - Carbs: {value}g (editable)
   - Protein: {value}g (editable)
   - Fat cap: {value}g (editable)
   - Fluids: {value} fl oz (editable)
   - Sodium: {value}mg (editable)

   **During-Run Section** (default: expanded)
   - Total Carbs: {value}g (editable, primary display)
   - Total Fluids: {value} fl oz (editable, primary display)
   - Total Sodium: {value}mg (editable, primary display)
   - *Note: Hourly rates calculated but not displayed prominently*

   **Post-Run Section** (default: collapsed)
   - Carbs: {value}g (editable)
   - Protein: {value}g (editable)
   - Fluids: {value} fl oz (editable)
   - Sodium: {value}mg (editable)

4. **Global Help Icon ("?")**
   - Single icon in app bar or prominent location
   - Opens bottom sheet with scientific rationale

5. **Footer Actions**
   - Primary: "Create plan" button
   - Secondary: "Reset all" link

### Display Formatting
- **Units**: US/Imperial (oz, miles, min/mi)
- **Rounding**: 
  - Grams: nearest 1g
  - Fluids: nearest 0.5 fl oz
  - Sodium: nearest 25mg
- **Format**: Always show totals, not per-hour rates
- **Conversions**: ml → fl oz (× 0.033814)

---

## Validation & Warnings

### Validation Ranges (Based on ISSN Research)
**Pre-Run** (1-4 hours before):
- Carbs: 1-4 g/kg body weight (warn if outside)
- Protein: 0.15-0.25 g/kg (optional)
- Fat: <0.2 g/kg (warn if exceeded)
- Fluids: 5-7 ml/kg (approximately 10-14 fl oz for 70kg runner)
- Sodium: 200-400mg

**During-Run** (per hour rates, but display totals):
- Carbs: 30-60 g/h for runs >2.5h (warn <20 or >90 g/h)
- Fluids: 450-750 ml/h (15-25 fl oz/h) (warn <12 or >40 fl oz/h)
- Sodium: 500-700 mg/L of fluid consumed

**Post-Run** (within 30 min):
- Carbs: 1.0-1.2 g/kg body weight
- Protein: 0.25-0.3 g/kg (15-25g typical)
- Fluids: 150% of body weight lost
- Sodium: 500-1000mg

### Validation Behavior
- **Type**: Real-time validation on input change
- **Display**: Non-blocking warnings below fields
- **Style**: Amber warning icon with brief message
- **Allow**: User can proceed with any values (warnings don't block)

### Field Linking Logic
When user edits:
- **Pre/Post sections**: Values are independent
- **During section**: 
  - If user edits total → Calculate hourly rate (total ÷ duration_h)
  - Store both values but only display total
  - No visible "link" toggle to user

---

## Content Management Integration

### CMS Content Keys
```json
{
  "adjust_macros": {
    "screen_title": "Adjust Your Macros",
    "banner": {
      "short_run": "For this duration, during-run carbs are optional",
      "long_run": "Target at least {amount}g carbs during your run"
    },
    "sections": {
      "pre_run": "Pre-Run (1-4 hours before)",
      "during_run": "During Run",
      "post_run": "Post-Run (within 30 min)"
    },
    "validation": {
      "carbs_low": "Below recommended range",
      "carbs_high": "Above recommended range",
      "fluids_low": "May lead to dehydration",
      "fluids_high": "May cause GI distress",
      "sodium_low": "Risk of cramping",
      "sodium_high": "Excessive sodium"
    },
    "help_content": {
      "title": "Why These Targets?",
      "content": "[See scientific rationale content below]"
    },
    "actions": {
      "create_plan": "Create Plan",
      "reset_all": "Reset All",
      "reset_section": "Reset"
    }
  }
}
```

### Scientific Rationale Content (for CMS)
*See separate file: `nutrition_guidance_content.md`*

---

## API Integration

### Request to generate-ai-nutrition-plan
```json
{
  "run_parameters": {
    "distance_mi": 10.0,
    "duration_h": 1.5,
    "pace_min_per_mile": 9.0,
    "calories_gross_kcal": 1050,
    "met": 10.5
  },
  "original_macros": { /* from generate-macros */ },
  "adjusted_macros": {
    "pre_run": {
      "carbs_g": 45,
      "protein_g": 15,
      "fat_cap_g": 10,
      "fluids_fl_oz": 12,
      "sodium_mg": 300
    },
    "during_run": {
      "total_carbs_g": 60,
      "total_fluids_fl_oz": 24,
      "total_sodium_mg": 500
    },
    "post_run": {
      "carbs_g": 60,
      "protein_g": 20,
      "fluids_fl_oz": 20,
      "sodium_mg": 500
    }
  },
  "adjustments_made": ["pre_run.carbs_g", "during_run.total_carbs_g"]
}
```

---

## Analytics Events

Track the following:
```dart
// Screen view
Analytics.track('adjust_macros_screen_viewed', {
  'duration_h': 1.5,
  'distance_mi': 10.0,
  'has_adjustments': false
});

// Field edited
Analytics.track('macro_adjusted', {
  'section': 'pre_run',
  'field': 'carbs_g',
  'original_value': 45,
  'new_value': 50,
  'within_recommended_range': true
});

// Plan created
Analytics.track('nutrition_plan_created', {
  'adjustments_count': 3,
  'duration_h': 1.5
});

// Help viewed
Analytics.track('macro_help_viewed');
```

---

## Testing Requirements

### Unit Tests (`test/features/nutrition_plan/`)
- Validation logic for each macro field
- Field linking calculations
- Unit conversion functions
- Offline fallback calculations

### Integration Tests
- Full flow from distance_pace_gut_entry → adjust_macros → plan
- API error handling and retry logic
- Drift database operations
- Navigation state management

### Widget Tests
- Field editing and validation display
- Collapsible sections
- Bottom sheet display
- Loading states

---

## Acceptance Criteria

1. ✅ Screen receives macro data from previous screen's API call
2. ✅ All macro fields are editable with appropriate numeric keyboards
3. ✅ Validation warnings appear but don't block progression
4. ✅ During-run values show totals (not hourly rates)
5. ✅ Global help icon opens scientific rationale
6. ✅ Reset functionality works at global level
7. ✅ Create Plan calls API with adjusted values
8. ✅ Error states handled gracefully with snackbar messages
9. ✅ Analytics events track user interactions
10. ✅ All text comes from CMS/ContentService
11. ✅ Offline fallback algorithm available
12. ✅ Data persisted to Drift database

---

## Implementation Status

📋 **See [implementation_timeline.md](./implementation_timeline.md) for detailed progress tracking and phase breakdown.**

---

## Notes for Implementer

- Use existing FOA pattern from other screens
- Follow AsyncNotifier pattern for controller
- Integrate with ContentService for all UI text
- Use existing theme/styling from app
- Consider adding haptic feedback for validation warnings
- Ensure accessibility with proper semantic labels