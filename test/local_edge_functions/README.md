# Local Edge Function Testing

This directory contains a local Node.js environment for testing Mealvana edge functions without calling Supabase. This allows for faster, more reliable testing during development.

## Setup

### Prerequisites
- Node.js 18.0.0 or higher
- npm or yarn

### Installation

1. Navigate to the local testing directory:
```bash
cd test/local_edge_functions
```

2. Install dependencies:
```bash
npm install
```

## Available Functions

### 1. Generate AI Nutrition Plan
**File**: `functions/generate-ai-nutrition-plan.js`
**Test**: `test/generate-ai-nutrition-plan.test.js`

Local adaptation of the AI-powered nutrition planning edge function with:
- Linear programming optimization using `javascript-lp-solver`
- Mock food database for testing
- Same constraint logic as production function
- Proper serving size handling (0.5 increments)
- Food preference integration

### 2. Run Plan (Algorithmic)
**File**: `functions/run-plan.js` 
**Test**: `test/run-plan.test.js`

Local implementation of the algorithmic fallback nutrition planning:
- ACSM-based energy expenditure calculations
- Evidence-based nutrition guidelines
- Gut training level adjustments
- Duration-based fueling strategies

## Running Tests

### Run All Tests
```bash
npm test
```

### Run Specific Function Tests
```bash
# Test AI nutrition plan generation
npm run test:generate-ai

# Test algorithmic run plan generation  
npm run test:run-plan
```

### Watch Mode (for development)
```bash
npm run test:watch
```

### Manual Testing
```bash
# Run manual tests to see output
node test/generate-ai-nutrition-plan.test.js
node test/run-plan.test.js
```

## Test Data

The local tests use the same test data structure as the Flutter integration tests:

```javascript
const testNutritionPlanRequest = {
  device_id: 'test-device-local',
  age: 30,
  gender: 'female', 
  weight_kg: 60.0,
  height_cm: 165.0,
  gut_training_level: 'intermediate',
  distance_miles: 6.2, // 10K
  pace_minutes_per_mile: 8.5,
  time_before_run_hours: 2.0,
  macro_targets: { /* ... */ },
  liked_foods: ['oatmeal', 'banana'],
  willing_to_try_foods: ['sports_drink'],
  disliked_foods: []
};
```

## Key Differences from Production

### Mock Components
- **Food Database**: Uses simplified 5-food mock database instead of full Supabase database
- **Supabase Client**: Mock client that returns test data
- **Environment Variables**: Mock environment setup

### Simplified Logic
- **AI Integration**: Uses pure linear programming without LLM integration
- **Food Categories**: Simplified category matching
- **Error Handling**: Basic error handling for testing

### Testing Benefits
- **Fast Execution**: No network calls, runs in milliseconds
- **Deterministic**: Same inputs always produce same outputs
- **Offline**: Works without internet connection
- **Debuggable**: Easy to add console.log statements and debug locally

## Adding New Functions

To test additional edge functions locally:

1. Create function file in `functions/[function-name].js`
2. Export main function and HTTP handler
3. Create test file in `test/[function-name].test.js` 
4. Add npm script in `package.json`
5. Import any required dependencies

Example structure:
```javascript
// functions/my-function.js
export async function myFunction(requestData) {
  // Function logic here
  return { success: true, data: result };
}

export async function handleRequest(request) {
  // HTTP handler wrapper
}

// test/my-function.test.js
import { test, describe } from 'node:test';
import assert from 'node:assert';
import { myFunction } from '../functions/my-function.js';

describe('My Function Tests', () => {
  test('should work correctly', async () => {
    const result = await myFunction(testData);
    assert.strictEqual(result.success, true);
  });
});
```

## Integration with Flutter Tests

The local tests complement the Flutter integration tests:

1. **Flutter Tests**: Test actual Supabase integration, network handling, full data flow
2. **Local Tests**: Test business logic, edge cases, performance, rapid iteration

Use local tests during development for:
- Algorithm debugging
- Performance optimization  
- Edge case testing
- Rapid iteration

Use Flutter integration tests for:
- End-to-end validation
- Network error handling
- Production environment testing
- Final validation before deployment

## Development Workflow

1. **Write local test** for new feature or bug fix
2. **Implement logic** in local function 
3. **Verify locally** with fast test execution
4. **Port changes** to actual Supabase edge function
5. **Run Flutter integration tests** to validate end-to-end

This approach provides fast feedback loops while ensuring production compatibility.