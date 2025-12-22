# Upsert User Profile Edge Function

## Overview

The `upsert-user-profile` Edge Function consolidates the functionality of three separate Edge Functions:
- `create-user` - Creates new user profiles
- `save-food-preferences` - Saves user food preferences
- `update-user-preferences` - Updates user dietary and sport preferences

This unified function accepts ANY combination of user profile fields and handles both INSERT (new user) and UPDATE (existing user) operations using PostgreSQL's UPSERT pattern.

## Endpoint

```
POST /functions/v1/upsert-user-profile
```

## Request Payload

All fields are optional except `user_id`:

```typescript
{
  // REQUIRED
  "user_id": "uuid-string",

  // Basic Profile Fields
  "gender": "male" | "female" | "other",
  "birthday": "YYYY-MM-DD",
  "height_feet": 5,
  "height_inches": 10,
  "weight_pounds": 150.5,
  "runs_with_water_bottle": true,
  "gut_training_level": "low" | "moderate" | "high",

  // Food Preferences (handled in food_preferences table)
  "food_preferences": {
    "banana": "like",
    "oatmeal": "dislike",
    "energy_gel": "willing_to_try"
  },
  "preference_levels": {
    "banana": 5,
    "oatmeal": 1,
    "energy_gel": 3
  },

  // Dietary Preference (v2 schema - not in production yet)
  "dietary_preference": "omnivore" | "vegetarian" | "pescatarian" | "vegan" | "mediterranean" | "paleo" | "keto" | "low_carb" | null,

  // Allergies (v2 schema - not in production yet)
  "allergies": ["dairy", "gluten", "peanuts"],

  // Sport-Specific Fields
  "gi_sensitivity": true,
  "cycling_ftp_watts": 250,
  "typical_bike_bottles": 2,
  "has_aero_bottle": true,
  "has_bento_box": false,
  "swimming_css_seconds_per_100m": 90,
  "typical_wetsuit": true,
  "typical_swim_cap_type": "none" | "latex" | "silicone" | "neoprene",

  // Onboarding Flag
  "onboarding_completed": true,

  // App Version (for analytics)
  "app_version": "1.2.3"
}
```

## Response Format

### Success Response (200)

```json
{
  "success": true,
  "message": "User profile updated successfully",
  "user": {
    "id": "uuid-string",
    "gender": "male",
    "birthday": "1990-01-01",
    "height_feet": 5,
    "height_inches": 10,
    "weight_pounds": 150.5,
    // ... all other user fields
  },
  "preferences_count": 15,
  "saved_preferences": [
    {
      "food_name": "banana",
      "preference": "like",
      "preference_level": 5
    },
    // ... other preferences
  ]
}
```

### Error Response (400/404/500)

```json
{
  "success": false,
  "message": "Error description",
  "error_details": { /* Optional error details */ }
}
```

## Validation Rules

### Required Fields
- `user_id` (string, UUID format)

### Enum Validations
- `gender`: Must be "male", "female", or "other"
- `gut_training_level`: Must be "low", "moderate", or "high"
- `dietary_preference`: Must be "omnivore", "vegetarian", "pescatarian", "vegan", "mediterranean", "paleo", "keto", "low_carb", or null
- `allergies`: Array of "dairy", "eggs", "fish", "gluten", "peanuts", "sesame", "shellfish", "soy", "tree_nuts"
- `typical_swim_cap_type`: Must be "none", "latex", "silicone", or "neoprene"
- `food_preferences` values: Must be "like", "dislike", or "willing_to_try"

### Range Validations
- `typical_bike_bottles`: Must be between 0 and 6

## Usage Examples

### 1. Create New User (Minimal Profile)

```typescript
const response = await supabase.functions.invoke('upsert-user-profile', {
  body: {
    user_id: 'new-user-uuid',
    gender: 'male',
    birthday: '1990-01-01',
    height_feet: 5,
    height_inches: 10,
    weight_pounds: 150,
    gut_training_level: 'moderate',
    app_version: '1.2.3'
  }
});
```

### 2. Update Existing User (Partial Update)

```typescript
// Only update weight and gut training level
const response = await supabase.functions.invoke('upsert-user-profile', {
  body: {
    user_id: 'existing-user-uuid',
    weight_pounds: 155,
    gut_training_level: 'high'
  }
});
```

### 3. Save Food Preferences

```typescript
const response = await supabase.functions.invoke('upsert-user-profile', {
  body: {
    user_id: 'user-uuid',
    food_preferences: {
      'banana': 'like',
      'energy_gel': 'willing_to_try',
      'sports_drink': 'like'
    },
    preference_levels: {
      'banana': 5,
      'energy_gel': 3,
      'sports_drink': 4
    },
    onboarding_completed: true
  }
});
```

### 4. Update Sport-Specific Preferences

```typescript
const response = await supabase.functions.invoke('upsert-user-profile', {
  body: {
    user_id: 'user-uuid',
    cycling_ftp_watts: 250,
    typical_bike_bottles: 2,
    has_aero_bottle: true,
    has_bento_box: false
  }
});
```

### 5. Complete Onboarding (All Fields)

```typescript
const response = await supabase.functions.invoke('upsert-user-profile', {
  body: {
    user_id: 'user-uuid',
    gender: 'female',
    birthday: '1985-05-15',
    height_feet: 5,
    height_inches: 6,
    weight_pounds: 135,
    runs_with_water_bottle: true,
    gut_training_level: 'high',
    food_preferences: {
      'banana': 'like',
      'energy_gel': 'like',
      // ... more preferences
    },
    dietary_preference: 'vegetarian',
    allergies: ['dairy', 'eggs'],
    gi_sensitivity: false,
    onboarding_completed: true,
    app_version: '1.2.3'
  }
});
```

## Database Operations

### Users Table
- Uses PostgreSQL UPSERT (`INSERT ... ON CONFLICT ... DO UPDATE`)
- Updates only provided fields (partial updates supported)
- Automatically sets `updated_at` timestamp

### Food Preferences Table
- Uses PostgreSQL UPSERT on `(user_id, food_name)` unique constraint
- Supports batch upsert of multiple preferences
- Preserves existing preferences not included in request

## Migration Notes

### V2 Schema Fields (Not Yet in Production)
The following fields are part of the v2 schema but are not yet available in production:
- `dietary_preference`
- `allergies`

These fields are included in the Edge Function for forward compatibility. They will be silently ignored in production until the schema migration is deployed.

## Error Handling

The function includes comprehensive error handling:

1. **Validation Errors (400)**: Invalid field values or missing required fields
2. **Database Errors (500)**: Supabase query failures
3. **Internal Errors (500)**: Unexpected runtime errors

All errors return descriptive messages and optional error details for debugging.

## Logging

The function logs key operations:
- `[upsert-user-profile] Processing request for user_id: {id}`
- `[upsert-user-profile] Upserting user profile`
- `[upsert-user-profile] Processing {count} food preferences`
- `[upsert-user-profile] Successfully completed for user: {id}`

## Performance Considerations

- **Single Database Transaction**: User profile and food preferences are saved in separate operations (not atomic)
- **Batch Operations**: Food preferences are upserted in a single batch operation
- **Partial Success**: User profile will be saved even if food preferences fail

## Testing

To test this function locally:

```bash
# Start Supabase locally
supabase start

# Serve the function
supabase functions serve upsert-user-profile

# Test with curl
curl -i --location --request POST 'http://localhost:54321/functions/v1/upsert-user-profile' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "user_id": "test-user-id",
    "gender": "male",
    "weight_pounds": 150
  }'
```

## Deployment

```bash
# Deploy to production
supabase functions deploy upsert-user-profile

# Deploy to staging
supabase functions deploy upsert-user-profile --project-ref staging-ref
```

## Future Improvements

1. **Atomic Transactions**: Wrap user profile and food preferences in a single transaction
2. **Validation Schema**: Use Zod or similar library for type-safe validation
3. **Rate Limiting**: Add rate limiting to prevent abuse
4. **Caching**: Cache validation rules to improve performance
5. **Batch User Updates**: Support updating multiple users in a single request
