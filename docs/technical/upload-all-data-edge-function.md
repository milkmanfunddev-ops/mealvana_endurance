# Upload All Data Edge Function

## Overview
The `upload-all-data` Edge Function provides a best-effort upload mechanism for syncing dirty records from the client to Supabase. It complements the `sync-all-data` function (download) to enable bidirectional synchronization.

## Design Principles

### Best-Effort Partial Success
- Each table uploads independently
- One table's failure doesn't block other tables
- Returns detailed status per table
- Allows client to retry only failed tables

### Security
- Uses `SUPABASE_SERVICE_ROLE_KEY` to bypass RLS
- Validates `user_id` in request body
- All records must be pre-validated by client

## API Specification

### Endpoint
```
POST /upload-all-data
```

### Request Format
```typescript
{
  user_id: string,  // Required: UUID of the authenticated user
  dirty_records?: {
    activities?: Array<ActivityRecord>,
    events?: Array<EventRecord>,
    carb_loading_plans?: Array<CarbLoadingPlanRecord>,
    carb_loading_days?: Array<CarbLoadingDayRecord>,
    carb_loading_day_meals?: Array<CarbLoadingDayMealRecord>,
    user_foods?: Array<UserFoodRecord>,
    feedback?: Array<FeedbackRecord>,
    feature_survey_responses?: Array<FeatureSurveyRecord>,
    food_preferences?: Array<FoodPreferenceRecord>
  }
}
```

### Response Format
```typescript
{
  success: boolean,      // true if at least one table succeeded
  timestamp: string,      // ISO 8601 timestamp
  results: {
    activities?: { success: boolean, uploaded: number, error?: string },
    events?: { success: boolean, uploaded: number, error?: string },
    carb_loading_plans?: { success: boolean, uploaded: number, error?: string },
    carb_loading_days?: { success: boolean, uploaded: number, error?: string },
    carb_loading_day_meals?: { success: boolean, uploaded: number, error?: string },
    user_foods?: { success: boolean, uploaded: number, error?: string },
    feedback?: { success: boolean, uploaded: number, error?: string },
    feature_survey_responses?: { success: boolean, uploaded: number, error?: string },
    food_preferences?: { success: boolean, uploaded: number, error?: string }
  }
}
```

### HTTP Status Codes
- `200 OK`: At least one table uploaded successfully (check `results` for details)
- `400 Bad Request`: Missing or invalid `user_id`
- `500 Internal Server Error`: All tables failed or unexpected error

## Supported Tables

The function supports uploading to 9 tables:

1. **activities** - User's scheduled workouts and runs
2. **events** - User's race calendar events
3. **carb_loading_plans** - Multi-day carb loading plans
4. **carb_loading_days** - Individual days within carb loading plans
5. **carb_loading_day_meals** - Meals within carb loading days
6. **user_foods** - User-created custom foods
7. **feedback** - User feedback submissions
8. **feature_survey_responses** - Feature survey responses
9. **food_preferences** - User's food likes/dislikes

## Implementation Details

### Conflict Resolution
All upserts use `{ onConflict: 'id' }` strategy:
- If record exists, it's updated
- If record doesn't exist, it's inserted
- Uses the `id` column as the unique constraint

### Error Handling
Each table upload is wrapped in try-catch:
```typescript
try {
  const { error } = await supabaseClient
    .from('table_name')
    .upsert(records, { onConflict: 'id' });

  if (error) throw error;

  results.table_name = { success: true, uploaded: records.length };
} catch (error) {
  results.table_name = { success: false, uploaded: 0, error: error.message };
}
```

### Logging
The function logs:
- Start of upload with user_id
- Upload progress for each table
- Success/failure status for each table
- Total records uploaded
- Failed tables (if any)

## Client Integration

### Example Usage
```dart
// In DataSyncService
Future<void> uploadDirtyRecords() async {
  final dirtyRecords = await _database.getDirtyRecords();

  final response = await supabase.functions.invoke(
    'upload-all-data',
    body: {
      'user_id': userId,
      'dirty_records': {
        'activities': dirtyRecords.activities,
        'events': dirtyRecords.events,
        // ... other tables
      },
    },
  );

  if (response.status == 200) {
    final results = response.data['results'];

    // Mark successfully uploaded records as clean
    if (results['activities']?['success'] == true) {
      await _database.markActivitiesClean();
    }

    // Retry failed tables later
    if (results['events']?['success'] == false) {
      // Schedule retry or show error to user
    }
  }
}
```

### Retry Strategy
For failed tables:
1. Check `results[table_name].success == false`
2. Log error: `results[table_name].error`
3. Schedule retry with exponential backoff
4. Consider showing user notification after multiple failures

## Deployment

### Deploy Function
```bash
supabase functions deploy upload-all-data
```

### Environment Variables
The function uses:
- `SUPABASE_URL` - Automatically set by Supabase
- `SUPABASE_SERVICE_ROLE_KEY` - Automatically set by Supabase

### Testing
```bash
# Test with curl
curl -X POST 'https://vlmtsdzpnjnavdgytcmi.supabase.co/functions/v1/upload-all-data' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "user_id": "YOUR_USER_ID",
    "dirty_records": {
      "activities": [
        {
          "id": "test-id",
          "user_id": "YOUR_USER_ID",
          "scheduled_date_time": "2025-12-19T10:00:00Z",
          "distance_km": 10.0,
          "distance_miles": 6.21,
          "pace_km": 360,
          "pace_mi": 580,
          "source": "manual",
          "created_at": "2025-12-19T10:00:00Z",
          "updated_at": "2025-12-19T10:00:00Z"
        }
      ]
    }
  }'
```

## Monitoring

### Success Metrics
- Total records uploaded per sync
- Success rate per table
- Average upload time
- Error frequency by table

### Error Tracking
- Failed table names
- Error messages by table
- Retry attempts
- User impact (data loss risk)

## Future Enhancements

### Batch Size Limits
Consider adding:
- Maximum records per table (e.g., 1000)
- Total payload size limit (e.g., 5MB)
- Automatic batching for large uploads

### Conflict Resolution Strategies
Support different strategies:
- `last_write_wins` (current default)
- `server_wins` (skip client updates)
- `merge` (field-level merging)

### Transaction Support
Consider wrapping related tables in transactions:
- `carb_loading_plans` + `carb_loading_days` + `carb_loading_day_meals`
- All-or-nothing for referential integrity

## Related Documentation
- [Sync All Data Edge Function](/docs/technical/sync-all-data-edge-function.md)
- [Data Sync Service](/docs/technical/data-sync-service.md)
- [Database Architecture](/docs/database/README.md)
