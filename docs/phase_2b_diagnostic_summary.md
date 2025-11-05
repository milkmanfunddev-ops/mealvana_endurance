# Phase 2B Diagnostic Summary - Foods Disappearing Issue

**Date**: 2025-11-04
**Status**: 🔍 Diagnostic logging added, awaiting test results

---

## The Mystery

Your logs from `/docs/logs.txt` show a puzzling sequence:

1. **Line 16** (08:32:43): `✅ Database initialized with 31 seed foods`
2. **Line 23** (08:32:43): `💡 No user profile found - skipping sync`
3. **Line 104** (08:33:20 - 38 seconds later): `⚠️ Food not found: 76fbae6a-ca0b-4404-ba93-48be328aae3b (Salt Packet)`

**The foods exist during database initialization, but disappear 38 seconds later!**

---

## What We Verified

### ✅ Foods ARE in the seed database
```bash
sqlite3 assets/data/app_seed.db "SELECT id, name FROM foods WHERE id='76fbae6a-ca0b-4404-ba93-48be328aae3b';"
# Output: 76fbae6a-ca0b-4404-ba93-48be328aae3b|Salt Packet
```

### ✅ Drift's `m.createAll()` preserves existing tables
According to Drift documentation and code analysis:
- `m.createAll()` uses `CREATE TABLE IF NOT EXISTS`
- It will NOT drop or recreate tables that already exist
- Seed data in existing tables is preserved

### ✅ `_populateDefaultData()` is safe
Only inserts into:
- `categoriesTable` (with `InsertMode.insertOrIgnore`)
- `mealTypesTable` (with `InsertMode.insertOrIgnore`)
- `productTypesTable` (with `InsertMode.insertOrIgnore`)

Does NOT touch `foods` table at all.

### ✅ No sync runs during app startup (fresh install)
Log line 23 confirms: "skipping sync (fresh install before onboarding)"

### ✅ `saveFoodPreferences()` doesn't delete foods
Only operates on `foodPreferencesTable`, not `foods` table.

---

## Timeline Analysis

Between lines 16 and 104 (38 seconds), the user:
1. Completed food preferences onboarding
2. Saved 31 food preferences
3. Navigated to main screen
4. Started nutrition plan generation

**No code path should be deleting foods during any of these steps.**

---

## Possible Root Causes

### Theory 1: Multiple Database Instances ❌ UNLIKELY
- `appDatabaseProvider` uses `Provider<AppDatabase>` (keeps singleton)
- All repositories use same `ref.watch(appDatabaseProvider)`

### Theory 2: Transaction Isolation Issue ❓ POSSIBLE
- onCreate verification happens inside transaction
- FoodRepository query happens 38 seconds later
- Possibly transaction never committed?

### Theory 3: Hidden Code Path Wiping Foods ❓ POSSIBLE
- Some code path during onboarding/navigation that we missed
- Perhaps a reset or initialization function?

### Theory 4: Seed DB Copy Corrupted ❓ POSSIBLE
- Copy succeeded but file was corrupted
- onCreate verified count before corruption manifested
- Later queries fail due to corruption

---

## Diagnostic Logging Added

Enhanced [FoodRepository.getFoodById()](/lib/features/nutrition_plan/data/food_repository.dart:183-224) with:

```dart
// Counts total foods in table before each lookup
final totalFoods = await (_database.select(_database.foodsTable).get()).length;
_logger.debug('🔍 [FOOD_LOOKUP] Searching for food $id (total foods in table: $totalFoods)');
```

**This will tell us**:
- **If totalFoods = 31**: Foods are present, lookup issue is with specific ID
- **If totalFoods = 0**: Foods were completely wiped between onCreate and lookup
- **If totalFoods = something else**: Partial data or corruption

---

## Next Steps

### 1. Run Fresh Install Test with New Logging ✅ READY
```bash
./scripts/reset_simulator.sh
flutter run
```

### 2. Watch for New Diagnostic Logs
Expected if working correctly:
```
flutter: 🔍 [FOOD_LOOKUP] Searching for food 76fbae6a-... (total foods in table: 31)
flutter: ✅ [FOOD_LOOKUP] Found food in foods table: Salt Packet
```

Expected if foods are missing:
```
flutter: 🔍 [FOOD_LOOKUP] Searching for food 76fbae6a-... (total foods in table: 0)
flutter: ⚠️ [FOOD_LOOKUP] Food not found in either table (searched 0 foods)
```

### 3. Based on Results

**If totalFoods = 0**:
- Add logging to onCreate/beforeOpen to verify transaction commit
- Check for hidden initialization code that clears tables
- Verify database file integrity

**If totalFoods = 31 but food not found**:
- Check if food IDs in seed DB match expected IDs
- Verify seed DB was copied correctly (hash check)
- Possibly UUID/ID mismatch issue

---

## Files Modified

1. [/lib/features/nutrition_plan/data/food_repository.dart](/lib/features/nutrition_plan/data/food_repository.dart)
   - Added diagnostic logging to `getFoodById()` (lines 185-190, 198-201, 213-216, 220-223)

2. [/docs/phase_2b_fresh_install_test_guide.md](/docs/phase_2b_fresh_install_test_guide.md)
   - Updated expected logs section (lines 61-85)
   - Added diagnostic logging explanation (lines 126-142)

---

## Code Analysis Summary

**What we know works**:
- ✅ Seed DB copy (73,728 bytes copied successfully)
- ✅ onCreate triggers (logs confirm)
- ✅ onCreate verifies 31 foods present
- ✅ beforeOpen verifies 31 foods present

**What mysteriously fails**:
- ❌ FoodRepository can't find foods 38 seconds later
- ❌ Nutrition plan has 0g carbs (should be 309g)

**What we need**:
- 🔍 Food count when FoodRepository queries (new logging provides this)

---

**Created**: 2025-11-04
**Author**: Claude Code
**Status**: Awaiting fresh install test with diagnostic logging
