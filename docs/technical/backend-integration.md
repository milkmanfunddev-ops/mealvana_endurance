# Backend Integration - Mealvana Endurance

## Overview

Supabase backend implementation for the nutrition planning app with offline-first architecture, real-time features for future coach sharing, and secure user data management. The backend serves as the source of truth while supporting seamless offline functionality through local Hive caching.

## Database Schema Design

### Core Tables

Based on the app requirements, we need these primary entities:

```sql
-- User profiles (from onboarding)
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    gender VARCHAR(10) NOT NULL CHECK (gender IN ('male', 'female', 'other')),
    birthday DATE NOT NULL,
    height_feet INTEGER NOT NULL,
    height_inches INTEGER NOT NULL,
    weight_pounds DECIMAL(5,2) NOT NULL,
    runs_with_water_bottle BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ NULL
);

-- Food preferences from onboarding
CREATE TABLE food_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    food_name VARCHAR(100) NOT NULL,
    preference VARCHAR(20) NOT NULL CHECK (preference IN ('like', 'dislike', 'open_to_try')),
    food_category VARCHAR(20) NOT NULL CHECK (food_category IN ('pre_run', 'during_run', 'after_run')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ NULL,
    UNIQUE(user_id, food_name)
);

-- Generated nutrition plans
CREATE TABLE nutrition_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    distance_miles DECIMAL(5,2) NOT NULL,
    average_pace_minutes INTEGER NOT NULL,
    estimated_duration_minutes INTEGER NOT NULL,
    total_carbs_grams INTEGER NOT NULL,
    total_sodium_mg INTEGER NOT NULL,
    total_fluids_oz INTEGER NOT NULL,
    plan_data JSONB NOT NULL, -- Complete plan structure
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ NULL
);

-- User feedback on plans and app
CREATE TABLE feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    nutrition_plan_id UUID REFERENCES nutrition_plans(id),
    feedback_type VARCHAR(20) NOT NULL,
    feedback_category VARCHAR(20) NOT NULL CHECK (feedback_category IN ('plan', 'app')),
    suggestion_text TEXT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ NULL
);
```

### Row Level Security (RLS) Policies

Secure user data access:

```sql
-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutrition_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

-- Users can only access their own data
CREATE POLICY "Users can manage their own profile" ON user_profiles
FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own preferences" ON food_preferences
FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own plans" ON nutrition_plans
FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own feedback" ON feedback
FOR ALL USING (auth.uid() = user_id);
```

### Database Functions

Stored procedures for complex operations:

```sql
-- Function to calculate nutrition needs based on user profile and run parameters
CREATE OR REPLACE FUNCTION calculate_nutrition_needs(
    p_user_id UUID,
    p_distance_miles DECIMAL,
    p_pace_minutes INTEGER
) RETURNS JSON AS $$
DECLARE
    profile user_profiles%ROWTYPE;
    duration_minutes INTEGER;
    base_carbs INTEGER;
    base_sodium INTEGER;
    base_fluids INTEGER;
BEGIN
    -- Get user profile
    SELECT * INTO profile FROM user_profiles WHERE user_id = p_user_id AND deleted_at IS NULL;
    
    -- Calculate duration
    duration_minutes := (p_distance_miles * p_pace_minutes)::INTEGER;
    
    -- Base calculations (simplified - would be more complex in reality)
    base_carbs := CASE 
        WHEN duration_minutes > 60 THEN duration_minutes * 1.2
        ELSE duration_minutes * 0.8
    END;
    
    base_sodium := CASE
        WHEN duration_minutes > 90 THEN 800 + (duration_minutes - 90) * 5
        ELSE 600
    END;
    
    base_fluids := duration_minutes * 0.8;
    
    -- Adjust for user characteristics
    IF profile.weight_pounds > 180 THEN
        base_carbs := base_carbs * 1.1;
        base_fluids := base_fluids * 1.1;
    END IF;
    
    RETURN json_build_object(
        'carbs_grams', base_carbs,
        'sodium_mg', base_sodium,
        'fluids_oz', base_fluids,
        'estimated_duration_minutes', duration_minutes
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## Repository Implementation

### Base Repository Pattern

Common repository interface for all entities:

```dart
// lib/shared/data/base_repository.dart
abstract class BaseRepository<T> {
  Future<List<T>> getAll({bool forceRefresh = false});
  Future<T?> getById(String id);
  Future<T> create(T entity);
  Future<T> update(T entity);
  Future<void> delete(String id);
  Future<void> sync();
}
```

### User Profile Repository

Handle user profile CRUD operations:

```dart
// lib/features/user/data/user_profile_repository.dart
@riverpod
class UserProfileRepository extends _$UserProfileRepository {
  @override
  void build() {}

  Future<UserProfile?> getCurrentUserProfile() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    
    if (currentUser == null) return null;
    
    try {
      // Try to get from local cache first (offline-first)
      final hiveBox = Hive.box<Map<String, dynamic>>('user_profiles');
      final cachedProfile = hiveBox.get(currentUser.id);
      
      if (cachedProfile != null && !_shouldRefresh(cachedProfile)) {
        return UserProfile.fromJson(cachedProfile);
      }
      
      // Fetch from Supabase
      final response = await supabase
          .from('user_profiles')
          .select()
          .eq('user_id', currentUser.id)
          .maybeSingle();
      
      if (response != null) {
        // Cache the result
        await hiveBox.put(currentUser.id, response);
        return UserProfile.fromJson(response);
      }
      
      return null;
    } catch (error) {
      // Return cached data if available
      final hiveBox = Hive.box<Map<String, dynamic>>('user_profiles');
      final cachedProfile = hiveBox.get(currentUser?.id);
      
      if (cachedProfile != null) {
        return UserProfile.fromJson(cachedProfile);
      }
      
      rethrow;
    }
  }

  Future<UserProfile> createProfile(UserProfile profile) async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    
    if (currentUser == null) throw Exception('User not authenticated');
    
    final profileData = profile.copyWith(userId: currentUser.id).toJson();
    
    try {
      // Try to save to Supabase first
      final response = await supabase
          .from('user_profiles')
          .insert(profileData)
          .select()
          .single();
      
      // Cache successful save
      final hiveBox = Hive.box<Map<String, dynamic>>('user_profiles');
      await hiveBox.put(currentUser.id, response);
      
      return UserProfile.fromJson(response);
    } catch (error) {
      // Save to pending operations for later sync
      final pendingBox = Hive.box<Map<String, dynamic>>('pending_ops_user_profiles');
      await pendingBox.add({
        'operation': 'create',
        'data': profileData,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Cache locally for immediate use
      final hiveBox = Hive.box<Map<String, dynamic>>('user_profiles');
      await hiveBox.put(currentUser.id, profileData);
      
      return UserProfile.fromJson(profileData);
    }
  }

  bool _shouldRefresh(Map<String, dynamic> cachedData) {
    final updatedAt = DateTime.tryParse(cachedData['updated_at'] ?? '');
    if (updatedAt == null) return true;
    
    // Refresh if data is older than 5 minutes
    return DateTime.now().difference(updatedAt).inMinutes > 5;
  }
}
```

### Food Preferences Repository

Manage food preferences with batch operations:

```dart
// lib/features/onboarding/data/food_preferences_repository.dart
@riverpod
class FoodPreferencesRepository extends _$FoodPreferencesRepository {
  @override
  void build() {}

  Future<Map<String, FoodPreference>> getUserPreferences() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    
    if (currentUser == null) return {};
    
    try {
      // Check local cache first
      final hiveBox = Hive.box<Map<String, dynamic>>('food_preferences');
      final cacheKey = '${currentUser.id}_preferences';
      final cachedPrefs = hiveBox.get(cacheKey);
      
      if (cachedPrefs != null && !_shouldRefresh(cachedPrefs)) {
        return _parsePreferences(cachedPrefs['data']);
      }
      
      // Fetch from Supabase
      final response = await supabase
          .from('food_preferences')
          .select()
          .eq('user_id', currentUser.id)
          .eq('deleted_at', null);
      
      // Cache the result
      final cacheData = {
        'data': response,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await hiveBox.put(cacheKey, cacheData);
      
      return _parsePreferences(response);
    } catch (error) {
      // Return cached data if available
      final hiveBox = Hive.box<Map<String, dynamic>>('food_preferences');
      final cacheKey = '${currentUser.id}_preferences';
      final cachedPrefs = hiveBox.get(cacheKey);
      
      if (cachedPrefs != null) {
        return _parsePreferences(cachedPrefs['data']);
      }
      
      return {};
    }
  }

  Future<void> savePreferences(Map<String, FoodPreference> preferences) async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    
    if (currentUser == null) throw Exception('User not authenticated');
    
    // Convert preferences to database format
    final preferenceData = preferences.entries.map((entry) => {
      'user_id': currentUser.id,
      'food_name': entry.key,
      'preference': entry.value.name,
      'food_category': _getFoodCategory(entry.key),
    }).toList();
    
    try {
      // Batch upsert to Supabase
      await supabase
          .from('food_preferences')
          .upsert(preferenceData, onConflict: 'user_id,food_name');
      
      // Update local cache
      final hiveBox = Hive.box<Map<String, dynamic>>('food_preferences');
      final cacheKey = '${currentUser.id}_preferences';
      await hiveBox.put(cacheKey, {
        'data': preferenceData,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      // Queue for later sync
      final pendingBox = Hive.box<Map<String, dynamic>>('pending_ops_food_preferences');
      await pendingBox.add({
        'operation': 'batch_upsert',
        'data': preferenceData,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Cache locally
      final hiveBox = Hive.box<Map<String, dynamic>>('food_preferences');
      final cacheKey = '${currentUser.id}_preferences';
      await hiveBox.put(cacheKey, {
        'data': preferenceData,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Map<String, FoodPreference> _parsePreferences(List<dynamic> data) {
    final preferences = <String, FoodPreference>{};
    
    for (final item in data) {
      final foodName = item['food_name'] as String;
      final preference = item['preference'] as String;
      
      preferences[foodName] = FoodPreference.values.firstWhere(
        (e) => e.name == preference,
        orElse: () => FoodPreference.openToTry,
      );
    }
    
    return preferences;
  }

  String _getFoodCategory(String foodName) {
    // Same categorization logic as in analytics
    const preRunFoods = ['oatmeal', 'waffle', 'pancakes', 'bagel', 'bread', 
                        'peanut butter', 'banana', 'apple', 'juice', 
                        'granola bars', 'coffee'];
    const duringRunFoods = ['sports drink', 'gel', 'chews', 'sport drink mix',
                           'dates', 'dried fruits', 'electrolyte tablets'];
    const afterRunFoods = ['coconut water', 'protein shake', 'protein bars'];

    if (preRunFoods.contains(foodName.toLowerCase())) return 'pre_run';
    if (duringRunFoods.contains(foodName.toLowerCase())) return 'during_run';
    if (afterRunFoods.contains(foodName.toLowerCase())) return 'after_run';
    return 'unknown';
  }
}
```

### Nutrition Plans Repository

Store and retrieve generated nutrition plans:

```dart
// lib/features/nutrition_plan/data/nutrition_plans_repository.dart
@riverpod
class NutritionPlansRepository extends _$NutritionPlansRepository {
  @override
  void build() {}

  Future<List<NutritionPlan>> getUserPlans() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    
    if (currentUser == null) return [];
    
    try {
      // Check local cache
      final hiveBox = Hive.box<Map<String, dynamic>>('nutrition_plans');
      final cacheKey = '${currentUser.id}_plans';
      final cachedPlans = hiveBox.get(cacheKey);
      
      if (cachedPlans != null && !_shouldRefresh(cachedPlans)) {
        return _parsePlans(cachedPlans['data']);
      }
      
      // Fetch from Supabase
      final response = await supabase
          .from('nutrition_plans')
          .select()
          .eq('user_id', currentUser.id)
          .eq('deleted_at', null)
          .order('created_at', ascending: false);
      
      // Cache results
      final cacheData = {
        'data': response,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await hiveBox.put(cacheKey, cacheData);
      
      return _parsePlans(response);
    } catch (error) {
      // Return cached data
      final hiveBox = Hive.box<Map<String, dynamic>>('nutrition_plans');
      final cacheKey = '${currentUser.id}_plans';
      final cachedPlans = hiveBox.get(cacheKey);
      
      if (cachedPlans != null) {
        return _parsePlans(cachedPlans['data']);
      }
      
      return [];
    }
  }

  Future<NutritionPlan> savePlan(NutritionPlan plan) async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    
    if (currentUser == null) throw Exception('User not authenticated');
    
    final planData = plan.copyWith(userId: currentUser.id).toJson();
    
    try {
      // Save to Supabase
      final response = await supabase
          .from('nutrition_plans')
          .insert(planData)
          .select()
          .single();
      
      // Update local cache
      await _updateLocalPlanCache(currentUser.id, response);
      
      return NutritionPlan.fromJson(response);
    } catch (error) {
      // Queue for sync
      final pendingBox = Hive.box<Map<String, dynamic>>('pending_ops_nutrition_plans');
      await pendingBox.add({
        'operation': 'create',
        'data': planData,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Add to local cache immediately
      await _updateLocalPlanCache(currentUser.id, planData);
      
      return NutritionPlan.fromJson(planData);
    }
  }

  Future<void> _updateLocalPlanCache(String userId, Map<String, dynamic> newPlan) async {
    final hiveBox = Hive.box<Map<String, dynamic>>('nutrition_plans');
    final cacheKey = '${userId}_plans';
    
    // Get current cached plans
    final cachedData = hiveBox.get(cacheKey);
    final currentPlans = cachedData?['data'] as List<dynamic>? ?? [];
    
    // Add new plan to the beginning
    final updatedPlans = [newPlan, ...currentPlans];
    
    // Update cache
    await hiveBox.put(cacheKey, {
      'data': updatedPlans,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  List<NutritionPlan> _parsePlans(List<dynamic> data) {
    return data.map((item) => NutritionPlan.fromJson(item)).toList();
  }
}
```

## Authentication Integration

### Supabase Auth Setup

Configure authentication providers:

```dart
// lib/shared/services/auth_service.dart
@riverpod
class AuthService extends _$AuthService {
  @override
  User? build() {
    return Supabase.instance.client.auth.currentUser;
  }

  Future<void> signInWithEmail(String email, String password) async {
    final supabase = Supabase.instance.client;
    
    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    if (response.user != null) {
      state = response.user;
      // Trigger sync after successful login
      await _syncAfterAuth();
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    final supabase = Supabase.instance.client;
    
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
    );
    
    if (response.user != null) {
      state = response.user;
    }
  }

  Future<void> signInWithGoogle() async {
    final supabase = Supabase.instance.client;
    
    await supabase.auth.signInWithOAuth(
      Provider.google,
      redirectTo: 'com.mealvana.endurance://auth/callback',
    );
  }

  Future<void> signInWithApple() async {
    final supabase = Supabase.instance.client;
    
    await supabase.auth.signInWithOAuth(
      Provider.apple,
      redirectTo: 'com.mealvana.endurance://auth/callback',
    );
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    state = null;
    
    // Clear local caches
    await _clearLocalData();
  }

  Future<void> _syncAfterAuth() async {
    // Trigger sync for all repositories
    ref.read(syncServiceProvider).syncAll();
  }

  Future<void> _clearLocalData() async {
    final boxes = ['user_profiles', 'food_preferences', 'nutrition_plans', 'feedback'];
    
    for (final boxName in boxes) {
      final box = Hive.box<Map<String, dynamic>>(boxName);
      await box.clear();
    }
  }
}
```

## Sync Service Implementation

### Offline-First Sync Strategy

Handle periodic synchronization:

```dart
// lib/shared/services/sync_service.dart
@riverpod
class SyncService extends _$SyncService {
  @override
  bool build() => false;

  Future<void> syncAll() async {
    if (state) return; // Already syncing
    
    state = true;
    
    try {
      await _syncPendingOperations();
      await _pullLatestData();
    } finally {
      state = false;
    }
  }

  Future<void> _syncPendingOperations() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    
    if (currentUser == null) return;
    
    // Sync each entity type
    await _syncPendingForEntity('user_profiles');
    await _syncPendingForEntity('food_preferences');
    await _syncPendingForEntity('nutrition_plans');
    await _syncPendingForEntity('feedback');
  }

  Future<void> _syncPendingForEntity(String entityType) async {
    final pendingBox = Hive.box<Map<String, dynamic>>('pending_ops_$entityType');
    final supabase = Supabase.instance.client;
    
    final pendingOps = pendingBox.values.toList();
    
    for (int i = 0; i < pendingOps.length; i++) {
      final op = pendingOps[i];
      
      try {
        switch (op['operation']) {
          case 'create':
            await supabase.from(entityType).insert(op['data']);
            break;
          case 'update':
            await supabase.from(entityType)
                .update(op['data'])
                .eq('id', op['data']['id']);
            break;
          case 'delete':
            await supabase.from(entityType)
                .update({'deleted_at': DateTime.now().toIso8601String()})
                .eq('id', op['data']['id']);
            break;
          case 'batch_upsert':
            await supabase.from(entityType)
                .upsert(op['data'], onConflict: 'user_id,food_name');
            break;
        }
        
        // Remove successfully synced operation
        await pendingBox.deleteAt(i);
      } catch (error) {
        // Log error but continue with other operations
        print('Failed to sync ${op['operation']} for $entityType: $error');
      }
    }
  }

  Future<void> _pullLatestData() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    
    if (currentUser == null) return;
    
    // Get last sync timestamps
    final metaBox = Hive.box<Map<String, dynamic>>('meta');
    
    // Pull each entity type
    await _pullEntityData('user_profiles', metaBox);
    await _pullEntityData('food_preferences', metaBox);
    await _pullEntityData('nutrition_plans', metaBox);
    await _pullEntityData('feedback', metaBox);
  }

  Future<void> _pullEntityData(String entityType, Box<Map<String, dynamic>> metaBox) async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser!;
    
    final lastSyncKey = '${entityType}_last_sync';
    final lastSync = metaBox.get(lastSyncKey)?['timestamp'] as String?;
    
    var query = supabase.from(entityType).select().eq('user_id', currentUser.id);
    
    if (lastSync != null) {
      query = query.gt('updated_at', lastSync);
    }
    
    final response = await query;
    
    if (response.isNotEmpty) {
      // Update local cache with newest-wins strategy
      final cacheBox = Hive.box<Map<String, dynamic>>(entityType);
      
      for (final item in response) {
        final itemId = item['id'] as String;
        final existing = cacheBox.get(itemId);
        
        // Newest-wins conflict resolution
        if (existing == null || _isNewer(item, existing)) {
          await cacheBox.put(itemId, item);
        }
      }
      
      // Update last sync timestamp
      await metaBox.put(lastSyncKey, {
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  bool _isNewer(Map<String, dynamic> remote, Map<String, dynamic> local) {
    final remoteTime = DateTime.tryParse(remote['updated_at'] ?? '');
    final localTime = DateTime.tryParse(local['updated_at'] ?? '');
    
    if (remoteTime == null || localTime == null) return true;
    
    return remoteTime.isAfter(localTime);
  }
}
```

This backend integration provides a robust foundation for the nutrition app with offline-first capabilities, secure user data management, and seamless synchronization between local and remote data stores.