# Dev/Prod Setup - Lee's Action Items

## Overview

This document contains **ALL** the manual tasks that require your direct action to set up the dev/prod environment. Everything here needs to be done by you - these cannot be automated and require access to external services, credentials, and GitHub settings.

---

## ✅ Prerequisites (One-Time Setup)

### 1. Install Supabase CLI

**Already Done** ✅ (you mentioned Supabase CLI is already running)

Verify it's working:
```bash
supabase --version
```

### 2. Ensure Git Branch Structure

**What You Need To Do:**

Currently you only have `main` branch. You need to create:

```bash
# Create develop branch from main
git checkout -b develop
git push -u origin develop

# This will be your primary development branch
# All development work happens here
# Auto-deploys to dev environment when pushed
```

**Branch Strategy:**
- `main` - Production (manual approval required)
- `develop` - Development (auto-deploys to dev)

---

## 🎯 Phase 1: Supabase Projects Setup

### 1.1 Create Development Supabase Project

**Where:** https://database.new

**Steps:**
1. Click "New Project"
2. Fill in:
   - **Organization**: Your existing org
   - **Name**: `Mealvana Endurance - Dev`
   - **Database Password**: Generate a strong password (save this!)
   - **Region**: `us-east-2` (same as your current prod)
   - **Pricing Plan**: Free tier is fine for dev

**What To Save:**
```
DEV_PROJECT_ID=<project-ref>           # e.g., "abcdefghijklmnop"
DEV_DB_PASSWORD=<database-password>    # Generated password
DEV_SUPABASE_URL=https://<project-ref>.supabase.co
DEV_ANON_KEY=<anon-key>                # From Settings → API
DEV_SERVICE_ROLE_KEY=<service-key>     # From Settings → API
```

**Where to find the keys:**
1. Go to new project
2. Settings → API
3. Copy:
   - Project URL
   - `anon` `public` key (long JWT starting with eyJ...)
   - `service_role` key (different JWT)

### 1.2 Rename Existing Production Project

**Where:** https://supabase.com/dashboard/project/wvmvsodrvbkxfydabqed

**Steps:**
1. Go to Settings → General
2. **Current name:** "Mealvana Endurance"
3. **Change to:** "Mealvana Endurance - Production"
4. Click Save

**What To Save:**
```
PROD_PROJECT_ID=wvmvsodrvbkxfydabqed   # (already known)
PROD_DB_PASSWORD=<your-current-password>
PROD_SUPABASE_URL=https://wvmvsodrvbkxfydabqed.supabase.co
PROD_ANON_KEY=<anon-key>
PROD_SERVICE_ROLE_KEY=<service-key>
```

### 1.3 Get Supabase Personal Access Token

**Where:** https://supabase.com/dashboard/account/tokens

**Steps:**
1. Click "Generate new token"
2. Name: `GitHub Actions - Mealvana`
3. Copy the token immediately (you can't view it again)

**What To Save:**
```
SUPABASE_ACCESS_TOKEN=sbp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

---

## 🔐 Phase 2: Create Local Environment Files

### 2.1 Create `.env.dev.local`

**Location:** Root of your project

**File:** `.env.dev.local`

```bash
# Development Environment - KEEP THIS FILE SECRET
# This file should NEVER be committed to git

# Supabase (Dev Project)
SUPABASE_URL=https://<DEV_PROJECT_ID>.supabase.co
SUPABASE_ANON_KEY=<DEV_ANON_KEY>
SUPABASE_SERVICE_ROLE_KEY=<DEV_SERVICE_ROLE_KEY>

# Analytics (Dev Mixpanel)
MIXPANEL_PROJECT_TOKEN=df6e8dd4f3dc1363fa194a156298b16c

# Error Tracking (Dev Sentry - already configured)
SENTRY_DSN=https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328
SENTRY_ENVIRONMENT=development

# Feature Flags
DEV_MODE_ENABLED=true
APP_ENV=dev
```

**Replace:**
- `<DEV_PROJECT_ID>` with your dev project ref from 1.1
- `<DEV_ANON_KEY>` with the anon key from 1.1
- `<DEV_SERVICE_ROLE_KEY>` with service role key from 1.1

### 2.2 Create `.env.prod.local`

**Location:** Root of your project

**File:** `.env.prod.local`

```bash
# Production Environment - KEEP THIS FILE SECRET
# This file should NEVER be committed to git

# Supabase (Production Project)
SUPABASE_URL=https://wvmvsodrvbkxfydabqed.supabase.co
SUPABASE_ANON_KEY=<PROD_ANON_KEY>
SUPABASE_SERVICE_ROLE_KEY=<PROD_SERVICE_ROLE_KEY>

# Analytics (Production Mixpanel)
MIXPANEL_PROJECT_TOKEN=bd8fe50bb67b1dd0860351e6297347db

# Error Tracking (Production Sentry)
SENTRY_DSN=https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328
SENTRY_ENVIRONMENT=production

# Feature Flags
DEV_MODE_ENABLED=false
APP_ENV=prod
```

**Replace:**
- `<PROD_ANON_KEY>` with the anon key from 1.2
- `<PROD_SERVICE_ROLE_KEY>` with service role key from 1.2

### 2.3 Set Active Environment

**What You Need To Do:**

Copy one of the env files to `.env` (this is what gets loaded):

```bash
# For local development, use dev:
cp .env.dev.local .env

# When you need to test prod config:
cp .env.prod.local .env
```

**Note:** `.env` is gitignored, so you can safely switch between environments

---

## 🔑 Phase 3: Configure GitHub Secrets

### 3.1 Navigate to GitHub Secrets

**Where:** https://github.com/YOUR_USERNAME/mealvana_endurance/settings/secrets/actions

(Replace YOUR_USERNAME with your actual GitHub username)

### 3.2 Add Repository Secrets

Click "New repository secret" for each of these:

#### Supabase Secrets

**Name:** `SUPABASE_ACCESS_TOKEN`
**Value:** `<from step 1.3>`

**Name:** `DEV_PROJECT_ID`
**Value:** `<from step 1.1>` (e.g., "abcdefghijklmnop")

**Name:** `DEV_DB_PASSWORD`
**Value:** `<from step 1.1>`

**Name:** `PROD_PROJECT_ID`
**Value:** `wvmvsodrvbkxfydabqed`

**Name:** `PROD_DB_PASSWORD`
**Value:** `<from step 1.2>`

---

## 📱 Phase 4: Test Your Setup

### 4.1 Test Local Development Build

```bash
# Use dev environment
cp .env.dev.local .env

# Run the app
flutter run

# Verify it connects to DEV Supabase project
```

### 4.2 Test Supabase CLI Linking

```bash
# Link to dev project
supabase link --project-ref <DEV_PROJECT_ID>

# Enter your SUPABASE_ACCESS_TOKEN when prompted
# Enter DEV_DB_PASSWORD when prompted

# Check status
supabase status

# Should show linked to dev project
```

### 4.3 Test Production Build (Don't Deploy Yet)

```bash
# Use prod environment
cp .env.prod.local .env

# Just test that it compiles (don't deploy)
flutter build ios --release  # If on Mac
# OR
flutter build apk --release  # If on Linux/Windows

# This verifies prod config is correct
```

---

## ✅ Phase 5: Verify GitHub Actions

### 5.1 Test Auto-Deploy to Dev

```bash
# Switch to develop branch
git checkout develop

# Make a small change (e.g., add comment to a migration file)
# Push to develop
git add .
git commit -m "Test dev auto-deploy"
git push origin develop

# Watch GitHub Actions
# Go to: https://github.com/YOUR_USERNAME/mealvana_endurance/actions
# Should see "Deploy to Dev" workflow running
```

### 5.2 Configure Production Environment Protection

**Where:** https://github.com/YOUR_USERNAME/mealvana_endurance/settings/environments

**Steps:**
1. Click "New environment"
2. Name: `production`
3. Check "Required reviewers"
4. Add yourself as a reviewer
5. Save protection rules

**Result:** Now pushing to `main` will require your manual approval before deploying

---

## 📋 Checklist Summary

Use this to track your progress:

### Supabase Projects
- [ ] Created dev Supabase project
- [ ] Renamed prod Supabase project
- [ ] Collected all dev credentials (project ID, password, anon key, service key)
- [ ] Collected all prod credentials (project ID, password, anon key, service key)
- [ ] Generated Supabase personal access token

### Git Branches
- [ ] Created `develop` branch
- [ ] Pushed `develop` to origin

### Local Environment Files
- [ ] Created `.env.dev.local` with dev credentials
- [ ] Created `.env.prod.local` with prod credentials
- [ ] Copied one to `.env` for active use
- [ ] Verified `.env` and `.env.*.local` are in `.gitignore`

### GitHub Secrets
- [ ] Added `SUPABASE_ACCESS_TOKEN`
- [ ] Added `DEV_PROJECT_ID`
- [ ] Added `DEV_DB_PASSWORD`
- [ ] Added `PROD_PROJECT_ID`
- [ ] Added `PROD_DB_PASSWORD`

### GitHub Environment Protection
- [ ] Created `production` environment
- [ ] Added required reviewer (yourself)

### Testing
- [ ] Tested local dev build with `.env.dev.local`
- [ ] Tested Supabase CLI linking to dev project
- [ ] Tested that prod config compiles
- [ ] Pushed to `develop` and verified auto-deploy works
- [ ] Verified production requires manual approval

---

## 🔒 Security Best Practices

**NEVER commit these files:**
- `.env`
- `.env.dev.local`
- `.env.prod.local`
- Any file containing credentials

**Safe to commit:**
- `.env.dev.template` (no secrets, just structure)
- `.env.prod.template` (no secrets, just structure)

**Credentials Storage:**

Consider using a password manager:
- 1Password
- Bitwarden
- LastPass

Create a secure note with all your credentials from this setup.

---

## 📞 Need Help?

If you get stuck on any step:

1. **Supabase Issues:** Check https://supabase.com/docs
2. **GitHub Actions Issues:** Check workflow logs at https://github.com/YOUR_USERNAME/mealvana_endurance/actions
3. **Environment Issues:** Run `flutter doctor` and `supabase --version`

---

**Last Updated:** 2025-10-06
**Status:** Ready for your action
