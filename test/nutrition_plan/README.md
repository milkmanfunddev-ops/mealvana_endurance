# Nutrition Plan Integration Tests

This directory contains integration tests for the nutrition plan functionality, specifically testing the `generate-ai-nutrition-plan` edge function.

## Purpose

The main integration test validates that:

1. **Adjusted macros are properly sent** from the adjust macros screen to the edge function
2. **The edge function receives the correct macro targets** in the expected format
3. **The returned nutrition plan matches the adjusted values** (not the original calculated values)
4. **Food recommendations align with the adjusted macro targets**

## Problem Being Tested

Previously, the AI nutrition plan was receiving incorrect macro values because:
- The `createNutritionPlan` method had a TODO and wasn't calling the actual edge function
- Values being sent didn't match what the user adjusted on the adjust macros screen
- The data flow was broken between the adjust macros screen and the AI plan generation

## Running the Integration Test

### Prerequisites

1. **Supabase Project**: You need access to a Supabase project with the `generate-ai-nutrition-plan` edge function deployed
2. **Environment Variables**: Set up your Supabase credentials

### Setup

1. Export your Supabase credentials:
```bash
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key-here"
```

2. Run the integration test:
```bash
# Option 1: Run the specific test file
flutter test test/nutrition_plan/generate_ai_nutrition_plan_integration_test.dart

# Option 2: Run via the helper script
dart test/nutrition_plan/run_integration_test.dart
```

### What the Test Does

The integration test sends this adjusted macro data to the edge function:

```dart
final testMacroTargets = {
  'pre_run': {
    'carbs_g': 75.0,      // User adjusted from original 65.0
    'protein_g': 25.0,    // User adjusted from original 20.0
    'fat_g': 15.0,
    'water_ml': 600.0,    // User adjusted from original 500.0
    'sodium_mg': 400.0,   // User adjusted from original 300.0
  },
  'during_run': {
    'carbs_total_g': 45.0,     // User adjusted from original 35.0
    'sodium_total_mg': 800.0,  // User adjusted from original 650.0
    'water_total_ml': 750.0,   // User adjusted from original 600.0
  },
  'post_run': {
    'carbs_g': 80.0,      // User adjusted from original 70.0
    'protein_g': 30.0,    // User adjusted from original 25.0
    'fat_g': 12.0,
    'water_ml': 700.0,    // User adjusted from original 600.0
    'sodium_mg': 500.0,   // User adjusted from original 450.0
  },
};
```

### Expected Results

✅ **Success Criteria:**
- Edge function returns success (status < 400)
- Response contains the exact adjusted macro values
- Food recommendations align with adjusted targets (within ±10g tolerance)
- Returned `macro_targets` match what was sent

❌ **Failure Indicators:**
- Edge function returns original calculated values instead of adjusted values
- Food recommendations don't align with the adjusted targets
- Response structure is incorrect or missing fields

## Test Files

- `generate_ai_nutrition_plan_integration_test.dart` - Main integration test
- `run_integration_test.dart` - Helper script with environment checking
- `README.md` - This documentation

## Troubleshooting

### "Missing environment variables" error
Make sure you've exported `SUPABASE_URL` and `SUPABASE_ANON_KEY` in your current shell session.

### "Edge function returns 400+" error
- Check that the edge function is deployed and working
- Verify your API key has the correct permissions
- Check the edge function logs in Supabase dashboard

### "Macro values don't match" error
This indicates the data flow issue is still present:
- The edge function is receiving different values than expected
- The LLM service might not be sending the adjusted macros correctly
- The controller might not be calling the right service method

### "Food recommendations don't align" error
This suggests:
- The edge function is working but the AI is not following the macro targets
- The food database might be limited for the test scenario
- The tolerance might need adjustment based on available foods

## Next Steps

If the test fails, check:
1. **Controller Implementation**: Is `createNutritionPlan` calling `generateLLMNutritionPlanFromMacros`?
2. **Service Implementation**: Is the LLM service sending the `macro_targets` structure?
3. **Edge Function**: Is it properly reading and using the `macro_targets` instead of calculating new ones?
4. **Data Persistence**: Are adjusted values being properly saved and retrieved?