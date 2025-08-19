# Supabase Integration Setup Guide

## 🚀 Quick Setup

### Step 1: Execute SQL in Supabase Dashboard

1. **Open Supabase Dashboard**
   - Go to [https://supabase.com/dashboard](https://supabase.com/dashboard)
   - Navigate to your project: `wvmvsodrvbkxfydabqed.supabase.co`

2. **Open SQL Editor**
   - Click "SQL Editor" in the left sidebar
   - Click "New Query"

3. **Run the Setup Script**
   - Copy the entire contents of `/docs/technical/supabase-setup.sql`
   - Paste into the SQL editor
   - Click "Run" (or press Ctrl/Cmd + Enter)

This will:
- ✅ Create the `app_content` table with proper schema
- ✅ Set up Row Level Security (public read access)
- ✅ Insert your current content as version 1 for both production and development
- ✅ Create helper functions for content management

### Step 2: Verify Setup

```sql
-- Check if table was created and populated
SELECT version, environment, is_active, created_at 
FROM app_content 
ORDER BY environment, version DESC;

-- View current algorithm parameters
SELECT content->'algorithm'->'during_run'->'carbs'->'gut_training_multipliers' as gut_training
FROM current_content;
```

You should see:
- 2 rows (production and development environments)
- Algorithm parameters showing: `{"low": 0.7, "moderate": 0.8, "high": 1.0}`

### Step 3: Test App Integration

1. **Restart Your App**
   ```bash
   flutter run
   ```

2. **Check Debug Output**
   The app will now:
   - Load content immediately from cache/defaults
   - Check Supabase for updates in background
   - Show "Content updated to version X" if newer version found

## 🔧 How the Integration Works

### Content Flow Priority
1. **Supabase** (latest version check)
2. **Hive Cache** (local database)  
3. **Bundled Defaults** (`assets/config/content_defaults.json`)

### App Startup Flow
```
App Start → ContentService.initialize() → 
  1. Load cached/default content immediately
  2. Check Supabase for updates in background
  3. Update cache if newer version found
  4. New content takes effect immediately
```

### Background Updates
- ✅ Non-blocking: App starts immediately with cached content
- ✅ Automatic: Checks on every app startup
- ✅ Graceful fallback: Continues with cached content if Supabase unavailable
- ✅ Version-based: Only updates when version number increases

## 📝 Managing Content

### Create New Content Version

```sql
-- Update algorithm parameters
SELECT create_content_version('production', 'en', '{
  "main_screen": {
    "title": "Mealvana Endurance",
    "distance_label": "Distance"
  },
  "algorithm": {
    "during_run": {
      "carbs": {
        "gut_training_multipliers": {
          "low": 0.75,
          "moderate": 0.85, 
          "high": 1.1
        },
        "absorption_limit_max_g_per_h": 65
      }
    }
  }
}'::jsonb);
```

### Update Specific Parameters

```sql
-- Just update gut training multipliers
SELECT create_content_version('production', 'en', 
  jsonb_set(
    (SELECT content FROM get_latest_content('production', 'en')),
    '{algorithm,during_run,carbs,gut_training_multipliers,high}',
    '1.2'
  )
);
```

### View Current Content

```sql
-- See all content versions
SELECT version, environment, created_at, 
       content->'main_screen'->>'title' as app_title
FROM app_content 
ORDER BY environment, version DESC;

-- Get specific algorithm values
SELECT content->'algorithm'->'during_run'->'carbs'->>'absorption_limit_max_g_per_h' as max_carbs
FROM current_content 
WHERE environment = 'production';
```

## ✅ Testing Your Changes

1. **Make a change** in Supabase (update algorithm parameter)
2. **Restart the app** to trigger background content check
3. **Generate a nutrition plan** with same inputs
4. **Compare results** - they should reflect your parameter changes

### Example Test:
```
Before: gut_training_multipliers.high = 1.0
→ 70kg athlete gets: 70g/h (clamped to 60g/h max)

After: gut_training_multipliers.high = 1.1  
→ 70kg athlete gets: 77g/h (clamped to 60g/h max)
→ Algorithm uses the higher value up to the limit
```

## 🔍 Monitoring

### Check Content Updates
- App logs will show "Content updated to version X" when updates occur
- No logs = using cached content (normal behavior)

### Debug Content Issues
```dart
// In ContentService - check current version
final content = await contentService.getActiveContent();
print('Current content version: ${content?.version}');

// Force refresh for testing
await contentService.refreshFromBackend();
```

## 🎯 What This Enables

### For Your Team
- **Instant Updates**: Change algorithm parameters without app releases
- **A/B Testing**: Test different parameter values with different environments
- **Quick Fixes**: Fix UI text or calculation errors immediately
- **Localization Ready**: Support multiple languages (en, es, etc.)

### For Development
- **Environment Support**: Different content for dev/staging/production
- **Version Control**: Track all content changes with timestamps
- **Offline First**: App works perfectly without internet connection
- **Graceful Degradation**: Fallback to cached/bundled content if needed

Your Supabase-integrated fat backend is now fully operational! 🎉