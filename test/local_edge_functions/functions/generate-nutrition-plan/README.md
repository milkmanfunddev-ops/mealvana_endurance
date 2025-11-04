# Generate AI Nutrition Plan - Local Edge Function Tests

This directory contains **unit tests and local edge function tests** for the `generate-nutrition-plan` Supabase edge function.

## Test Files

### Business Logic Tests
- **`business-logic.test.ts`** - Core business logic validation
  - Food preference handling (liked, willing, disliked, essential)
  - Essential food override logic (safety-first approach)
  - Food exclusion and scoring algorithms
  - Nutritional feasibility validation

### Technical Tests
- **`lp-model-debug.test.ts`** - Linear programming model debugging
  - LP solver constraint validation
  - Model structure testing
  - Debugging utilities for LP optimization failures

## Key Test Scenarios

1. **Picky_Beginner_5K** - Runner with many food dislikes
2. **Marathon_Gel_Lover** - High-performance athlete with energy gel preferences
3. **Ultra_Whole_Food_Purist** - Ultra runner preferring natural foods
4. **All_Foods_Disliked_Emergency** - Extreme constraint testing

## Running Tests

```bash
# Run all generate-nutrition-plan local tests
npm test -- functions/generate-nutrition-plan

# Run specific test file
npm test -- business-logic
npm test -- lp-model-debug
```

## Critical Requirements Validated

- ✅ **Disliked foods never appear** (except essential foods)
- ✅ **Essential foods override dislikes** (GU Gel, Gatorade)
- ✅ **Food preference scoring accurate** (Essential=250, Liked=200, Willing=80, Neutral=20)
- ✅ **Nutritional feasibility maintained** (even with picky eaters)
- ✅ **Edge case handling** (empty preferences, extreme constraints)

## Test Philosophy

These tests focus on **business logic validation** rather than full system integration. They test the core algorithms and decision-making logic that powers the nutrition planning system.

For **integration tests** with real Supabase data, see: `/test/integration/edge/generate-nutrition-plan/`