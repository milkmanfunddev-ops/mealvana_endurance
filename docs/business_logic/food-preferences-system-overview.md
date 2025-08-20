# Food Preferences System Overview

## 🎯 **System Architecture**

The food preferences system allows users to specify their preferences for foods and uses this data to personalize nutrition plans.

### **Database Structure**

#### `food_preferences` Table
```sql
CREATE TABLE food_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    device_id TEXT NOT NULL REFERENCES users(device_id) ON DELETE CASCADE,
    food_name TEXT NOT NULL,
    preference TEXT NOT NULL CHECK (preference IN ('like', 'dislike', 'willing_to_try')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Key Features:**
- ✅ Stores user preferences per food item
- ✅ Three preference levels: `like`, `dislike`, `willing_to_try`
- ✅ Unique constraint prevents duplicate preferences for same user/food
- ✅ Automatic timestamps and triggers
- ✅ Row Level Security (RLS) enabled

## 🔄 **API Endpoints**

### 1. **Save Food Preferences**
**Endpoint:** `/functions/v1/save-food-preferences`

**Request:**
```json
{
  "device_id": "device123",
  "food_preferences": {
    "Oatmeal": "like",
    "Banana sliced": "like", 
    "Gels": "willing_to_try",
    "Coffee": "like",
    "Orange juice": "dislike",
    "Sport drinks": "willing_to_try",
    "Protein bar": "like",
    "Coconut water": "like"
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "Food preferences saved successfully",
  "preferences_count": 8,
  "saved_preferences": [
    { "food_name": "Oatmeal", "preference": "like" },
    { "food_name": "Banana sliced", "preference": "like" }
    // ... etc
  ]
}
```

**Features:**
- ✅ Validates user exists
- ✅ Validates preference values
- ✅ Uses `upsert_food_preferences()` database function
- ✅ Updates user's `onboarding_completed` status
- ✅ Returns saved preferences for confirmation

### 2. **Create Nutrition Plan (Updated)**
**Endpoint:** `/functions/v1/create-nutrition-plan`

**Enhanced Logic:**
- ✅ Fetches user food preferences from database
- ✅ Creates three priority categories:
  1. **Liked foods** (highest priority)
  2. **Willing-to-try foods** (medium priority)  
  3. **Other foods** (lowest priority)
- ✅ Uses structured serving data for proper quantity formatting

## 🏆 **Food Selection Priority System**

### **Priority Order**
```typescript
// 1. LIKED foods (user actively enjoys these)
const likedFoods = foodPreferences?.filter(fp => fp.preference === 'like').map(fp => fp.food_name) ?? [];

// 2. WILLING-TO-TRY foods (user is open to trying these)
const willingToTryFoods = foodPreferences?.filter(fp => fp.preference === 'willing_to_try').map(fp => fp.food_name) ?? [];

// 3. OTHER foods (foods user hasn't expressed preference about)
const otherFoods = foods.filter(f => !preferredFoods.includes(f.name));

// Final order: liked → willing-to-try → others
const orderedFoods = [...likedFoodsInCategory, ...willingToTryFoodsInCategory, ...otherFoods];
```

### **Selection Algorithm**
1. **Filter foods by timing category** (before/during/after run)
2. **Order foods by preference priority** (liked > willing-to-try > others)
3. **Select foods to meet nutritional targets** 
4. **Apply special logic for during-run foods** (prioritize gels/sports drinks)
5. **Format quantities using structured serving data**

## 📊 **Food Display Improvements**

### **Before (Hardcoded Parsing)**
- `"3 cooked oatmeal"` ❌
- `"2.3 banana Banana slices"` ❌
- `"5.1 packet Gels"` ❌

### **After (Structured Database)**
- `"3 cups cooked oatmeal"` ✅
- `"2.3 bananas, sliced"` ✅
- `"5.1 packets"` ✅

## 🔧 **Implementation Flow**

### **1. User Onboarding**
```
Food Preferences Screen
    ↓
User selects preferences (like/willing-to-try/dislike)
    ↓
save-food-preferences edge function
    ↓
Data saved to food_preferences table
    ↓
onboarding_completed = true
```

### **2. Nutrition Plan Generation**
```
create-nutrition-plan edge function
    ↓
Fetch user food preferences
    ↓
Create priority food lists (liked → willing-to-try → others)
    ↓
Filter foods by category (before/during/after)
    ↓
Select foods using priority order
    ↓
Format quantities with structured serving data
    ↓
Return personalized nutrition plan
```

## 📝 **Key Benefits**

### **For Users**
- ✅ **Personalized recommendations** based on actual preferences
- ✅ **Natural food quantities** (e.g., "3 cups" not "3 cooked")
- ✅ **Gradual expansion** via willing-to-try foods
- ✅ **Respect for dislikes** (disliked foods are excluded)

### **For Algorithm**
- ✅ **Better food selection** when user preferences are limited
- ✅ **Fallback to willing-to-try** foods when liked foods insufficient
- ✅ **Multi-category food support** (foods can be for multiple timings)
- ✅ **Database-driven serving data** (no hardcoded parsing)

### **For Development**
- ✅ **Clean separation of concerns** (preferences vs nutrition calculation)
- ✅ **Structured data model** (easy to query and update)
- ✅ **Extensible preference system** (could add more granular preferences)
- ✅ **Proper database normalization** (food_categories join table)

## 🚀 **Next Steps**

1. **Deploy edge functions** to Supabase
2. **Update Flutter app** to use new save-food-preferences endpoint
3. **Test preference-based plan generation**
4. **Monitor user feedback** on food recommendations
5. **Consider additional preference granularity** (e.g., "love", "neutral", etc.)

## 💡 **Database Helper Functions**

### `upsert_food_preferences(device_id, preferences_jsonb)`
- Deletes existing preferences for user
- Inserts new preferences from JSONB object
- Returns success/failure status
- Handles all validation and constraint checks

**Usage:**
```sql
SELECT upsert_food_preferences(
  'device123', 
  '{"Oatmeal": "like", "Gels": "willing_to_try"}'::jsonb
);
```

This comprehensive system ensures users get personalized nutrition plans based on their actual food preferences while maintaining clean, structured data architecture.