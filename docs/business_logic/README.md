# Business Logic & Edge Functions

This directory contains the core business logic and Edge Functions for the Mealvana Endurance nutrition planning system.

## 📁 **Files Overview**

### **Edge Functions**
- **`create-user-edge-function.ts`** - Creates new users with device-based authentication
- **`save-food-preferences-edge-function.ts`** - Saves user food preferences (like/dislike/willing_to_try)
- **`generate-ai-nutrition-plan/index.ts`** - AI-powered personalized nutrition plan generation

### **Documentation**
- **`nutrition_algorithms.md`** - Detailed nutrition calculation algorithms
- **`food-preferences-system-overview.md`** - Complete food preferences system documentation
- **`edge-functions-readme.md`** - Edge functions deployment and usage guide

### **Requirements**
- **`../requirements/nutrition_plan_guidelines.md`** - Comprehensive endurance athlete nutrition guidelines
- **`../requirements/README.md`** - MVP design requirements and user flows

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

### **Evidence-Based Nutrition Guidelines**
The system follows comprehensive endurance athlete nutrition guidelines:

**Macro Target Guidelines:**
- **Carbohydrates:**
  - Pre-workout: 1–4g/kg body weight (~70–280g for 70kg athlete)
  - During workout: 30–60g/hour (up to 90g/hour with glucose+fructose mix)
- **Sodium:** 300–600mg/hour (up to 1000mg/hour in heat)
- **Fluids:** ~0.4–0.8 L/hour depending on sweat rate

### **Phase-Specific Food Selection**
The algorithm applies specific rules for each phase:

**Pre-Workout (2–3 hrs before start):**
- Limits to 3–6 different food items to reduce GI stress
- Prioritizes low to moderate fiber and fat foods for faster digestion
- Includes easily digestible carbs (oatmeal, banana, waffle, white bread, honey)
- Avoids high-fat or fibrous items (granola bars, nuts, raw veggies)
- Recommends 16–24 oz fluids slowly

**During Run:**
- Matches carb needs to duration with steady intake every 20–30 min
- Uses carb-dense, portable options (gels, chews, drink mix)
- Restricts to easily consumed forms while running (gels, chews, fluids)
- Flags impractical foods for running (banana, sandwich, oatmeal)
- Maximizes palatability while minimizing complexity (2–4 items)

### **Smart Food Prioritization**
The nutrition plan algorithm prioritizes foods based on:
1. **User preferences** (liked > willing-to-try > neutral foods)
2. **Phase appropriateness** (per practicality guidelines)
3. **Nutritional fit** (macro targets and timing)
4. **Digestibility** (fiber, fat content considerations)

### **Product-Specific Practicality**
Each food item is evaluated for phase-specific suitability:
- **Pre-Run Suitable:** Oatmeal, banana, peanut butter, waffle, gel (optional)
- **During-Run Suitable:** Gel, chews, sports drink, tailwind drink mix
- **Post-Run Suitable:** Protein shake, coconut water, banana, granola bar
- **Phase Restrictions:** Never assigns impractical foods (e.g., oatmeal during run)

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