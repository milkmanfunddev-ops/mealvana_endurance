# Secrets and Environment Configuration

Complete reference for all secrets and environment variables required for Mealvana Endurance CI/CD.

## Overview

Secrets are stored in two places:
1. **Codemagic** - For mobile app builds
2. **GitHub Actions** - For backend deployments

## Codemagic Environment Variables

### Required Groups

Create these groups in Codemagic → Team Settings → Global Variables and Secrets:

#### 1. `supabase_dev` (Development Environment)

| Variable | Value | Secure |
|----------|-------|--------|
| `SUPABASE_URL` | `https://[dev-project].supabase.co` | No |
| `SUPABASE_ANON_KEY` | `eyJhbGc...` (JWT) | Yes |

**Used by:** Integration tests, dev builds

#### 2. `supabase_prod` (Production Environment)

| Variable | Value | Secure |
|----------|-------|--------|
| `SUPABASE_URL` | `https://wvmvsodrvbkxfydabqed.supabase.co` | No |
| `SUPABASE_ANON_KEY` | `eyJhbGc...` (JWT) | Yes |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJhbGc...` (JWT) | Yes |

**Used by:** iOS builds, Android builds

#### 3. `shorebird_credentials` (OTA Updates)

| Variable | Value | Secure |
|----------|-------|--------|
| `SHOREBIRD_TOKEN` | (from `shorebird login:ci`) | Yes |

**Used by:** Shorebird release and patch workflows

**How to generate:**
```bash
shorebird login:ci
# Copy the output token
```

#### 4. `app_store_credentials` (iOS Distribution)

This is configured via Codemagic integrations, not environment variables.

**Setup:**
1. Go to Team Settings → Integrations → Developer Portal
2. Add App Store Connect API key
3. Name it: `Mealvana`
4. Required role: **App Manager** (not Developer)

**Required info:**
- Key ID (from App Store Connect)
- Issuer ID (from App Store Connect)
- Private key (.p8 file)

#### 5. `google_play_credentials` (Android Distribution)

| Variable | Value | Secure |
|----------|-------|--------|
| `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` | `{"type": "service_account", ...}` | Yes |

**How to generate:**
1. Go to Google Cloud Console
2. Create service account with "Service Account User" role
3. Generate JSON key
4. Enable Google Play API
5. Add service account to Play Console with release access

### App-Level Variables

These are set directly on the app in Codemagic (not in groups):

| Variable | Current Value | Notes |
|----------|---------------|-------|
| `APP_ENV` | `prod` | Environment flag |
| `DEV_MODE_ENABLED` | `false` | Feature toggle |
| `SENTRY_DSN` | `https://...@sentry.io/...` | Error tracking |
| `SENTRY_ENVIRONMENT` | `production` | Sentry env |
| `MIXPANEL_PROJECT_TOKEN` | `bd8fe50b...` | Analytics |
| `GOOGLE_IOS_CLIENT_ID` | `171527...` | Google Sign-In |
| `GOOGLE_ANDROID_CLIENT_ID` | `171527...` | Google Sign-In |
| `GOOGLE_WEB_CLIENT_ID` | `171527...` | Google Sign-In |
| `USDA_API_KEY` | `tQo3xq...` | Food database |
| `ACTIVE_COM_API_KEY` | `me46yg...` | Event search |
| `LOCATIONIQ_API_KEY` | `pk.16aad...` | Geocoding |
| `TRAININGPEAKS_CLIENT_ID` | `mealvana` | TrainingPeaks OAuth |
| `TRAININGPEAKS_CLIENT_SECRET` | `CSBPmj...` | TrainingPeaks OAuth |
| `TRAININGPEAKS_SCOPES` | `athlete:profile...` | OAuth scopes |

### Variables to Review/Remove

These variables in your current config may be incorrect or unused:

| Variable | Issue |
|----------|-------|
| `SUPABASE_SECRET_KEY` | Format looks like Stripe, not Supabase |
| `SUPABASE_PUBLISHABLE_KEY` | Format looks like Stripe, not Supabase |

**Action:** Verify if these are needed. If for Stripe, rename appropriately. If not needed, remove.

---

## GitHub Actions Secrets

### Repository Secrets

Configure in GitHub → Settings → Secrets and variables → Actions

| Secret | Purpose | How to Get |
|--------|---------|------------|
| `SUPABASE_ACCESS_TOKEN` | CLI authentication | `supabase login` |
| `DEV_PROJECT_ID` | Dev Supabase project | Dashboard → Settings → General |
| `DEV_DB_PASSWORD` | Dev database | Dashboard → Settings → Database |
| `DEV_SUPABASE_URL` | Dev API URL | Dashboard → Settings → API |
| `DEV_ANON_KEY` | Dev anonymous key | Dashboard → Settings → API |
| `PROD_PROJECT_ID` | Prod Supabase project | Dashboard → Settings → General |
| `PROD_DB_PASSWORD` | Prod database | Dashboard → Settings → Database |
| `CODECOV_TOKEN` | Coverage reporting | codecov.io dashboard |

### Environment Secrets

Configure in GitHub → Settings → Environments

**Development Environment:**
- No secrets required (uses repository secrets)
- No approval required

**Production Environment:**
- Configure required reviewers
- Same secrets as repository (or override)

---

## Generating Secrets

### Supabase Access Token

```bash
supabase login
# Opens browser for authentication
# Token is copied to clipboard
# Paste into GitHub secret: SUPABASE_ACCESS_TOKEN
```

### Shorebird Token

```bash
shorebird login:ci
# Output: SHOREBIRD_TOKEN=<base64-token>
# Copy entire value to Codemagic
```

### App Store Connect API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Users and Access → Integrations → App Store Connect API
3. Click + to generate new key
4. **Select Role: App Manager** (required for publishing)
5. Download .p8 file (only available once!)
6. Note Key ID and Issuer ID
7. Add to Codemagic Developer Portal integration

### Google Play Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create or select project
3. APIs & Services → Enable "Google Play Android Developer API"
4. IAM & Admin → Service Accounts → Create
5. Grant role: "Service Account User"
6. Create JSON key → Download
7. Go to [Play Console](https://play.google.com/console)
8. Setup → API access → Link Google Cloud project
9. Add service account with "Release Manager" permission
10. Paste JSON into Codemagic as `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS`

---

## Security Best Practices

1. **Never commit secrets to git**
   - Use `.env.local` files locally
   - Add `.env*` to `.gitignore`

2. **Rotate secrets regularly**
   - Supabase keys: When compromised
   - API keys: Annually
   - Certificates: Before expiration (check App Store Connect)

3. **Use minimal permissions**
   - Service accounts: Only needed scopes
   - API keys: Restrict to specific services

4. **Audit access**
   - Review Codemagic team members quarterly
   - Review GitHub collaborators

5. **Mark secrets as Secure**
   - Always enable "Secure" in Codemagic
   - Values hidden in logs

---

## Environment Variable Usage in Code

### Flutter App

```dart
// lib/shared/services/app_config.dart
class AppConfig {
  static String get supabaseUrl =>
    const String.fromEnvironment('SUPABASE_URL');

  static String get supabaseAnonKey =>
    const String.fromEnvironment('SUPABASE_ANON_KEY');
}
```

### Build Command

```yaml
- name: Build iOS
  script: |
    flutter build ipa --release \
      --dart-define=SUPABASE_URL=$SUPABASE_URL \
      --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
      --dart-define=SENTRY_DSN=$SENTRY_DSN
```

---

## Checklist: Setting Up Fresh Environment

### Codemagic

- [ ] Create `supabase_dev` group with dev credentials
- [ ] Create `supabase_prod` group with prod credentials
- [ ] Create `shorebird_credentials` group with token
- [ ] Add App Store Connect API key integration (name: "Mealvana")
- [ ] Create `google_play_credentials` group with service account JSON
- [ ] Add all app-level variables (Sentry, Mixpanel, etc.)
- [ ] Verify YAML groups match created groups

### GitHub Actions

- [ ] Add `SUPABASE_ACCESS_TOKEN` secret
- [ ] Add dev environment secrets
- [ ] Add prod environment secrets
- [ ] Create "production" environment with required reviewers
- [ ] Add Codecov token (optional)

### Verification

- [ ] Trigger test workflow manually
- [ ] Verify dev deployment works
- [ ] Test iOS build (may fail code signing initially)
- [ ] Review all error messages for missing secrets
