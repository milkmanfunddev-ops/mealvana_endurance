# Mealvana Endurance Edge Functions Guide

## Overview

Mealvana Endurance uses Supabase Edge Functions to implement a **fat backend architecture** where complex business logic runs server-side. This approach provides algorithm flexibility, data consistency, and security while maintaining offline-first client functionality.

## 🚨 CRITICAL: Enum Format Requirements

**All Edge Functions expect enum values in underscore format, not camelCase.**

### The Issue We Solved

During development, we encountered a CHECK constraint failure:
```
CHECK constraint failed: preference IN ('like', 'dislike', 'willing_to_try')
```

**Root Cause**: The Dart enum `FoodPreference.willingToTry.name` returns `"willingToTry"` (camelCase), but the database and Edge Functions expect `"willing_to_try"` (underscore format).

**Solution**: Always use `FoodPreference.value` getter for Edge Function calls:

```dart
// ✅ CORRECT - Use .value for Edge Function calls
enum FoodPreference {
  like,
  dislike,
  willingToTry;

  String get value => name == 'willingToTry' ? 'willing_to_try' : name;
}

// When calling Edge Functions:
final preferences = foodPreferences.map(
  (key, value) => MapEntry(key, value.value), // Uses underscore format
);

// ❌ WRONG - Don't use .name for Edge Functions
final preferences = foodPreferences.map(
  (key, value) => MapEntry(key, value.name), // Uses camelCase - will fail!
);
```

**Database Consistency**: Both local Drift database and Supabase backend use underscore format to maintain consistency across all data sources.

## Edge Functions Architecture

### Fat Backend Benefits

1. **Algorithm Flexibility**: Update nutrition calculations without app releases
2. **Data Consistency**: Server-side validation ensures data integrity
3. **Performance**: Optimized calculations in Edge runtime
4. **Security**: Sensitive business logic protected server-side
5. **A/B Testing**: Algorithm parameters can be modified dynamically

### Request/Response Patterns

All Edge Functions follow consistent patterns:

```typescript
// CORS Headers (required for web clients)
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

// Response Format
interface EdgeFunctionResponse {
  success: boolean;
  message?: string;
  data?: any;
  error?: string;
}
```

### Authentication

Edge Functions use Supabase service role keys for database access:
- **Service Role Key**: Full database access for server-side operations
- **Client Authentication**: Device-based authentication without traditional user accounts

## Active Edge Functions

### 1. create-user
**Purpose**: User registration with device-based authentication
**Location**: `/supabase/functions/create-user/index.ts`

**Request Format**:
```typescript
interface CreateUserRequest {
  device_id: string;
  gender: 'male' | 'female' | 'other';
  birthday: string; // ISO date string
  height_feet: number;
  height_inches: number;
  weight_pounds: number;
  runs_with_water_bottle: boolean;
  gut_training_level: 'low' | 'moderate' | 'high';
  food_preferences?: Record<string, 'like' | 'dislike' | 'willing_to_try'>;
  app_version: string;
}
```

**Key Features**:
- Device-based authentication (no passwords)
- Atomic user creation with optional food preferences
- Conflict handling for existing users
- Input validation and sanitization

### 2. save-food-preferences
**Purpose**: Food preference persistence with validation
**Location**: `/supabase/functions/save-food-preferences/index.ts`

**Request Format**:
```typescript
interface SaveFoodPreferencesRequest {
  device_id: string;
  food_preferences: Record<string, 'like' | 'dislike' | 'willing_to_try'>;
}
```

**Key Features**:
- User validation before saving preferences
- Enum value validation (underscore format)
- Bulk upsert operations for performance
- Onboarding completion tracking

**🚨 CRITICAL**: This function expects `willing_to_try`, not `willingToTry`!

### 3. run-plan
**Purpose**: Deterministic nutrition plan generation (algorithmic fallback)
**Location**: `/supabase/functions/run-plan/index.ts`

**Key Features**:
- Fast, deterministic nutrition calculations
- ACSM-based energy expenditure formulas
- Phase-based food scoring (before/during/after run)
- User preference integration
- Fallback for AI system when needed

**Algorithm Scoring**:
```typescript
const SCORING_CONFIG = {
  preference: {
    like: 20,
    willing_to_try: 5,
    dislike: 0
  },
  pre: {
    carb_density_multiplier: 120,
    high_fat_penalty: 20,
    prep_penalty: 5
  },
  during: {
    carb_value: 2.0,
    sodium_value: 0.05,
    aid_station_bonus: 12
  }
};
```

### 4. generate-ai-nutrition-plan
**Purpose**: AI-powered nutrition optimization with linear programming
**Location**: `/supabase/functions/generate-ai-nutrition-plan/alg_improved_fixed.ts`

**Key Features**:
- Linear programming optimization using `javascript-lp-solver`
- Multi-objective optimization (carbs, protein, fluids, sodium)
- Phase-specific optimization weights
- Post-processing for electrolyte and hydration balance
- Food exclusion handling via database flags

**Optimization Approach**:
```typescript
const OPTIMIZATION_WEIGHTS = {
  before: {
    carbs: 1.0,      // Primary focus
    protein: 0.6,    // Important secondary
    fluids: 0.2,     // Reduced to prevent over-target
    sodium: 0.2      // Reduced to prevent massive overshoot
  },
  during: {
    carbs: 1.0,      // Performance focus
    fluids: 0.7,     // High hydration priority
    sodium: 0.8      // Cramping prevention
  },
  after: {
    carbs: 0.9,      // Recovery focus
    protein: 0.7,    // Muscle recovery
    fluids: 0.2,     // Controlled hydration
    sodium: 0.3      // Controlled electrolyte replacement
  }
};
```

### 5. get-foods
**Purpose**: Food data retrieval with category filtering
**Location**: `/supabase/functions/get-foods/index.ts`

**Key Features**:
- Category-based food filtering (before_run, during_run, after_run)
- Join queries across foods, categories, and food_categories tables
- Both generic and branded food support
- Optimized for mobile client caching

### 6. barcode-lookup
**Purpose**: Product identification via multiple API providers
**Location**: `/supabase/functions/barcode-lookup/index.ts`

**Key Features**:
- Sequential API fallback strategy
- Primary: Open Food Facts API (free, comprehensive)
- Fallback: USDA FoodData Central API (limited but reliable)
- 24-hour caching for performance
- Structured nutrition data normalization

**API Fallback Chain**:
1. **Open Food Facts**: Community-driven, international products
2. **USDA FoodData Central**: Official US nutrition database
3. **Graceful Failure**: Structured error for manual entry

### 7. carb-loading
**Purpose**: Carbohydrate loading plan generation
**Location**: `/supabase/functions/carb-loading/index.ts`

**Key Features**:
- Multi-day carb loading schedule
- Personalized based on user weight and race distance
- Integration with existing food preferences
- Progressive carb increase over 3-6 days

## Development Patterns

### Error Handling
```typescript
try {
  // Edge Function logic
  const result = await performOperation();

  return new Response(JSON.stringify({
    success: true,
    data: result
  }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  });
} catch (error) {
  console.error('Edge Function error:', error);

  return new Response(JSON.stringify({
    success: false,
    message: 'Internal server error',
    error: error.message
  }), {
    status: 500,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  });
}
```

### Database Operations
```typescript
// Always use service role for Edge Functions
const supabaseClient = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

// Use RPC for complex operations
const { data, error } = await supabaseClient.rpc('upsert_food_preferences', {
  p_device_id: deviceId,
  p_preferences: preferences
});
```

### Input Validation
```typescript
// Validate required fields
if (!device_id || !food_preferences || typeof food_preferences !== 'object') {
  return new Response(JSON.stringify({
    success: false,
    message: 'Missing required fields'
  }), {
    status: 400,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  });
}

// Validate enum values
const validPreferences = ['like', 'dislike', 'willing_to_try'];
for (const [foodName, preference] of Object.entries(food_preferences)) {
  if (!validPreferences.includes(preference)) {
    return new Response(JSON.stringify({
      success: false,
      message: `Invalid preference value: ${preference}`
    }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
}
```

## Client Integration

### AuthRepositoryEdge Pattern
```dart
class AuthRepositoryEdge {
  AuthRepositoryEdge(this._supabase);
  final SupabaseClient _supabase;

  Future<SaveFoodPreferencesResult> saveFoodPreferences(
    String deviceId,
    Map<String, FoodPreference> preferences
  ) async {
    try {
      final requestBody = {
        'device_id': deviceId,
        'food_preferences': preferences.map(
          (key, value) => MapEntry(key, value.value), // ⚠️ Use .value!
        ),
      };

      final response = await _supabase.functions.invoke(
        'save-food-preferences',
        body: requestBody,
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>;
        return SaveFoodPreferencesResult(
          success: data['success'] == true,
          message: data['message'],
        );
      }

      return SaveFoodPreferencesResult(
        success: false,
        message: 'Edge Function call failed with status ${response.status}',
      );
    } catch (e) {
      return SaveFoodPreferencesResult(
        success: false,
        message: 'Failed to save food preferences: $e',
      );
    }
  }
}
```

### Service Layer Integration
```dart
class AuthService {
  Future<void> saveFoodPreferences(
    String userId,
    Map<String, FoodPreference> preferences
  ) async {
    // 1. Save to server via Edge Function (primary)
    final result = await _authRepositoryEdge.saveFoodPreferences(userId, preferences);

    if (!result.success) {
      throw Exception(result.message ?? 'Failed to save food preferences to server');
    }

    // 2. Cache locally for offline access (secondary)
    final userRepo = await _userRepository;
    await userRepo.saveFoodPreferences(userId, preferences);
  }
}
```

## Testing Edge Functions

### Local Development
```bash
# Start Supabase local development
supabase start

# Serve functions locally
supabase functions serve --debug

# Test with curl
curl -X POST 'http://localhost:54321/functions/v1/save-food-preferences' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "device_id": "test-device-123",
    "food_preferences": {
      "Bananas": "like",
      "Oatmeal": "willing_to_try",
      "Energy bars": "dislike"
    }
  }'
```

### Production Deployment
```bash
# Deploy single function
supabase functions deploy save-food-preferences

# Deploy all functions
supabase functions deploy

# Check function logs
supabase functions logs save-food-preferences
```

## Performance Considerations

### Optimization Strategies
1. **Caching**: 24-hour cache for barcode lookups and food data
2. **Batch Operations**: Use database RPC functions for bulk operations
3. **Connection Pooling**: Reuse Supabase client instances
4. **Input Validation**: Fail fast with proper error messages
5. **Response Compression**: Minimal response payloads

### Monitoring
- Edge Function execution time
- Database query performance
- Error rates and patterns
- Client retry behavior

## Security Best Practices

### Data Protection
1. **Service Role Key**: Never expose in client code
2. **Input Sanitization**: Validate all inputs before processing
3. **Rate Limiting**: Implement via Supabase dashboard
4. **CORS Configuration**: Restrict origins in production
5. **Error Messages**: Don't leak sensitive information

### Authentication
- Device-based authentication without passwords
- JWT validation for authenticated endpoints
- Service role for server-side operations only

---

This Edge Functions architecture provides a robust, scalable foundation for Mealvana Endurance's nutrition planning functionality while maintaining data consistency and security.