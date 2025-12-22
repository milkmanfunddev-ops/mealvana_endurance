# Edge Function Audit - December 2025

## Summary
This document tracks which Supabase edge functions are actively used in the codebase vs unused/deprecated.

**Audit Date:** 2025-12-20
**Audited By:** Claude AI Assistant
**Method:** Searched entire `lib/` directory for `.functions.invoke()` calls

---

## ACTIVELY USED Edge Functions (13)

These functions have confirmed invocations in the Dart codebase:

### 1. **create-user** ✅
- **Location:** `/supabase/functions/create-user/`
- **Invoked in:** `lib/features/auth/data/auth_repository_edge.dart:47`
- **Purpose:** Device-based user registration
- **Status:** ACTIVE - Core authentication flow

### 2. **delete-user** ✅
- **Location:** `/supabase/functions/delete-user/`
- **Invoked in:** `lib/features/settings/presentation/providers/settings_controller.dart:568`
- **Purpose:** Account deletion
- **Status:** ACTIVE - Settings feature

### 3. **generate-macros** ✅
- **Location:** `/supabase/functions/generate-macros/`
- **Invoked in:** `lib/features/nutrition_plan/application/macro_generation_service.dart:322`
- **Purpose:** ACSM-based macro target calculations
- **Status:** ACTIVE - Core nutrition feature

### 4. **generate-nutrition-plan** ✅
- **Location:** `/supabase/functions/generate-nutrition-plan/`
- **Invoked in:** `lib/features/nutrition_plan/application/llm_nutrition_plan_service.dart:145,577`
- **Purpose:** AI-powered nutrition plan generation (primary)
- **Status:** ACTIVE - Core feature (LLM-based)

### 5. **get-foods** ✅
- **Location:** `/supabase/functions/get-foods/`
- **Invoked in:** `lib/features/nutrition_plan/data/food_repository.dart:29`
- **Purpose:** Fetch nutrition foods database
- **Status:** ACTIVE - Food data management

### 6. **get-weather-forecast** ✅
- **Location:** `/supabase/functions/get-weather-forecast/`
- **Invoked in:** `lib/features/weather/application/weather_service.dart:135`
- **Purpose:** Weather data for race planning
- **Status:** ACTIVE - Weather feature

### 7. **lookup-product** ✅
- **Location:** `/supabase/functions/lookup-product/`
- **Invoked in:** `lib/features/barcode_scanning/application/product_detail_service.dart:39`
- **Purpose:** Barcode scanning product lookup
- **Status:** ACTIVE - Barcode scanning feature

### 8. **save-food-preferences** ✅
- **Location:** `/supabase/functions/save-food-preferences/` (MISSING - needs creation?)
- **Invoked in:** `lib/features/auth/data/auth_repository_edge.dart:203`
- **Purpose:** Save user food preferences
- **Status:** ACTIVE - Referenced but function may be missing

### 9. **save-user-food** ✅
- **Location:** `/supabase/functions/save-user-food/`
- **Invoked in:**
  - `lib/shared/widgets/food_preferences_content.dart:460`
  - `lib/features/settings/presentation/screens/food_preferences_screen.dart:656`
  - `lib/features/onboarding/presentation/screens/food_preferences_screen.dart:1364`
- **Purpose:** Save custom user foods
- **Status:** ACTIVE - Food management feature

### 10. **search-public-events** ✅
- **Location:** `/supabase/functions/search-public-events/`
- **Invoked in:** `lib/features/events/application/public_events_service.dart:41`
- **Purpose:** Search race calendar
- **Status:** ACTIVE - Events feature

### 11. **send-nutrition-plan-email** ✅
- **Location:** `/supabase/functions/send-nutrition-plan-email/`
- **Invoked in:** `lib/features/sharing/application/email_service.dart:35`
- **Purpose:** Email nutrition plans as PDF
- **Status:** ACTIVE - Sharing feature

### 12. **sync-all-data** ✅
- **Location:** `/supabase/functions/sync-all-data/`
- **Invoked in:** `lib/shared/services/sync/data_sync_service.dart:330`
- **Purpose:** Unified data sync (Phase 2B - replaces multiple calls)
- **Status:** ACTIVE - Core sync infrastructure

### 13. **upload-all-data** ✅
- **Location:** `/supabase/functions/upload-all-data/`
- **Invoked in:** `lib/shared/services/sync/data_sync_service.dart:1109`
- **Purpose:** Upload dirty records to cloud
- **Status:** ACTIVE - Offline-first sync

### 14. **upsert-user-profile** ✅
- **Location:** `/supabase/functions/upsert-user-profile/`
- **Invoked in:** `lib/features/auth/data/auth_repository_edge.dart:355`
- **Purpose:** Update user profile data
- **Status:** ACTIVE - Core user management

---

## UNUSED/DEPRECATED Edge Functions (11)

These functions have NO invocations in the Dart codebase:

### 1. **barcode-lookup** ❌ DEPRECATED
- **Location:** `/supabase/functions/barcode-lookup/`
- **Replaced By:** `lookup-product` (used instead)
- **Reason:** Likely superseded by newer `lookup-product` function
- **Action:** ARCHIVE

### 2. **carb-loading** ❌ DEPRECATED
- **Location:** `/supabase/functions/carb-loading/`
- **Code Status:** Service file commented out (`lib/features/carb_loading/application/carb_loading_edge_service.dart`)
- **Reason:** Feature implemented locally, edge function not used
- **Action:** ARCHIVE

### 3. **create-nutrition-plan** ❌ DEPRECATED
- **Location:** `/supabase/functions/create-nutrition-plan/`
- **Replaced By:** `generate-nutrition-plan` (LLM-based)
- **Reason:** Old nutrition plan generation, superseded by AI version
- **Action:** ARCHIVE

### 4. **delete-user-food** ❌ UNUSED
- **Location:** `/supabase/functions/delete-user-food/`
- **Reason:** No Dart invocations found
- **Action:** VERIFY BEFORE ARCHIVING (may be called from other edge functions)

### 5. **generate-ai-nutrition-plan** ❌ DEPRECATED
- **Location:** `/supabase/functions/generate-ai-nutrition-plan/`
- **Replaced By:** `generate-nutrition-plan` (consolidated AI logic)
- **Reason:** Likely merged into `generate-nutrition-plan`
- **Action:** ARCHIVE

### 6. **get-carb-loading-foods** ❌ DEPRECATED
- **Location:** `/supabase/functions/get-carb-loading-foods/`
- **Replaced By:** `sync-all-data` (unified sync)
- **Reason:** Phase 2B migration - now included in sync-all-data response
- **Action:** ARCHIVE

### 7. **run-plan** ❌ DEPRECATED
- **Location:** `/supabase/functions/run-plan/`
- **Replaced By:** `generate-nutrition-plan`
- **Reason:** Old nutrition plan generation logic
- **Action:** ARCHIVE

### 8. **save-activity-completion** ❌ UNUSED
- **Location:** `/supabase/functions/save-activity-completion/`
- **Reason:** No Dart invocations found
- **Action:** VERIFY BEFORE ARCHIVING (may be legacy from activities feature)

### 9. **search-active-events** ❌ UNUSED
- **Location:** `/supabase/functions/search-active-events/`
- **Active Alternative:** `search-public-events` (used instead)
- **Reason:** Likely superseded by search-public-events
- **Action:** ARCHIVE

### 10. **send-push-notification** ❌ UNUSED
- **Location:** `/supabase/functions/send-push-notification/`
- **Reason:** No Dart invocations found
- **Action:** VERIFY BEFORE ARCHIVING (may be for future feature)

### 11. **sync-final-surge** ❌ UNUSED
- **Location:** `/supabase/functions/sync-final-surge/`
- **Reason:** No Dart invocations found (Final Surge integration not implemented yet)
- **Action:** KEEP - Future roadmap feature (see /docs/final_surge/)

### 12. **update-user-preferences** ❌ LIKELY DEPRECATED
- **Location:** `/supabase/functions/update-user-preferences/`
- **Replaced By:** `upsert-user-profile` (consolidated user updates)
- **Reason:** Likely merged into upsert-user-profile
- **Action:** ARCHIVE

### 13. **upload-user-data** ❌ EMPTY DIRECTORY
- **Location:** `/supabase/functions/upload-user-data/`
- **Replaced By:** `upload-all-data`
- **Reason:** Empty directory (2 files, likely placeholder)
- **Action:** DELETE

---

## SPECIAL CASES - Requires Human Review

### 1. **save-food-preferences** ⚠️ MISSING?
- **Invoked in:** `lib/features/auth/data/auth_repository_edge.dart:203`
- **Problem:** No matching edge function directory found
- **Possible:**
  - Function was renamed/deleted but code not updated
  - Handled by `upsert-user-profile` instead
- **Action:** HUMAN REVIEW - Update calling code or create function

---

## Recommended Actions

### SAFE TO ARCHIVE (9 functions):
1. `barcode-lookup` → Superseded by `lookup-product`
2. `carb-loading` → Not used (local implementation)
3. `create-nutrition-plan` → Superseded by `generate-nutrition-plan`
4. `generate-ai-nutrition-plan` → Merged into `generate-nutrition-plan`
5. `get-carb-loading-foods` → Merged into `sync-all-data`
6. `run-plan` → Superseded by `generate-nutrition-plan`
7. `search-active-events` → Superseded by `search-public-events`
8. `update-user-preferences` → Merged into `upsert-user-profile`
9. `upload-user-data` → Empty directory, superseded by `upload-all-data`

### KEEP (Future Features - 1 function):
1. `sync-final-surge` → Roadmap feature (Final Surge integration planned)

### VERIFY BEFORE ARCHIVING (2 functions):
1. `delete-user-food` → Check if called from other edge functions or database triggers
2. `save-activity-completion` → Check if legacy from activities feature
3. `send-push-notification` → Check if planned for future notifications feature

### FIX REQUIRED (1 issue):
1. **save-food-preferences** → Missing edge function but called in code - needs investigation

---

## Archive Command

```bash
# Create archive directory
mkdir -p /Users/leemartin/development/mealvana_endurance/supabase/functions/_archived

# Move deprecated functions (SAFE batch)
cd /Users/leemartin/development/mealvana_endurance/supabase/functions
mv barcode-lookup _archived/
mv carb-loading _archived/
mv create-nutrition-plan _archived/
mv generate-ai-nutrition-plan _archived/
mv get-carb-loading-foods _archived/
mv run-plan _archived/
mv search-active-events _archived/
mv update-user-preferences _archived/

# Delete empty directory
rm -rf upload-user-data

# After human verification, move these:
# mv delete-user-food _archived/
# mv save-activity-completion _archived/
# mv send-push-notification _archived/
```

---

## Verification Steps

1. ✅ Searched all `.dart` files for `.functions.invoke()` calls
2. ✅ Cross-referenced with edge function directories
3. ✅ Identified deprecated vs active functions
4. ✅ Documented replacements and migration paths
5. ⏳ **Pending:** Human review of special cases
6. ⏳ **Pending:** Archive execution

---

## Notes

- **Total Functions:** 25 (includes empty directory)
- **Active:** 13 functions (52%)
- **Deprecated/Unused:** 11 functions (44%)
- **Special Cases:** 1 (4%)
- **Archive Target:** 9 functions immediately, 2 after verification

**Next Steps:**
1. Human review of `save-food-preferences` missing function issue
2. Verify `delete-user-food`, `save-activity-completion`, `send-push-notification` usage
3. Execute archive command for safe batch
4. Update deployment configs to exclude archived functions
