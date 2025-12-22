# Device ID Sync Fix - Deployment Checklist

**Bug Fix:** Missing `device_id` parameter in `upsert-user-profile` Edge Function
**Date:** 2025-12-18
**Priority:** CRITICAL - Blocks user onboarding

## Pre-Deployment Verification

### Code Changes Verified
- [x] Edge Function updated to require `device_id`
- [x] Edge Function validates `device_id` is not null
- [x] Edge Function includes `device_id` in UPSERT query
- [x] Dart repository method has `required String deviceId` parameter
- [x] All 5 call sites in AuthService pass `deviceId`
- [x] Integration tests pass (5/5 onboarding tests)
- [x] Flutter analyze shows no errors

### Testing Completed
- [x] Local integration tests pass
- [ ] Manual testing on development environment
- [ ] Verify user creation works
- [ ] Verify profile updates work
- [ ] Check Supabase logs for errors

## Deployment Steps

### CRITICAL: Deploy in This Order!

#### Step 1: Deploy Edge Function FIRST
```bash
cd /Users/leemartin/development/mealvana_endurance/supabase
supabase functions deploy upsert-user-profile
```

**Why First?** The Flutter app changes depend on the Edge Function accepting `device_id`. Deploying Flutter first would cause errors.

**Verify:**
- [ ] Edge Function deploys successfully
- [ ] Check Supabase dashboard shows new version
- [ ] Test Edge Function manually via Supabase dashboard

#### Step 2: Deploy Flutter App (After Edge Function)
**Mobile (Shorebird OTA):**
```bash
# iOS
shorebird patch ios

# Android
shorebird patch android
```

**Web (Vercel):**
```bash
flutter build web --release --wasm --pwa-strategy=none
# Deploy to Vercel
vercel deploy --prod
```

**Verify:**
- [ ] iOS patch pushed successfully
- [ ] Android patch pushed successfully
- [ ] Web build completes
- [ ] Vercel deployment succeeds

## Post-Deployment Verification

### Edge Function Monitoring
Check Supabase Edge Function logs for:
- [ ] No more "null value in column device_id" errors
- [ ] Successful user profile UPSERTs
- [ ] Proper device_id values in logs

**Log Query:**
```sql
-- Check recent user inserts have device_id
SELECT id, device_id, created_at, updated_at
FROM users
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC
LIMIT 10;
```

### App Monitoring
Check Sentry for:
- [ ] No constraint violation errors
- [ ] User onboarding completion rate normal
- [ ] No new critical errors related to auth

**Sentry Query:**
```
error.type:supabase_auth_user_creation_failure
timeframe:1h
```

### Database Verification
Check production database:
```sql
-- Verify no users with null device_id
SELECT COUNT(*)
FROM users
WHERE device_id IS NULL;
-- Should be 0

-- Check recent user creations
SELECT id, device_id, auth_user_id, created_at
FROM users
WHERE created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC
LIMIT 20;
```

### User Flow Testing
Manually test critical flows:
- [ ] New user onboarding (fresh install)
- [ ] User profile creation
- [ ] Sport preferences update
- [ ] Dietary preferences update
- [ ] Allergies update
- [ ] Food preferences save (onboarding completion)

## Rollback Plan

If issues occur after deployment:

### Rollback Edge Function
```bash
cd /Users/leemartin/development/mealvana_endurance/supabase
git log supabase/functions/upsert-user-profile/index.ts
# Find previous commit hash
git checkout <previous-commit-hash> supabase/functions/upsert-user-profile/index.ts
supabase functions deploy upsert-user-profile
```

### Rollback Flutter App
**Mobile:**
```bash
# Shorebird allows rollback to previous patch
shorebird releases list
shorebird patch rollback --patch-number <previous-patch>
```

**Web:**
```bash
# Rollback Vercel deployment
vercel rollback
```

## Success Criteria

The deployment is considered successful when:
- [ ] No constraint violation errors in Edge Function logs
- [ ] No Sentry errors related to device_id
- [ ] Users can complete onboarding successfully
- [ ] All profile update operations work
- [ ] Database shows correct device_id values for new users
- [ ] Integration tests continue to pass in production

## Timeline Estimate

| Step | Duration | Notes |
|------|----------|-------|
| Edge Function deployment | 2 min | Supabase auto-deploy |
| Edge Function verification | 5 min | Check logs, test manually |
| Flutter iOS patch | 5 min | Shorebird upload |
| Flutter Android patch | 5 min | Shorebird upload |
| Flutter Web build | 3 min | Compile time |
| Web deployment | 2 min | Vercel auto-deploy |
| Post-deployment testing | 15 min | Manual verification |
| **Total** | **37 min** | Plus monitoring time |

## Communication Plan

### Stakeholders to Notify
- [ ] Engineering team
- [ ] Product team (if user-facing)
- [ ] QA team for testing

### Notifications
**Before Deployment:**
> "Deploying critical fix for user onboarding sync bug. Edge Function deployment at [time], app deployment at [time]."

**After Successful Deployment:**
> "Device ID sync fix deployed successfully. All tests passing. Monitoring for 24 hours."

**If Rollback Required:**
> "Rolling back device ID sync fix due to [reason]. Investigating root cause."

## Notes

- This fix is **backwards compatible** - old clients will fail gracefully with validation error
- The Edge Function now properly validates both `user_id` AND `device_id`
- All Flutter changes are compile-time safe (required parameter)
- No database migration required
- No data cleanup required (existing users already have device_id)

## Related Documentation

- [Fix Documentation](/docs/bugfixes/device_id_sync_fix.md)
- [Edge Functions Guide](/docs/business_logic/edge-functions-current.md)
- [Database Schema v1](/database_schemas/v1/README.md)
