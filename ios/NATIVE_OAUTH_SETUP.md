# iOS Native OAuth Setup Instructions

## Required Manual Steps in Xcode

### 1. Sign in with Apple Capability

**⚠️ IMPORTANT:** This capability MUST be added manually in Xcode. It cannot be configured via files.

**Steps:**
1. Open the project in Xcode: `open ios/Runner.xcworkspace`
2. Select the **Runner** target in the project navigator
3. Click the **Signing & Capabilities** tab
4. Click **+ Capability** button
5. Search for and add **Sign in with Apple**
6. Verify the capability appears in the capabilities list

**Why This Matters:**
- Without this capability, Apple Sign-In will fail at runtime
- This adds the required entitlement to your app's provisioning profile
- Must be configured for BOTH Debug and Release configurations

### 2. Google Sign-In Client IDs

**File to Update:** `ios/Runner/Info.plist`

**What to Replace:**
- `GIDClientID`: Your iOS client ID from Google Cloud Console
- `CFBundleURLSchemes`: Reversed client ID (e.g., `com.googleusercontent.apps.123456789`)

**Steps:**
1. Go to [Google Cloud Console - Credentials](https://console.cloud.google.com/apis/credentials)
2. Select your project (or create one)
3. Create an OAuth 2.0 Client ID for **iOS**:
   - Application type: iOS
   - Bundle ID: `com.milkman.mealvanaendurance`
4. Copy the generated Client ID
5. In `Info.plist`:
   - Replace `YOUR_IOS_CLIENT_ID_HERE.apps.googleusercontent.com` with your full client ID
   - Replace `com.googleusercontent.apps.YOUR_IOS_CLIENT_ID_HERE` with reversed client ID

**Example:**
```xml
<!-- If your iOS client ID is: 123456789-abcdef.apps.googleusercontent.com -->

<key>GIDClientID</key>
<string>123456789-abcdef.apps.googleusercontent.com</string>

<!-- URL Scheme should be: -->
<string>com.googleusercontent.apps.123456789-abcdef</string>
```

### 3. Verify Configuration

**Test Checklist:**
- [ ] Sign in with Apple capability visible in Xcode
- [ ] `GIDClientID` replaced with real iOS client ID
- [ ] Reversed client ID added to `CFBundleURLSchemes`
- [ ] App builds successfully in Xcode
- [ ] No signing errors in Xcode

### 4. Apple Developer Portal Configuration

**For Apple Sign-In:**
1. Go to [Apple Developer Portal - Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)
2. Select your App ID: `com.milkman.mealvanaendurance`
3. Enable **Sign in with Apple** capability
4. Create a **Services ID** (if using web redirect):
   - Identifier: `com.milkman.mealvanaendurance.auth`
   - Add redirect URL: `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`
5. Generate a `.p8` key for Supabase:
   - Create new key with "Sign in with Apple" enabled
   - Download `.p8` file (can only download once!)
   - Note the Key ID and Team ID
   - Store securely in 1Password

### 5. Supabase Dashboard Configuration

See: `/docs/startup_auth_roadmap/SUPABASE_DASHBOARD_CONFIG.md` (to be created)

---

## Troubleshooting

### "Sign in with Apple capability not found"
- Verify you added the capability in Xcode (see step 1 above)
- Check your provisioning profile includes the entitlement
- Regenerate provisioning profile if needed

### "Invalid client ID" error
- Verify client IDs in `Info.plist` match Google Cloud Console exactly
- Ensure no extra spaces or line breaks
- Check reversed client ID format is correct

### "Bundle ID mismatch"
- Confirm bundle ID in Xcode is `com.milkman.mealvanaendurance`
- Verify Google Cloud Console iOS client uses same bundle ID
- Check Apple Developer Portal uses same bundle ID

---

## Reference

- [Google Sign-In iOS Setup](https://developers.google.com/identity/sign-in/ios/start-integrating)
- [Apple Sign-In Documentation](https://developer.apple.com/sign-in-with-apple/get-started/)
- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
