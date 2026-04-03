# Garmin Connect Integration

## Architecture Overview

Garmin Connect uses a **push-only** model. Unlike TrainingPeaks and Final Surge where we pull workouts on demand, Garmin pushes completed activity and health data to our edge functions when users sync their Garmin devices (via Garmin Connect Mobile or Garmin Express).

**The Flutter app only handles OAuth connect/disconnect.** Activities arrive automatically via server-side push and appear through the normal sync/hydration flow.

## Components

### Server-Side (Deployed)

| Component | Path | Purpose |
|-----------|------|---------|
| `garmin-push` | `supabase/functions/garmin-push/` | Receives activity + health data pushes from Garmin |
| `garmin-ping` | `supabase/functions/garmin-ping/` | Handles ping notifications (data available at callback URL) |
| `garmin-deregistration` | `supabase/functions/garmin-deregistration/` | Handles user deregistration notifications |
| `garmin-oauth-callback` | `supabase/functions/garmin-oauth-callback/` | Redirects OAuth callback to app custom scheme |
| Shared utilities | `supabase/functions/_shared/garmin/` | Types, auth validation, activity/health mappers |

### Database Tables

| Table | Purpose |
|-------|---------|
| `garmin_user_mappings` | Maps Garmin userId to our userId + stores OAuth tokens |
| `garmin_health_data` | Stores wellness data (dailies, sleep, body comp, stress, epochs) |

### Flutter-Side

| Component | Path | Purpose |
|-----------|------|---------|
| `GarminOAuthService` | `lib/features/integrations/application/garmin_oauth_service.dart` | OAuth 2.0 PKCE flow + mapping upsert |
| Provider | `integrations_providers.dart` | `garminOAuthServiceProvider`, `garminIntegrationProvider`, `isGarminConnectedProvider` |
| Controller | `connect_training_controller.dart` | `connectGarmin()`, `disconnectGarmin()`, state fields |
| UI | `connected_apps_screen.dart` | Garmin card in settings + onboarding modes |
| Config | `app_config.dart` | `garminClientId`, `garminClientSecret`, `garminRedirectUri` |

## OAuth 2.0 PKCE Flow

1. Generate PKCE `code_verifier` (64 random bytes, base64url-encoded) and `code_challenge` (SHA-256 of verifier, base64url-encoded)
2. Open `https://connect.garmin.com/oauth2Confirm` with params: `client_id`, `response_type=code`, `redirect_uri`, `scope`, `code_challenge`, `code_challenge_method=S256`, `state`
3. User authenticates on Garmin's site
4. Garmin redirects to our `garmin-oauth-callback` edge function, which 302-redirects to `com.milkman.mealvanaendurance://callback?code=...&state=...`
5. `flutter_web_auth_2` captures the redirect
6. Exchange code for tokens at `https://diauth.garmin.com/di-oauth2-service/oauth/token`
7. Fetch Garmin user ID from `https://apis.garmin.com/wellness-api/rest/user/id`
8. Save `IntegrationModel` via `IntegrationsRepository.upsertIntegration()`
9. **Critical**: Upsert `garmin_user_mappings` row in Supabase — this is what lets the push handler map incoming data to our user

## Garmin Developer Portal Configuration

- Portal: https://apis.garmin.com/tools/endpoints
- 10 push endpoints enabled: Activities, Activity Details, Manually Updated Activities, Deregistrations, Body Comps, Dailies, Epochs, Sleeps, Stress, User Metrics
- All endpoints point to our Supabase edge functions

## Environment Variables

```
GARMIN_CLIENT_ID=<from Garmin developer portal>
GARMIN_CLIENT_SECRET=<from Garmin developer portal>
GARMIN_REDIRECT_URI=<supabase-url>/functions/v1/garmin-oauth-callback
```

## RLS Policies

`garmin_user_mappings` has policies for:
- SELECT: Users can view their own mappings (`auth.uid() = user_id`)
- INSERT: Users can insert their own mappings (`auth.uid() = user_id`)
- UPDATE: Users can update their own mappings (`auth.uid() = user_id`)
- DELETE: Users can delete their own mappings (`auth.uid() = user_id`)
- ALL: Service role has full access (`auth.role() = 'service_role'`)

## Key Differences from TP/FS

| Aspect | TrainingPeaks / Final Surge | Garmin Connect |
|--------|----------------------------|----------------|
| Data flow | Pull on demand | Server-side push |
| Sync button | "Sync Now" shown | No sync button (`showSyncButton: false`) |
| Sync service | Yes (API client + transformer) | None needed |
| Activities | Imported via sync service | Arrive via `garmin-push` edge function |
| Manual sync | User taps "Sync Now" | Automatic when Garmin device syncs |

## Production Approval

Garmin requires Partner Verification before production use:
1. Have 2+ real Garmin users connected and receiving push data
2. Demonstrate proper push handling (activities, health data)
3. Apply for Production Key on Garmin developer portal
4. Manual review + brand compliance check

## Dev Testing

- Lee's Garmin User ID: `af701316-e43f-4a8c-be41-a3fde89a8e96` (from portal User ID tool)
- Lee's JWT garmin_guid: `d9092123-92f7-4a51-a75e-11d8f06bdea6` (different from above!)
- Lee's dev Mealvana user ID: `607f9dd5-6fa7-48ee-a628-720d4a0506a1`

## Known Gotchas

1. **User ID mismatch**: The Garmin user ID from the portal's "User ID" tool is different from the `garmin_guid` in JWTs. Always use the one from the `/wellness-api/rest/user/id` endpoint.
2. **Push-only**: There is no way to pull data on demand from Garmin. Users must sync their device.
3. **Column names**: The database table is `users` (not `user_profiles`).
