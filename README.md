# Mealvana Endurance – Startup & Auth Notes

This repository contains the Flutter codebase for the Mealvana Endurance mobile app.  
The current focus is stabilizing first-run onboarding, adopting Supabase Auth (anonymous sessions + social/email login), and keeping development telemetry isolated from production. For the full plan see [`docs/features/startup_auth_roadmap/README.md`](docs/features/startup_auth_roadmap/README.md).

## Key Decisions (Nov 2025)
- **Canonical IDs** – Every user is represented by the Supabase Auth UUID. Device IDs remain as metadata on the `users` table only.
- **Anonymous Auth first** – On cold start we call `supabase.auth.signInAnonymously()` if no session exists. All onboarding data is tied to that auth UID immediately.
- **Post-onboarding auth screen** – After food preferences we show a Kyle-designed “Create your account” screen with Google/Apple/email CTAs and a Skip button. All buttons call the Supabase Auth APIs directly; no edge functions are used.
- **Direct Supabase writes** – Edge functions are no longer used for user creation; onboarding writes to Drift first and syncs via `supabase.from('users').upsert`.
- **Environment routing** – Debug/Profile builds load `.env.dev.local` (dev DSNs/tokens, `options.environment = 'development'`). Release builds load `.env.prod.local`. The hidden environment switcher remains for QA overrides.
- **Telemetry** – Debug events/crashes go to dev Mixpanel/Sentry projects; Release events go to prod. Instrumentation must annotate anonymous vs permanent users.

## Verification Checklist
1. **Startup logs** – When running `flutter run`, verify the console prints `Loading env: .env.dev.local` and shows the Mixpanel token being used.
2. **Sentry** – Trigger a test exception in debug mode; confirm it appears in the dev project with environment `development`.
3. **Anonymous session** – Inspect the Drift DB (or logs) to confirm a Supabase UUID is stored after onboarding, not the device ID.
4. **Auth linking page** – Test the new screen after food preferences: email/password linking (`updateUser`), Google, Apple, and Skip. Confirm the same Supabase UID remains after linking and analytics events fire.

For implementation ordering, migration notes, and open questions, consult the roadmap document linked above. Update both documents whenever requirements change.
