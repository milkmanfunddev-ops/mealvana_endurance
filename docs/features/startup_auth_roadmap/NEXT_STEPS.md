# Native OAuth - Remaining Manual Steps

**Status:** ✅ Client app files configured | ⚠️ Console/dashboard setup required
**Updated:** November 18, 2025

---

## ✅ What's Already Done

### Client App Configuration
- ✅ `.env` updated with Web and iOS client IDs
- ✅ `android/app/src/main/res/values/strings.xml` updated
- ✅ `ios/Runner/Info.plist` updated with iOS client ID and reversed URL scheme
- ✅ Android debug keystore at `/secrets/google/debug.keystore`
- ✅ SHA-1 fingerprint: `BE:B9:37:51:39:7E:AE:C9:6A:D7:63:29:6E:34:5A:1D:CD:2A:CB:AA`

### Apple Configuration
- ✅ Services ID: `com.milkman.mealvanaendurance.auth`
- ✅ Private key (.p8): `/secrets/apple/AuthKey_Z875MDK9BR.p8`
- ✅ Key ID: `Z875MDK9BR`

### Google Configuration
- ✅ Web Client ID: `171527646530-d1hr8a9ja4ucqk28cjpcfnlo288qhccn.apps.googleusercontent.com`
- ✅ iOS Client ID: `171527646530-g0u0p8e6vuipqbc5j4svl3j9149u597n.apps.googleusercontent.com`
- ⚠️ iOS Bundle ID: **MUST FIX** - Currently shows `com.example.mealvanaEndurance`, should be `com.milkman.mealvanaendurance`

---

## 🚨 CRITICAL: Required Manual Steps

### Step 1: Fix Google iOS Client Bundle ID (URGENT)

**Why:** The iOS client was created with the wrong bundle ID.

1. Go to [Google Cloud Console - Credentials](https://console.cloud.google.com/apis/credentials)
2. Find "iOS client" and click **Edit**
3. Change Bundle ID from `com.example.mealvanaEndurance` to `com.milkman.mealvanaendurance`
4. Click **Save**

---

### Step 2: Create Android OAuth Client in Google Cloud Console

**Required for Android app to work.**

1. Go to [Google Cloud Console - Credentials](https://console.cloud.google.com/apis/credentials)
2. Click **Create Credentials** → **OAuth client ID**
3. Select **Application type:** Android
4. Configure:
   - **Name:** Mealvana Endurance Android Debug
   - **Package name:** `com.milkman.mealvanaendurance`
   - **SHA-1 certificate fingerprint:** `BE:B9:37:51:39:7E:AE:C9:6A:D7:63:29:6E:34:5A:1D:CD:2A:CB:AA`
5. Click **Create**
6. **Copy the generated Client ID** (format: `XXXXXXXXX-YYYYY.apps.googleusercontent.com`)

**Then update these files with the new Android Client ID:**
- `.env` line 16: Replace `PENDING_CREATE_IN_GOOGLE_CLOUD.apps.googleusercontent.com`
- `android/app/src/main/res/values/strings.xml` line 24: Replace `PENDING_CREATE_IN_GOOGLE_CLOUD.apps.googleusercontent.com`

---

### Step 3: Update Supabase Google Provider - Authorized Client IDs

**Why:** Supabase needs to trust tokens from ALL your client apps (web, iOS, Android).

1. Go to [Supabase Dashboard - Google Provider](https://supabase.com/dashboard/project/wvmvsodrvbkxfydabqed/auth/providers)
2. Click **Edit** on Google provider
3. In the **"Authorized Client IDs"** field, add ALL client IDs (comma-separated):
   ```
   171527646530-d1hr8a9ja4ucqk28cjpcfnlo288qhccn.apps.googleusercontent.com,171527646530-g0u0p8e6vuipqbc5j4svl3j9149u597n.apps.googleusercontent.com,YOUR_ANDROID_CLIENT_ID_FROM_STEP_2
   ```
   Replace `YOUR_ANDROID_CLIENT_ID_FROM_STEP_2` with the actual Android client ID you created.
4. Click **Save**

---

### Step 4: Get Apple Team ID and Update Supabase Apple Provider

**Find your Team ID:**
1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Look at the top-right corner next to your organization name
3. You'll see something like "Milkman Inc - **9Y99749RG3**"
4. The last part is your Team ID (copy it)

**Update Supabase:**
1. Go to [Supabase Dashboard - Apple Provider](https://supabase.com/dashboard/project/wvmvsodrvbkxfydabqed/auth/providers)
2. Click **Edit** on Apple provider
3. **If you see Team ID and Key ID fields** (scroll down if needed), fill them in:
   - **Team ID:** Your Team ID from step above
   - **Key ID:** `Z875MDK9BR`
4. Verify other fields:
   - **Services ID:** `com.milkman.mealvanaendurance.auth` ✅
   - **Secret Key:** Already filled ✅
   - **Callback URL:** `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback` ✅
5. Click **Save**

**Note:** If you don't see Team ID/Key ID fields, Supabase may be deriving them from the .p8 file automatically. Verify Apple Sign-In is enabled and showing as configured.

---

### Step 5: Complete Apple Services ID Web Authentication

**Why:** Apple needs to know where to redirect after authentication.

1. Go to [Apple Developer Portal - Services IDs](https://developer.apple.com/account/resources/identifiers/list/serviceid)
2. Click on **"Mealvana Endurance Auth"** (`com.milkman.mealvanaendurance.auth`)
3. Check **Sign in with Apple** checkbox
4. Click **Configure** button next to it
5. In the modal, fill in:
   - **Primary App ID:** Select `com.milkman.mealvanaendurance` from dropdown
   - **Domains and Subdomains:** `wvmvsodrvbkxfydabqed.supabase.co`
   - **Return URLs:** `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`
6. Click **Save**
7. Click **Continue**
8. Click **Save** again on the main Services ID page

---

### Step 6: Add Sign in with Apple Capability in Xcode

**⚠️ CRITICAL:** This MUST be done manually in Xcode (cannot be done via files).

1. Open the iOS project in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. Select the **Runner** target in the left sidebar
3. Click the **Signing & Capabilities** tab
4. Click the **+ Capability** button (top-left of the capabilities section)
5. Search for **"Sign in with Apple"**
6. Double-click to add it
7. Verify it appears in the capabilities list
8. Close Xcode (changes are saved automatically)

---

## 📋 Post-Configuration Checklist

After completing all steps above:

**Google Cloud Console:**
- [ ] iOS client bundle ID is `com.milkman.mealvanaendurance`
- [ ] Android debug client created with correct SHA-1
- [ ] All 3 client IDs documented (web, iOS, Android)

**Supabase Dashboard:**
- [ ] Google provider enabled
- [ ] Google "Authorized Client IDs" includes all 3 client IDs
- [ ] Apple provider enabled
- [ ] Apple Team ID and Key ID configured (if fields visible)

**Apple Developer Portal:**
- [ ] Services ID web authentication configured
- [ ] Domains and return URLs match Supabase exactly

**Client App:**
- [ ] `.env` updated with Android client ID
- [ ] `android/app/src/main/res/values/strings.xml` updated with Android client ID
- [ ] Xcode Sign in with Apple capability added

**Testing:**
- [ ] Run `flutter pub get`
- [ ] Run `dart run build_runner build --delete-conflicting-outputs`
- [ ] App builds successfully on iOS and Android
- [ ] Test Google Sign-In on both platforms
- [ ] Test Apple Sign-In on iOS physical device (requires real Apple ID)

---

## 🚀 Testing Commands

```bash
# Install dependencies
flutter pub get

# Generate Riverpod code
dart run build_runner build --delete-conflicting-outputs

# Run on iOS simulator
flutter run -d "iPhone 15"

# Run on Android emulator
flutter run -d emulator-5554
```

---

## 📚 Reference Information

### Android Debug Keystore Location
- **Path:** `/secrets/google/debug.keystore`
- **SHA-1:** `BE:B9:37:51:39:7E:AE:C9:6A:D7:63:29:6E:34:5A:1D:CD:2A:CB:AA`
- **Alias:** `androiddebugkey`
- **Password:** `android`

### Apple Credentials
- **Team ID:** Get from Apple Developer Portal (top-right)
- **Key ID:** `Z875MDK9BR`
- **Private Key:** `/secrets/apple/AuthKey_Z875MDK9BR.p8`
- **Services ID:** `com.milkman.mealvanaendurance.auth`

### Google Client IDs
- **Web:** `171527646530-d1hr8a9ja4ucqk28cjpcfnlo288qhccn.apps.googleusercontent.com`
- **iOS:** `171527646530-g0u0p8e6vuipqbc5j4svl3j9149u597n.apps.googleusercontent.com`
- **Android Debug:** Create in Step 2, then update files
- **Android Release:** Create later with release keystore SHA-1

### Supabase Project
- **Project ID:** `wvmvsodrvbkxfydabqed`
- **URL:** `https://wvmvsodrvbkxfydabqed.supabase.co`
- **Callback:** `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`

---

## 🆘 Troubleshooting

### "Invalid client ID" error
- **Cause:** Client ID not in Supabase "Authorized Client IDs"
- **Fix:** Add to Supabase Google provider settings (Step 3)

### "12500: Sign in cancelled" on Android
- **Cause:** SHA-1 fingerprint doesn't match
- **Fix:** Verify SHA-1 in Google Cloud Console matches `BE:B9:37:51:39:7E:AE:C9:6A:D7:63:29:6E:34:5A:1D:CD:2A:CB:AA`

### Apple Sign-In not available
- **Cause:** Missing Xcode capability
- **Fix:** Complete Step 6 above

### iOS Google Sign-In error
- **Cause:** Wrong bundle ID in Google Cloud
- **Fix:** Complete Step 1 (fix bundle ID)

---

## 📞 Next Actions

**Immediate (before testing):**
1. Complete Steps 1-6 above
2. Update `.env` and `strings.xml` with Android client ID from Step 2
3. Run `flutter pub get` and `dart run build_runner build`

**For Production Release:**
1. Create Android release client with release keystore SHA-1
2. Add release client ID to Supabase "Authorized Client IDs"
3. Update `.env.prod.local` with release Android client ID
4. Schedule Apple .p8 key rotation (6 months from now)

---

**Document Version:** 1.0
**Last Updated:** November 18, 2025
**Status:** Ready for manual configuration steps
