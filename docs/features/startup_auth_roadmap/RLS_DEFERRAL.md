# RLS Security Implementation - DEFERRED

**Decision Date:** 2025-11-18
**Status:** ⏸️ Postponed
**Reason:** Focus on core features first; implement security before production launch

---

## Decision Summary

**We are deferring implementation of Row Level Security (RLS) policies** to focus development effort on Phase 2 (Account Linking with Apple/Google/Email OAuth).

## Current Security State

### What's Permissive (Insecure)

The current RLS policies use `WITH CHECK true` and `USING true`, which means:

```sql
-- ⚠️ CURRENT STATE (Insecure)
create policy "Users can insert own data" on public.users
    for insert with check true;  -- ANY user can insert ANY profile

create policy "Users can read own data" on public.users
    for select using true;  -- ANY user can read ALL profiles

create policy "Users can update own data" on public.users
    for update using true;  -- ANY user can update ANY profile
```

**Impact:**
- Any anonymous user can read all user profiles
- Any anonymous user can modify any user's data
- Cross-user data access is completely open
- **NOT suitable for production with real user data**

### What's Required (Secure)

When we implement RLS, policies will use `auth.uid()`:

```sql
-- ✅ REQUIRED FOR PRODUCTION (Secure)
create policy "Users can only read own profile"
  on users FOR SELECT
  USING (auth.uid() = id);

create policy "Users can only update own profile"
  on users FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

create policy "Users can create own profile"
  on users FOR INSERT
  WITH CHECK (auth.uid() = id);
```

**Result:**
- Users can only access their own data
- `auth.uid()` enforcement prevents cross-user access
- JWT-based security throughout

---

## Why This Is Acceptable (For Now)

1. **Development Phase**
   - App not in production with real users yet
   - Current users are internal team/testers only
   - Data is test data that can be wiped

2. **Focus on Core Features**
   - Phase 2 (OAuth) provides user value immediately
   - Account linking is customer-facing feature
   - RLS is infrastructure (not visible to users)

3. **Can Implement Later**
   - RLS can be added without code changes
   - SQL-only change (no app deployment needed)
   - Can implement before production launch

---

## When RLS MUST Be Implemented

**BEFORE any of these:**

- ✅ App Store / Play Store public launch
- ✅ Beta testing with external users (non-team)
- ✅ Any real user data collection
- ✅ Production Supabase project with real accounts

**Recommended Timeline:**
- Implement RLS during Phase 4 prep (before launch)
- Estimated effort: 1 week
- Required testing: SQL policy tests, integration tests

---

## Risk Mitigation

### Current Mitigations
1. **Limited Access**
   - Dev Supabase project only accessible to team
   - No external users yet
   - Test data only

2. **Monitoring**
   - Sentry tracking auth errors
   - Supabase dashboard monitoring
   - Database activity logs

### Future Requirements
1. **Before Production:**
   - Implement all RLS policies using `auth.uid()`
   - Write SQL tests for policy enforcement
   - Run security audit
   - Test cross-user access prevention

2. **Deployment Checklist Item:**
   - [ ] RLS policies implemented and tested
   - [ ] All tables secured with `auth.uid()` policies
   - [ ] SQL tests passing
   - [ ] Integration tests confirm security

---

## Technical Debt Tracker

**Debt:** Permissive RLS policies allow cross-user data access
**Priority:** HIGH (must fix before production)
**Effort:** 1 week
**Blocking:** Public launch, external beta

**Implementation Plan:**
1. Audit all 17 tables for RLS policies
2. Rewrite policies to use `auth.uid()`
3. Add SQL policy tests
4. Run integration tests
5. Document security model

---

## References

- Main Roadmap: `/docs/features/startup_auth_roadmap/README.md`
- Implementation Plan: `/docs/features/startup_auth_roadmap/IMPLEMENTATION_ROADMAP.md`
- Phase 3 Details: See IMPLEMENTATION_ROADMAP.md Phase 3 section
- Database Schema: `/database_schemas/v1/schema.sql`

---

**Decision Maker:** Development Team
**Approved By:** [Name]
**Review Date:** Before Phase 4 (Launch Prep)
