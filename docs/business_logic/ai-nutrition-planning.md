# AI-Powered Nutrition Planning

## 🎯 **Architecture Overview**

The Mealvana Endurance app uses a sophisticated **AI-first nutrition planning system** with intelligent fallback strategies to ensure users always receive personalized nutrition plans.

### **Two-Tier Planning System**

```
User Request
    ↓
🤖 AI-Powered LLM Planning (Primary)
    ↓ (if fails)
⚡ Algorithmic Fallback Planning (Secondary)
    ↓
📱 Personalized Nutrition Plan
```

## 🤖 **Primary: AI-Powered LLM Planning**

### **Edge Function: `generate-ai-nutrition-plan`**

**Purpose**: Leverages AI/LLM capabilities to generate highly personalized nutrition plans that understand context, preferences, and nuanced requirements.

**Key Features**:
- **Natural Language Understanding**: Interprets complex user requirements
- **Advanced Personalization**: Considers individual preferences, gut training, and constraints
- **Context-Aware Planning**: Understands race conditions, weather, and performance goals
- **Linear Programming Optimization**: Uses sophisticated constraint solving for optimal food selection

### **Linear Programming Optimization Engine**

The AI Edge Function implements a **JavaScript Linear Programming Solver** for multi-objective optimization:

#### **Optimization Objectives**
```typescript
const CONSTRAINT_PRIORITY = {
  carbs_g: 2.0,     // HIGH priority - primary fuel source
  protein_g: 0.3,   // Low priority (optional for most phases)
  fat_g: 0.3,       // Low priority (optional for most phases)  
  sodium_mg: 1.8,   // High priority but slightly less than carbs
  water_ml: 1.5     // High priority for hydration
};
```

#### **Food Selection Scoring**
```typescript
const SCORING_CONFIG = {
  preference: {
    like: 20,           // Strongly favor liked foods
    willing_to_try: 5,  // Moderate preference
    dislike: 0          // Avoid disliked foods
  },
  phase_specific_bonuses: {
    aid_station_bonus: 12,        // Bonus for race-available foods
    gi_sensitive_penalty: 20,     // Penalty for hard-to-digest foods
    carb_density_multiplier: 120  // Prioritize efficient carb sources
  }
};
```

### **Performance Optimizations**
- **Food Candidate Limiting**: Maximum 8-12 foods per phase to reduce solver complexity
- **Constraint Tolerance**: Tight tolerances for critical nutrients (carbs ±5g, sodium ±25mg)
- **Serving Size Steps**: Granular serving increments (0.25-0.5 steps) for precise targeting

## ⚡ **Fallback: Algorithmic Planning**

### **Edge Function: `run-plan`**

**Purpose**: Fast, deterministic nutrition planning when AI service is unavailable or fails.

**Key Features**:
- **Sub-second Response Times**: Optimized for speed and reliability
- **No External Dependencies**: Pure TypeScript with no heavy packages
- **Evidence-Based Algorithms**: ACSM formulas and sports nutrition research
- **Preference Integration**: Respects user food likes/dislikes with scoring system

### **Deterministic Algorithm Flow**

```typescript
1. Calculate Energy Requirements (ACSM equations)
   → MET calculation from pace
   → Gross calories: MET × weight × duration
   → Net transport cost: ~1 kcal/kg/km

2. Determine Nutrition Targets by Phase
   → Pre-run: 1-4g/kg carbs (time-dependent)
   → During-run: 30-60g/h carbs (gut training adjusted)
   → Post-run: 1g/kg carbs + 0.2g/kg protein

3. Score and Select Foods
   → Filter by phase appropriateness
   → Apply preference scoring (like: +20, willing: +5)
   → Optimize for nutritional targets
   → Minimize GI distress risk
```

## 🔄 **Fallback Strategy Implementation**

### **Service Layer Logic**
```dart
// lib/features/nutrition_plan/application/nutrition_plan_service.dart

Future<NutritionPlan> generateNutritionPlan() async {
  try {
    // FIRST: Try LLM-based nutrition plan generation
    final llmPlan = await _llmService.generateLLMNutritionPlan();
    
    if (llmPlan != null) {
      await _analytics.trackPlanGenerated(
        distanceMiles: distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile,
        totalCalories: llmPlan.totalCalories ?? 0,
        totalCarbs: llmPlan.macroTargets?.carbs ?? 0,
        beforeRunItems: _countItems(llmPlan.sections, 'Before Run'),
        duringRunItems: _countItems(llmPlan.sections, 'During Run'),
        afterRunItems: _countItems(llmPlan.sections, 'After Run'),
        isFirstPlan: await _isFirstPlan(),
      );
      return llmPlan;
    }

    // FALLBACK: Use algorithmic run-plan Edge Function
    final algorithmicPlan = await _repository.createNutritionPlanV2();
    await _analytics.trackPlanGenerated(
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
      totalCalories: algorithmicPlan.totalCalories ?? 0,
      totalCarbs: algorithmicPlan.macroTargets?.carbs ?? 0,
      beforeRunItems: _countItems(algorithmicPlan.sections, 'Before Run'),
      duringRunItems: _countItems(algorithmicPlan.sections, 'During Run'),
      afterRunItems: _countItems(algorithmicPlan.sections, 'After Run'),
      isFirstPlan: await _isFirstPlan(),
    );
    return algorithmicPlan;
    
  } catch (e) {
    // Error handling and analytics
    await _analytics.trackPlanGenerationFailed(
      errorMessage: e.toString(),
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
    );
    rethrow;
  }
}
```

> As above, `_countItems` refers to a helper in `NutritionPlanService` that counts foods per plan section.

## 📊 **Performance & Analytics**

### **Response Time Tracking**
- **LLM Planning**: Typically 2-5 seconds (includes AI processing)
- **Algorithmic Fallback**: <1 second (optimized for speed)
- **Success Rate Monitoring**: Tracks LLM success vs fallback usage

### **Quality Metrics**
- **Plan Completion Rate**: Percentage of successfully generated plans
- **User Satisfaction**: Implicit feedback through plan usage
- **Nutritional Accuracy**: Adherence to evidence-based targets

## 🔧 **Configuration & Tuning**

### **AI Model Parameters**
```typescript
// Configurable constraints in generate-ai-nutrition-plan
const DEFAULT_TOL = {
  carbs_g: 5,       // Tight tolerance for primary fuel
  protein_g: 15,    // Relaxed for optional macros
  sodium_mg: 25,    // Critical for performance
  water_ml: 50      // Hydration precision
};
```

### **Food Selection Limits**
```typescript
const MAX_FOOD_CANDIDATES = {
  before: 8,    // Pre-run simplicity
  during: 12,   // During-run gets more options
  after: 8      // Post-run recovery focus
};
```

## 🚀 **Deployment & Testing**

### **Edge Function Deployment**
```bash
# Deploy AI planning function
supabase functions deploy generate-ai-nutrition-plan

# Deploy algorithmic fallback
supabase functions deploy run-plan

# Test both systems
curl -X POST 'https://project.supabase.co/functions/v1/generate-ai-nutrition-plan' \
  -H 'Authorization: Bearer ANON_KEY' \
  -d '{"device_id": "test", "distance_miles": 13.1, "pace_minutes_per_mile": 8.5}'
```

### **Testing Strategy**
- **Load Testing**: Ensure fallback triggers appropriately under high load
- **Accuracy Testing**: Compare AI vs algorithmic outputs for consistency
- **Performance Testing**: Monitor response times and success rates

## 💡 **Benefits of AI-First Architecture**

### **For Users**
- **Highly Personalized**: AI understands nuanced preferences and constraints
- **Context-Aware**: Considers race conditions, weather, individual history
- **Reliable**: Algorithmic fallback ensures plans always generate
- **Fast**: Sub-second fallback when AI is unavailable

### **For Developers**
- **Flexibility**: Easy to improve AI models without affecting fallback
- **Reliability**: Dual-system ensures high availability
- **Analytics**: Rich data on AI performance and user preferences
- **Scalability**: Can handle varying AI service availability

This AI-first architecture represents a significant evolution from simple algorithmic planning to sophisticated, personalized nutrition guidance that adapts to individual needs while maintaining reliability through intelligent fallback strategies.
