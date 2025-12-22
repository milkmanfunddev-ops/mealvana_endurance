# Codemagic Environment Setup Guide (2025)

**Complete step-by-step guide for configuring all environment variables in Codemagic for the Mealvana Endurance app**

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Environment Groups Structure](#environment-groups-structure)
4. [Step 1: Create Environment Variable Groups](#step-1-create-environment-variable-groups)
5. [Step 2: Configure Dev Flavor Variables](#step-2-configure-dev-flavor-variables)
6. [Step 3: Configure Prod Flavor Variables](#step-3-configure-prod-flavor-variables)
7. [Step 4: Configure Firebase](#step-4-configure-firebase)
8. [Step 5: Configure Shorebird](#step-5-configure-shorebird)
9. [Step 6: Configure App Store Connect](#step-6-configure-app-store-connect)
10. [Step 7: Configure Google Play](#step-7-configure-google-play)
11. [Verification & Testing](#verification--testing)
12. [Security Best Practices](#security-best-practices)
13. [Troubleshooting](#troubleshooting)
14. [Complete Checklist](#complete-checklist)

---

## Overview

The Mealvana Endurance app uses a **dual-flavor architecture** (dev and prod) with separate environment configurations. This guide walks you through setting up all required environment variables in Codemagic to support:

- Development builds with dev Supabase instance
- Production builds with prod Supabase instance
- Firebase integration for Android
- Shorebird over-the-air (OTA) updates
- App Store Connect publishing
- Google Play Store publishing

**Total Setup Time**: 45-60 minutes (first time)

---

## Prerequisites

Before starting, gather these credentials:

- [ ] Supabase Dev and Prod credentials (URLs, anon keys, service role keys)
- [ ] Mixpanel project tokens (dev and prod)
- [ ] Sentry DSNs (dev and prod)
- [ ] TrainingPeaks API credentials (sandbox and production)
- [ ] Final Surge API credentials
- [ ] Wiredash project ID and secret
- [ ] LocationIQ API key
- [ ] Active.com API key
- [ ] OneSignal App ID
- [ ] Firebase google-services.json file (Android)
- [ ] App Store Connect API key (.p8 file, Key ID, Issuer ID)
- [ ] Google Play service account JSON key
- [ ] Shorebird CI token (generate with `shorebird login:ci`)

---

## Environment Groups Structure

Codemagic uses **environment variable groups** to organize credentials. We'll create these groups:

| Group Name | Purpose | Required For Workflows |
|------------|---------|------------------------|
| `mealvana_dev` | Dev flavor configuration | integration-tests, integration-test-quick |
| `mealvana_prod` | Prod flavor configuration | All production builds and patches |
| `firebase_config` | Firebase configuration | All Android workflows |
| `shorebird_credentials` | Shorebird CI token | All Shorebird release/patch workflows |
| `google_play_credentials` | Google Play publishing | android-shorebird-release, android-build-legacy |

**Note**: App Store Connect is configured via Integration (not environment variable group)

---

## Step 1: Create Environment Variable Groups

### 1.1 Access Codemagic Team Settings

1. Log in to [Codemagic](https://codemagic.io)
2. Click your team name in the top-right corner
3. Select **Team settings** from dropdown
4. Click **Global variables and secrets** in left sidebar

### 1.2 Create First Group: `mealvana_dev`

1. Click **+ Add environment variable group** button
2. Enter group name: `mealvana_dev`
3. Add description: "Development environment configuration for Mealvana Endurance"
4. Click **Create**

### 1.3 Create Remaining Groups

Repeat for each group:

- **Group 2**: `mealvana_prod` - "Production environment configuration for Mealvana Endurance"
- **Group 3**: `firebase_config` - "Firebase configuration for Android builds"
- **Group 4**: `shorebird_credentials` - "Shorebird CI token for OTA updates"
- **Group 5**: `google_play_credentials` - "Google Play Store publishing credentials"

You should now have 5 environment variable groups created.

---

## Step 2: Configure Dev Flavor Variables

### 2.1 Open the `mealvana_dev` Group

1. Click on **mealvana_dev** group in the list
2. Click **+ Add variable** to start adding variables

### 2.2 Add Supabase Dev Variables

Add these variables one by one:

| Variable Name | Value | Secure? | Notes |
|---------------|-------|---------|-------|
| `SUPABASE_URL` | `https://vlmtsdzpnjnavdgytcmi.supabase.co` | No | Public URL |
| `SUPABASE_ANON_KEY` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZsbXRzZHpwbmpuYXZkZ3l0Y21pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk4NTI3OTAsImV4cCI6MjA3NTQyODc5MH0._7t1pjG_1zk4xkfseu2ACqYXdwEJKcRUWyvY4ZXs35o` | No | Public anon key |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZsbXRzZHpwbmpuYXZkZ3l0Y21pIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1OTg1Mjc5MCwiZXhwIjoyMDc1NDI4NzkwfQ.ugFmXxvIEYZPNMzIhPRB6x-MGbODfE1BXVdKyLpngO0` | **YES** | Must be secure |

**How to add a variable:**

1. Click **+ Add variable**
2. Enter **Variable name** (e.g., `SUPABASE_URL`)
3. Enter **Variable value** (copy from table above)
4. Check **Secure** checkbox if marked "YES" in table
5. Click **Add**

**What "Secure" means:**
- Value is encrypted at rest
- Value is not displayed in build logs
- Value cannot be viewed after saving (only replaced)

### 2.3 Add Analytics & Monitoring Variables

| Variable Name | Value | Secure? |
|---------------|-------|---------|
| `MIXPANEL_PROJECT_TOKEN` | `df6e8dd4f3dc1363fa194a156298b16c` | No |
| `SENTRY_DSN` | `https://40b0481418b8542bded2a45a63fa6c37@o4509882392969216.ingest.us.sentry.io/4510121638166528` | **YES** |
| `SENTRY_ENVIRONMENT` | `development` | No |
| `LOCATIONIQ_API_KEY` | `pk.16aad2b03e593779fc9d9443eb16b2ba` | No |

### 2.4 Add External API Variables

| Variable Name | Value | Secure? |
|---------------|-------|---------|
| `ACTIVE_COM_API_KEY` | `me46ygqfz5ghw34e97c7rv4p` | No |
| `WIREDASH_PROJECT_ID` | `mealvana-endurance-vn1pxw3` | No |
| `WIREDASH_SECRET` | `wuQrGN_DMojjIopfhEblvMpU53FSChuD` | **YES** |
| `ONESIGNAL_APP_ID` | `335e597f-9862-4fa1-91f9-506d546ef953` | No |

### 2.5 Add TrainingPeaks Sandbox Variables

| Variable Name | Value | Secure? |
|---------------|-------|---------|
| `TRAININGPEAKS_CLIENT_ID` | `mealvana` | No |
| `TRAININGPEAKS_CLIENT_SECRET` | `CSBPmjgHFFTjGNUfBlPTqcx1bm9ilR6laqHO31Ms` | **YES** |
| `TRAININGPEAKS_OAUTH_URL` | `https://oauth.sandbox.trainingpeaks.com` | No |
| `TRAININGPEAKS_API_URL` | `https://api.sandbox.trainingpeaks.com` | No |
| `TRAININGPEAKS_SCOPES` | `athlete:profile events:read events:write file:write metrics:read metrics:write nutrition:write nutrition:read webhook:write-subscriptions webhook:read-subscriptions workouts:read workouts:details workouts:wod workouts:plan` | No |

**Note**: The scopes value is very long. Make sure to copy it entirely in one line.

### 2.6 Add Final Surge Variables

| Variable Name | Value | Secure? |
|---------------|-------|---------|
| `FINAL_SURGE_CLIENT_ID` | `BD5D0C2B-7507-405B-8A3F-DB161288E6FC` | No |
| `FINAL_SURGE_CLIENT_SECRET` | `65kj$#deujXLk3h?mpkm*V94X$dkb2$u78H35-Sc#$es#^C2e5^pMat3*2QAe7+$` | **YES** |
| `FINAL_SURGE_BASE_URL` | `https://log.finalsurge.com` | No |
| `FINAL_SURGE_REDIRECT_URI` | `http://127.0.0.1:8888/callback` | No |

**Security Warning**: The Final Surge client secret contains special characters (`#`, `$`, `?`, `*`). These are part of the password - copy exactly as shown.

### 2.7 Add Feature Flags

| Variable Name | Value | Secure? |
|---------------|-------|---------|
| `DEV_MODE_ENABLED` | `true` | No |
| `APP_ENV` | `dev` | No |
| `APP_ENVIRONMENT` | `dev` | No |

**Total variables in `mealvana_dev`**: 24 variables

---

## Step 3: Configure Prod Flavor Variables

### 3.1 Open the `mealvana_prod` Group

Click on **mealvana_prod** group in the environment variable groups list.

### 3.2 Add Supabase Prod Variables

| Variable Name | Value | Secure? |
|---------------|-------|---------|
| `SUPABASE_URL` | `https://wvmvsodrvbkxfydabqed.supabase.co` | No |
| `SUPABASE_ANON_KEY` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind2bXZzb2RydmJreGZ5ZGFicWVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyOTMxMDcsImV4cCI6MjA3MDg2OTEwN30.pG2IYdEIIFS8_zPxzr6pZplzWQqvD13dvslrpFMAPCk` | No |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind2bXZzb2RydmJreGZ5ZGFicWVkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI5MzEwNywiZXhwIjoyMDcwODY5MTA3fQ.FDQqvFxGvaZZNdj7iN6cU1mfKC6HOhoov89g06_xWl8` | **YES** |

### 3.3 Add Analytics & Monitoring Variables (Prod)

| Variable Name | Value | Secure? | Notes |
|---------------|-------|---------|-------|
| `MIXPANEL_PROJECT_TOKEN` | `bd8fe50bb67b1dd0860351e6297347db` | No | Different from dev |
| `SENTRY_DSN` | `https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328` | **YES** | Different from dev |
| `SENTRY_ENVIRONMENT` | `production` | No | Different from dev |
| `LOCATIONIQ_API_KEY` | `pk.16aad2b03e593779fc9d9443eb16b2ba` | No | Same as dev |

### 3.4 Add External API Variables (Prod)

These are identical to dev environment:

| Variable Name | Value | Secure? |
|---------------|-------|---------|
| `ACTIVE_COM_API_KEY` | `me46ygqfz5ghw34e97c7rv4p` | No |
| `WIREDASH_PROJECT_ID` | `mealvana-endurance-vn1pxw3` | No |
| `WIREDASH_SECRET` | `wuQrGN_DMojjIopfhEblvMpU53FSChuD` | **YES** |
| `ONESIGNAL_APP_ID` | `335e597f-9862-4fa1-91f9-506d546ef953` | No |

### 3.5 Add TrainingPeaks Production Variables

**Important**: Production TrainingPeaks uses different OAuth and API URLs:

| Variable Name | Value | Secure? |
|---------------|-------|---------|
| `TRAININGPEAKS_CLIENT_ID` | `mealvana` | No |
| `TRAININGPEAKS_CLIENT_SECRET` | `CSBPmjgHFFTjGNUfBlPTqcx1bm9ilR6laqHO31Ms` | **YES** |
| `TRAININGPEAKS_OAUTH_URL` | `https://oauth.trainingpeaks.com` | No |
| `TRAININGPEAKS_API_URL` | `https://api.trainingpeaks.com` | No |
| `TRAININGPEAKS_SCOPES` | `athlete:profile events:read events:write file:write metrics:read metrics:write nutrition:write nutrition:read webhook:write-subscriptions webhook:read-subscriptions workouts:read workouts:details workouts:wod workouts:plan` | No |

**Note**: Notice the URLs don't have `.sandbox` in production.

### 3.6 Add Final Surge Variables (Prod)

**Important**: Production Final Surge uses a different redirect URI:

| Variable Name | Value | Secure? |
|---------------|-------|---------|
| `FINAL_SURGE_CLIENT_ID` | `BD5D0C2B-7507-405B-8A3F-DB161288E6FC` | No |
| `FINAL_SURGE_CLIENT_SECRET` | `65kj$#deujXLk3h?mpkm*V94X$dkb2$u78H35-Sc#$es#^C2e5^pMat3*2QAe7+$` | **YES** |
| `FINAL_SURGE_BASE_URL` | `https://log.finalsurge.com` | No |
| `FINAL_SURGE_REDIRECT_URI` | `mealvana://auth/finalsurge` | No |

**Note**: Prod uses custom app URL scheme (`mealvana://`) instead of localhost.

### 3.7 Add Feature Flags (Prod)

| Variable Name | Value | Secure? |
|---------------|-------|---------|
| `DEV_MODE_ENABLED` | `false` | No |
| `APP_ENV` | `prod` | No |
| `APP_ENVIRONMENT` | `prod` | No |

**Total variables in `mealvana_prod`**: 24 variables

---

## Step 4: Configure Firebase

### 4.1 Understand Firebase Configuration

The Firebase configuration requires the entire contents of `android/app/google-services.json` to be stored as an environment variable.

**IMPORTANT**:
- Store as **plain JSON text** (NOT base64 encoded)
- The Codemagic workflow will base64 encode it during build
- Do NOT manually base64 encode before adding to Codemagic

### 4.2 Get google-services.json Content

1. Open your project in terminal
2. Navigate to Android app directory:
   ```bash
   cd android/app
   ```
3. Display the file contents:
   ```bash
   cat google-services.json
   ```
4. Copy the ENTIRE JSON output (from `{` to `}`)

### 4.3 Add to Codemagic

1. Open the **firebase_config** group
2. Click **+ Add variable**
3. Enter variable name: `ANDROID_FIREBASE_JSON`
4. Paste the ENTIRE JSON content in the value field:
   ```json
   {
     "project_info": {
       "project_number": "187980576164",
       "project_id": "mealvana-endurance-46886",
       "storage_bucket": "mealvana-endurance-46886.firebasestorage.app"
     },
     "client": [
       {
         "client_info": {
           "mobilesdk_app_id": "1:187980576164:android:140a82b494da58dc3c3d31",
           "android_client_info": {
             "package_name": "com.milkman.mealvanaendurance"
           }
         },
         ...
       }
     ],
     "configuration_version": "1"
   }
   ```
5. **Check "Secure"** - This contains API keys
6. Click **Add**

**Common Mistakes to Avoid**:
- ❌ Base64 encoding the JSON before adding (workflow handles this)
- ❌ Only copying part of the JSON (must be complete from `{` to `}`)
- ❌ Not marking as "Secure" (contains sensitive API keys)
- ❌ Adding extra whitespace or formatting changes

**How the workflow uses it**:
```bash
echo "$ANDROID_FIREBASE_JSON" | base64 --decode > android/app/google-services.json
```

**Total variables in `firebase_config`**: 1 variable

---

## Step 5: Configure Shorebird

### 5.1 Generate Shorebird CI Token

Shorebird requires a special CI token for automated builds. Generate it from your terminal:

```bash
# Login to Shorebird (if not already logged in)
shorebird login

# Generate CI token
shorebird login:ci
```

**Output example**:
```
Generated CI token:
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

**Important**: Copy the ENTIRE token (very long string starting with `eyJ`)

### 5.2 Add to Codemagic

1. Open the **shorebird_credentials** group
2. Click **+ Add variable**
3. Enter variable name: `SHOREBIRD_TOKEN`
4. Paste the entire token value
5. **Check "Secure"** - This grants deployment access
6. Click **Add**

**Security Note**: This token grants permission to create Shorebird releases and patches. Keep it secret.

**Total variables in `shorebird_credentials`**: 1 variable

---

## Step 6: Configure App Store Connect

App Store Connect is configured via **Codemagic Integration** (not environment variables).

### 6.1 Get App Store Connect API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **Users and Access** in top menu
3. Click **Integrations** tab
4. Click **Keys** (under App Store Connect API)
5. Click **+ Generate API Key** or use existing key

**You'll need**:
- API Key file (.p8 file) - Download when creating key
- Key ID (e.g., `2X9R4HXF34`)
- Issuer ID (e.g., `57246542-96fe-1a63-e053-0824d011072a`)

**Important**: Save the .p8 file immediately - you can only download it once!

### 6.2 Add Integration in Codemagic

1. In Codemagic, go to **Team settings**
2. Click **Integrations** in left sidebar
3. Click **+ Add integration**
4. Select **App Store Connect**
5. Fill in the form:
   - **Integration name**: `Mealvana` (MUST match name in codemagic.yaml)
   - **Issuer ID**: Paste from App Store Connect
   - **Key ID**: Paste from App Store Connect
   - **API key**: Upload the .p8 file
6. Click **Save**

**Critical**: The integration name `Mealvana` must exactly match the integration reference in `codemagic.yaml`:

```yaml
ios-shorebird-release:
  integrations:
    app_store_connect: Mealvana  # Must match integration name
```

**Verification**:
- Integration status should show "Active" with a green checkmark
- Test by triggering an iOS workflow (it will fail early if integration is wrong)

---

## Step 7: Configure Google Play

### 7.1 Create Service Account in Google Cloud

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your Firebase project (`mealvana-endurance-46886`)
3. Click **IAM & Admin** > **Service Accounts**
4. Click **+ CREATE SERVICE ACCOUNT**
5. Fill in details:
   - **Service account name**: `codemagic-publisher`
   - **Service account ID**: `codemagic-publisher` (auto-filled)
   - **Description**: "Codemagic CI/CD service account for Google Play publishing"
6. Click **CREATE AND CONTINUE**

### 7.2 Grant Permissions

1. In "Grant this service account access to project":
   - Skip this step (permissions granted in Google Play Console)
2. Click **CONTINUE**
3. Click **DONE**

### 7.3 Create JSON Key

1. Find the service account in the list
2. Click the three dots menu (⋮) on the right
3. Select **Manage keys**
4. Click **ADD KEY** > **Create new key**
5. Select **JSON** format
6. Click **CREATE**
7. The JSON key file will download automatically (e.g., `mealvana-endurance-46886-abc123.json`)

**Save this file securely** - it cannot be retrieved again!

### 7.4 Grant Access in Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app
3. Go to **Setup** > **API access**
4. Under "Service accounts", find your service account
5. Click **Grant access**
6. Set permissions:
   - **Releases**: "View app information and create and edit releases" (required)
   - **Release to production, exclude devices**: "Recommended" or "Admin" (optional)
7. Click **Invite user**
8. Click **Send invite**

### 7.5 Add Service Account Key to Codemagic

1. Open the downloaded JSON key file in a text editor
2. Copy the ENTIRE contents (from `{` to `}`)

Example structure:
```json
{
  "type": "service_account",
  "project_id": "mealvana-endurance-46886",
  "private_key_id": "abc123...",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----\n",
  "client_email": "codemagic-publisher@mealvana-endurance-46886.iam.gserviceaccount.com",
  "client_id": "123456789",
  ...
}
```

3. In Codemagic, open the **google_play_credentials** group
4. Click **+ Add variable**
5. Enter variable name: `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS`
6. Paste the ENTIRE JSON key contents
7. **Check "Secure"** - Contains private key
8. Click **Add**

**Common Mistakes**:
- ❌ Only copying part of the JSON (must include entire structure)
- ❌ Modifying JSON formatting (paste as-is)
- ❌ Not granting access in Google Play Console (builds succeed but publishing fails)
- ❌ Using wrong service account (must be from correct Firebase project)

**Total variables in `google_play_credentials`**: 1 variable

---

## Verification & Testing

### Step 1: Verify All Groups Are Created

Go to **Team settings** > **Global variables and secrets**. You should see:

- [x] `mealvana_dev` (24 variables)
- [x] `mealvana_prod` (24 variables)
- [x] `firebase_config` (1 variable)
- [x] `shorebird_credentials` (1 variable)
- [x] `google_play_credentials` (1 variable)
- [x] App Store Connect integration (configured under Integrations)

**Total**: 5 groups + 1 integration = 51 environment variables

### Step 2: Verify Workflow Configuration

Open your `codemagic.yaml` file and verify each workflow references the correct groups:

**Integration Tests** (uses dev):
```yaml
integration-tests:
  environment:
    groups:
      - supabase_dev  # Should be: mealvana_dev
```

**iOS Shorebird Release** (uses prod):
```yaml
ios-shorebird-release:
  environment:
    groups:
      - supabase_prod        # Should be: mealvana_prod
      - shorebird_credentials
      - app_store_credentials  # Remove - not needed (uses integration)
```

**Android Shorebird Release** (uses prod + firebase):
```yaml
android-shorebird-release:
  environment:
    groups:
      - supabase_prod        # Should be: mealvana_prod
      - shorebird_credentials
      - google_play_credentials
      - firebase_config
```

**Action Required**: Update your `codemagic.yaml` to reference the correct group names:

1. Replace all instances of `supabase_dev` with `mealvana_dev`
2. Replace all instances of `supabase_prod` with `mealvana_prod`
3. Remove `app_store_credentials` group (doesn't exist - uses integration instead)

### Step 3: Test with PR Validation Workflow

The safest way to test is with the PR validation workflow (no environment variables required):

1. Create a test branch: `git checkout -b test/codemagic-setup`
2. Make a trivial change (e.g., add a comment to README.md)
3. Commit and push: `git push origin test/codemagic-setup`
4. Create a pull request
5. Codemagic should trigger the `pr-validation` workflow automatically

**Expected Result**: Workflow should complete successfully with:
- Flutter dependencies installed
- Code generation completed
- Flutter analyze passed
- Dart formatting check passed
- Unit tests passed

### Step 4: Test Dev Environment

Manually trigger the `integration-test-quick` workflow:

1. In Codemagic, go to your app
2. Click **Start new build**
3. Select workflow: `integration-test-quick`
4. Select branch: `develop` or your test branch
5. Click **Start new build**

**Expected Result**:
- Environment variables from `mealvana_dev` are loaded
- Supabase dev instance is accessible
- Integration test runs successfully

**If it fails**:
- Check build logs for "Environment variable not found" errors
- Verify group name in workflow matches group name in Codemagic
- Ensure all required variables in `mealvana_dev` are present

### Step 5: Test Firebase Configuration (Android)

Manually trigger `android-build-legacy` workflow (safer than Shorebird for first test):

1. Click **Start new build**
2. Select workflow: `android-build-legacy`
3. Select branch: `main` (or test branch)
4. Click **Start new build**

**Expected Result**:
- Firebase configuration loads successfully
- google-services.json is created in `android/app/`
- Build completes without Firebase errors

**If it fails**:
- Check for "google-services.json not found" error
- Verify `ANDROID_FIREBASE_JSON` variable is NOT base64 encoded in Codemagic
- Verify JSON is valid (use [jsonlint.com](https://jsonlint.com))

### Step 6: Test Shorebird (Optional)

Only test Shorebird workflows after confirming regular builds work:

1. Start with `ios-build-legacy` or `android-build-legacy` first
2. Once those succeed, try `ios-shorebird-release` or `android-shorebird-release`

**Note**: Shorebird workflows require valid code signing, so failures may be signing-related, not environment variable issues.

---

## Security Best Practices

### 1. Variables That MUST Be Secure

Always mark these as "Secure" (checked):

**Supabase**:
- `SUPABASE_SERVICE_ROLE_KEY` (dev and prod)

**Analytics & Monitoring**:
- `SENTRY_DSN` (dev and prod)

**External APIs**:
- `WIREDASH_SECRET`
- `TRAININGPEAKS_CLIENT_SECRET`
- `FINAL_SURGE_CLIENT_SECRET`

**Deployment**:
- `SHOREBIRD_TOKEN`
- `ANDROID_FIREBASE_JSON`
- `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS`

### 2. What Happens When a Secret Is Leaked

If any secure credential is compromised:

**Immediate Actions**:
1. **Rotate the credential** in the source system (Supabase, Sentry, etc.)
2. **Update Codemagic** with new credential
3. **Invalidate old credential** in source system
4. **Review recent activity** for unauthorized access

**Rotation Instructions**:

| Service | How to Rotate |
|---------|---------------|
| Supabase Service Role Key | Supabase Dashboard > Settings > API > Reset service_role key |
| Sentry DSN | Sentry > Settings > Projects > [Project] > Client Keys > Regenerate |
| Shorebird Token | Run `shorebird login:ci` again to generate new token |
| Google Play Service Account | Google Cloud Console > IAM & Admin > Service Accounts > Create new key + delete old |
| App Store Connect API | App Store Connect > Users and Access > Keys > Revoke + Generate new |

### 3. Access Control

**Who should have access**:
- Team admins: Full access to all environment variables
- Developers: Read-only access to variable names (not values)
- CI/CD bots: Automatic access during builds

**How to review access**:
1. Go to **Team settings** > **Team**
2. Review member roles
3. Ensure only trusted team members have "Admin" role

### 4. Audit Logging

Codemagic logs all environment variable changes:

1. Go to **Team settings** > **Audit log**
2. Filter by "Environment variables"
3. Review recent changes

**Red flags**:
- Variables added/modified by unknown users
- Secure flags removed from sensitive variables
- Unexpected variable deletions

### 5. Use Different Credentials for Dev/Prod

**Never** use the same credentials for dev and prod environments:

| Service | Dev Credential | Prod Credential |
|---------|----------------|-----------------|
| Supabase | Dev project | Prod project |
| Mixpanel | Dev project token | Prod project token |
| Sentry | Dev DSN | Prod DSN |
| TrainingPeaks | Sandbox API | Production API |

This ensures a compromised dev environment doesn't affect production.

---

## Troubleshooting

### Problem: "Environment variable group not found"

**Symptom**: Build fails with error like:
```
Error: Environment variable group 'supabase_dev' not found
```

**Solution**:
1. Verify group name in `codemagic.yaml` matches exactly (case-sensitive)
2. Check group exists in **Team settings** > **Global variables and secrets**
3. Ensure workflow references correct group name

**Example fix** in `codemagic.yaml`:
```yaml
# Before (wrong)
groups:
  - supabase_dev

# After (correct)
groups:
  - mealvana_dev
```

---

### Problem: "Environment variable not set"

**Symptom**: Build fails with:
```
Error: SUPABASE_URL is not set
```

**Solution**:
1. Open the environment variable group
2. Verify the variable exists with correct name (case-sensitive)
3. Ensure variable has a value (not empty)
4. Check workflow includes the correct group

---

### Problem: Firebase configuration fails

**Symptom**:
```
google-services.json not found
or
Failed to decode Firebase configuration
```

**Solutions**:

**A. Variable not base64 encoded correctly**:
- DO: Store plain JSON in Codemagic (workflow handles encoding)
- DON'T: Manually base64 encode before adding to Codemagic

**B. JSON is invalid**:
1. Copy the variable value
2. Paste into [jsonlint.com](https://jsonlint.com)
3. Fix any JSON syntax errors
4. Re-add to Codemagic

**C. Variable marked as secure (good) but not loading**:
- Verify workflow script uses correct variable name:
  ```bash
  echo "$ANDROID_FIREBASE_JSON" | base64 --decode > android/app/google-services.json
  ```

---

### Problem: Shorebird authentication fails

**Symptom**:
```
Error: Invalid Shorebird token
or
Error: Not authorized to create releases
```

**Solutions**:

**A. Generate new CI token**:
```bash
shorebird login
shorebird login:ci
```

**B. Update in Codemagic**:
1. Open `shorebird_credentials` group
2. Delete old `SHOREBIRD_TOKEN` variable
3. Add new variable with fresh token
4. Ensure marked as "Secure"

**C. Verify organization access**:
- Ensure your Shorebird account has access to the app
- Check on [console.shorebird.dev](https://console.shorebird.dev)

---

### Problem: App Store Connect integration fails

**Symptom**:
```
Error: App Store Connect authentication failed
or
Error: Invalid API key
```

**Solutions**:

**A. Verify integration name matches**:
```yaml
# codemagic.yaml
integrations:
  app_store_connect: Mealvana  # Must match exactly
```

**B. Re-create integration**:
1. Delete existing integration in Codemagic
2. Get fresh .p8 key from App Store Connect
3. Create new integration with exact name `Mealvana`

**C. Check API key permissions**:
- In App Store Connect > Users and Access > Keys
- Ensure key has "Admin" or "App Manager" access
- Verify key is not expired or revoked

---

### Problem: Google Play publishing fails

**Symptom**:
```
Error: Insufficient permissions to publish
or
Error: Service account not authorized
```

**Solutions**:

**A. Grant access in Google Play Console**:
1. Go to Google Play Console > API access
2. Find service account
3. Click "Grant access"
4. Ensure "Releases" permission is checked
5. Click "Invite user" > "Send invite"

**B. Verify service account key is valid**:
1. Check JSON key structure is complete (from `{` to `}`)
2. Ensure `private_key` field includes full key with `-----BEGIN PRIVATE KEY-----` header

**C. Wait for permission propagation**:
- Google Play permissions can take 10-30 minutes to activate
- Retry build after waiting

---

### Problem: Multi-line value formatting issues

**Symptom**: Long values (like TrainingPeaks scopes) are truncated or wrapped incorrectly.

**Solution**:
1. Copy the entire value in one continuous line (no line breaks)
2. Paste into Codemagic variable value field
3. Don't add quotes around the value
4. Verify by checking character count matches expected length

**Example**:
```
# Correct (one line)
athlete:profile events:read events:write file:write metrics:read...

# Wrong (split across lines)
athlete:profile events:read
events:write file:write metrics:read...
```

---

### Problem: Special characters in passwords

**Symptom**: Build fails with authentication errors for Final Surge or other services with complex passwords.

**Solution**:
- Copy password exactly as-is (including `#`, `$`, `?`, `*`, etc.)
- Don't add extra escaping or quotes
- Codemagic handles special characters automatically
- Mark as "Secure" to prevent logging issues

**Example**:
```bash
# Password: 65kj$#deujXLk3h?mpkm*V94X$dkb2$u78H35-Sc#$es#^C2e5^pMat3*2QAe7+$

# Correct in Codemagic
FINAL_SURGE_CLIENT_SECRET = 65kj$#deujXLk3h?mpkm*V94X$dkb2$u78H35-Sc#$es#^C2e5^pMat3*2QAe7+$

# Wrong (adding quotes or escaping)
FINAL_SURGE_CLIENT_SECRET = "65kj\$\#deujXLk3h..."  # Don't do this
```

---

## Complete Checklist

Use this checklist to verify your setup is complete:

### Environment Variable Groups

- [ ] **mealvana_dev** group created (24 variables)
  - [ ] SUPABASE_URL
  - [ ] SUPABASE_ANON_KEY
  - [ ] SUPABASE_SERVICE_ROLE_KEY (secure)
  - [ ] MIXPANEL_PROJECT_TOKEN
  - [ ] SENTRY_DSN (secure)
  - [ ] SENTRY_ENVIRONMENT
  - [ ] LOCATIONIQ_API_KEY
  - [ ] ACTIVE_COM_API_KEY
  - [ ] WIREDASH_PROJECT_ID
  - [ ] WIREDASH_SECRET (secure)
  - [ ] ONESIGNAL_APP_ID
  - [ ] TRAININGPEAKS_CLIENT_ID
  - [ ] TRAININGPEAKS_CLIENT_SECRET (secure)
  - [ ] TRAININGPEAKS_OAUTH_URL
  - [ ] TRAININGPEAKS_API_URL
  - [ ] TRAININGPEAKS_SCOPES
  - [ ] FINAL_SURGE_CLIENT_ID
  - [ ] FINAL_SURGE_CLIENT_SECRET (secure)
  - [ ] FINAL_SURGE_BASE_URL
  - [ ] FINAL_SURGE_REDIRECT_URI
  - [ ] DEV_MODE_ENABLED
  - [ ] APP_ENV
  - [ ] APP_ENVIRONMENT

- [ ] **mealvana_prod** group created (24 variables)
  - [ ] All same variables as dev (with prod values)
  - [ ] Verify different URLs for Supabase, Mixpanel, Sentry
  - [ ] Verify TrainingPeaks uses production URLs (not sandbox)
  - [ ] Verify Final Surge redirect URI uses `mealvana://` scheme

- [ ] **firebase_config** group created (1 variable)
  - [ ] ANDROID_FIREBASE_JSON (secure, plain JSON format)

- [ ] **shorebird_credentials** group created (1 variable)
  - [ ] SHOREBIRD_TOKEN (secure)

- [ ] **google_play_credentials** group created (1 variable)
  - [ ] GCLOUD_SERVICE_ACCOUNT_CREDENTIALS (secure, full JSON key)

### Integrations

- [ ] **App Store Connect** integration created
  - [ ] Integration name: `Mealvana`
  - [ ] Issuer ID configured
  - [ ] Key ID configured
  - [ ] .p8 API key uploaded
  - [ ] Status shows "Active"

### Workflow Configuration

- [ ] `codemagic.yaml` updated to reference correct group names
  - [ ] `supabase_dev` → `mealvana_dev`
  - [ ] `supabase_prod` → `mealvana_prod`
  - [ ] Removed `app_store_credentials` group references
  - [ ] All workflows include required groups

### Security Configuration

- [ ] All service role keys marked as "Secure"
- [ ] All client secrets marked as "Secure"
- [ ] All DSNs marked as "Secure"
- [ ] All JSON credentials marked as "Secure"
- [ ] Shorebird token marked as "Secure"

### Testing

- [ ] PR validation workflow tested (no env vars)
- [ ] Dev integration test workflow tested
- [ ] Firebase configuration tested (Android build)
- [ ] iOS build tested (legacy or Shorebird)
- [ ] Android build tested (legacy or Shorebird)

### Documentation

- [ ] Team members know where to find credentials
- [ ] Credential rotation process documented
- [ ] Emergency contacts identified (who can reset credentials)
- [ ] Backup copies of service account keys stored securely

---

## Quick Reference: Variable by Workflow

| Workflow | Required Groups |
|----------|-----------------|
| `integration-tests` | `mealvana_dev` |
| `integration-test-quick` | `mealvana_dev` |
| `ios-shorebird-release` | `mealvana_prod`, `shorebird_credentials` |
| `ios-shorebird-patch` | `mealvana_prod`, `shorebird_credentials` |
| `android-shorebird-release` | `mealvana_prod`, `shorebird_credentials`, `google_play_credentials`, `firebase_config` |
| `android-shorebird-patch` | `mealvana_prod`, `shorebird_credentials`, `firebase_config` |
| `pr-validation` | None |
| `ios-build-legacy` | `mealvana_prod` |
| `android-build-legacy` | `mealvana_prod`, `google_play_credentials`, `firebase_config` |

---

## Additional Resources

- [Codemagic Environment Variables Documentation](https://docs.codemagic.io/yaml-basic-configuration/configuring-environment-variables/)
- [Codemagic Team Settings](https://docs.codemagic.io/knowledge-codemagic/teams/)
- [Shorebird CI/CD Setup](https://docs.shorebird.dev/code-push/ci/codemagic/)
- [App Store Connect API Keys](https://developer.apple.com/documentation/appstoreconnectapi/creating_api_keys_for_app_store_connect_api)
- [Google Play Console API Access](https://developers.google.com/android-publisher/getting_started)

---

**Last Updated**: 2025-12-18
**Maintainer**: Development Team
**Version**: 1.0.0

---

**Questions or Issues?**

If you encounter issues not covered in this guide:

1. Check Codemagic build logs for specific error messages
2. Verify all credentials are current and not expired
3. Review the troubleshooting section above
4. Contact the development team for assistance

**Success Criteria**: All workflows should run successfully with proper environment variable configuration. Test each workflow at least once to verify setup.
