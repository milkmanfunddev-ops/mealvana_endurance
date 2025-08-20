# Business Logic & Edge Functions

This directory contains the core business logic and Edge Functions for the Mealvana Endurance nutrition planning system.

## 📁 **Files Overview**

### **Edge Functions**
- **`create-user-edge-function.ts`** - Creates new users with device-based authentication
- **`save-food-preferences-edge-function.ts`** - Saves user food preferences (like/dislike/willing_to_try)
- **`updated-create-nutrition-plan-edge-function.ts`** - Generates personalized nutrition plans

### **Documentation**
- **`nutrition_algorithms.md`** - Detailed nutrition calculation algorithms
- **`food-preferences-system-overview.md`** - Complete food preferences system documentation
- **`edge-functions-readme.md`** - Edge functions deployment and usage guide

## 🚀 **Edge Functions Overview**

### **1. Create User**
**Endpoint:** `/functions/v1/create-user`

Creates a new user with device-based authentication and biometric data.

**Request:**
```json
{
  "device_id": "unique_device_identifier",
  "gender": "male|female|other",
  "birthday": "1990-01-01",
  "height_feet": 5,
  "height_inches": 10,
  "weight_pounds": 150,
  "runs_with_water_bottle": true,
  "gut_training_level": "moderate",
  "app_version": "1.0.0"
}
```

### **2. Save Food Preferences**
**Endpoint:** `/functions/v1/save-food-preferences`

Saves user food preferences and completes onboarding.

**Request:**
```json
{
  "device_id": "device123",
  "food_preferences": {
    "Oatmeal": "like",
    "Banana sliced": "like",
    "Gels": "willing_to_try",
    "Orange juice": "dislike"
  }
}
```

### **3. Create Nutrition Plan**
**Endpoint:** `/functions/v1/create-nutrition-plan`

Generates personalized nutrition plans based on user data and preferences.

**Request:**
```json
{
  "device_id": "device123",
  "distance_miles": 10,
  "pace_minutes_per_mile": 8.5,
  "time_before_run_hours": 2.0,
  "gut_training_level": "moderate"
}
```

**Response:** Complete nutrition plan with before/during/after run sections.

## 🎯 **Key Features**

### **Smart Food Prioritization**
The nutrition plan algorithm prioritizes foods based on user preferences:
1. **Liked foods** (highest priority)
2. **Willing-to-try foods** (medium priority)
3. **Other foods** (lowest priority)

### **Multi-Category Food System**
Foods can belong to multiple timing categories (before/during/after run) using a normalized database structure.

### **Structured Serving Data**
Food quantities are displayed using database-driven serving information:
- **Before:** `"3 cooked oatmeal"`
- **After:** `"3 cups cooked oatmeal"`

### **Nutrition Algorithms**
- **Pre-run:** 1-4g carbs per kg body weight based on timing
- **During-run:** 30-60g carbs per hour based on gut training
- **Post-run:** 1g carbs + 0.2g protein per kg body weight

## 🔧 **Deployment**

### **Deploy to Supabase**
```bash
# Deploy all functions
supabase functions deploy create-user
supabase functions deploy save-food-preferences  
supabase functions deploy create-nutrition-plan
```

### **Environment Variables**
Ensure these are set in your Supabase project:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

## 📊 **Architecture**

```
Flutter App
    ↓
Edge Functions (Deno)
    ↓
Supabase Database (PostgreSQL)
    ↓
Response with Nutrition Plan
```

### **Data Flow**
1. **User Creation** → Save biometric data
2. **Food Preferences** → Save like/dislike/willing-to-try
3. **Plan Generation** → Use preferences + algorithms → Return personalized plan

### **Error Handling**
All edge functions include:
- ✅ Input validation
- ✅ Database error handling  
- ✅ CORS support
- ✅ Detailed error messages
- ✅ Logging for debugging

## 🧪 **Testing**

### **Test User Creation**
```bash
curl -X POST 'https://your-project.supabase.co/functions/v1/create-user' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"device_id": "test123", "gender": "male", ...}'
```

### **Test Food Preferences**
```bash
curl -X POST 'https://your-project.supabase.co/functions/v1/save-food-preferences' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"device_id": "test123", "food_preferences": {...}}'
```

### **Test Nutrition Plan**
```bash
curl -X POST 'https://your-project.supabase.co/functions/v1/create-nutrition-plan' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"device_id": "test123", "distance_miles": 10, "pace_minutes_per_mile": 8.5}'
```

## 📚 **Further Reading**

- **`nutrition_algorithms.md`** - Deep dive into nutrition calculations
- **`food-preferences-system-overview.md`** - Complete food preference system
- **`/docs/database/`** - Database schema and migrations
- **`/docs/technical/`** - Technical architecture guides