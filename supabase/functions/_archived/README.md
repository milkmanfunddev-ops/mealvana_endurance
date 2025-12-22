# Archived Edge Functions

This directory contains Supabase edge functions that are no longer actively used in the application.

**Archive Date:** 2025-12-20
**Archived By:** Claude AI Assistant
**Audit Document:** `/supabase/functions/EDGE_FUNCTION_AUDIT.md`

---

## Archived Functions (8)

### 1. barcode-lookup
- **Reason:** Superseded by `lookup-product`
- **Archived:** 2025-12-20
- **Replacement:** Use `lookup-product` edge function instead

### 2. carb-loading
- **Reason:** Not used - feature implemented locally
- **Archived:** 2025-12-20
- **Code:** Service file commented out in `lib/features/carb_loading/application/carb_loading_edge_service.dart`
- **Note:** Local Dart implementation handles carb loading calculations

### 3. create-nutrition-plan
- **Reason:** Superseded by `generate-nutrition-plan`
- **Archived:** 2025-12-20
- **Replacement:** Use `generate-nutrition-plan` (LLM-based) edge function instead
- **Note:** Old algorithm-based nutrition plan generation

### 4. generate-ai-nutrition-plan
- **Reason:** Merged into `generate-nutrition-plan`
- **Archived:** 2025-12-20
- **Replacement:** Use `generate-nutrition-plan` edge function instead
- **Note:** AI logic consolidated into single endpoint

### 5. get-carb-loading-foods
- **Reason:** Replaced by `sync-all-data` (Phase 2B unified sync)
- **Archived:** 2025-12-20
- **Replacement:** Use `sync-all-data` edge function which returns all data including carb loading foods
- **Note:** Part of sync consolidation effort to reduce network calls

### 6. run-plan
- **Reason:** Superseded by `generate-nutrition-plan`
- **Archived:** 2025-12-20
- **Replacement:** Use `generate-nutrition-plan` edge function instead
- **Note:** Old nutrition plan generation logic

### 7. search-active-events
- **Reason:** Superseded by `search-public-events`
- **Archived:** 2025-12-20
- **Replacement:** Use `search-public-events` edge function instead
- **Note:** Events search functionality consolidated

### 8. update-user-preferences
- **Reason:** Merged into `upsert-user-profile`
- **Archived:** 2025-12-20
- **Replacement:** Use `upsert-user-profile` edge function for all user profile updates
- **Note:** User profile operations consolidated into single endpoint

---

## Restoration Instructions

If you need to restore any of these functions:

1. Copy the function directory back to `/supabase/functions/`
2. Redeploy using Supabase CLI: `supabase functions deploy <function-name>`
3. Update the audit document to reflect restoration
4. Add back any Dart code that invokes the function

---

## Cleanup Policy

These archived functions should be reviewed periodically:

- **After 6 months (June 2026):** Consider permanent deletion if no restoration needed
- **Before deletion:** Ensure no dependencies in database triggers, RLS policies, or other edge functions
- **Git History:** Functions remain in git history even after permanent deletion

---

## See Also

- Main Audit Document: `/supabase/functions/EDGE_FUNCTION_AUDIT.md`
- Active Edge Functions: `/supabase/functions/` (parent directory)
- Deployment Docs: `/docs/technical/README.md`
