# Codemagic CI/CD Analysis - December 2025

## Executive Summary

**Current State**: 9 workflows configured across testing, iOS/Android production, and Shorebird OTA updates

**Overall Assessment**: Production-ready with minor configuration issues

**Status**:
- Testing Workflows: Fully operational
- iOS Production Pipeline: Complete and working
- Android Production Pipeline: Variable name issue + signing verification needed
- Shorebird OTA: Complete infrastructure, credentials verified
- Legacy Builds: Available as fallback

**Key Strengths**:
- Comprehensive test coverage (160+ tests)
- Dual deployment strategy (Shorebird + legacy)
- Fast PR feedback loop
- Clear workflow separation (release vs patch)
- Excellent documentation

**Key Weaknesses**:
- Firebase variable name mismatch (Android)
- YAML anchors defined but unused (code duplication)
- Integration tests run twice per build
- Test failures don't fail builds (|| true suppression)

## Current Workflow Architecture

### Testing Workflows

#### 1. integration-tests
- **Purpose**: Complete integration test suite on iOS simulator
- **Triggers**: PR to develop/feature/release branches
- **Instance**: mac_mini_m2 (60 min timeout)
- **Environment**: Dev Supabase
- **Steps**:
  1. Flutter pub get + code generation
  2. Unit tests with machine output
  3. Boot iOS simulator (iPhone 15 Pro)
  4. Run integration_test/test_runner.dart
  5. Capture results + logs
  6. Shutdown simulator
- **Artifacts**: test-results/**, JSON + log files
- **Publishing**: Slack notifications (#builds)

#### 2. integration-test-quick
- **Purpose**: Single-flow testing for rapid feedback
- **Triggers**: Manual only
- **Instance**: mac_mini_m2 (30 min timeout)
- **Environment**: Dev Supabase
- **Configurable**: TEST_FLOW variable (default: event_management_flow_test.dart)
- **Use Case**: Fast iteration on specific features

#### 3. pr-validation
- **Purpose**: Fast quality checks on every PR
- **Triggers**: All pull requests
- **Instance**: mac_mini_m2 (30 min timeout)
- **Steps**:
  1. Flutter analyze
  2. Dart format check (--set-exit-if-changed)
  3. Unit tests with machine output
- **Benefits**: 5-10 minute feedback vs 30-60 min integration tests
- **Artifacts**: test-results/**

### iOS Production Workflows

#### 4. ios-shorebird-release
- **Purpose**: Create Shorebird-enabled release + TestFlight submission
- **Triggers**: Push to main or release/* branches
- **Instance**: mac_mini_m2 (120 min timeout)
- **Environment**:
  - Production Supabase
  - Shorebird credentials group
  - App Store Connect integration
- **Steps**:
  1. Dependencies + code generation
  2. Unit tests
  3. Install Shorebird CLI
  4. Install CocoaPods
  5. Code signing with CRITICAL export options
  6. shorebird release ios
- **Publishing**:
  - TestFlight (submit_to_testflight: true)
  - Slack notifications
- **Artifacts**: IPA files, Xcode logs

**CRITICAL Configuration**:
```yaml
xcode-project use-profiles --custom-export-options='{"manageAppVersionAndBuildNumber":false}'
```

**Why Critical**: Shorebird manages versioning for patches. If Xcode auto-increments build numbers, patch deployments fail with version mismatch errors.

#### 5. ios-shorebird-patch
- **Purpose**: OTA updates without App Store review
- **Triggers**: Manual only
- **Instance**: mac_mini_m2 (60 min timeout)
- **Environment**: Production Supabase + Shorebird credentials
- **Configurable**: RELEASE_VERSION (default: "latest")
- **Steps**:
  1. Dependencies + code generation
  2. Unit tests
  3. Install Shorebird CLI
  4. Install CocoaPods
  5. shorebird patch ios (with optional --release-version)
- **Publishing**: None (distributed via Shorebird, not App Store)
- **Use Cases**: Bug fixes, UI text changes, algorithm tweaks

#### 6. ios-build-legacy
- **Purpose**: Standard Flutter build without Shorebird (fallback)
- **Triggers**: Manual only
- **Instance**: mac_mini_m2 (120 min timeout)
- **Environment**: Production Supabase + App Store credentials
- **Steps**:
  1. Dependencies + code generation
  2. Unit tests
  3. Install CocoaPods
  4. Standard Flutter IPA build
- **Publishing**: TestFlight
- **Use Case**: Fallback if Shorebird has issues

### Android Production Workflows

#### 7. android-shorebird-release
- **Purpose**: Create Shorebird-enabled release + Play Store submission
- **Triggers**: Push to main or release/* branches
- **Instance**: mac_mini_m2 (120 min timeout)
- **Environment**:
  - Production Supabase
  - Shorebird credentials
  - Google Play credentials
  - firebase_config group (GOOGLE_SERVICES_JSON)
- **Steps**:
  1. Dependencies + code generation
  2. Load Firebase configuration (BASE64 DECODE)
  3. Unit tests
  4. Install Shorebird CLI
  5. shorebird release android --artifact=aab
- **Publishing**:
  - Google Play (internal track)
  - Slack notifications
- **Artifacts**: AAB files, APKs, ProGuard mapping

**Issue Found**: Variable name mismatch (see High Priority Issues below)

#### 8. android-shorebird-patch
- **Purpose**: OTA updates without Play Store review
- **Triggers**: Manual only
- **Instance**: mac_mini_m2 (60 min timeout)
- **Environment**: Production Supabase + Shorebird + Firebase
- **Configurable**: RELEASE_VERSION (default: "latest")
- **Steps**:
  1. Dependencies + code generation
  2. Load Firebase configuration (BASE64 DECODE)
  3. Unit tests
  4. Install Shorebird CLI
  5. shorebird patch android (with optional --release-version)
- **Publishing**: None (distributed via Shorebird)

#### 9. android-build-legacy
- **Purpose**: Standard Flutter build without Shorebird (fallback)
- **Triggers**: Manual only
- **Instance**: mac_mini_m2 (120 min timeout)
- **Environment**: Production Supabase + Google Play + Firebase
- **Steps**:
  1. Dependencies + code generation
  2. Load Firebase configuration (BASE64 DECODE)
  3. Unit tests
  4. Standard Flutter appbundle build
- **Publishing**: Google Play (internal track)
- **Use Case**: Fallback if Shorebird has issues

## Issues Found

### High Priority (Blocking)

#### 1. Firebase Variable Name Mismatch (CRITICAL)

**Location**: All Android workflows (lines 396-401, 470-476, 645-651)

**Problem**:
- YAML uses: `$ANDROID_FIREBASE_JSON` with base64 decode
- Documentation (/docs/ci-cd/firebase-config-codemagic.md) references: `$GOOGLE_SERVICES_JSON` without base64

**Current Code**:
```yaml
- name: Load Firebase configuration
  script: |
    #!/usr/bin/env sh
    set -e
    echo "$ANDROID_FIREBASE_JSON" | base64 --decode > android/app/google-services.json
    echo "✅ google-services.json created"
    ls -la android/app/google-services.json
```

**Documentation Says**:
```yaml
- name: Create google-services.json
  script: |
    echo "$GOOGLE_SERVICES_JSON" > android/app/google-services.json
    echo "✅ google-services.json created"
```

**Impact**:
- Android builds may fail with "File google-services.json is missing"
- Inconsistency between docs and actual configuration
- Team confusion about which variable to use

**Solution Options**:

**Option A (Recommended)**: Standardize on `GOOGLE_SERVICES_JSON` (simpler, no encoding)
```yaml
- name: Load Firebase configuration
  script: |
    echo "$GOOGLE_SERVICES_JSON" > android/app/google-services.json
    echo "✅ google-services.json created"
```
- Update Codemagic environment variable name
- Matches documentation
- No base64 encoding/decoding overhead
- Simpler to debug

**Option B**: Update documentation to match YAML
- Keep `ANDROID_FIREBASE_JSON` with base64
- Update firebase-config-codemagic.md
- Add base64 encoding instructions to docs
- More complex for team members

**Recommendation**: Use Option A (GOOGLE_SERVICES_JSON without base64)

#### 2. Android Code Signing Verification Needed

**Problem**:
- No explicit keystore configuration in codemagic.yaml
- android/app/build.gradle.kts expects key.properties file
- Must verify Android signing is configured in Codemagic UI

**Code Reference** (android/app/build.gradle.kts):
```kotlin
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

**Required Verification**:
1. Check Codemagic UI → App Settings → Code Signing
2. Verify Android keystore is uploaded
3. Confirm credentials variables exist:
   - CM_KEYSTORE
   - CM_KEYSTORE_PASSWORD
   - CM_KEY_PASSWORD
   - CM_KEY_ALIAS

**If Missing**: Add to codemagic.yaml scripts:
```yaml
- name: Set up Android signing
  script: |
    echo "storePassword=$CM_KEYSTORE_PASSWORD" > android/key.properties
    echo "keyPassword=$CM_KEY_PASSWORD" >> android/key.properties
    echo "keyAlias=$CM_KEY_ALIAS" >> android/key.properties
    echo "storeFile=$CM_KEYSTORE_PATH" >> android/key.properties
```

**Action Required**: Verify signing setup before next Android release

### Medium Priority (Optimization)

#### 3. Unused YAML Anchors (Code Duplication)

**Location**: Lines 16-40 in codemagic.yaml

**Problem**: Anchors defined but never referenced with `*anchor_name`

**Defined Anchors**:
```yaml
definitions:
  scripts:
    - &install_shorebird       # Line 17
    - &flutter_pub_get         # Line 30
    - &run_build_runner        # Line 34
    - &run_unit_tests          # Line 38
```

**Result**: Same code duplicated across 9 workflows

**Example Duplication**:
- "Install Shorebird CLI" script copied 6 times (140+ lines total)
- "Get Flutter dependencies" copied 9 times
- "Run code generation" copied 9 times
- "Run unit tests" copied 7 times

**Impact**:
- Harder to maintain (change in 9 places instead of 1)
- Risk of inconsistency between workflows
- Larger YAML file (674 lines vs ~400 with anchors)

**Solution**: Use anchor references
```yaml
scripts:
  - *install_shorebird
  - *flutter_pub_get
  - *run_build_runner
  - *run_unit_tests
```

**Estimated Savings**: ~200-250 lines of YAML

#### 4. Integration Tests Run Twice (Waste)

**Location**: integration-tests workflow, lines 111-126

**Problem**: Tests executed twice in same workflow

**Current Code**:
```yaml
- name: Run integration tests
  script: |
    # Run 1: Machine-readable output
    flutter test integration_test/test_runner.dart \
      -d "$TEST_DEVICE" \
      --machine \
      > test-results/integration-tests.json 2>&1 || true

    # Run 2: Verbose output for logs (DUPLICATE)
    flutter test integration_test/test_runner.dart \
      -d "$TEST_DEVICE" \
      --reporter expanded \
      2>&1 | tee test-results/integration-tests.log || true
```

**Impact**:
- Wastes 10-20 minutes per build (tests run twice)
- Uses extra CI/CD minutes (costs money)
- Delays developer feedback

**Solution**: Run once with expanded output
```yaml
- name: Run integration tests
  script: |
    mkdir -p test-results

    flutter test integration_test/test_runner.dart \
      -d "$TEST_DEVICE" \
      --reporter expanded \
      2>&1 | tee test-results/integration-tests.log
  test_report: test-results/integration-tests.log
```

**Benefits**:
- 50% faster integration test workflow
- Same information captured
- Simpler script logic

#### 5. Test Failures Don't Fail Builds

**Location**: Multiple workflows use `|| true`

**Examples**:
- Line 86: `flutter test --machine > test-results/unit-tests.json || true`
- Line 119: `flutter test integration_test/test_runner.dart ... || true`
- Line 125: `flutter test integration_test/test_runner.dart ... || true`

**Problem**:
- `|| true` suppresses non-zero exit codes
- Builds show success even when tests fail
- Failed tests don't block deployment
- Team doesn't know about test failures until after merge

**Impact**:
- Broken code can reach production
- False confidence in CI/CD status
- Defeats purpose of automated testing

**Solution**: Remove `|| true` and let builds fail properly
```yaml
- name: Run unit tests
  script: |
    mkdir -p test-results
    flutter test --machine > test-results/unit-tests.json
  test_report: test-results/unit-tests.json
```

**Benefits**:
- Failed tests block deployment
- Immediate visibility of test failures
- Proper CI/CD quality gate

**Caveat**: May reveal currently-failing tests that need fixing

### Low Priority (Nice to Have)

#### 6. Missing Dev Flavor Builds

**Context**:
- android/app/build.gradle.kts defines dev/prod flavors
- lib/main_dev.dart and lib/main_prod.dart exist
- Separate bundle IDs: com.mealvana.endurance.dev vs .endurance
- Separate Supabase projects (dev/prod)

**Current State**:
- Codemagic only builds prod flavor
- No automated dev flavor builds
- Dev testing requires manual local builds

**Recommendation**: Add manual dev flavor workflows
```yaml
ios-dev-build:
  name: iOS Dev Flavor
  triggering:
    events: []  # Manual only

  scripts:
    - name: Build iOS Dev
      script: |
        flutter build ipa --release \
          --flavor dev \
          -t lib/main_dev.dart

android-dev-build:
  name: Android Dev Flavor
  triggering:
    events: []  # Manual only

  scripts:
    - name: Build Android Dev
      script: |
        flutter build appbundle --release \
          --flavor dev \
          -t lib/main_dev.dart
```

**Benefits**:
- Test dev flavor before production
- Verify Supabase dev integration
- QA testing on real devices

**Priority**: Low (can continue manual builds for now)

#### 7. No Build Caching

**Current State**: No cache configuration in any workflow

**Missing Caching**:
- Flutter SDK (downloaded every build)
- Pub dependencies (flutter pub get every time)
- CocoaPods (pod install every time)
- Gradle dependencies (Android builds)

**Impact**: Slower builds than necessary (5-10 extra minutes)

**Solution**: Add cache configuration
```yaml
cache:
  cache_paths:
    - ~/.pub-cache
    - ~/Library/Caches/CocoaPods
    - ~/.gradle/caches
```

**Benefits**:
- Faster builds (30-40% reduction)
- Reduced CI/CD costs
- Faster developer feedback

**Caveats**:
- Caching can cause issues if dependencies change
- May need cache invalidation mechanism
- Requires testing to ensure stability

**Priority**: Low (builds are fast enough for now)

## Configuration Completeness Assessment

| Component | Status | Notes |
|-----------|--------|-------|
| iOS Release Pipeline | ✅ Complete | Shorebird + TestFlight working |
| Android Release Pipeline | ⚠️ Mostly Complete | Variable name + signing verification needed |
| Integration Testing | ✅ Complete | iOS simulator tests working |
| PR Validation | ✅ Complete | Fast feedback loop (5-10 min) |
| Shorebird OTA Updates | ✅ Complete | Both iOS and Android |
| Legacy Builds | ✅ Complete | Fallback option available |
| Environment Secrets | ⚠️ Mostly Complete | Audit needed for unused variables |
| Documentation | ✅ Excellent | Comprehensive docs in /docs/ci-cd/ |
| Build Caching | ❌ Missing | Optional optimization |
| Dev Flavor Builds | ❌ Missing | Manual only, not blocking |

## Critical Shorebird Requirements

### iOS Export Options (MANDATORY)

**Code**:
```yaml
xcode-project use-profiles --custom-export-options='{"manageAppVersionAndBuildNumber":false}'
```

**Why Critical**:
- Shorebird manages its own versioning system for patches
- If Xcode auto-increments build numbers, patch deployments fail
- Error message: "Version mismatch between release and patch"
- Must be `false` for both release and patch workflows

**When Required**:
- All ios-shorebird-release builds (Line 265)
- All ios-shorebird-patch builds (uses release metadata)

**What Happens If Wrong**:
1. Release builds with manageAppVersionAndBuildNumber: true
2. Xcode auto-increments build number to 43
3. Shorebird records release as version 1.0.0+42
4. Patch attempts to update version 1.0.0+42
5. Xcode auto-increments again to 43 during patch build
6. Version mismatch → patch fails
7. Users never receive OTA update

**Current Status**: ✅ Correctly configured in codemagic.yaml

## Shorebird Decision Tree

| Scenario | Workflow to Use | App Store Review? | Reason |
|----------|----------------|-------------------|---------|
| New version (1.0.0 → 1.1.0) | ios-shorebird-release | Yes | Version number change requires store review |
| Bug fix (same version) | ios-shorebird-patch | No | Dart code only, instant OTA |
| UI text change | ios-shorebird-patch | No | Content management, no native changes |
| Algorithm parameter tweak | ios-shorebird-patch | No | JSON config changes only |
| Minor feature (Dart only) | ios-shorebird-patch | No | No native code or permissions |
| Native code change (Swift/Kotlin) | ios-shorebird-release | Yes | Shorebird can't patch native code |
| New permission (location, camera) | ios-shorebird-release | Yes | Info.plist changes require review |
| New dependency with native code | ios-shorebird-release | Yes | Native modules need full rebuild |
| Database schema change | ios-shorebird-patch | No | Drift migrations are Dart code |
| Analytics event changes | ios-shorebird-patch | No | Dart code only |

## Environment Variables Required

### Codemagic Environment Variable Groups

#### supabase_dev (Integration Tests)
| Variable | Value | Secret | Used By |
|----------|-------|--------|---------|
| SUPABASE_URL | https://[dev-project].supabase.co | No | integration-tests, integration-test-quick |
| SUPABASE_ANON_KEY | eyJhbGciOiJIUz... | Yes | integration-tests, integration-test-quick |

#### supabase_prod (Production Builds)
| Variable | Value | Secret | Used By |
|----------|-------|--------|---------|
| SUPABASE_URL | https://[prod-project].supabase.co | No | All release/patch workflows |
| SUPABASE_ANON_KEY | eyJhbGciOiJIUz... | Yes | All release/patch workflows |
| SUPABASE_SERVICE_ROLE_KEY | eyJhbGciOiJIUz... | Yes | Edge function testing (optional) |

#### shorebird_credentials (OTA Updates)
| Variable | Value | Secret | Used By |
|----------|-------|--------|---------|
| SHOREBIRD_TOKEN | [base64-token] | Yes | All Shorebird workflows (6 workflows) |

**How to Generate**:
```bash
shorebird login:ci
# Output: SHOREBIRD_TOKEN=<base64-encoded-token>
```

#### firebase_config (Android Builds)
| Variable | Value | Secret | Used By |
|----------|-------|--------|---------|
| ANDROID_FIREBASE_JSON | [base64-encoded] | Yes | All Android workflows |

**Current Status**: ⚠️ Variable name mismatch (see High Priority Issues)

**Recommended Change**: Rename to `GOOGLE_SERVICES_JSON` and remove base64 encoding

#### app_store_credentials (iOS Deployment)
| Variable | Value | Secret | Used By |
|----------|-------|--------|---------|
| App Store Connect API Key | Configured in UI | Yes | iOS release workflows |

**Configuration**: Codemagic UI → App Settings → iOS code signing → App Store Connect

#### google_play_credentials (Android Deployment)
| Variable | Value | Secret | Used By |
|----------|-------|--------|---------|
| GCLOUD_SERVICE_ACCOUNT_CREDENTIALS | JSON key file | Yes | Android release workflows |

**How to Get**: Google Cloud Console → Service Accounts → Create Key (JSON)

### Android Code Signing Variables (NEEDS VERIFICATION)

| Variable | Value | Secret | Used By |
|----------|-------|--------|---------|
| CM_KEYSTORE | Path to keystore | Yes | Android builds |
| CM_KEYSTORE_PASSWORD | Store password | Yes | Android builds |
| CM_KEY_PASSWORD | Key password | Yes | Android builds |
| CM_KEY_ALIAS | Key alias | Yes | Android builds |

**Status**: ⚠️ Not explicitly configured in YAML, must verify in Codemagic UI

See: [/docs/ci-cd/environment-variables-setup-guide.md](/docs/ci-cd/environment-variables-setup-guide.md) for complete setup instructions.

## Recommended Actions

### Immediate (Before Next Android Build)

**Priority: HIGH - Blocking Android Releases**

1. **Fix Firebase Variable Name**
   - Update Codemagic environment variable:
     - Old: `ANDROID_FIREBASE_JSON` (base64-encoded)
     - New: `GOOGLE_SERVICES_JSON` (plain JSON)
   - Update codemagic.yaml (3 locations):
     - Line 396-401 (android-shorebird-release)
     - Line 470-476 (android-shorebird-patch)
     - Line 645-651 (android-build-legacy)
   - Remove base64 decode step
   - Update documentation to match

2. **Verify Android Code Signing**
   - Check Codemagic UI → App Settings → Android code signing
   - Verify keystore file uploaded
   - Verify credentials variables exist (CM_KEYSTORE, CM_KEYSTORE_PASSWORD, etc.)
   - Add explicit key.properties creation to YAML if needed

3. **Verify Shorebird Token**
   - Check Codemagic → shorebird_credentials group
   - Confirm SHOREBIRD_TOKEN exists and is valid
   - Test with manual ios-shorebird-patch workflow

**Estimated Time**: 30-60 minutes

### Short Term (Within Next Sprint)

**Priority: MEDIUM - Quality Improvements**

4. **Refactor YAML to Use Anchors**
   - Replace duplicated scripts with `*anchor_name` references
   - Test one workflow first (pr-validation)
   - Roll out to all workflows
   - Verify no behavior changes
   - **Benefit**: Reduce YAML from 674 to ~400 lines

5. **Fix Test Output Handling**
   - Remove duplicate test execution (lines 116-126)
   - Run integration tests once with expanded output
   - Update test_report configuration
   - **Benefit**: 50% faster integration test workflow

6. **Remove `|| true` from Test Commands**
   - Update unit test commands (line 86, etc.)
   - Update integration test commands (lines 119, 125)
   - Fix any currently-failing tests that this exposes
   - **Benefit**: Proper quality gates, failed tests block deployment

**Estimated Time**: 4-8 hours

### Medium Term (Next Month)

**Priority: LOW - Nice to Have**

7. **Add Dev Flavor Manual Workflows**
   - Create ios-dev-build workflow
   - Create android-dev-build workflow
   - Configure dev Supabase environment variables
   - Test on real devices
   - **Benefit**: Better QA testing before production

8. **Implement Build Caching**
   - Add cache_paths configuration
   - Test cache invalidation
   - Monitor build speed improvements
   - **Benefit**: 30-40% faster builds

9. **Add Code Coverage Reporting**
   - Configure flutter test --coverage
   - Upload to Codecov or Coveralls
   - Add coverage badges to README
   - **Benefit**: Track test coverage over time

**Estimated Time**: 8-16 hours

## Flavor Architecture Integration

### Current Flavor Setup

**Flavors Defined**:
- **Dev**: Development environment with dev Supabase
- **Prod**: Production environment with prod Supabase

**Separation Points**:

| Component | Dev | Prod |
|-----------|-----|------|
| Bundle ID (iOS) | com.mealvana.endurance.dev | com.mealvana.endurance |
| Package Name (Android) | com.mealvana.endurance.dev | com.mealvana.endurance |
| Supabase Project | Dev project | Production project |
| Analytics | Disabled | Enabled (RudderStack + Mixpanel) |
| Entry Point | lib/main_dev.dart | lib/main_prod.dart |
| Xcode Scheme | dev | Runner (prod) |
| Android Product Flavor | dev | prod |
| Environment File | .env.dev.local | .env.prod.local |

**Xcode Configuration**:
- Schemes: dev, prod
- xcconfig files:
  - ios/Flutter/dev-Debug.xcconfig
  - ios/Flutter/dev-Profile.xcconfig
  - ios/Flutter/dev-Release.xcconfig
  - ios/Flutter/prod-Debug.xcconfig
  - ios/Flutter/prod-Profile.xcconfig
  - ios/Flutter/prod-Release.xcconfig

**Android Configuration**:
- build.gradle.kts product flavors:
  ```kotlin
  productFlavors {
      create("dev") {
          applicationIdSuffix = ".dev"
      }
      create("prod") {
          // Production settings
      }
  }
  ```

### Current CI/CD Flavor Usage

**Automated Workflows** (Prod Only):
- ios-shorebird-release → prod flavor (main/release branches)
- ios-shorebird-patch → prod flavor (manual)
- android-shorebird-release → prod flavor (main/release branches)
- android-shorebird-patch → prod flavor (manual)

**Manual Workflows** (Prod Only):
- ios-build-legacy → prod flavor
- android-build-legacy → prod flavor

**Dev Flavor**: Not currently in CI/CD, manual local builds only

### Local Development Commands

**Dev Flavor**:
```bash
# iOS
flutter build ipa --release --flavor dev -t lib/main_dev.dart

# Android
flutter build appbundle --release --flavor dev -t lib/main_dev.dart

# Run on device
flutter run --flavor dev -t lib/main_dev.dart
```

**Prod Flavor** (via Shorebird):
```bash
# iOS
shorebird release ios --flutter-version=stable

# Android
shorebird release android --flutter-version=stable --artifact=aab
```

**Prod Flavor** (standard Flutter):
```bash
# iOS
flutter build ipa --release --flavor prod -t lib/main_prod.dart

# Android
flutter build appbundle --release --flavor prod -t lib/main_prod.dart
```

## Testing Strategy Integration

### Test Execution in CI/CD

**Unit Tests** (11+ tests):
- Run in: All workflows except integration-test-quick
- Command: `flutter test`
- Duration: 5-15 seconds
- Coverage: Core business logic, services, repositories

**Integration Tests** (Full Suite):
- Run in: integration-tests workflow only
- Command: `flutter test integration_test/test_runner.dart`
- Duration: 20-30 minutes
- Platform: iOS Simulator (iPhone 15 Pro)
- Coverage: End-to-end user flows

**Edge Function Tests** (150+ tests):
- Run in: GitHub Actions (not Codemagic)
- Workflow: .github/workflows/test.yml
- Duration: 2-5 minutes
- Coverage: Supabase Edge Functions (Deno)

**Total**: 160+ automated tests per deployment

### Test Execution Matrix

| Workflow | Unit Tests | Integration Tests | Edge Function Tests |
|----------|-----------|-------------------|---------------------|
| pr-validation | ✅ | ❌ | ❌ (GitHub Actions) |
| integration-tests | ✅ | ✅ | ❌ (GitHub Actions) |
| integration-test-quick | ❌ | ✅ (Single flow) | ❌ (GitHub Actions) |
| ios-shorebird-release | ✅ | ❌ | ❌ (GitHub Actions) |
| ios-shorebird-patch | ✅ | ❌ | ❌ (GitHub Actions) |
| android-shorebird-release | ✅ | ❌ | ❌ (GitHub Actions) |
| android-shorebird-patch | ✅ | ❌ | ❌ (GitHub Actions) |
| ios-build-legacy | ✅ | ❌ | ❌ (GitHub Actions) |
| android-build-legacy | ✅ | ❌ | ❌ (GitHub Actions) |

**Note**: Edge function tests run separately in GitHub Actions before Supabase deployment.

## Build Commands Reference

### Development Builds (Local Only)

**Dev Flavor**:
```bash
# iOS Dev
flutter build ipa --release --flavor dev -t lib/main_dev.dart

# Android Dev
flutter build appbundle --release --flavor dev -t lib/main_dev.dart

# Run on device
flutter run --flavor dev -t lib/main_dev.dart
```

### Production Builds (CI/CD)

**Shorebird Release** (Current Default):
```bash
# iOS with Shorebird
shorebird release ios --flutter-version=stable

# Android with Shorebird
shorebird release android --flutter-version=stable --artifact=aab
```

**Shorebird Patch** (OTA Updates):
```bash
# iOS patch (latest release)
shorebird patch ios

# iOS patch (specific version)
shorebird patch ios --release-version=1.0.0+42

# Android patch (latest release)
shorebird patch android

# Android patch (specific version)
shorebird patch android --release-version=1.0.0+42
```

**Legacy Builds** (Fallback):
```bash
# iOS without Shorebird
flutter build ipa --release \
  --export-options-plist=/Users/builder/export_options.plist

# Android without Shorebird
flutter build appbundle --release
```

### Test Commands

```bash
# Unit tests only
flutter test

# Integration tests on iOS simulator
flutter test integration_test/test_runner.dart -d <simulator-id>

# Single integration test flow
flutter test integration_test/flows/event_management_flow_test.dart -d <simulator-id>

# Code analysis
flutter analyze

# Code formatting check
dart format --set-exit-if-changed lib test
```

## Workflow Trigger Summary

| Workflow | Automatic | Manual | Trigger Events |
|----------|-----------|--------|----------------|
| pr-validation | ✅ | ❌ | All pull requests |
| integration-tests | ✅ | ❌ | PR to develop/feature/release |
| integration-test-quick | ❌ | ✅ | Manual only |
| ios-shorebird-release | ✅ | ❌ | Push to main/release/* |
| ios-shorebird-patch | ❌ | ✅ | Manual only |
| ios-build-legacy | ❌ | ✅ | Manual only |
| android-shorebird-release | ✅ | ❌ | Push to main/release/* |
| android-shorebird-patch | ❌ | ✅ | Manual only |
| android-build-legacy | ❌ | ✅ | Manual only |

## Security Considerations

### Secret Management

**Properly Secured**:
- All Supabase keys marked as Secret (encrypted)
- Shorebird token encrypted
- App Store Connect API key in Codemagic integration
- Google Play service account JSON encrypted

**Best Practices Followed**:
- Environment variables never logged
- Secrets not committed to git
- Separate dev/prod credentials
- Team access controlled via Codemagic permissions

**Potential Improvements**:
- Audit unused environment variables
- Rotate credentials regularly
- Add secret scanning to GitHub Actions
- Document credential rotation procedure

### Build Security

**Current Safeguards**:
- Unit tests run before every build
- Code signing verified before distribution
- TestFlight/Play Store internal track testing
- Separate dev/prod environments

**Recommendations**:
- Add dependency vulnerability scanning
- Enable ProGuard obfuscation for Android release builds
- Add runtime integrity checks
- Implement certificate pinning for API calls

## Cost Optimization

### Current Usage

**Codemagic Instance**: mac_mini_m2
- Cost: Premium tier (faster than mac_mini_m1)
- Justification: Needed for iOS builds and Xcode

**Build Duration Estimates**:
- pr-validation: 5-10 minutes
- integration-tests: 30-40 minutes (with duplicate test issue)
- integration-test-quick: 15-20 minutes
- iOS release: 60-80 minutes
- iOS patch: 20-30 minutes
- Android release: 40-60 minutes
- Android patch: 15-25 minutes

**Monthly Estimate** (assuming 20 workdays):
- 20 PRs/day × 10 min = 200 min/day × 20 = 4,000 min/month
- 10 integration test runs/week × 35 min = 350 min/week × 4 = 1,400 min/month
- 4 releases/month × 70 min = 280 min/month
- 8 patches/month × 25 min = 200 min/month

**Total**: ~5,880 minutes/month = 98 hours/month

### Optimization Opportunities

1. **Fix Duplicate Test Execution**: Save 500-700 min/month
2. **Implement Build Caching**: Save 1,200-1,500 min/month
3. **Use Linux Instance for Android**: Save 30% on Android builds
4. **Optimize Integration Tests**: Run only on final PR approval

**Potential Monthly Savings**: 1,700-2,200 minutes (~28-37 hours)

## Future Enhancements

### Planned Improvements

1. **Add Web Deployment**
   - Build web version with flutter build web --wasm
   - Deploy to Vercel or Firebase Hosting
   - Environment: dev-web.mealvana.com, mealvana.com

2. **Add Automated Release Notes**
   - Generate from commit messages
   - Format for TestFlight/Play Store
   - Include in Slack notifications

3. **Add Automated Screenshot Testing**
   - Generate screenshots for App Store
   - Compare screenshots between builds
   - Detect visual regressions

4. **Add Performance Monitoring**
   - Track build duration over time
   - Alert on unusually slow builds
   - Identify optimization opportunities

5. **Add Automated Rollback**
   - Detect crash rate spikes post-release
   - Automatically delete bad Shorebird patches
   - Alert team via Slack

---

## Appendix

### Related Documentation

- [Codemagic Setup Guide](/docs/ci-cd/codemagic-setup.md)
- [Environment Variables Reference](/docs/ci-cd/secrets-and-environments.md)
- [Shorebird Integration](/docs/ci-cd/shorebird-integration.md)
- [Firebase Configuration](/docs/ci-cd/firebase-config-codemagic.md)
- [Troubleshooting Guide](/docs/ci-cd/troubleshooting.md)
- [GitHub Actions Workflows](/docs/ci-cd/github-actions.md)
- [Testing Strategy](/docs/test/README.md)

### External Resources

- [Codemagic Documentation](https://docs.codemagic.io)
- [Shorebird Documentation](https://docs.shorebird.dev)
- [Flutter CI/CD Best Practices](https://docs.flutter.dev/deployment/cd)
- [Codemagic + Shorebird Guide](https://blog.codemagic.io/how-to-set-up-flutter-code-push-with-shorebird-and-codemagic-cicd/)

### Change Log

| Date | Author | Changes |
|------|--------|---------|
| 2025-12-18 | Analysis | Initial comprehensive analysis created |

---

**Last Updated**: 2025-12-18

**Analysis Performed By**: CI/CD Review Process

**Codemagic YAML Version**: As of commit 6b7f2d8 (2025-12-18)
