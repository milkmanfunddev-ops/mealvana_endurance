# Environment Configuration Summary

## Overview
This document details how dev and prod environments are configured and what behavior differs between them.

## ✅ Two Flavors (NOT Three!)

You have **2 FLAVORS** (environments):
- **dev** - Development environment
- **prod** - Production environment

**IMPORTANT**: "Profile" is NOT a third environment! It's a Flutter build mode for performance testing.

### Build Modes vs Flavors

Each flavor has 3 build modes (standard Flutter):
- **Debug** - Development with hot reload
- **Profile** - Performance profiling (measures FPS, memory)
- **Release** - Production-optimized (minified, obfuscated)

So you have:
- `dev-Debug`, `dev-Profile`, `dev-Release`
- `prod-Debug`, `prod-Profile`, `prod-Release`

This is **correct and follows Flutter/iOS/Android standards**. ✅

## Environment-Specific Configuration

### 📊 Analytics (Mixpanel)

**Dev Flavor:**
- ❌ **COMPLETELY DISABLED** (no tracking at all)
- Uses `NoopAnalyticsTracker` (no-op implementation)
- `analyticsTrackerProvider` checks `config.devModeEnabled` and returns noop tracker
- Developers not tracked in Mixpanel

**Prod Flavor:**
- ✅ **ENABLED**
- Uses `MixpanelAnalyticsTracker`
- Token: `bd8fe50bb67b1dd0860351e6297347db` (from .env.prod.local)
- All user events tracked to production Mixpanel project

**Implementation:**
```dart
// lib/shared/services/analytics/analytics_tracker.dart:256
final analyticsTrackerProvider = Provider<AnalyticsTracker>((ref) {
  final config = ref.watch(appConfigProvider);

  // Disable analytics in development environment
  if (config.devModeEnabled) {
    return const NoopAnalyticsTracker();
  }

  // Enable analytics in production environment
  final logger = ref.watch(appLoggerProvider);
  return MixpanelAnalyticsTracker(config: config, logger: logger);
});
```

---

### 🐛 Error Tracking (Sentry)

**Dev Flavor:**
- ✅ **ENABLED** with separate dev project
- DSN: `https://40b0481418b8542bded2a45a63fa0c37@o4509882392969216.ingest.us.sentry.io/4510121638166528`
- Project: **mealvana-endurance-dev**
- Environment tag: `development`
- Errors reported to dev Sentry project

**Prod Flavor:**
- ✅ **ENABLED** with separate prod project
- DSN: `https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328`
- Project: **mealvana-endurance**
- Environment tag: `production`
- Errors reported to prod Sentry project

**Configuration Files:**
- `.env.dev.local` - Dev Sentry DSN
- `.env.prod.local` - Prod Sentry DSN
- `lib/main_dev.dart` and `lib/main_prod.dart` - Initialize Sentry with respective DSNs

**Why Separate Projects:**
- Clean separation of dev and prod errors
- Different alerting rules (dev errors less urgent)
- Easier debugging (don't mix test errors with real user errors)

---

### 🗄️ Database (Supabase)

**Dev Flavor:**
- ✅ Dev Supabase project
- URL: `https://vlmtsdzpnjnavdgytcmi.supabase.co`
- Database: Development schema with test data
- No impact on production data

**Prod Flavor:**
- ✅ Prod Supabase project
- URL: `https://wvmvsodrvbkxfydabqed.supabase.co`
- Database: Production schema with real user data
- All production users

**Configuration:**
- `.env.dev.local` - Dev Supabase URL and keys
- `.env.prod.local` - Prod Supabase URL and keys
- `AppConfig.fromEnv()` reads from appropriate .env file

**Local Drift Database:**
- Both flavors use local Drift SQLite for offline-first
- Syncs to respective Supabase project (dev to dev, prod to prod)
- Database files stored separately by flavor (different app bundle IDs)

---

### ⚡ Edge Functions (Supabase)

**How Edge Functions Determine Environment:**

Edge functions automatically connect to the correct database based on which Supabase project they're deployed to:

```typescript
// Example: supabase/functions/create-user/index.ts:16
const supabaseClient = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',           // Automatically set by Supabase
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '' // Automatically set by Supabase
);
```

**Dev Flavor:**
- Calls dev Supabase edge functions
- Dev functions have dev `SUPABASE_URL` env var
- Dev functions connect to dev database automatically

**Prod Flavor:**
- Calls prod Supabase edge functions
- Prod functions have prod `SUPABASE_URL` env var
- Prod functions connect to prod database automatically

**Edge Functions Deployed:**
- `create-user`, `delete-user`, `sync-all-data`
- `generate-ai-nutrition-plan`, `generate-macros`, `generate-nutrition-plan`
- `carb-loading`, `get-carb-loading-foods`, `get-foods`
- `save-*` functions (activity, calendar, food preferences, etc.)
- `search-active-events`, `search-public-events`
- `send-nutrition-plan-email`, `send-push-notification`
- And more (26 total functions)

**✅ No client-side configuration needed** - functions automatically use correct database based on deployment target.

---

### 🔔 Push Notifications (OneSignal)

**Both Flavors:**
- ✅ Same OneSignal app ID (no separation needed)
- Dev and prod can share push notification infrastructure
- Not critical for dev testing

**Configuration:**
- `.env.dev.local` and `.env.prod.local` have same `ONESIGNAL_APP_ID`
- Value: `335e597f-9862-4fa1-91f9-506d546ef953`

---

### 💬 User Feedback (Wiredash)

**Both Flavors:**
- ✅ Same Wiredash project (no separation needed)
- Dev and prod feedback goes to same project
- Easy to manage all feedback in one place

**Configuration:**
- `.env.dev.local` and `.env.prod.local` have same values:
  - `WIREDASH_PROJECT_ID=mealvana-endurance-vn1pxw3`
  - `WIREDASH_SECRET=wuQrGN_DMojjIopfhEblvMpU53FSChuD`

---

### 🌐 External APIs

**Both Flavors:**
- ✅ Same API keys and endpoints (no separation needed)
- USDA Food API
- Active.com Events API
- TrainingPeaks API
- Final Surge API

**Configuration:**
- All API keys identical in `.env.dev.local` and `.env.prod.local`
- External APIs don't differentiate between dev and prod usage

---

## Configuration Files

### .env.dev.local
```bash
APP_ENVIRONMENT=dev

SUPABASE_URL=https://vlmtsdzpnjnavdgytcmi.supabase.co
SUPABASE_ANON_KEY=eyJ...35o

MIXPANEL_PROJECT_TOKEN=df6e8dd4f3dc1363fa194a156298b16c  # Not used (analytics disabled)

SENTRY_DSN=https://40b0481418b8542bded2a45a63fa0c37@o4509882392969216.ingest.us.sentry.io/4510121638166528
SENTRY_ENVIRONMENT=development

# ... other shared configs
```

### .env.prod.local
```bash
APP_ENVIRONMENT=prod

SUPABASE_URL=https://wvmvsodrvbkxfydabqed.supabase.co
SUPABASE_ANON_KEY=eyJ...APCk

MIXPANEL_PROJECT_TOKEN=bd8fe50bb67b1dd0860351e6297347db  # Used for tracking

SENTRY_DSN=https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328
SENTRY_ENVIRONMENT=production

# ... other shared configs
```

---

## Entry Points

### lib/main_dev.dart
- Loads `.env.dev.local`
- Initializes with dev Sentry DSN
- `AppConfig.fromEnv()` reads `APP_ENVIRONMENT=dev`
- `config.devModeEnabled = true`
- Analytics disabled automatically

### lib/main_prod.dart
- Loads `.env.prod.local`
- Initializes with prod Sentry DSN
- `AppConfig.fromEnv()` reads `APP_ENVIRONMENT=prod`
- `config.devModeEnabled = false`
- Analytics enabled automatically

### lib/main.dart (Fallback)
- **DO NOT USE** - fallback only
- Loads `.env.prod.local` by default (safe default)
- Comments direct developers to use `main_dev.dart` or `main_prod.dart`

---

## How Environment Detection Works

### AppConfig Service

```dart
// lib/shared/services/app_config.dart:64
factory AppConfig.fromEnv() {
  // Read environment from .env file (should be 'dev' or 'prod')
  final appEnv = dotenv.get('APP_ENVIRONMENT', fallback: 'prod');
  final isDevMode = appEnv == 'dev';

  return AppConfig(
    devModeEnabled: isDevMode,
    appEnvironment: appEnv,
    supabaseUrl: dotenv.get('SUPABASE_URL', fallback: ''),
    // ... other configs
  );
}
```

### Service Behavior Based on Environment

**Analytics Tracker:**
```dart
// Checks config.devModeEnabled
if (config.devModeEnabled) {
  return const NoopAnalyticsTracker(); // No tracking in dev
}
return MixpanelAnalyticsTracker(config: config, logger: logger);
```

**Sentry Reporter:**
```dart
// Initialized in main_dev.dart or main_prod.dart
await SentryFlutter.init((options) {
  options.dsn = config.sentryDsn; // Different DSN per environment
  options.environment = config.sentryEnvironment; // 'development' or 'production'
});
```

**Supabase Client:**
```dart
// Initialized in main_dev.dart or main_prod.dart
await Supabase.initialize(
  url: config.supabaseUrl, // Different URL per environment
  anonKey: config.supabaseAnonKey,
);
```

---

## Running Flavors

### Command Line

```bash
# Development
flutter run --flavor dev -t lib/main_dev.dart

# Production
flutter run --flavor prod -t lib/main_prod.dart
```

### VS Code

1. Open Run & Debug panel (⇧⌘D)
2. Select flavor from dropdown:
   - "Dev Flavor"
   - "Prod Flavor"
   - "Dev Flavor (Profile Mode)"
   - "Prod Flavor (Profile Mode)"
   - "Dev Flavor (Release Mode)"
   - "Prod Flavor (Release Mode)"
3. Press F5

Configuration: `.vscode/launch.json`

---

## Visual Indicators

### Dev Flavor
- App name: "Endurance Dev"
- Bundle ID: `com.mealvana.endurance.dev` (iOS) / `com.milkman.mealvanaendurance.dev` (Android)
- Environment indicator: ✅ Amber wrench icon (top-right corner)
- Icon: Same as prod (no visual distinction on home screen)

### Prod Flavor
- App name: "Endurance"
- Bundle ID: `com.mealvana.endurance` (iOS) / `com.milkman.mealvanaendurance` (Android)
- Environment indicator: ❌ None (clean interface)
- Icon: Same as dev

---

## Testing Checklist

When testing flavors, verify:

### Dev Flavor
- [ ] App name shows "Endurance Dev"
- [ ] Amber wrench icon visible (top-right)
- [ ] ❌ No Mixpanel events tracked (check Mixpanel dashboard - should be empty)
- [ ] ✅ Sentry errors go to "mealvana-endurance-dev" project
- [ ] ✅ Supabase calls go to dev project (vlmtsdzpnjnavdgytcmi)
- [ ] ✅ Edge functions use dev database
- [ ] ✅ Can install side-by-side with prod flavor

### Prod Flavor
- [ ] App name shows "Endurance"
- [ ] No environment indicator (clean UI)
- [ ] ✅ Mixpanel events tracked (check prod Mixpanel dashboard)
- [ ] ✅ Sentry errors go to "mealvana-endurance" project
- [ ] ✅ Supabase calls go to prod project (wvmvsodrvbkxfydabqed)
- [ ] ✅ Edge functions use prod database
- [ ] ✅ Can install side-by-side with prod flavor

---

## Troubleshooting

### "Analytics still tracking in dev"
- Check `AppConfig.devModeEnabled` is true
- Verify `APP_ENVIRONMENT=dev` in `.env.dev.local`
- Check `analyticsTrackerProvider` returns `NoopAnalyticsTracker`

### "Errors going to wrong Sentry project"
- Check `.env.dev.local` has dev DSN (ending in ...6528)
- Check `.env.prod.local` has prod DSN (ending in ...3328)
- Verify main_dev.dart loads `.env.dev.local`

### "Edge function using wrong database"
- Edge functions automatically use correct DB based on deployment
- Verify you deployed functions to correct Supabase project
- Check Supabase dashboard shows functions in correct project

### "Can't install both flavors"
- Verify bundle IDs are different (dev has `.dev` suffix)
- Check Xcode configuration (different bundle IDs per flavor)
- Android: Check `applicationIdSuffix = ".dev"` in build.gradle.kts

---

## Summary Table

| Service | Dev Flavor | Prod Flavor | Notes |
|---------|------------|-------------|-------|
| **Analytics** | ❌ Disabled | ✅ Enabled | NoopAnalyticsTracker vs MixpanelAnalyticsTracker |
| **Sentry** | ✅ Dev project (DSN ...6528) | ✅ Prod project (DSN ...3328) | Separate projects for isolation |
| **Supabase** | ✅ Dev project (vlmts...) | ✅ Prod project (wvmvs...) | Different databases |
| **Edge Functions** | ✅ Dev deployment | ✅ Prod deployment | Auto-connect to respective DB |
| **OneSignal** | ✅ Same app ID | ✅ Same app ID | Shared push infrastructure |
| **Wiredash** | ✅ Same project | ✅ Same project | Shared feedback |
| **External APIs** | ✅ Same keys | ✅ Same keys | No separation needed |
| **Local DB** | ✅ Separate SQLite file | ✅ Separate SQLite file | Different bundle IDs = different files |

---

## Documentation References

- **Flavors Setup**: `/docs/flavors/README.md`
- **Usage Guide**: `/docs/flavors/USAGE.md`
- **iOS Xcode Setup**: `/docs/flavors/XCODE_SETUP_INSTRUCTIONS.md`
- **Implementation Complete**: `/docs/flavors/IMPLEMENTATION_COMPLETE.md`
- **Andrea Bizzotto Guidance**: `/docs/flavors/andrea_bizzotto_guidance.md`

---

## Questions?

All environment-specific behavior is now properly configured! The only remaining step is completing the Xcode setup for iOS builds.
