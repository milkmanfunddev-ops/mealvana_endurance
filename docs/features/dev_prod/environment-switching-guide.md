# Environment Switching Guide

## Overview

Mealvana Endurance supports switching between development and production environments using a simple code flag and optional runtime toggle. This allows you to control which Mixpanel project, Sentry environment, and Supabase backend the app connects to.

## Quick Start

### For Production Builds

1. Open `/lib/shared/services/app_config.dart`
2. Find line 49: `static const bool _DEFAULT_DEV_MODE = true;`
3. Change to: `static const bool _DEFAULT_DEV_MODE = false;`
4. Build and deploy

**That's it!** The app will now use production credentials for everything.

### For Development Builds

The default is already set to development mode (`true`), so no changes needed.

## Environment Configuration

When `_DEFAULT_DEV_MODE = true` (Development):
- **Mixpanel**: Mealvana Endurance Dev (`df6e8dd4f3dc1363fa194a156298b16c`)
- **Sentry**: `development` environment
- **Supabase**: Dev project (`vlmtsdzpnjnavdgytcmi`)

When `_DEFAULT_DEV_MODE = false` (Production):
- **Mixpanel**: Mealvana Endurance (`bd8fe50bb67b1dd0860351e6297347db`)
- **Sentry**: `production` environment
- **Supabase**: Production project (`wvmvsodrvbkxfydabqed`)

## Secret Environment Panel

### Accessing the Panel

1. Open the app
2. Navigate to **Settings** screen
3. **Long-press** on the "Settings" title text in the app bar
4. Environment switcher dialog will appear

### Using the Panel

The dialog shows:
- Current environment mode (Development / Production)
- Current Mixpanel project
- Current Sentry environment
- Current Supabase project

You can:
- Switch to Production (if currently in dev)
- Switch to Development (if currently in prod)
- Cancel to keep current setting

**Important**: After switching, the app will prompt you to force-quit and restart for changes to take effect.

## Visual Indicator

When in development mode, a wrench icon (🔧) appears in the top-right corner of screens.

To add the indicator to a screen:
```dart
import '../../../../shared/widgets/environment_indicator.dart';

return ScreenWithEnvironmentIndicator(
  child: YourScreenContent(),
);
```

Or use the standalone widget:
```dart
Stack(
  children: [
    YourContent(),
    const EnvironmentIndicator(),
  ],
)
```

## How It Works

### Compile-Time Flag

The `_DEFAULT_DEV_MODE` constant in `app_config.dart` determines the default environment at compile time.

### Runtime Override

The secret panel allows runtime override via `SharedPreferences`:
- Override persists across app restarts
- Takes precedence over `_DEFAULT_DEV_MODE`
- Requires app restart to take effect (analytics/Sentry need reinitializing)

### Priority Order

1. Runtime override (if set via secret panel)
2. `_DEFAULT_DEV_MODE` constant (fallback)

Clear the runtime override to revert to default:
```dart
await AppConfig.clearDevModeOverride();
```

## Development Workflow

### Internal Testing

1. Keep `_DEFAULT_DEV_MODE = true` in code
2. Build and install on test devices
3. All analytics go to "Mealvana Endurance Dev" Mixpanel project

### Production Release

1. Change `_DEFAULT_DEV_MODE = false`
2. Commit and push
3. Build release: `flutter build ipa --release`
4. Submit to App Store
5. All analytics go to "Mealvana Endurance" production Mixpanel project

### QA Testing Both Modes

1. Install dev build (with `_DEFAULT_DEV_MODE = true`)
2. Use secret panel to switch to production mode
3. Force-quit and restart
4. Test production environment
5. Use secret panel to switch back to dev
6. Force-quit and restart

## Code Reference

### Key Files

- **AppConfig**: `/lib/shared/services/app_config.dart`
  - Main configuration class
  - `_DEFAULT_DEV_MODE` flag (line 49)
  - Runtime override methods

- **Environment Switcher Dialog**: `/lib/shared/widgets/environment_switcher_dialog.dart`
  - Secret panel UI
  - Shows current environment details

- **Environment Indicator**: `/lib/shared/widgets/environment_indicator.dart`
  - Wrench icon widget
  - Only visible in dev mode

- **Settings Screen**: `/lib/features/settings/presentation/screens/settings_screen.dart`
  - Long-press gesture on title (line 35)
  - Triggers environment switcher

### Initialization

In `main.dart`:
```dart
// Load runtime override from SharedPreferences
await AppConfig.loadDevModeOverride();

// Create config (will use override or default)
final config = AppConfig.fromEnv();
```

### Helper Methods

```dart
// Check current mode
if (config.isProduction) { ... }
if (config.isDevelopment) { ... }

// Get environment string
String env = config.appEnvironment; // 'dev' or 'prod'

// Get effective dev mode
bool devMode = AppConfig.effectiveDevMode;
```

## Troubleshooting

### App still using dev after switching to prod

**Cause**: Forgot to force-quit the app after switching.

**Solution**:
1. Force-quit the app completely
2. Restart the app
3. Analytics/Sentry initialize fresh with new credentials

### Runtime override not working

**Cause**: App not restarted, or SharedPreferences not persisted.

**Solution**:
1. Use the "Exit App" button in the restart dialog
2. Manually force-quit and restart
3. If still not working, clear app data and reinstall

### Can't tell which environment I'm in

**Solution**: Use the secret panel to check:
1. Go to Settings
2. Long-press "Settings" title
3. Dialog shows all current environment details

Or look for the wrench icon (only in dev mode).

### Accidentally committed `_DEFAULT_DEV_MODE = true` in a prod release

**Immediate fix**:
1. Change flag to `false`
2. Rebuild and redeploy
3. Users will get corrected version on next update

**Prevention**:
- Add pre-commit hook to check flag value
- Use runtime override for internal testing instead
- Set up CI/CD to enforce `false` on `main` branch

## Best Practices

### ✅ Do

- Use `_DEFAULT_DEV_MODE = true` for all development
- Use `_DEFAULT_DEV_MODE = false` only for production releases
- Use secret panel for QA testing both environments
- Check git diff before committing to ensure flag is correct

### ❌ Don't

- Don't use `.env` file swapping (tokens are hardcoded now)
- Don't change tokens in code (use flag instead)
- Don't rely on build flavors (we intentionally avoided this complexity)
- Don't leave runtime override active in production builds

## Migration from .env Files

Previous setup used `.env` files. Now:

- **Before**: Copy `.env.dev.local` → `.env` or `.env.prod.local` → `.env`
- **After**: Change `_DEFAULT_DEV_MODE` flag

The `.env` files are still loaded but ignored for environment-specific configs. Only used for:
- `USDA_API_KEY` (if needed)
- Future non-environment-specific configs

All Mixpanel/Sentry/Supabase credentials are now in `app_config.dart` based on the flag.

## Security Notes

- Mixpanel tokens are **client-side keys** (safe to hardcode)
- Supabase anon keys are **public keys** (safe to hardcode)
- Sentry DSN is **public** (safe to hardcode)
- Service role keys are **NOT** in the app (only in backend)

The environment flag doesn't expose any secrets, it just selects which public credentials to use.

---

**Last Updated**: 2025-10-17
**Version**: 1.0
**Status**: Active
