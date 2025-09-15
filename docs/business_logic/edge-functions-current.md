# Active Edge Functions (2025)

## 🚀 **Current Production Edge Functions**

### **Primary Functions**

#### **1. `generate-ai-nutrition-plan`**
**Purpose**: AI-powered primary nutrition planning with linear programming optimization

**Features**:
- LLM/AI integration for personalized planning
- JavaScript Linear Programming Solver for multi-objective optimization
- Advanced food preference scoring and constraint solving
- Performance-optimized with candidate limiting and tolerance tuning

**Request**:
```json
{
  "device_id": "string",
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

**Response**: Complete nutrition plan with optimized food selections and timing

#### **2. `run-plan`** 
**Purpose**: Fast deterministic algorithmic fallback when AI service unavailable

**Features**:
- Sub-second response times with no external dependencies
- Evidence-based ACSM calculations and sports nutrition research
- User preference integration with scoring system
- Optimized for reliability and speed

**Request**:
```json
{
  "device_id": "string", 
  "weight_kg": 70.0,
  "duration_min": 111,
  "pre_window_min": 120,
  "gut_training": "moderate",
  "gi_sensitivity": "low",
  "temp_f": 75.0,
  "humidity": 65.0,
  "sweat_rate": "medium",
  "pace_min_per_km": 5.28
}
```

**Response**: Algorithmically generated nutrition plan with phase-specific recommendations

### **Supporting Functions**

#### **3. `save-food-preferences`**
**Purpose**: User food preference management (like/willing_to_try/dislike)

**Features**:
- Three-tier preference system integration
- Database upsert with conflict resolution
- Onboarding completion tracking
- User preference validation

**Request**:
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
**Purpose**: New user creation with device-based authentication

**Features**:
- Device-based authentication (no passwords)
- Biometric data validation and storage
- Food preferences initialization
- Comprehensive error handling and CORS support

**Request**:
```json
{
  "device_id": "unique_device_identifier",
  "gender": "male",
  "birthday": "1990-01-01", 
  "height_feet": 5,
  "height_inches": 10,
  "weight_pounds": 150,
  "runs_with_water_bottle": true,
  "gut_training_level": "moderate",
  "app_version": "1.2.0"
}
```

#### **5. `get-foods`**
**Purpose**: Food database retrieval with caching and filtering

**Features**:
- Cached food data with 24-hour refresh cycles
- Category-based filtering
- Search functionality
- Brand and affiliate information integration

**Request**:
```json
{
  "category": "during_run",
  "search": "gel",
  "limit": 50
}
```

## 📊 **Function Usage Patterns**

### **Primary Planning Flow**
```
User Request → generate-ai-nutrition-plan (Primary)
    ↓ (if fails or unavailable)
User Request → run-plan (Fallback)
    ↓
Complete Nutrition Plan
```

### **User Onboarding Flow**
```
1. create-user (biometric data)
2. save-food-preferences (preference selection)
3. generate-ai-nutrition-plan (first plan)
```

### **Data Management Flow**
```
get-foods → Cache locally for 24 hours
save-food-preferences → Update user profile
```

## 🔧 **Deployment Guide**

### **Prerequisites**
- Supabase project with appropriate environment variables
- Database tables: users, food_preferences, foods, nutrition_plans
- Row Level Security (RLS) policies configured

### **Environment Variables**
```bash
SUPABASE_URL=https://project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
SUPABASE_ANON_KEY=your_anon_key
```

### **Deployment Commands**
```bash
# Deploy all current functions
supabase functions deploy generate-ai-nutrition-plan
supabase functions deploy run-plan  
supabase functions deploy save-food-preferences
supabase functions deploy create-user
supabase functions deploy get-foods

# Verify deployments
supabase functions list
```

## 🧪 **Testing Guide**

### **Health Checks**
```bash
# Test AI nutrition planning
curl -X POST 'https://project.supabase.co/functions/v1/generate-ai-nutrition-plan' \
  -H 'Authorization: Bearer ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"device_id": "test", "distance_miles": 13.1, "pace_minutes_per_mile": 8.5}'

# Test algorithmic fallback
curl -X POST 'https://project.supabase.co/functions/v1/run-plan' \
  -H 'Authorization: Bearer ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"device_id": "test", "weight_kg": 70, "duration_min": 111}'

# Test user creation
curl -X POST 'https://project.supabase.co/functions/v1/create-user' \
  -H 'Authorization: Bearer ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"device_id": "test123", "gender": "other", "weight_pounds": 150}'
```

### **Load Testing**
- Use tools like Apache Bench or Artillery for load testing
- Monitor fallback behavior under high AI service load
- Verify response time SLAs (AI: <5s, algorithmic: <1s)

### **Integration Testing**
```bash
# Full user flow test
1. POST create-user (new user)
2. POST save-food-preferences (onboarding)
3. GET get-foods (verify food data)
4. POST generate-ai-nutrition-plan (first plan)
5. Verify plan quality and food selections
```

## 📈 **Performance Monitoring**

### **Key Metrics**
- **AI Success Rate**: % of requests handled by primary AI function
- **Fallback Rate**: % of requests using algorithmic backup
- **Response Times**: P50, P95, P99 for both functions
- **Error Rates**: Function failures and error types
- **User Satisfaction**: Plan completion and usage rates

### **Alerting Thresholds**
- AI success rate drops below 85%
- Algorithmic fallback response time exceeds 2 seconds
- Overall error rate exceeds 5%
- Database query timeouts or connection issues

## 🔒 **Security & Access Control**

### **Authentication**
- All functions require Supabase authentication
- Device-based authentication (no passwords)
- Row Level Security (RLS) enforced at database level

### **Rate Limiting**
- Built-in Supabase Edge Function rate limiting
- Additional custom rate limiting for expensive AI operations
- User-based request throttling for abuse prevention

### **Data Privacy**
- No sensitive user data logged in function execution
- Food preferences and biometric data encrypted in transit
- CORS headers properly configured for mobile app access

## 🔄 **Migration & Rollback**

### **Blue-Green Deployment**
- Deploy new versions alongside existing functions
- Test new versions with subset of traffic
- Full cutover once stability verified
- Rollback capability via function version management

### **Function Versioning**
```bash
# Deploy new version
supabase functions deploy function-name --version v2

# Rollback if needed  
supabase functions deploy function-name --version v1
```

## 📋 **Legacy Functions (Deprecated)**

### **No Longer Active**
- ❌ `create-nutrition-plan` - Replaced by `run-plan` and `generate-ai-nutrition-plan`
- ❌ `generate-macros` - Functionality merged into primary planning functions

These legacy functions have been moved to `/old` directories and should not be used in production.

## 💡 **Architecture Benefits**

### **Reliability**
- Dual-system ensures high availability
- Graceful degradation from AI to algorithmic planning
- Independent scaling of primary and fallback systems

### **Performance**
- AI system optimized for personalization
- Algorithmic system optimized for speed
- Smart caching and data management

### **Maintainability** 
- Clear separation of concerns between functions
- Independent deployment and testing
- Comprehensive monitoring and alerting

This Edge Functions architecture provides a robust, scalable foundation for personalized nutrition planning while maintaining reliability through intelligent fallback strategies.