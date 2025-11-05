# Phase 2B Fresh Install Test Guide

**Purpose**: Validate seed database integration with proper fresh install
**Status**: ✅ DateTimeColumn Issue Fixed - Ready for Final Testing

---

## Issues Fixed

### Issue 1: Old Database Present (FIXED)
Previous test showed existing database with missing tables. Solution: Complete app deletion.

### Issue 2: Table Name Mismatch (FIXED)
Seed DB had `foods` table, but Drift expected `foods_table`. Solution: Added table name override.

### Issue 3: DateTimeColumn Parsing (FIXED - November 4, 2025)
Seed DB stored `created_at` as TEXT timestamps, causing:
```
FormatException: Invalid radix-10 number (at character 1)
2025-09-24 19:35:46.868228 +00:00
```

**Solution**: Converted all `created_at` columns to INTEGER (Unix milliseconds) in seed database.
- Updated `foods`, `product_types`, and `carb_loading_foods` tables
- Database size reduced from 72KB to 68KB
- All timestamps now Drift-compatible

---

## Solution: Complete App Deletion

### Option 1: Use Helper Script (Recommended)

```bash
# From project root
./scripts/reset_simulator.sh
```

This will:
1. Find booted simulator
2. Uninstall app completely
3. Verify deletion successful

### Option 2: Manual Deletion

1. **Long-press app icon** on simulator
2. **Click "Remove App"**
3. **Confirm deletion**

OR from terminal:
```bash
xcrun simctl uninstall booted com.leemartin.mealvanaEndurance
```

---

## Expected Fresh Install Logs

After deleting the app and running `flutter run`, you should see:

```
flutter: supabase.supabase_flutter: INFO: ***** Supabase init completed *****
flutter: 🌱 Fresh install detected - copying seed database
flutter: 📍 Target path: /path/to/mealvana_endurance_db.sqlite
flutter: ✅ Seed database copied successfully (73728 bytes)
flutter: 📊 Seed DB contains 7 tables with food data
flutter: 📋 onCreate will create remaining 19 tables
flutter: 🔨 onCreate triggered - checking for seed tables
flutter: 📊 Found 7 existing tables from seed DB: foods, carb_loading_foods, ...
flutter: ✅ onCreate completed - foods table has 31 items
flutter: ✅ Database initialized with 31 seed foods
flutter: 💡 [APP_STARTUP] No user profile found - skipping sync (fresh install before onboarding)
```

**When nutrition plan is generated, you should see**:
```
flutter: 🔍 [FOOD_LOOKUP] Searching for food 76fbae6a-... (total foods in table: 31)
flutter: ✅ [FOOD_LOOKUP] Found food in foods table: Salt Packet
flutter: 🔍 [FOOD_LOOKUP] Searching for food 408c9d6e-... (total foods in table: 31)
flutter: ✅ [FOOD_LOOKUP] Found food in foods table: Water
```

**Key Indicators of Success**:
- ✅ "Fresh install detected"
- ✅ "Seed database copied successfully (69632 bytes)" (68KB after compression)
- ✅ "onCreate completed - foods table has 31 items"
- ✅ "Database initialized with 31 seed foods"
- ✅ "total foods in table: 31" (when looking up foods)
- ✅ "Found food in foods table" (for each food)
- ✅ NO "Existing database opened"
- ✅ NO "no such table" errors
- ✅ NO "total foods in table: 0"
- ✅ NO "FormatException" errors (DateTimeColumn parsing fixed)

---

## What You Should NOT See

❌ **"Existing database opened (v1 → v1)"** - Means app wasn't deleted (Issue 1)
❌ **"no such table: users"** - Means old broken database still present (Issue 1)
❌ **"Database created without seed data"** - Seed DB copy issue
❌ **"total foods in table: 0"** - Seed data was wiped (Issue 2 - table name mismatch)
❌ **"Food not found in either table"** - Foods missing
❌ **"FormatException: Invalid radix-10 number"** - DateTimeColumn parsing (Issue 3 - FIXED)

---

## Verification Steps

### 1. Delete App Completely
```bash
./scripts/reset_simulator.sh
```

### 2. Run Fresh Install
```bash
flutter run
```

### 3. Check Logs
Look for the success indicators above.

### 4. Verify Foods Visible
- App should show foods immediately
- No loading spinner
- No network errors

### 5. Check Network Activity (Optional)
- Use Flutter DevTools Network tab
- Should see only 1 call: `sync-all-data`
- NO `get-foods` calls

---

## New Diagnostic Logging

The latest code includes enhanced logging in FoodRepository to help diagnose the missing foods issue:

```dart
// When looking up a food by ID, you'll now see:
flutter: 🔍 [FOOD_LOOKUP] Searching for food 76fbae6a-... (total foods in table: X)
flutter: ✅ [FOOD_LOOKUP] Found food in foods table: Salt Packet
// OR
flutter: ⚠️ [FOOD_LOOKUP] Food not found in either table (searched X foods)
```

**This tells us**:
- If X = 31: Seed data is present, lookup issue is specific to food ID
- If X = 0: Seed data was completely wiped between onCreate and food lookup
- If X > 0 but food not found: Seed data partially present, missing specific items

---

## Troubleshooting

### Issue: Still seeing "Existing database opened"

**Solution**:
1. Stop the app
2. Delete more thoroughly:
   ```bash
   # Find and delete app container
   xcrun simctl listapps booted | grep mealvana

   # Or reset entire simulator (nuclear option)
   xcrun simctl erase all
   ```

### Issue: "Failed to copy seed database"

**Check**:
- `assets/data/app_seed.db` exists
- File size is 72 KB
- Schema version is 0:
  ```bash
  sqlite3 assets/data/app_seed.db "PRAGMA user_version;"
  # Should print: 0
  ```

### Issue: onCreate not triggered

**Likely cause**: Schema version not 0
**Fix**:
```bash
sqlite3 assets/data/app_seed.db "PRAGMA user_version = 0;"
flutter clean
flutter run
```

---

## Verbose Logging Added

The following verbose logging has been added to help diagnose issues:

### Database Copy Logic
- 🌱 Fresh install detection
- 📍 Target file path
- ✅ Copy success with byte count
- 📊 Seed DB table info
- 📋 onCreate info

### Existing Database Detection
- 📂 File already exists message
- 💡 "NOT a fresh install" warning

### onCreate Callback
- 🔨 onCreate triggered
- 📊 Which tables will be skipped (seed tables)
- 📋 Which tables will be created (empty tables)
- ✅ Completion message

### beforeOpen Callback
- ✅ Seed food verification
- ⚠️ Warnings if seed data missing

---

## Post-Test Validation

After successful fresh install:

1. **Check food count**: Should show 31 foods immediately
2. **Go offline**: Enable airplane mode, restart app - foods should still be there
3. **Check database file**:
   ```bash
   # Get app container path from logs, then:
   sqlite3 /path/to/mealvana_endurance_db.sqlite ".tables"
   # Should show all 26 tables
   ```

---

## Success Criteria

- [ ] App deletes completely from simulator
- [ ] Fresh install logs appear (not "existing database")
- [ ] onCreate triggers and creates all tables
- [ ] 31 seed foods verified
- [ ] No "no such table" errors
- [ ] App UI shows foods immediately
- [ ] Works offline (airplane mode test)

Once all checks pass: **Phase 2B is COMPLETE** ✅

---

## Next Steps After Success

1. Mark Phase 2B as complete in roadmap
2. Document any final observations
3. Proceed to Phase 2C: Offline-First Repository Refactoring

---

**Created**: 2025-11-04
**Updated**: 2025-11-04
**Status**: Ready for fresh install test
