# CI/CD Troubleshooting Guide

Common issues and solutions for Mealvana Endurance CI/CD pipelines.

## Configuration Conflict (Current Issue)

### Problem

The Codemagic Workflow Editor shows **Shorebird Release** mode, but the `codemagic.yaml` file contains standard Flutter build commands without Shorebird integration.

**Symptoms:**
- Builds may fail with Shorebird-related errors
- iOS builds don't produce OTA-capable releases
- Confusion about which configuration is active

### Root Cause

Codemagic has two configuration modes:
1. **Workflow Editor** (UI-based) - Currently set to Shorebird
2. **codemagic.yaml** (file-based) - Standard Flutter builds

When `codemagic.yaml` exists in the repository, it typically takes precedence.

### Solution Options

#### Option A: Full YAML with Shorebird (Recommended)

Update `codemagic.yaml` to include Shorebird commands:

```yaml
workflows:
  ios-shorebird-release:
    name: iOS Shorebird Release
    instance_type: mac_mini_m2
    max_build_duration: 120

    integrations:
      app_store_connect: Mealvana

    environment:
      flutter: stable
      xcode: latest
      cocoapods: default
      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.mealvana.endurance
      groups:
        - supabase_prod
        - shorebird_credentials  # Add this group
        - app_store_credentials
      vars:
        FLUTTER_ENV: prod

    triggering:
      events:
        - push
      branch_patterns:
        - pattern: 'main'
          include: true
        - pattern: 'release/*'
          include: true

    scripts:
      - name: Get Flutter dependencies
        script: flutter pub get

      - name: Run code generation
        script: dart run build_runner build --delete-conflicting-outputs

      - name: Run unit tests
        script: flutter test

      - name: Install Shorebird
        script: |
          curl -fsSL https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash
          export PATH="$HOME/.shorebird/bin:$PATH"
          echo "PATH=$HOME/.shorebird/bin:$PATH" >> $CM_ENV

      - name: Install CocoaPods
        script: cd ios && pod install

      - name: Set up code signing
        script: |
          xcode-project use-profiles --custom-export-options='{"manageAppVersionAndBuildNumber":false}'

      - name: Build with Shorebird
        script: |
          shorebird release ios \
            --flutter-version=stable \
            --export-options-plist=/Users/builder/export_options.plist

    artifacts:
      - build/ios/ipa/*.ipa
      - /tmp/xcodebuild_logs/*.log

    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
        submit_to_app_store: false
      slack:
        channel: '#builds'
        notify:
          success: true
          failure: true
```

**Required Setup:**

1. **Generate Shorebird Token:**
   ```bash
   shorebird login:ci
   # Copy the token output
   ```

2. **Add to Codemagic:**
   - Go to Team Settings → Global Variables and Secrets
   - Create group: `shorebird_credentials`
   - Add variable: `SHOREBIRD_TOKEN` (mark as Secret)

#### Option B: Use Workflow Editor Only

1. Delete `codemagic.yaml` from repository
2. Configure entirely via Codemagic UI
3. Shorebird integration handled automatically

**Tradeoff:** Lose the sophisticated 5-workflow setup.

#### Option C: Disable Shorebird in Workflow Editor

1. In Codemagic UI, set "Publish updates to user devices using Shorebird" to **Disabled**
2. Keep `codemagic.yaml` as-is for standard builds
3. Add Shorebird manually later when ready

---

## Codemagic Issues

### Missing Environment Variables

**Error:** `SUPABASE_URL not found` or similar

**Solution:**
1. Verify group exists in Codemagic → Settings → Environment variables
2. Check group name matches exactly (case-sensitive)
3. Ensure workflow has group in `environment.groups`
4. Mark secrets as "Secure"

### iOS Code Signing Fails

**Error:** `No signing certificate found` or `Provisioning profile not found`

**Solutions:**

1. **Check App Store Connect Integration:**
   - Settings → Integrations → Developer Portal
   - Verify API key name matches `integrations.app_store_connect` in YAML
   - Ensure API key has **App Manager** role (not Developer)

2. **Check Bundle ID:**
   ```yaml
   ios_signing:
     bundle_identifier: com.mealvana.endurance  # Must match exactly
   ```

3. **Regenerate Certificates:**
   - In App Store Connect, revoke and recreate if expired
   - Re-upload to Codemagic

### Shorebird Build Fails

**Error:** `manageAppVersionAndBuildNumber must be false`

**Fix:** Add this script after code signing:
```yaml
- name: Fix export_options.plist
  script: |
    /usr/libexec/PlistBuddy -c 'Add :manageAppVersionAndBuildNumber bool false' /Users/builder/export_options.plist
```

**Error:** `SHOREBIRD_TOKEN not set`

**Fix:**
1. Generate token: `shorebird login:ci`
2. Add to Codemagic as encrypted variable
3. Add `shorebird_credentials` group to workflow

### Simulator Boot Fails

**Error:** `Unable to boot simulator`

**Fix:**
```yaml
- name: Boot iOS Simulator
  script: |
    xcrun simctl shutdown all || true
    sleep 5  # Add delay
    RUNTIME=$(xcrun simctl list runtimes | grep -oE 'com.apple.CoreSimulator.SimRuntime.iOS-[0-9]+-[0-9]+' | tail -1)
    TEST_DEVICE=$(xcrun simctl create "Test iPhone" "iPhone 15 Pro" "$RUNTIME")
    xcrun simctl boot "$TEST_DEVICE"
    sleep 30  # Increase wait time
```

### Build Timeout

**Error:** `Build exceeded max duration`

**Fix:**
```yaml
max_build_duration: 120  # Increase from 60
```

Or optimize by:
- Using `cancel_previous_builds: true`
- Running tests in parallel
- Caching dependencies

---

## GitHub Actions Issues

### Supabase CLI Authentication

**Error:** `Not logged in`

**Fix:**
1. Regenerate access token: `supabase login`
2. Update GitHub secret: `SUPABASE_ACCESS_TOKEN`

### Database Connection Timeout

**Error:** `Connection to database timed out`

**Causes:**
- Supabase project paused (free tier)
- Wrong project ID

**Fix:**
1. Wake up project in Supabase dashboard
2. Verify `PROJECT_ID` matches dashboard

### Edge Function Deploy Fails

**Error:** `Function not found` or syntax errors

**Fix:**
1. Test locally: `supabase functions serve`
2. Check TypeScript syntax
3. Verify all imports are valid Deno URLs

### Schema Drift False Positive

**Error:** Drift detected but no actual changes

**Cause:** Comments or formatting differences

**Fix:**
1. Pull latest: `supabase db pull`
2. Regenerate snapshot: `dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v1/`
3. Commit normalized files

---

## Verification Commands

### Local Verification Before CI

```bash
# Flutter checks
flutter analyze
dart format --set-exit-if-changed lib test
flutter test

# Code generation
dart run build_runner build --delete-conflicting-outputs

# Supabase checks
supabase db diff --schema public
supabase functions serve  # Test edge functions locally
```

### Check Codemagic Configuration

```bash
# Validate YAML syntax
yq e '.' codemagic.yaml > /dev/null && echo "YAML valid"

# Check Shorebird setup
shorebird doctor
```

### Check GitHub Actions

```bash
# Validate workflow syntax
gh workflow list
gh run list --workflow=test.yml
```

---

## Environment Variable Reference

### Codemagic Variables (Current Config)

| Variable | Group | Purpose | Status |
|----------|-------|---------|--------|
| `SUPABASE_URL` | supabase_prod | Backend URL | Correct |
| `SUPABASE_ANON_KEY` | supabase_prod | Anonymous key | Correct |
| `SUPABASE_SERVICE_ROLE_KEY` | supabase_prod | Admin access | Correct |
| `SHOREBIRD_TOKEN` | shorebird_credentials | OTA auth | **MISSING** |
| `SUPABASE_SECRET_KEY` | (root) | Unknown | **Check format** |
| `SUPABASE_PUBLISHABLE_KEY` | (root) | Unknown | **Check format** |

### Suspicious Variables

From your Workflow Editor screenshot:

```
SUPABASE_SECRET_KEY = sb_secret_oe8R0c...
SUPABASE_PUBLISHABLE_KEY = sb_publishable_vE...
```

These look like **Stripe** key format, not Supabase. Verify these are needed or remove them.

---

## Getting Help

1. **Codemagic Support:** support@codemagic.io
2. **Shorebird Discord:** https://discord.gg/shorebird
3. **GitHub Actions Docs:** https://docs.github.com/en/actions
4. **Supabase Discord:** https://discord.supabase.com
