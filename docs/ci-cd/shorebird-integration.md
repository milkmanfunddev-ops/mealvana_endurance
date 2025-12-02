# Shorebird Code Push Integration

This document explains how to set up and use Shorebird for over-the-air (OTA) updates with Codemagic CI/CD.

## Overview

Shorebird enables instant Dart code updates without App Store review. Perfect for:
- Bug fixes
- UI text changes (via Content Management System)
- Algorithm parameter tweaks
- Minor feature additions

**Limitations:**
- Cannot update native code (Swift/Kotlin)
- Cannot add new permissions
- Cannot change app version in pubspec.yaml

## Current Status

**Shorebird is initialized** in this project:
- App ID: `16f10ae3-5b24-4e65-81cd-917f904f50d6`
- Config file: `/shorebird.yaml`

**CI/CD Integration: NOT COMPLETE**
- Workflow Editor shows Shorebird enabled
- YAML config missing Shorebird commands
- `SHOREBIRD_TOKEN` not configured

## Setup Steps

### Step 1: Generate CI Token

```bash
# On your local machine
shorebird login:ci

# Output:
# SHOREBIRD_TOKEN=<base64-encoded-token>
# Copy this entire value
```

### Step 2: Add Token to Codemagic

1. Go to Codemagic → Team Settings → Global Variables and Secrets
2. Create a new group: `shorebird_credentials`
3. Add variable:
   - Name: `SHOREBIRD_TOKEN`
   - Value: (paste the token from step 1)
   - Mark as **Secure** (encrypted)

### Step 3: Update codemagic.yaml

Add Shorebird installation and build scripts:

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
        - shorebird_credentials  # Contains SHOREBIRD_TOKEN
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

      - name: Install Shorebird CLI
        script: |
          curl -fsSL https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash
          export PATH="$HOME/.shorebird/bin:$PATH"
          echo "PATH=$HOME/.shorebird/bin:$PATH" >> $CM_ENV
          shorebird doctor

      - name: Install CocoaPods
        script: cd ios && pod install

      - name: Set up code signing
        script: |
          xcode-project use-profiles --custom-export-options='{"manageAppVersionAndBuildNumber":false}'

      - name: Create Shorebird Release
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

  # Separate workflow for patches (OTA only, no App Store)
  ios-shorebird-patch:
    name: iOS Shorebird Patch (OTA)
    instance_type: mac_mini_m2
    max_build_duration: 60

    environment:
      flutter: stable
      xcode: latest
      groups:
        - supabase_prod
        - shorebird_credentials
      vars:
        FLUTTER_ENV: prod
        RELEASE_VERSION: ""  # Set when triggering manually

    scripts:
      - name: Get Flutter dependencies
        script: flutter pub get

      - name: Run code generation
        script: dart run build_runner build --delete-conflicting-outputs

      - name: Install Shorebird CLI
        script: |
          curl -fsSL https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash
          export PATH="$HOME/.shorebird/bin:$PATH"
          echo "PATH=$HOME/.shorebird/bin:$PATH" >> $CM_ENV

      - name: Create Shorebird Patch
        script: |
          if [ -z "$RELEASE_VERSION" ]; then
            # Patch latest release
            shorebird patch ios
          else
            # Patch specific version
            shorebird patch ios --release-version=$RELEASE_VERSION
          fi

    # NO publishing block - patches don't go to App Store
```

## Workflow Decision Guide

| Scenario | Workflow | App Store? |
|----------|----------|------------|
| New version (1.0.0 → 1.1.0) | `ios-shorebird-release` | Yes |
| Bug fix (same version) | `ios-shorebird-patch` | No |
| UI text change | `ios-shorebird-patch` | No |
| Algorithm tweak | `ios-shorebird-patch` | No |
| Native code change | `ios-shorebird-release` | Yes |
| New permission | `ios-shorebird-release` | Yes |

## Critical Configuration: export_options.plist

Shorebird requires `manageAppVersionAndBuildNumber: false` in the export options.

**Why:** Shorebird manages its own versioning for patches. If Xcode auto-increments, patches fail.

**How:**
```yaml
- name: Set up code signing
  script: |
    xcode-project use-profiles --custom-export-options='{"manageAppVersionAndBuildNumber":false}'
```

## Verifying Shorebird Setup

### Local Verification

```bash
# Check Shorebird is working
shorebird doctor

# View releases
shorebird releases list

# View patches for a release
shorebird patches list --release-version=1.0.0
```

### CI Verification

After a successful build:
1. Check Codemagic logs for "Shorebird release created"
2. Run `shorebird releases list` locally to confirm
3. Test OTA update on a device with the old version

## Testing OTA Updates

1. Install release build from TestFlight
2. Make a code change
3. Run patch workflow
4. Restart app on device
5. Verify changes appear (may need to restart twice)

## Rollback Procedure

If a patch causes issues:

```bash
# List patches
shorebird patches list --release-version=1.0.0

# Delete problematic patch
shorebird patches delete --release-version=1.0.0 --patch-number=3
```

Users will automatically get the previous patch on next app restart.

## Cost Considerations

- Shorebird has usage-based pricing
- Each patch upload and download counts toward quota
- Monitor usage at https://console.shorebird.dev

## Troubleshooting

### Error: `SHOREBIRD_TOKEN not set`

```bash
# Generate new token
shorebird login:ci

# Add to Codemagic as encrypted environment variable
```

### Error: `Release not found`

Patches require an existing release with matching version:
```bash
# Check available releases
shorebird releases list

# Ensure RELEASE_VERSION matches an existing release
```

### Error: `manageAppVersionAndBuildNumber`

Ensure export options are set correctly:
```yaml
xcode-project use-profiles --custom-export-options='{"manageAppVersionAndBuildNumber":false}'
```

### Error: `Flutter version mismatch`

Patch must use same Flutter version as release:
```bash
# Check release Flutter version
shorebird releases list

# Specify in patch command
shorebird patch ios --flutter-version=3.24.0
```

## References

- [Shorebird Documentation](https://docs.shorebird.dev)
- [Shorebird + Codemagic Guide](https://blog.codemagic.io/how-to-set-up-flutter-code-push-with-shorebird-and-codemagic-cicd/)
- [Codemagic Shorebird Docs](https://docs.codemagic.io/flutter-publishing/shorebird/)
- [Project Shorebird Config](/shorebird.yaml)
- [Shorebird Code Push Overview](/docs/technical/shorebird-code-push.md)
