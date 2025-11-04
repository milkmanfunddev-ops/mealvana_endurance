# Local Edge Function Tests

This directory contains unit tests and end-to-end tests for Mealvana Endurance's Supabase edge functions.

---

## Directory Structure

```
test/local_edge_functions/
├── README.md                           # This file
├── e2e-multi-sport-test.ts            # End-to-end test for all sports
├── functions/
│   ├── generate-macros/
│   │   ├── cycling-macros.test.ts     # 41 cycling macro tests
│   │   └── swimming-macros.test.ts    # 42 swimming macro tests
│   └── generate-nutrition-plan/
│       ├── README.md                  # Nutrition plan test documentation
│       ├── business-logic.test.ts     # Food preference & safety tests
│       └── lp-model-debug.test.ts     # Linear programming debugging tests
```

---

## Running Tests

### Unit Tests (Vitest)

**All tests:**
```bash
npm test
```

**Specific test file:**
```bash
npm test -- cycling-macros
npm test -- swimming-macros
npm test -- business-logic
```

**Watch mode:**
```bash
npm test -- --watch
```

### End-to-End Tests

**Multi-sport E2E test (against dev environment):**
```bash
npx tsx test/local_edge_functions/e2e-multi-sport-test.ts
```

**Requirements:**
- Supabase dev environment running (vlmtsdzpnjnavdgytcmi.supabase.co)
- Valid anon key in `.env` file
- Edge functions deployed to dev

---

## Test Categories

### 1. Macro Generation Tests

**File:** `functions/generate-macros/cycling-macros.test.ts` (41 tests)

Tests cycling macro calculations including:
- MET calculation from speed
- Terrain adjustments (flat, rolling, hilly)
- Elevation gain impact
- Indoor vs outdoor air resistance
- Carb recommendations (30-90 g/h based on duration)
- Hydration calculations (0.5-0.75 L/h)
- Pre-ride, during-ride, post-ride nutrition

**File:** `functions/generate-macros/swimming-macros.test.ts` (42 tests)

Tests swimming macro calculations including:
- MET calculation from pace per 100m
- Pool vs open water energy expenditure
- Water temperature effects
- Wetsuit impact on energy cost
- Carb recommendations (30-60 g/h, harder to consume)
- Hydration calculations (0.4-0.8 L/h)
- Pre-swim, during-swim, post-swim nutrition

**Status:** ✅ All 83 tests passing

### 2. Nutrition Plan Tests

**File:** `functions/generate-nutrition-plan/business-logic.test.ts`

Tests food preference and safety logic:
- Food preference handling (liked, willing, disliked, essential)
- Essential food override logic (safety-first approach)
- Food exclusion and scoring algorithms
- Nutritional feasibility validation

**File:** `functions/generate-nutrition-plan/lp-model-debug.test.ts`

Tests linear programming model:
- LP solver constraint validation
- Model structure testing
- Debugging utilities for LP optimization failures

**Status:** ✅ All tests passing

### 3. End-to-End Tests

**File:** `e2e-multi-sport-test.ts`

Tests against deployed dev environment:
- ✅ Running macro generation (backward compatibility)
- ✅ Cycling macro generation (new feature)
- ✅ Swimming macro generation (new feature)
- ✅ Backward compatibility (no activity_type defaults to running)

**Status:** ✅ All 4 scenarios passing

---

## Test Philosophy

**TDD Approach:**
1. Write failing tests first
2. Implement minimum code to pass
3. Refactor for quality
4. Repeat

**Coverage Focus:**
- **Business logic:** 100% coverage of critical paths
- **Edge cases:** Extreme inputs, missing data, invalid parameters
- **Integration:** Real API calls to dev environment
- **Performance:** Response times under 3 seconds

**Risk-Based Testing:**
- Test the 5% of functionality that causes 95% of user pain
- Prioritize safety (nutrition recommendations)
- Validate accuracy (±10g tolerance for macro targets)

---

## Adding New Tests

### Unit Test Template

```typescript
import { describe, it, expect } from 'vitest';

describe('Feature Name', () => {
  it('should handle basic case', () => {
    const result = yourFunction(input);
    expect(result).toBe(expected);
  });

  it('should handle edge case', () => {
    const result = yourFunction(edgeInput);
    expect(result).toBe(expected);
  });
});
```

### E2E Test Template

```typescript
async function testNewSport(): Promise<TestResult> {
  console.log('\n🏋️ Testing NEW SPORT...');

  const response = await fetch(`${SUPABASE_URL}/functions/v1/generate-macros`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    },
    body: JSON.stringify({
      activity_type: 'new_sport',
      // ... parameters
    }),
  });

  const data = await response.json();

  if (response.ok && data.success) {
    console.log('✅ New sport: SUCCESS');
    return { sport: 'new_sport', macrosSuccess: true, macrosData: data };
  } else {
    console.log('❌ New sport: FAILED');
    return { sport: 'new_sport', macrosSuccess: false, macrosError: JSON.stringify(data) };
  }
}
```

---

## Debugging Tips

### 1. Check Edge Function Logs

```bash
supabase functions logs generate-macros
supabase functions logs generate-nutrition-plan
```

### 2. Test with curl

```bash
curl -X POST \
  https://vlmtsdzpnjnavdgytcmi.supabase.co/functions/v1/generate-macros \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer [ANON_KEY]' \
  -d '{"activity_type":"cycling","weight":70,...}' \
  | jq '.'
```

### 3. Run Specific Test

```bash
npm test -- cycling-macros -t "should calculate MET for moderate cycling"
```

### 4. Enable Verbose Logging

```bash
npm test -- --reporter=verbose
```

---

## CI/CD Integration

Tests run automatically on:
- Every push to `develop` branch
- Every pull request to `main` branch
- Before deployment to dev/production

**GitHub Actions Workflow:**
- `.github/workflows/test-edge-functions.yml`

**Test Requirements for Deployment:**
- All unit tests must pass
- E2E tests must pass against dev environment
- No high-severity linting errors

---

## Known Issues

1. **Deno decorator warning:**
   - Warning: "Specifying decorator through flags is no longer supported"
   - Impact: None (tests still work)
   - Resolution: Use deno.json configuration (future enhancement)

2. **E2E test nutrition plans:**
   - Currently not tested in E2E (requires food preferences in database)
   - Will be addressed in Phase 9 integration tests

---

## Resources

- [Vitest Documentation](https://vitest.dev/)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [Testing Strategy](/docs/test/README.md)
- [Phase 3 Deployment Summary](/docs/features/cycling_swimming/phase3-deployment-summary.md)

---

**Last Updated:** 2025-10-15
**Maintained By:** Mealvana Development Team
