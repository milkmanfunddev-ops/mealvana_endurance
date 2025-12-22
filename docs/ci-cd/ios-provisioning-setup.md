# iOS Provisioning Profile Setup Guide

## Overview

### What Are Provisioning Profiles?

Provisioning profiles are essential security files that Apple uses to verify your app's identity and grant permission to run on devices or distribute through the App Store. They act as a bridge between:

- **Your development/distribution certificate** (proves you're an authorized Apple developer)
- **Your App ID/Bundle ID** (uniquely identifies your app)
- **Devices** (for development profiles) or **distribution channels** (for App Store/TestFlight)

### Profile Types

**Development Profiles:**
- Used for testing on physical devices during development
- Tied to specific device UUIDs
- Not used by Codemagic (we use distribution profiles for TestFlight)

**Distribution Profiles:**
- Used for App Store and TestFlight releases
- Not tied to specific devices
- What Codemagic needs for CI/CD builds
- Two types:
  - **App Store Distribution**: For App Store and TestFlight releases
  - **Ad Hoc Distribution**: For distributing outside App Store (not used in this project)

### How Codemagic Handles Code Signing

Codemagic offers two approaches:

1. **Automatic Code Signing** (Recommended):
   - Uses App Store Connect API integration
   - Automatically creates and renews certificates
   - Automatically fetches and manages provisioning profiles
   - No manual certificate management required

2. **Manual Code Signing**:
   - You manually create and upload certificates (.p12 files)
   - You manually create and upload provisioning profiles (.mobileprovision files)
   - More control but more maintenance overhead

## Bundle IDs Required

Mealvana Endurance uses two flavors, each requiring separate provisioning profiles:

### 1. Dev Flavor: `com.mealvana.endurance.dev`

**Purpose:**
- Development and internal testing
- TestFlight internal testers only
- Rapid iteration and QA validation

**Codemagic Workflow:**
- Workflow name: `dev-ios`
- Trigger: Manual only
- Destination: TestFlight (internal testers)

### 2. Prod Flavor: `com.mealvana.endurance`

**Purpose:**
- Production releases
- TestFlight internal testers → public beta → App Store
- User-facing builds

**Codemagic Workflow:**
- Workflow name: `prod-ios`
- Trigger: Automated on `release/*` branches
- Destination: TestFlight → App Store

## Step-by-Step Setup in Apple Developer Portal

### Step 1: Create Bundle IDs (If Not Already Created)

1. Navigate to [Apple Developer Account](https://developer.apple.com/account/)
2. Click **Certificates, Identifiers & Profiles**
3. Select **Identifiers** from the sidebar
4. Click the **+** button to create a new identifier

#### For Dev Flavor:

5. Select **App IDs** → Click **Continue**
6. Select **App** → Click **Continue**
7. Configure the App ID:
   - **Description**: `Mealvana Endurance Dev`
   - **Bundle ID**: Select **Explicit**
   - Enter: `com.mealvana.endurance.dev`
   - **Capabilities**: Select all capabilities your app needs:
     - ✅ Push Notifications
     - ✅ Sign in with Apple
     - ✅ Associated Domains (if using deep links)
     - ✅ App Groups (if sharing data between extensions)
8. Click **Continue** → **Register**

#### For Prod Flavor:

9. Repeat steps 3-4
10. Configure the App ID:
    - **Description**: `Mealvana Endurance`
    - **Bundle ID**: Select **Explicit**
    - Enter: `com.mealvana.endurance` (no suffix)
    - **Capabilities**: Same as dev flavor
11. Click **Continue** → **Register**

### Step 2: Create Distribution Certificates

You have two options: let Codemagic create them automatically (recommended) or create them manually.

#### Option A: Automatic (Recommended - Skip to Step 3)

If you're using Codemagic's automatic code signing, skip this step. Codemagic will create certificates automatically.

#### Option B: Manual Creation

1. Navigate to **Certificates** in Apple Developer Portal
2. Click the **+** button
3. Select **Apple Distribution** (under Software)
4. Click **Continue**

5. **Create Certificate Signing Request (CSR)**:

   **Option B1: Create CSR on Your Mac:**
   - Open **Keychain Access** app
   - Menu: **Keychain Access** → **Certificate Assistant** → **Request a Certificate from a Certificate Authority**
   - Enter your email address
   - Common Name: `Mealvana Endurance Distribution`
   - Select **Saved to disk**
   - Click **Continue** and save the `.certSigningRequest` file

   **Option B2: Use Codemagic-Generated CSR:**
   - In Codemagic → Your App → Code Signing Identities
   - Generate CSR directly in Codemagic interface
   - Download the CSR file

6. Upload the CSR file to Apple Developer Portal
7. Click **Continue**
8. Download the certificate (`.cer` file)

9. **Convert to .p12 format** (if created on Mac):
   - Double-click the `.cer` file to install in Keychain
   - Open **Keychain Access**
   - Find the certificate (usually under "My Certificates")
   - Right-click → **Export "Apple Distribution: Your Name"**
   - Save as `.p12` format
   - Set a strong password
   - Save the password securely (you'll need it for Codemagic)

10. Keep the `.p12` file and password secure for uploading to Codemagic

### Step 3: Create Provisioning Profiles

#### For Dev Flavor:

1. Navigate to **Profiles** in Apple Developer Portal
2. Click the **+** button
3. Select **App Store** (under Distribution)
4. Click **Continue**
5. **App ID**: Select `com.mealvana.endurance.dev`
6. Click **Continue**
7. **Select Certificate**: Choose your distribution certificate (from Step 2)
8. Click **Continue**
9. **Provisioning Profile Name**: `Mealvana Endurance Dev Distribution`
10. Click **Generate**
11. Download the provisioning profile (`.mobileprovision` file)
12. Save securely for uploading to Codemagic

#### For Prod Flavor:

13. Repeat steps 1-4
14. **App ID**: Select `com.mealvana.endurance` (no suffix)
15. Click **Continue**
16. **Select Certificate**: Choose your distribution certificate
17. Click **Continue**
18. **Provisioning Profile Name**: `Mealvana Endurance Production Distribution`
19. Click **Generate**
20. Download the provisioning profile (`.mobileprovision` file)
21. Save securely for uploading to Codemagic

### Step 4: Upload to Codemagic

You have two paths: automatic or manual code signing.

#### Option A: Automatic Code Signing (Recommended)

See the **Automatic Code Signing Setup** section below.

#### Option B: Manual Code Signing

1. Log in to [Codemagic](https://codemagic.io)
2. Navigate to **Your App** → **Settings** → **Code signing identities**
3. Scroll to **iOS code signing**

4. **Upload Distribution Certificate:**
   - Click **Add certificate**
   - Upload the `.p12` file from Step 2
   - Enter the certificate password
   - Name it: `Mealvana Distribution Certificate`

5. **Upload Provisioning Profiles:**
   - Click **Add profile**
   - Upload `Mealvana Endurance Dev Distribution.mobileprovision`
   - Repeat for `Mealvana Endurance Production Distribution.mobileprovision`

6. Click **Save**

## Automatic Code Signing (Recommended)

### Why Automatic Signing?

- Codemagic manages certificates and profiles automatically
- Auto-renewal prevents expired certificate failures
- Works seamlessly with multiple bundle IDs (dev/prod flavors)
- No manual certificate/profile management
- Faster onboarding for new team members

### Prerequisites

1. **App Store Connect API Key** with proper permissions
2. **App Manager role** (not just Developer)
3. **Bundle IDs already created** in Apple Developer Portal

### Setup Instructions

#### Step 1: Create App Store Connect API Key

1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Go to **Users and Access** → **Integrations** → **App Store Connect API**
3. Click **Generate API Key** (or use existing key)
4. Configure the key:
   - **Name**: `Codemagic CI/CD`
   - **Access**: Select **App Manager** (required for certificate management)
   - Click **Generate**
5. Download the API key (`.p8` file) immediately
   - You can only download this once!
   - Save it securely
6. Note the following (you'll need these):
   - **Key ID**: (e.g., `AB12CD34EF`)
   - **Issuer ID**: (e.g., `12345678-90ab-cdef-1234-567890abcdef`)

#### Step 2: Add API Key to Codemagic

1. In Codemagic, click **Teams** (top-right menu)
2. Select your team
3. Click **Integrations** tab
4. Scroll to **App Store Connect**
5. Click **Add integration**
6. Configure the integration:
   - **Integration name**: `Mealvana` (must match exactly in `codemagic.yaml`)
   - **Issuer ID**: Paste from Step 1
   - **Key ID**: Paste from Step 1
   - **API Key file**: Upload the `.p8` file from Step 1
7. Click **Save**

#### Step 3: Verify Configuration in codemagic.yaml

Ensure your `codemagic.yaml` has the correct integration reference:

```yaml
workflows:
  dev-ios:
    name: Dev iOS Build
    integrations:
      app_store_connect: Mealvana  # Must match integration name exactly (case-sensitive)
    environment:
      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.mealvana.endurance.dev
    # ... rest of workflow

  prod-ios:
    name: Production iOS Build
    integrations:
      app_store_connect: Mealvana  # Must match integration name exactly
    environment:
      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.mealvana.endurance
    # ... rest of workflow
```

#### Step 4: Verify Automatic Signing Works

1. Trigger a test build of `dev-ios` workflow
2. Monitor build logs for:
   ```
   ✅ Fetching code signing files from App Store Connect...
   ✅ Code signing identity found
   ✅ Provisioning profile found: Mealvana Endurance Dev Distribution
   ✅ Build succeeded
   ```
3. If successful, automatic signing is working correctly

### Benefits of Automatic Signing

- **Zero maintenance**: Codemagic handles certificate renewal
- **Multi-flavor support**: Works for both dev and prod bundle IDs
- **Team scaling**: New team members don't need certificate access
- **Failure prevention**: No expired certificate surprises
- **Audit trail**: All signing operations logged in App Store Connect

## Manual Code Signing (Alternative)

If you prefer manual control over certificates and profiles (not recommended unless you have specific compliance requirements):

### Upload Certificates

1. Export certificate from **Keychain Access** as `.p12` format:
   - Open Keychain Access
   - Find your distribution certificate under "My Certificates"
   - Right-click → Export
   - Save as `.p12` with a strong password
2. In Codemagic → **App Settings** → **Code signing identities**
3. Upload certificate with password
4. Upload matching provisioning profiles (from Step 3)

### Configure in YAML

```yaml
workflows:
  dev-ios:
    environment:
      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.mealvana.endurance.dev
        # Codemagic will automatically select matching certificate and profile

  prod-ios:
    environment:
      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.mealvana.endurance
```

### Maintenance Requirements

- Manually renew certificates before expiration (1 year)
- Manually renew provisioning profiles before expiration (1 year)
- Re-upload renewed files to Codemagic
- Update team members when certificates change

## Verification

### Test Dev Flavor Signing

1. In Codemagic, navigate to your app
2. Click **Start new build**
3. Select **dev-ios** workflow
4. Click **Start build**
5. Monitor build logs for signing success:
   ```
   ✅ Code signing identity found: Apple Distribution: Your Name (TEAM_ID)
   ✅ Provisioning profile found: Mealvana Endurance Dev Distribution
   ✅ Signing iOS app...
   ✅ Build succeeded
   ```
6. Verify TestFlight upload succeeds

### Test Prod Flavor Signing

1. Create a test release branch:
   ```bash
   git checkout -b release/test-signing
   git push origin release/test-signing
   ```
2. Verify `prod-ios` workflow triggers automatically
3. Monitor signing logs (same success indicators as dev)
4. Verify TestFlight upload succeeds
5. Clean up test branch:
   ```bash
   git push origin --delete release/test-signing
   ```

## Troubleshooting

### "No code signing identity found"

**Symptoms:**
```
❌ Error: No code signing identity found for bundle identifier: com.mealvana.endurance.dev
```

**Possible Causes:**
- Certificate not uploaded to Codemagic
- Certificate expired (distribution certs expire after 1 year)
- Certificate revoked in Apple Developer Portal

**Solutions:**
1. Check certificate expiration in Apple Developer Portal → Certificates
2. If expired: Create new certificate (Step 2) and upload to Codemagic
3. If using automatic signing: Verify App Store Connect API key has "App Manager" role
4. If using manual signing: Re-upload valid certificate

### "No matching provisioning profile found"

**Symptoms:**
```
❌ Error: No provisioning profile found matching bundle identifier: com.mealvana.endurance.dev
```

**Possible Causes:**
- Bundle ID mismatch between `codemagic.yaml` and provisioning profile
- Provisioning profile not uploaded to Codemagic
- Provisioning profile expired
- Certificate and profile don't match

**Solutions:**
1. Verify bundle ID in `codemagic.yaml` exactly matches profile:
   ```yaml
   bundle_identifier: com.mealvana.endurance.dev  # Must match profile
   ```
2. Download profile from Apple Developer Portal and verify bundle ID
3. If using manual signing: Upload correct `.mobileprovision` file to Codemagic
4. If expired: Create new provisioning profile (Step 3)

### "Provisioning profile expired"

**Symptoms:**
```
❌ Error: Provisioning profile has expired
```

**Cause:**
Provisioning profiles expire after 1 year.

**Solutions:**
1. Navigate to Apple Developer Portal → Profiles
2. Find expired profile (shows expiration date)
3. Option A: Edit and regenerate existing profile
4. Option B: Create new profile (Step 3)
5. Download new `.mobileprovision` file
6. If using manual signing: Upload to Codemagic
7. If using automatic signing: Codemagic will auto-fetch new profile

### "Certificate expired"

**Symptoms:**
```
❌ Error: Certificate has expired
```

**Cause:**
Distribution certificates expire after 1 year.

**Solutions:**
1. Navigate to Apple Developer Portal → Certificates
2. Find expired certificate (shows expiration date)
3. Revoke expired certificate
4. Create new certificate (Step 2)
5. Create new provisioning profiles with new certificate (Step 3)
6. If using manual signing: Upload new `.p12` and `.mobileprovision` files to Codemagic
7. If using automatic signing: Codemagic will auto-create new certificate

### "Automatic signing failed"

**Symptoms:**
```
❌ Error: Failed to fetch code signing files from App Store Connect
```

**Possible Causes:**
- App Store Connect API key lacks permissions
- Integration name mismatch in `codemagic.yaml`
- API key expired or revoked
- Network issues connecting to App Store Connect

**Solutions:**
1. Verify API key has "App Manager" role (not just "Developer"):
   - App Store Connect → Users and Access → Integrations
   - Check role for your API key
   - If wrong role: Generate new key with "App Manager"
2. Verify integration name matches exactly (case-sensitive):
   ```yaml
   integrations:
     app_store_connect: Mealvana  # Must match Codemagic integration name
   ```
3. Check API key status in App Store Connect (not revoked)
4. Regenerate API key if needed:
   - Revoke old key in App Store Connect
   - Generate new key (Step 1 in Automatic Signing)
   - Update Codemagic integration (Step 2 in Automatic Signing)

### "Bundle ID not found in App Store Connect"

**Symptoms:**
```
❌ Error: Bundle identifier 'com.mealvana.endurance.dev' is not available
```

**Cause:**
Bundle ID not registered in Apple Developer Portal.

**Solutions:**
1. Create bundle ID in Apple Developer Portal (Step 1)
2. Wait 5-10 minutes for Apple's systems to sync
3. Retry build

### "Profile doesn't include the currently selected device"

**Symptoms:**
```
❌ Error: Provisioning profile doesn't include the current device
```

**Cause:**
This error typically occurs with development profiles, not distribution profiles. Distribution profiles (App Store) don't need device UUIDs.

**Solutions:**
1. Verify you're using **App Store Distribution** profile, not Development profile
2. Check `codemagic.yaml`:
   ```yaml
   ios_signing:
     distribution_type: app_store  # Not "development" or "ad-hoc"
   ```

## Best Practices

### 1. Use Automatic Signing

**Why:**
- Eliminates manual certificate management
- Auto-renewal prevents expiration failures
- Scales better with team growth
- Reduces onboarding friction

**When to Use Manual:**
- Enterprise compliance requires manual control
- You need to use specific certificate across multiple services
- Legal requirements mandate manual certificate custody

### 2. Create Both Profiles Early

Set up both dev and prod bundle IDs and profiles before your first Codemagic build to avoid delays.

**Checklist:**
- ✅ Dev bundle ID: `com.mealvana.endurance.dev`
- ✅ Prod bundle ID: `com.mealvana.endurance`
- ✅ Dev provisioning profile created
- ✅ Prod provisioning profile created
- ✅ Codemagic integration configured
- ✅ Test builds successful for both flavors

### 3. Test Locally First

Before relying on Codemagic for builds, verify code signing works locally:

```bash
# Test dev flavor build
flutter build ipa --release --flavor dev -t lib/main_dev.dart

# Test prod flavor build
flutter build ipa --release --flavor prod -t lib/main_prod.dart
```

**What to Check:**
- Build completes without signing errors
- Archive appears in Xcode Organizer
- Can upload to TestFlight manually (optional verification)

### 4. Monitor Expiration Dates

**Certificates**: Expire after 1 year
**Provisioning Profiles**: Expire after 1 year

**Recommended:**
- Set calendar reminders 2 weeks before expiration
- Use automatic signing to eliminate manual renewal
- If using manual signing: Renew before expiration, not after

**Check Expiration:**
1. Apple Developer Portal → Certificates
2. Apple Developer Portal → Profiles
3. Note expiration dates for your distribution assets

### 5. Separate Teams (Optional)

For extra isolation between dev and prod environments:

**Setup:**
1. Create two App Store Connect teams:
   - Team 1: Development (dev flavor)
   - Team 2: Production (prod flavor)
2. Create separate API keys for each team
3. Create separate Codemagic integrations:
   - Integration 1: `Mealvana-Dev`
   - Integration 2: `Mealvana-Prod`
4. Update `codemagic.yaml`:
   ```yaml
   workflows:
     dev-ios:
       integrations:
         app_store_connect: Mealvana-Dev

     prod-ios:
       integrations:
         app_store_connect: Mealvana-Prod
   ```

**Benefits:**
- Complete isolation of dev and prod signing
- Different team members can manage each environment
- Reduced risk of accidental prod deployments

**Drawbacks:**
- More complexity
- Requires paid Apple Developer account for each team
- Overkill for most projects (including Mealvana Endurance)

## Security Notes

### Certificate Security

- **Never commit certificates or provisioning profiles to git**
  - Add to `.gitignore`: `*.p12`, `*.mobileprovision`, `*.cer`
  - Use Codemagic's encrypted storage instead
- **Use strong passwords** for `.p12` files (minimum 12 characters)
- **Store passwords securely** (use password manager, not plaintext)
- **Revoke compromised certificates immediately**
  - Apple Developer Portal → Certificates → Select → Revoke
  - Create new certificate and update Codemagic

### API Key Security

- **Store `.p8` API key files securely**
  - Never commit to git
  - Use encrypted storage (password manager, secure vault)
  - Only upload to trusted services (Codemagic, CI/CD platforms)
- **Use minimum required permissions**
  - "App Manager" for Codemagic (needed for certificate management)
  - Don't use "Admin" role unless absolutely necessary
- **Rotate API keys annually**
  - Proactive rotation reduces compromise risk
  - Revoke old keys after rotation complete

### Access Control

- **Limit team member access** to signing assets
  - Only developers who need signing access should have it
  - Use role-based access control in Codemagic
- **Audit access logs** periodically
  - Review who accessed signing assets
  - Check for unauthorized access attempts

### Incident Response

If a certificate or API key is compromised:

1. **Immediate Actions:**
   - Revoke certificate in Apple Developer Portal
   - Revoke API key in App Store Connect
   - Rotate all related credentials
   - Audit recent builds for unauthorized changes

2. **Recovery:**
   - Create new certificate (Step 2)
   - Create new API key (Automatic Signing Step 1)
   - Update Codemagic with new credentials
   - Test builds to verify recovery

3. **Prevention:**
   - Review access controls
   - Strengthen password policies
   - Enable two-factor authentication for all team members

## Helpful Commands

### Local Build Testing

```bash
# Test dev flavor build locally
flutter build ipa --release --flavor dev -t lib/main_dev.dart

# Test prod flavor build locally
flutter build ipa --release --flavor prod -t lib/main_prod.dart

# Clean build artifacts (if encountering caching issues)
flutter clean && flutter pub get
```

### Xcode Signing Verification

```bash
# Check Xcode for available provisioning profiles
xcodebuild -showProvisioningProfiles

# List available signing identities in Keychain
security find-identity -p codesigning

# Verify specific provisioning profile details
security cms -D -i /path/to/profile.mobileprovision
```

### Certificate Management

```bash
# List certificates in Keychain
security find-certificate -a -p -c "Apple Distribution"

# Export certificate from Keychain (macOS command line)
security export -k ~/Library/Keychains/login.keychain-db \
  -t identities -f pkcs12 -o certificate.p12 \
  -P "password"
```

### Provisioning Profile Inspection

```bash
# Decode provisioning profile to readable format
security cms -D -i /path/to/profile.mobileprovision > profile.plist
plutil -p profile.plist

# Extract bundle identifier from profile
/usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" profile.plist
```

### Codemagic CLI (for advanced users)

```bash
# Trigger build via Codemagic API (requires API token)
curl -X POST \
  -H "x-auth-token: YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"workflowId": "dev-ios"}' \
  https://api.codemagic.io/apps/YOUR_APP_ID/builds
```

## References

### Apple Documentation

- [Creating Provisioning Profiles](https://developer.apple.com/documentation/appstoreconnectapi/profiles)
- [App Distribution Guide](https://developer.apple.com/distribute/)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Introduction/Introduction.html)

### Codemagic Documentation

- [iOS Code Signing](https://docs.codemagic.io/code-signing/ios-code-signing/)
- [App Store Connect Integration](https://docs.codemagic.io/integrations/app-store-connect-integration/)
- [Automatic Code Signing](https://docs.codemagic.io/code-signing-yaml/signing-ios/)
- [Manual Code Signing](https://docs.codemagic.io/code-signing/ios-code-signing/#manual-code-signing)

### Flutter Documentation

- [iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [Build and Release iOS App](https://docs.flutter.dev/deployment/ios#create-an-app-bundle)
- [Flavors and Build Configurations](https://docs.flutter.dev/deployment/flavors)

### Community Resources

- [Flutter Community: iOS Code Signing](https://flutter.dev/community)
- [Stack Overflow: iOS Provisioning](https://stackoverflow.com/questions/tagged/ios-provisioning)

---

## Summary

This guide covers complete iOS provisioning setup for Mealvana Endurance's dual-flavor architecture (dev and prod). The recommended approach is **automatic code signing** using App Store Connect API integration, which eliminates manual certificate management and provides automatic renewal.

**Quick Start Checklist:**
1. ✅ Create bundle IDs in Apple Developer Portal (Step 1)
2. ✅ Create App Store Connect API key with "App Manager" role
3. ✅ Add API key to Codemagic integration named "Mealvana"
4. ✅ Verify `codemagic.yaml` references correct integration
5. ✅ Test builds for both dev and prod flavors
6. ✅ Monitor build logs for signing success

If you encounter issues, check the **Troubleshooting** section first. For security concerns, review the **Security Notes** section.

**Need Help?**
- Check Codemagic build logs for specific error messages
- Review Apple Developer Portal for certificate/profile status
- Consult the References section for official documentation
- Contact Apple Developer Support for account-specific issues
