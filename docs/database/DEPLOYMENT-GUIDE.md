# Food Preferences System Deployment Guide

## 🚀 **Step-by-Step Deployment**

### **Step 1: Create Food Preferences Table**

1. **Open Supabase Dashboard**
   - Go to your Supabase project
   - Navigate to **SQL Editor**

2. **Run the Migration**
   - Copy the contents of `/docs/database/migrations/create-food-preferences-table.sql`
   - Paste into SQL Editor and run

3. **Verify Table Creation**
   ```sql
   -- Check table exists
   SELECT * FROM food_preferences LIMIT 1;
   
   -- Check indexes were created
   SELECT indexname FROM pg_indexes WHERE tablename = 'food_preferences';
   
   -- Test the upsert function
   SELECT upsert_food_preferences(
     'test_device', 
     '{"Oatmeal": "like", "Gels": "willing_to_try"}'::jsonb
   );
   ```

### **Step 2: Deploy Edge Functions**

#### **Deploy save-food-preferences function:**
```bash
# In your project root
supabase functions deploy save-food-preferences
```

**Create the function file first:**
```bash
# Create function directory
mkdir -p supabase/functions/save-food-preferences

# Copy the function code from docs/business_logic/save-food-preferences-edge-function.ts
# to supabase/functions/save-food-preferences/index.ts
```

#### **Update create-nutrition-plan function:**
```bash
# Replace your existing function with the updated version from:
# docs/business_logic/updated-create-nutrition-plan-edge-function.ts

supabase functions deploy create-nutrition-plan
```

### **Step 3: Test the System**

#### **Test 1: Save Food Preferences**
```bash
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/save-food-preferences' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "device_id": "test_device_123",
    "food_preferences": {
      "Oatmeal": "like",
      "Banana sliced": "like",
      "Gels": "willing_to_try",
      "Orange juice": "dislike"
    }
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Food preferences saved successfully",
  "preferences_count": 4,
  "saved_preferences": [...]
}
```

#### **Test 2: Create Nutrition Plan with Preferences**
```bash
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/create-nutrition-plan' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "device_id": "test_device_123",
    "distance_miles": 10,
    "pace_minutes_per_mile": 8.5
  }'
```

**Expected:** Plan should prioritize liked foods, then willing-to-try foods.

### **Step 4: Update Flutter App**

#### **Update onboarding controller to use new endpoint:**

```dart
// In lib/features/onboarding/providers/onboarding_controller.dart

Future<bool> saveFoodPreferences(Map<String, FoodPreference> preferences) async {
  try {
    final response = await http.post(
      Uri.parse('${supabaseUrl}/functions/v1/save-food-preferences'),
      headers: {
        'Authorization': 'Bearer $supabaseAnonKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'device_id': deviceId,
        'food_preferences': preferences.map(
          (key, value) => MapEntry(key, value.name), // 'like', 'dislike', 'willing_to_try'
        ),
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['success'] == true;
    }
    return false;
  } catch (e) {
    debugPrint('Error saving food preferences: $e');
    return false;
  }
}
```

### **Step 5: Verify End-to-End Flow**

1. **Complete onboarding** - Food preferences should save to database
2. **Generate nutrition plan** - Should use preferred foods
3. **Check food display** - Should show proper quantities like "3 cups cooked oatmeal"

## 🔍 **Troubleshooting**

### **Common Issues:**

#### **Edge Function Deployment Fails**
```bash
# Check function logs
supabase functions logs save-food-preferences

# Verify environment variables
supabase secrets list
```

#### **Food Preferences Not Saving**
```sql
-- Check if table exists
\dt food_preferences

-- Check RLS policies
SELECT * FROM pg_policies WHERE tablename = 'food_preferences';

-- Check user exists
SELECT device_id FROM users WHERE device_id = 'your_test_device_id';
```

#### **Nutrition Plan Doesn't Use Preferences**
```sql
-- Verify preferences were saved
SELECT * FROM food_preferences WHERE device_id = 'your_device_id';

-- Check edge function logs
-- Should show console.log output about food selection priorities
```

#### **Food Quantities Display Wrong**
- Verify foods table has new serving fields (serving_amount, serving_unit, etc.)
- Check that edge function is using updated createFoodItemData function
- Look for "formatQuantity" usage in the Flutter app

## ✅ **Success Criteria**

- [ ] ✅ `food_preferences` table created and accessible
- [ ] ✅ `upsert_food_preferences()` function works
- [ ] ✅ `save-food-preferences` edge function deployed and working
- [ ] ✅ `create-nutrition-plan` edge function updated and working
- [ ] ✅ Flutter app saves preferences during onboarding
- [ ] ✅ Nutrition plans prioritize liked/willing-to-try foods
- [ ] ✅ Food quantities display properly (e.g., "3 cups cooked oatmeal")

## 📊 **Database Queries for Monitoring**

```sql
-- Check how many users have food preferences
SELECT COUNT(DISTINCT device_id) as users_with_preferences 
FROM food_preferences;

-- See preference distribution
SELECT preference, COUNT(*) as count 
FROM food_preferences 
GROUP BY preference;

-- Find users with most preferences
SELECT device_id, COUNT(*) as preference_count 
FROM food_preferences 
GROUP BY device_id 
ORDER BY preference_count DESC 
LIMIT 10;

-- Check which foods are most liked
SELECT food_name, COUNT(*) as like_count 
FROM food_preferences 
WHERE preference = 'like' 
GROUP BY food_name 
ORDER BY like_count DESC 
LIMIT 10;
```

Your food preferences system is now ready to deploy! 🎉