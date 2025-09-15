# Business Logic & Edge Functions

This directory contains the core business logic and Edge Functions for the Mealvana Endurance nutrition planning system, featuring an **AI-first architecture** with intelligent algorithmic fallback.

## 📁 **Files Overview**

### **Architecture Documentation**
- **`ai-nutrition-planning.md`** - AI-first architecture with LLM integration and fallback strategies
- **`edge-functions-current.md`** - Active Edge Functions deployment and testing guide
- **`nutrition_algorithms.md`** - Detailed nutrition calculation algorithms and evidence-based formulas
- **`food-preferences-system-overview.md`** - Food preferences system with three-tier preference model

### **Requirements & Guidelines**
- **`../requirements/nutrition_plan_guidelines.md`** - Evidence-based endurance athlete nutrition guidelines
- **`../requirements/README.md`** - MVP design requirements and user flows

## 🚀 **Current Architecture (2025)**

### **AI-First Dual-System Approach**

```
User Request for Nutrition Plan
    ↓
🤖 Primary: AI-Powered LLM Planning
    ├─ Linear Programming Optimization
    ├─ Advanced Personalization
    └─ Context-Aware Recommendations
    ↓ (if AI fails or unavailable)
⚡ Fallback: Algorithmic Planning  
    ├─ Sub-second Response Times
    ├─ Evidence-Based Calculations
    └─ Deterministic Food Selection
    ↓
📱 Personalized Nutrition Plan
```

### **Active Edge Functions**

#### **1. `generate-ai-nutrition-plan`** (Primary)
**Purpose**: AI-powered nutrition planning with sophisticated optimization

**Key Features**:
- **LLM Integration**: Natural language understanding for personalized planning
- **Linear Programming Solver**: Multi-objective optimization for food selection
- **Advanced Scoring**: User preferences, nutritional targets, and constraints
- **Performance Optimized**: Food candidate limiting and constraint tolerance tuning

**Request:**
```json
{
  "device_id": "device123",
  "distance_miles": 13.1,
  "pace_minutes_per_mile": 8.5,
  "time_before_run_hours": 2.0,
  "gut_training_level": "moderate",
  "temp_f": 75.0,
  "humidity": 65.0,
  "sweat_rate": "medium",
  "gi_sensitivity": "low",
  "allow_high_carb_run": true
}
```

#### **2. `run-plan`** (Fallback)
**Purpose**: Fast, reliable algorithmic planning when AI unavailable

**Key Features**:
- **Sub-second Response**: Optimized for speed and reliability
- **No Dependencies**: Pure TypeScript with no external packages  
- **Evidence-Based**: ACSM formulas and sports nutrition research
- **Preference Integration**: User food likes/dislikes with scoring

**Request:**
```json
{
  "device_id": "device123",
  "weight_kg": 70.0,
  "duration_min": 111,
  "pre_window_min": 120,
  "gut_training": "moderate",
  "pace_min_per_km": 5.28
}
```

#### **3. `save-food-preferences`**
**Purpose**: Three-tier food preference management

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

#### **4. `create-user`**
**Purpose**: Device-based user creation with biometric data

**Request:**
```json
{
  "device_id": "unique_device_identifier",
  "gender": "male",
  "birthday": "1990-01-01",
  "height_feet": 5,
  "height_inches": 10,
  "weight_pounds": 150,
  "gut_training_level": "moderate",
  "app_version": "1.2.0"
}
```

#### **5. `get-foods`**
**Purpose**: Food database retrieval with caching and filtering

**Request:**
```json
{
  "category": "during_run",
  "search": "gel",
  "limit": 50
}
```

## 🎯 **Key Features & Algorithms**

### **AI-Powered Personalization**
- **LLM Integration**: Natural language understanding for complex user requirements
- **Linear Programming Optimization**: Multi-objective constraint solving for optimal food selection
- **Context-Aware Planning**: Considers race conditions, weather, and individual performance history
- **Advanced Preference Modeling**: Sophisticated scoring for food likes, dislikes, and willingness to try

### **Evidence-Based Nutrition Guidelines**
Both AI and algorithmic systems follow comprehensive endurance athlete nutrition research:

**Macro Target Guidelines:**
- **Carbohydrates:**
  - Pre-workout: 1–4g/kg body weight (~70–280g for 70kg athlete)  
  - During workout: 30–60g/hour (up to 90g/hour with glucose+fructose mix)
- **Sodium:** 300–600mg/hour (up to 1000mg/hour in heat)
- **Fluids:** ~0.4–0.8 L/hour depending on sweat rate and environmental conditions

### **Multi-Objective Optimization**
The AI system uses constraint priority weighting:
```typescript
CONSTRAINT_PRIORITY = {
  carbs_g: 2.0,     // HIGH priority - primary fuel source
  sodium_mg: 1.8,   // High priority for performance  
  water_ml: 1.5,    // High priority for hydration
  protein_g: 0.3,   // Lower priority for most phases
  fat_g: 0.3        // Lower priority for most phases
}
```

### **Phase-Specific Intelligence**
Both systems apply sophisticated phase-specific rules:

**Pre-Workout (1-4 hrs before):**
- **AI System**: Contextual understanding of timing, individual digestibility, preferences
- **Algorithmic System**: Time-dependent carb scaling (1-4g/kg), digestibility scoring
- **Food Selection**: Prioritizes easily digestible carbs, avoids high-fat/fiber foods
- **Hydration**: 2-6ml/kg based on available time window

**During Run:**
- **AI System**: Linear programming for optimal carb/sodium/fluid balance
- **Algorithmic System**: Deterministic selection with preference scoring  
- **Food Selection**: Portable, easily consumed foods (gels, chews, drinks)
- **Intake Strategy**: Steady 20-30 min intervals, gut training capacity limits

**After Run:**
- **Recovery Focus**: 1g/kg carbs + 0.2g/kg protein within 2 hours
- **Rehydration**: 150% of fluid losses or systematic replacement strategy
- **Food Selection**: Combination foods addressing multiple recovery needs

### **Smart Food Prioritization**
Advanced multi-factor scoring system:
1. **User Preferences**: Like (+20 pts) > Willing-to-try (+5 pts) > Neutral (0 pts)
2. **Phase Appropriateness**: Practicality and digestibility scoring
3. **Nutritional Efficiency**: Macro density and bioavailability
4. **Individual Tolerance**: GI sensitivity and gut training adaptations
5. **Environmental Factors**: Heat, humidity, aid station availability

## 🔧 **Deployment & Infrastructure**

### **Deploy Current Edge Functions**
```bash
# Deploy primary AI-powered nutrition planning
supabase functions deploy generate-ai-nutrition-plan

# Deploy algorithmic fallback system  
supabase functions deploy run-plan

# Deploy supporting functions
supabase functions deploy save-food-preferences
supabase functions deploy create-user
supabase functions deploy get-foods
```

### **Environment Variables**
Required for all Edge Functions:
```bash
SUPABASE_URL=https://project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key  
SUPABASE_ANON_KEY=your_anon_key
```

## 📊 **Current Architecture Flow**

### **AI-First System Architecture**
```
Flutter App (Dart)
    ↓
NutritionPlanService (orchestrates AI → fallback)
    ↓
generate-ai-nutrition-plan (Primary: AI + Linear Programming)
    ↓ (if fails)
run-plan (Fallback: Fast Algorithmic)
    ↓
Supabase Database (PostgreSQL + RLS)
    ↓
Personalized Nutrition Plan Response
```

### **Data Flow & Caching Strategy**
1. **User Onboarding**: create-user → save-food-preferences → mark onboarding complete
2. **Food Data**: get-foods → Cache locally in Drift SQLite for 24 hours
3. **Plan Generation**: AI system (primary) → algorithmic fallback → local caching
4. **Preference Updates**: save-food-preferences → invalidate plan cache → regenerate

### **Intelligent Fallback Strategy**
```dart
// Service layer automatically handles fallback
try {
  // Primary: Try AI-powered planning
  plan = await llmService.generateNutritionPlan();
  analytics.track('plan_generated', type: 'ai');
} catch (aiError) {
  // Fallback: Use algorithmic planning
  plan = await repository.createNutritionPlanV2();
  analytics.track('plan_generated', type: 'algorithmic');
}
```

### **Error Handling & Reliability**
- ✅ **Dual-system reliability**: AI failure gracefully falls back to algorithms
- ✅ **Comprehensive logging**: Sentry integration with detailed error context  
- ✅ **Performance monitoring**: Response time tracking for both systems
- ✅ **Input validation**: Robust parameter checking and sanitization
- ✅ **CORS support**: Proper mobile app integration

## 🧪 **Testing Guide**

### **Test AI-Powered Planning (Primary)**
```bash
curl -X POST 'https://project.supabase.co/functions/v1/generate-ai-nutrition-plan' \
  -H 'Authorization: Bearer ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "device_id": "test123",
    "distance_miles": 13.1,
    "pace_minutes_per_mile": 8.5,
    "gut_training_level": "moderate",
    "temp_f": 75.0,
    "humidity": 65.0
  }'
```

### **Test Algorithmic Fallback**
```bash
curl -X POST 'https://project.supabase.co/functions/v1/run-plan' \
  -H 'Authorization: Bearer ANON_KEY' \
  -H 'Content-Type: application/json' \  
  -d '{
    "device_id": "test123", 
    "weight_kg": 70.0,
    "duration_min": 111,
    "gut_training": "moderate"
  }'
```

### **Integration Testing**
```bash
# Full user flow
1. POST create-user (device-based auth)
2. POST save-food-preferences (onboarding completion)
3. GET get-foods (verify food data caching)
4. POST generate-ai-nutrition-plan (primary system)
5. Verify plan quality and food preference integration
```

## 🚀 **Benefits of Current Architecture**

### **🤖 AI-First Advantages**
- **Highly Personalized**: Understands nuanced user requirements and context
- **Adaptive**: Learns from user behavior and preferences over time
- **Context-Aware**: Considers race conditions, weather, individual history
- **Advanced Optimization**: Linear programming for optimal food selection

### **⚡ Reliable Fallback System**  
- **High Availability**: Dual-system ensures plans always generate
- **Fast Performance**: <1 second algorithmic fallback when AI unavailable
- **Evidence-Based**: ACSM formulas and sports nutrition research
- **Consistent Quality**: Maintains nutrition standards regardless of system used

### **🏗️ Development Benefits**
- **Scalable**: Independent scaling of AI and algorithmic systems
- **Maintainable**: Clear separation between primary and fallback logic
- **Observable**: Comprehensive analytics and error tracking  
- **Flexible**: Easy to improve AI models without affecting reliability

### **📱 User Experience**
- **Seamless**: Users never experience failed plan generation
- **Fast**: Intelligent system selection based on availability
- **Accurate**: Both systems provide evidence-based nutrition guidance
- **Personalized**: Preferences respected regardless of system used

## 📚 **Documentation Links**

### **Detailed Architecture**
- **`ai-nutrition-planning.md`** - Complete AI system architecture and linear programming optimization
- **`edge-functions-current.md`** - Active Edge Functions with deployment and testing guides

### **Algorithm Deep Dives**  
- **`nutrition_algorithms.md`** - Evidence-based calculation formulas and ACSM equations
- **`food-preferences-system-overview.md`** - Three-tier preference system and database design

### **External References**
- **`/docs/database/`** - Dual database architecture (Drift SQLite + Supabase PostgreSQL)
- **`/docs/technical/`** - Flutter app architecture and Riverpod patterns
- **`../requirements/`** - Evidence-based nutrition guidelines and MVP requirements

This AI-first architecture represents a significant evolution from simple algorithmic planning to sophisticated, personalized nutrition guidance while maintaining reliability through intelligent fallback strategies! 🎉