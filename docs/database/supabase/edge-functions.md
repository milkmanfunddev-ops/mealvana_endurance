# Supabase Edge Functions

## Overview

Supabase Edge Functions provide serverless compute capabilities for Mealvana Endurance, enabling dynamic AI-powered nutrition plan generation and other backend operations. The `edge_functions` table supports dynamic code deployment and version management.

## Architecture

### Edge Functions Table

```sql
CREATE TABLE public.edge_functions (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name       text UNIQUE NOT NULL,
    code       text NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);
```

**Purpose**: Store and manage edge function code for dynamic deployment without redeployment.

## Active Functions

### 1. generate-ai-nutrition-plan

**Location**: `supabase/functions/generate-ai-nutrition-plan/index.ts`
**Purpose**: AI-powered nutrition plan generation using OpenAI GPT models

**Key Features**:
- Personalized plan generation based on user biometrics and preferences
- Food database integration with preference filtering
- Science-based calculations using ACSM formulas
- Structured JSON output for client consumption

**Request Format**:
```typescript
interface GeneratePlanRequest {
  user_profile: {
    weight_pounds: number;
    gut_training_level: 'low' | 'moderate' | 'high';
    runs_with_water_bottle: boolean;
    preferred_distance_unit: 'miles' | 'kilometers';
  };
  run_details: {
    distance_miles: number;
    pace_minutes_per_mile: number;
    planned_date?: string;
  };
  food_preferences?: {
    food_name: string;
    preference: 'like' | 'dislike' | 'willing_to_try';
  }[];
  algorithm_params?: AlgorithmParameters;
}
```

**Response Format**:
```typescript
interface NutritionPlan {
  plan_id: string;
  plan_name: string;
  distance_miles: number;
  pace_minutes_per_mile: number;
  total_calories: number;
  
  before_run: {
    timing_hours: number;
    foods: FoodRecommendation[];
    total_calories: number;
    total_carbs_g: number;
    hydration_ml: number;
  };
  
  during_run: {
    foods: FoodRecommendation[];
    schedule: TimingRecommendation[];
    total_calories: number;
    total_carbs_g: number;
    hydration_per_hour_ml: number;
  };
  
  notes: string[];
}
```

## Dynamic Code Deployment

### Code Management System

The `edge_functions` table enables hot-swapping of function code without redeployment:

```typescript
// Fetch current function code
const { data: functionData } = await supabase
  .from('edge_functions')
  .select('code')
  .eq('name', 'generate-ai-nutrition-plan')
  .single();

// Execute dynamic code
const dynamicFunction = new Function('params', functionData.code);
const result = await dynamicFunction(requestParams);
```

### Version Control

```typescript
// Update function code
await supabase
  .from('edge_functions')
  .upsert({
    name: 'generate-ai-nutrition-plan',
    code: newFunctionCode,
    updated_at: new Date().toISOString()
  });
```

## Algorithm Integration

### Content-Driven Parameters

Edge functions pull algorithm parameters from the `app_content` table:

```typescript
// Fetch algorithm parameters
const { data: contentData } = await supabase
  .from('app_content')
  .select('content')
  .eq('environment', 'production')
  .eq('locale', 'en')
  .eq('is_active', true)
  .order('version', { ascending: false })
  .limit(1)
  .single();

const algorithmParams = contentData.content.algorithm;
```

### Food Database Integration

Functions query the foods database with user preferences:

```sql
-- Get preferred foods for category
SELECT f.*, fp.preference
FROM foods f
JOIN food_categories fc ON f.id = fc.food_id
JOIN categories c ON fc.category_id = c.id
LEFT JOIN food_preferences fp ON f.name = fp.food_name 
                              AND fp.device_id = $1
WHERE c.name = $2
ORDER BY 
  CASE fp.preference 
    WHEN 'like' THEN 1
    WHEN 'willing_to_try' THEN 2
    WHEN NULL THEN 3
    WHEN 'dislike' THEN 4
  END,
  f.name;
```

## Security and Access Control

### Row Level Security

```sql
-- Public read access for function metadata
create policy "Anyone can read edge_functions" 
on public.edge_functions as permissive for select 
using (true);

-- Development access for code updates
create policy "Dev: anon can modify edge_functions" 
on public.edge_functions as permissive for all 
to anon using (true) with check (true);
```

### Environment Separation

- **Production**: Only authenticated users can modify function code
- **Development**: Anonymous users can update functions for testing
- **Function Execution**: Available to all clients via Supabase API

## Performance Considerations

### Caching Strategy

```typescript
// Cache frequently used data in function memory
let cachedFoods: Food[] | null = null;
let cacheTimestamp: number = 0;
const CACHE_DURATION = 30 * 60 * 1000; // 30 minutes

async function getFoods(): Promise<Food[]> {
  const now = Date.now();
  
  if (cachedFoods && (now - cacheTimestamp) < CACHE_DURATION) {
    return cachedFoods;
  }
  
  cachedFoods = await fetchFoodsFromDatabase();
  cacheTimestamp = now;
  
  return cachedFoods;
}
```

### Cold Start Optimization

- **Minimize Dependencies**: Keep edge function imports lightweight
- **Database Connection Pooling**: Reuse Supabase client instances
- **Precompute Constants**: Store algorithm constants in memory

## Development Workflow

### Local Development

```bash
# Start local Supabase
supabase start

# Serve functions locally
supabase functions serve --env-file .env.local

# Test function
curl -X POST http://localhost:54321/functions/v1/generate-ai-nutrition-plan \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d @test_request.json
```

### Deployment

```bash
# Deploy to staging
supabase functions deploy generate-ai-nutrition-plan --project-ref staging

# Deploy to production
supabase functions deploy generate-ai-nutrition-plan --project-ref production

# Update function code in database (for dynamic deployment)
psql -h db.project.supabase.co -U postgres -d postgres \
  -c "UPDATE edge_functions SET code = '...' WHERE name = 'generate-ai-nutrition-plan';"
```

### Testing Strategy

```typescript
// Unit tests for algorithm logic
describe('Nutrition Algorithm', () => {
  test('calculates energy expenditure correctly', () => {
    const result = calculateEnergyExpenditure({
      weight_pounds: 150,
      distance_miles: 10,
      pace_minutes_per_mile: 8
    });
    
    expect(result.calories_per_hour).toBeCloseTo(600, 0);
  });
});

// Integration tests for edge function
describe('Edge Function Integration', () => {
  test('generates valid nutrition plan', async () => {
    const response = await fetch('/functions/v1/generate-ai-nutrition-plan', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(testRequest)
    });
    
    const plan = await response.json();
    expect(plan.before_run.foods).toHaveLength(greaterThan(0));
  });
});
```

## Error Handling and Monitoring

### Error Response Format

```typescript
interface ErrorResponse {
  error: {
    message: string;
    code: string;
    details?: any;
  };
  timestamp: string;
  request_id: string;
}
```

### Logging Strategy

```typescript
// Structured logging for debugging
console.log(JSON.stringify({
  level: 'info',
  message: 'Plan generation started',
  user_id: request.user?.id,
  distance_miles: request.run_details.distance_miles,
  timestamp: new Date().toISOString()
}));
```

### Monitoring Queries

```sql
-- Function execution frequency
SELECT 
  DATE_TRUNC('hour', created_at) as hour,
  COUNT(*) as executions
FROM nutrition_plans 
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour;

-- Error rate monitoring
SELECT 
  COUNT(*) FILTER (WHERE notes LIKE '%error%') as errors,
  COUNT(*) as total,
  (COUNT(*) FILTER (WHERE notes LIKE '%error%') * 100.0 / COUNT(*)) as error_rate
FROM nutrition_plans 
WHERE created_at > NOW() - INTERVAL '1 hour';
```

## Future Enhancements

### Planned Functions

1. **calculate-macro-adjustments**: Dynamic macro target adjustments
2. **analyze-user-feedback**: AI-powered feedback analysis
3. **generate-meal-timing**: Optimal meal timing recommendations
4. **sync-wearable-data**: Integration with fitness wearables

### A/B Testing Support

```typescript
// Function versioning for A/B tests
const functionVersion = await getFunctionVersion(userId);
const algorithmParams = contentData.content.algorithm[functionVersion];
```

This edge functions system provides the backend intelligence for Mealvana Endurance's AI-powered nutrition planning while maintaining flexibility through dynamic code deployment and content-driven configuration.