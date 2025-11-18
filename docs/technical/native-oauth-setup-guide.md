# Native OAuth Configuration Guide for Supabase Flutter Apps

Complete step-by-step guide for setting up Google and Apple native OAuth authentication in Flutter apps using Supabase as the backend (Updated for 2024-2025).

## Table of Contents
- [Overview](#overview)
- [Google Cloud Console Configuration](#google-cloud-console-configuration)
- [Apple Developer Console Configuration](#apple-developer-console-configuration)
- [Supabase Dashboard Configuration](#supabase-dashboard-configuration)
- [Flutter Implementation](#flutter-implementation)
- [Troubleshooting Common Issues](#troubleshooting-common-issues)
- [Additional Resources](#additional-resources)

---

## Overview

### What You'll Need
- **Google Cloud Console** account for Google OAuth
- **Apple Developer** account ($99/year) for Apple Sign In
- **Supabase** project with authentication enabled
- Flutter project with these packages:
  - `supabase_flutter`
  - `google_sign_in` (for Google)
  - `sign_in_with_apple` (for Apple)

### Authentication Flow
Native OAuth follows this pattern:
1. User taps "Sign in with Google/Apple"
2. Native SDK opens authentication UI
3. User authenticates with provider
4. App receives ID token and access token
5. Tokens are sent to Supabase via `signInWithIdToken()`
6. Supabase creates/updates user session

---

## Google Cloud Console Configuration

### Step 1: Access Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing project
3. Navigate to **APIs & Services** → **Credentials**

### Step 2: Configure OAuth Consent Screen

1. Click **OAuth consent screen** in left sidebar
2. Choose **External** user type (unless you have Google Workspace)
3. Click **CREATE**
4. Fill in required fields:
   - **App name**: Your app's user-facing name
   - **User support email**: Your email address
   - **Developer contact information**: Your email address
5. Click **SAVE AND CONTINUE**

### Step 3: Configure Scopes

1. Click **ADD OR REMOVE SCOPES**
2. Add these scopes (required for Supabase):
   - `openid` (manually add if not present)
   - `.../auth/userinfo.email` (default)
   - `.../auth/userinfo.profile` (default)
3. Click **UPDATE** → **SAVE AND CONTINUE**

### Step 4: Enable Required API

🚨 **IMPORTANT (2025 Update)**: Only enable **Google People API**
- Search for "Google People API" in APIs & Services
- Click **ENABLE**
- ❌ **DO NOT enable**: Old "Google Sign-In API" or "Identity Toolkit API" (deprecated)

### Step 5: Create OAuth Client IDs

You need **THREE** separate OAuth client IDs for a complete Flutter setup:

#### 5.1 Web Client ID (Required for All Platforms)

1. Click **CREATE CREDENTIALS** → **OAuth client ID**
2. Application type: **Web application**
3. Name: `[Your App Name] Web Client`
4. Add **Authorized JavaScript origins** (optional for native):
   - `https://<project-ref>.supabase.co`
5. Add **Authorized redirect URIs**:
   - `https://<project-ref>.supabase.co/auth/v1/callback`
   - For local development: `http://localhost:3000/auth/v1/callback`
6. Click **CREATE**
7. **📝 SAVE**: Copy **Client ID** and **Client Secret** (you'll need these for Supabase)

**🎯 Key Point**: This Web Client ID is used as the `serverClientId` parameter in Flutter's `GoogleSignIn` configuration.

#### 5.2 Android Client ID

1. Click **CREATE CREDENTIALS** → **OAuth client ID**
2. Application type: **Android**
3. Name: `[Your App Name] Android`
4. **Package name**: Your Flutter app's Android package name
   - Found in `android/app/build.gradle` → `applicationId`
   - Example: `com.example.myapp`
5. **SHA-1 certificate fingerprint**: Add fingerprints for debug and release

##### Getting SHA-1 Fingerprints:

**For Debug Build:**
```bash
# macOS/Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Windows
keytool -list -v -keystore "C:\Users\[USERNAME]\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**For Release Build (using Gradle):**
```bash
cd android
./gradlew signingReport
```

Or in Android Studio:
1. Open Android project in Android Studio
2. Click **Gradle** tab (right side)
3. Navigate to: `Tasks` → `android` → `signingReport`
4. Double-click to run
5. View output in **Run** tab

**For Published Apps:**
- Go to [Google Play Console](https://play.google.com/console)
- Navigate to: **Release** → **Setup** → **App Integrity**
- Copy SHA-1 from **App signing key certificate** section

6. Click **CREATE**
7. **📝 SAVE**: Copy **Client ID**

**⚠️ Common Mistake**: Each package name + SHA-1 combination must be unique across ALL Google Cloud projects. You cannot reuse the same SHA-1 for the same package name in multiple projects.

#### 5.3 iOS Client ID

1. Click **CREATE CREDENTIALS** → **OAuth client ID**
2. Application type: **iOS**
3. Name: `[Your App Name] iOS`
4. **Bundle ID**: Your iOS app's bundle identifier
   - Found in `ios/Runner.xcodeproj/project.pbxproj`
   - Or open in Xcode: **Runner** → **General** → **Bundle Identifier**
   - Example: `com.example.myapp`
5. **App Store ID**: (Optional - add if published)
6. Click **CREATE**
7. **📝 SAVE**: Copy **Client ID**

### Step 6: Summary - What Client IDs Do You Need?

For Flutter apps integrating with Supabase:

| Client Type | Used For | Used In Code |
|------------|----------|--------------|
| **Web Client ID** | Backend authentication, `serverClientId` | `GoogleSignIn(serverClientId: ...)` |
| **Web Client Secret** | Supabase dashboard configuration | Supabase Dashboard only |
| **Android Client ID** | Registered but not used in code | Auto-detected via `google-services.json` |
| **iOS Client ID** | iOS authentication | `GoogleSignIn(clientId: ...)` |

### Common Google OAuth Mistakes

❌ **Mistake #1**: Using Android Client ID as `serverClientId`
✅ **Solution**: Always use the **Web Client ID** as `serverClientId`

❌ **Mistake #2**: Missing SHA-1 fingerprints for release build
✅ **Solution**: Add both debug AND release SHA-1 fingerprints

❌ **Mistake #3**: Enabling deprecated APIs
✅ **Solution**: Only enable "Google People API" (2024-2025)

❌ **Mistake #4**: Providing `clientId` on Android when using `google-services.json`
✅ **Solution**: Set `clientId: null` for Android, only provide for iOS

❌ **Mistake #5**: Reusing SHA-1 across projects
✅ **Solution**: Each package name + SHA-1 must be globally unique

---

## Apple Developer Console Configuration

### Prerequisites

- Apple Developer account ($99/year)
- Access to [Apple Developer Portal](https://developer.apple.com/account/)

### Step 1: Gather Required Information

You'll need to create/collect these identifiers:

| Item | Format | Example |
|------|--------|---------|
| **Team ID** | 10-character alphanumeric | `ABC123XYZ9` |
| **App ID (Bundle ID)** | Reverse domain | `com.example.myapp` |
| **Services ID** | Reverse domain | `com.example.myapp.auth` |
| **Signing Key** | `.p8` file | `AuthKey_ABC123XYZ9.p8` |

### Step 2: Register Email Sources

1. Go to [Apple Developer Console](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **Services** in sidebar
4. Click **Sign in with Apple for Email Communication**
5. Register your email domain and follow verification steps

### Step 3: Create/Configure App ID

1. Navigate to **Identifiers** → **App IDs**
2. Click the **+** button to create new App ID (or select existing)
3. Select **App IDs** → **App**
4. Fill in:
   - **Description**: Your app name
   - **Bundle ID**: Explicit - `com.example.myapp`
5. Under **Capabilities**, check **Sign in with Apple**
6. Click **Continue** → **Register**

**⚠️ Important**: Leave "Server-to-Server Notification Endpoint" blank

### Step 4: Create Services ID (for Web/Android)

This is required for Android and web authentication flows.

1. Navigate to **Identifiers** → **Services IDs**
2. Click the **+** button
3. Select **Services IDs**
4. Fill in:
   - **Description**: `[Your App Name] Auth Service`
   - **Identifier**: `com.example.myapp.auth` (different from Bundle ID)
5. Check **Sign in with Apple**
6. Click **Continue** → **Register**

### Step 5: Configure Services ID Domains and URLs

1. Click on the Services ID you just created
2. Check **Sign in with Apple**
3. Click **Configure** next to it
4. Add **Primary App ID**: Select your App ID from dropdown
5. Add **Website URLs**:

   **Domains and Subdomains:**
   - `<project-ref>.supabase.co`
   - (Optional) Your custom domain if you have one

   **Return URLs:**
   - `https://<project-ref>.supabase.co/auth/v1/callback`

6. Click **Save** → **Continue** → **Register**

**🎯 Key Point**: The "Domains and Subdomains" allows opening the auth flow, while "Return URLs" receives the credentials after authentication.

### Step 6: Create Signing Key

1. Navigate to **Keys** section
2. Click the **+** button
3. Key Name: `Sign in with Apple Key`
4. Check **Sign in with Apple**
5. Click **Configure** next to it
6. Select your **Primary App ID**
7. Click **Save** → **Continue** → **Register**
8. **📥 DOWNLOAD** the `.p8` file immediately
   - ⚠️ **You can only download this once!**
   - Store it securely - you'll need it in 6 months
9. **📝 SAVE**: Note down the **Key ID** (10-character, like `AB12CD34EF`)

### Step 7: Find Your Team ID

1. Go to [Apple Developer Account](https://developer.apple.com/account/)
2. Click your name in top right
3. **Team ID** is displayed under your account name
4. **📝 SAVE**: Copy your Team ID

### Step 8: Generate Client Secret for Supabase

Apple requires a JWT secret key generated from your `.p8` signing key. You have two options:

#### Option A: Use Supabase Dashboard (Easiest)

Supabase can generate the secret automatically:
1. Go to Supabase Dashboard → **Authentication** → **Providers**
2. Enable **Apple** provider
3. Upload your `.p8` file
4. Enter **Team ID** and **Key ID**
5. Supabase generates the secret automatically

#### Option B: Generate Manually

Use this Node.js script:

```javascript
const jwt = require('jsonwebtoken');
const fs = require('fs');

const privateKey = fs.readFileSync('AuthKey_XXXXXXXXXX.p8', 'utf8');

const token = jwt.sign(
  {},
  privateKey,
  {
    algorithm: 'ES256',
    expiresIn: '6months',
    issuer: 'YOUR_TEAM_ID',
    header: {
      alg: 'ES256',
      kid: 'YOUR_KEY_ID',
    },
  }
);

console.log(token);
```

**🔐 Security Note**: Store your `.p8` file securely - you'll need it every 6 months to regenerate the secret.

### Common Apple OAuth Mistakes

❌ **Mistake #1**: Using App ID (Bundle ID) as Services ID
✅ **Solution**: Services ID must be different from Bundle ID

❌ **Mistake #2**: Not adding Supabase domain to Services ID configuration
✅ **Solution**: Add `<project-ref>.supabase.co` to both Domains and Return URLs

❌ **Mistake #3**: Losing the `.p8` signing key file
✅ **Solution**: Download immediately and store securely (cannot re-download)

❌ **Mistake #4**: Forgetting to rotate secret every 6 months
✅ **Solution**: Set calendar reminder - Apple requires new secret every 6 months

❌ **Mistake #5**: Not registering email sources
✅ **Solution**: Register in Services section before configuring Sign in with Apple

---

## Supabase Dashboard Configuration

### Step 1: Access Supabase Authentication Settings

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Navigate to **Authentication** → **Providers**

### Step 2: Configure Google Provider

1. Scroll to **Google** provider
2. Click to expand configuration
3. Toggle **Enable Google Provider** to ON
4. Fill in the following:

   **Client ID (for OAuth)**:
   - Paste the **Web Client ID** from Google Cloud Console

   **Client Secret (for OAuth)**:
   - Paste the **Client Secret** from Web Client in Google Cloud Console

   **Authorized Client IDs**:
   - Add **Web Client ID**
   - Add **Android Client ID** (if using Android)
   - Add **iOS Client ID** (if using iOS)
   - Each ID on a separate line

   **Skip nonce check**:
   - Keep **disabled** (unchecked) for security

5. Note the **Callback URL (for OAuth)**:
   - This is auto-generated: `https://<project-ref>.supabase.co/auth/v1/callback`
   - Use this in Google Cloud Console redirect URIs

6. Click **Save**

#### Example Configuration:

```
Client ID: 123456789-abc123def456.apps.googleusercontent.com
Client Secret: GOCSPX-abc123def456ghi789jkl
Authorized Client IDs:
  123456789-abc123def456.apps.googleusercontent.com
  123456789-android123.apps.googleusercontent.com
  123456789-ios123.apps.googleusercontent.com
Skip nonce check: disabled
```

### Step 3: Configure Apple Provider

1. Scroll to **Apple** provider
2. Click to expand configuration
3. Toggle **Enable Apple Provider** to ON
4. Fill in the following:

   **Services ID**:
   - Enter your Services ID (e.g., `com.example.myapp.auth`)

   **Team ID**:
   - Enter your 10-character Team ID

   **Key ID**:
   - Enter your 10-character Key ID from the signing key

   **Secret Key (Client Secret)**:
   - Either paste the JWT token you generated
   - OR upload the `.p8` file (Supabase will generate JWT)

5. Note the **Callback URL (for OAuth)**:
   - This is auto-generated: `https://<project-ref>.supabase.co/auth/v1/callback`
   - Ensure this matches the Return URL in Apple Developer Console

6. Click **Save**

#### Example Configuration:

```
Services ID: com.example.myapp.auth
Team ID: ABC123XYZ9
Key ID: AB12CD34EF
Secret Key: [JWT token or .p8 file upload]
```

### Step 4: Configure Redirect URLs for Deep Linking

For native mobile apps, configure custom URL schemes:

1. Navigate to **Authentication** → **URL Configuration**
2. Add **Redirect URLs** for deep linking:

   ```
   io.supabase.flutterapp://login-callback/
   com.example.myapp://login-callback/
   ```

3. Format: `[YOUR_SCHEME]://[YOUR_HOSTNAME]/`
4. Click **Save**

**🎯 Key Point**: These URLs must match the deep link configuration in your Flutter app's platform-specific files.

### Step 5: Configure Site URL (Optional)

1. Still in **URL Configuration**
2. Set **Site URL** to your app's homepage:
   - For mobile apps: Your app store listing or marketing site
   - For web apps: Your production domain
3. This is where users are redirected after email confirmations

---

## Flutter Implementation

### Step 1: Add Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  supabase_flutter: ^2.0.0
  google_sign_in: ^6.1.5
  sign_in_with_apple: ^5.0.0
  crypto: ^3.0.3  # For Apple nonce hashing
```

Run:
```bash
flutter pub get
```

### Step 2: Configure Deep Linking

#### iOS Configuration (Info.plist)

Add to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>io.supabase.flutterapp</string>
    </array>
  </dict>
</array>

<!-- Flutter 3.27+ has deep linking enabled by default -->
<!-- For older versions, add: -->
<key>FlutterDeepLinkingEnabled</key>
<true/>
```

#### Android Configuration (AndroidManifest.xml)

Add intent filter to `android/app/src/main/AndroidManifest.xml` inside `<activity>`:

```xml
<activity
    android:name=".MainActivity"
    ...>

    <!-- Existing intent filters... -->

    <!-- Deep linking for OAuth -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />

        <data
            android:scheme="io.supabase.flutterapp"
            android:host="login-callback" />
    </intent-filter>
</activity>
```

**⚠️ Important**: The scheme must match what you configured in Supabase redirect URLs.

### Step 3: Initialize Supabase

In `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://YOUR_PROJECT_REF.supabase.co',
    anonKey: 'YOUR_ANON_KEY',
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // More secure for deep links
    ),
  );

  runApp(MyApp());
}

// Global accessor
final supabase = Supabase.instance.client;
```

### Step 4: Implement Google Sign-In

Create a service class:

```dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Google Sign-In for iOS and Android
  Future<AuthResponse> signInWithGoogle() async {
    // Web Client ID from Google Cloud Console
    const webClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

    // iOS Client ID from Google Cloud Console
    const iosClientId = 'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com';

    // Initialize GoogleSignIn
    // Note: Android auto-detects from google-services.json
    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: iosClientId,  // For iOS only
      serverClientId: webClientId,  // Backend verification (ALL platforms)
    );

    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw 'Google Sign-In was cancelled';
      }

      // Get authentication tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final String? accessToken = googleAuth.accessToken;
      final String? idToken = googleAuth.idToken;

      if (accessToken == null) {
        throw 'No Access Token found.';
      }
      if (idToken == null) {
        throw 'No ID Token found.';
      }

      // Sign in to Supabase with Google tokens
      return await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (error) {
      throw 'Google Sign-In failed: $error';
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _supabase.auth.signOut();
  }
}
```

### Step 5: Implement Apple Sign-In

Add to the same `AuthService` class:

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Apple Sign-In for iOS and macOS
  Future<AuthResponse> signInWithApple() async {
    try {
      // Generate nonce for security
      final rawNonce = _supabase.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      // Trigger Apple Sign-In flow
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final String? idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException(
          'Could not find ID Token from generated credential.',
        );
      }

      // Sign in to Supabase with Apple token
      return await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
    } catch (error) {
      throw 'Apple Sign-In failed: $error';
    }
  }

  /// Check if Apple Sign-In is available (iOS 13+)
  Future<bool> isAppleSignInAvailable() async {
    return await SignInWithApple.isAvailable();
  }
}
```

### Step 6: UI Implementation Example

```dart
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _error;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _authService.signInWithGoogle();
      // Navigate to home screen
      Navigator.pushReplacementNamed(context, '/home');
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _authService.signInWithApple();
      // Navigate to home screen
      Navigator.pushReplacementNamed(context, '/home');
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign In')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_error != null)
              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleGoogleSignIn,
              icon: Icon(Icons.login),
              label: Text('Sign in with Google'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),

            SizedBox(height: 16),

            FutureBuilder<bool>(
              future: _authService.isAppleSignInAvailable(),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleAppleSignIn,
                    icon: Icon(Icons.apple),
                    label: Text('Sign in with Apple'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                    ),
                  );
                }
                return SizedBox.shrink();
              },
            ),

            if (_isLoading)
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
```

### Step 7: Listen to Auth State Changes

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      switch (event) {
        case AuthChangeEvent.signedIn:
          print('User signed in: ${session?.user.email}');
          // Navigate to home screen
          break;
        case AuthChangeEvent.signedOut:
          print('User signed out');
          // Navigate to login screen
          break;
        case AuthChangeEvent.tokenRefreshed:
          print('Token refreshed');
          break;
        default:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      initialRoute: _supabase.auth.currentSession == null ? '/login' : '/home',
      routes: {
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
      },
    );
  }
}
```

---

## Troubleshooting Common Issues

### Google Sign-In Issues

#### Error: PlatformException (sign_in_failed, ApiException: 10)

**Cause**: SHA-1 certificate fingerprint or OAuth client ID misconfiguration.

**Solutions**:
1. Verify SHA-1 fingerprint matches in Google Cloud Console
2. For debug builds: Use debug keystore SHA-1
3. For release builds: Use release keystore or Play Store signing key SHA-1
4. Ensure package name matches exactly
5. Wait 10-15 minutes after adding SHA-1 (propagation delay)

**Check your configuration**:
```bash
# Verify your debug SHA-1
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1

# Verify package name
grep applicationId android/app/build.gradle
```

#### Error: PlatformException (sign_in_failed, ApiException: 12500)

**Cause**: Incorrect `serverClientId` - usually using Android Client ID instead of Web Client ID.

**Solution**:
1. Go to Google Cloud Console → Credentials
2. Find your **Web application** client (not Android)
3. Copy that Client ID
4. Use it as `serverClientId` in Flutter code:
   ```dart
   GoogleSignIn(
     serverClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
   )
   ```

#### Error: null idToken

**Cause**: Missing `serverClientId` or incorrect OAuth setup.

**Solution**:
1. Ensure you're passing `serverClientId` (Web Client ID)
2. Verify Web client has correct redirect URIs
3. Check that you're requesting correct scopes

#### Error: redirect_uri_mismatch

**Cause**: The callback URL in your Supabase dashboard doesn't match Google Cloud Console.

**Solution**:
1. Copy callback URL from Supabase: `https://<project-ref>.supabase.co/auth/v1/callback`
2. Add it to Google Cloud Console → Credentials → Web Client → Authorized redirect URIs
3. Click Save
4. Wait 5-10 minutes for changes to propagate

### Apple Sign-In Issues

#### Error: Could not find ID Token from generated credential

**Cause**: Apple authentication flow was cancelled or configuration is incorrect.

**Solutions**:
1. Verify Services ID is properly configured in Apple Developer Portal
2. Check that Supabase callback URL is in Services ID Return URLs
3. Ensure `<project-ref>.supabase.co` is in Domains and Subdomains
4. Verify Bundle ID matches your app's identifier

#### Error: Invalid client (Android)

**Cause**: Services ID not properly configured for web/Android flows.

**Solutions**:
1. Ensure Services ID is different from Bundle ID
2. Verify Return URLs include Supabase callback
3. For Android, ensure you've set up the redirect URI in Supabase
4. Some developers use Glitch.com as an intermediary for Android (see `sign_in_with_apple` package docs)

#### Error: Secret key expired

**Cause**: Apple's JWT secret expires every 6 months.

**Solution**:
1. Regenerate JWT using your saved `.p8` file
2. Update the secret in Supabase Dashboard
3. Set a calendar reminder for 6 months from now

**Regeneration script**:
```javascript
const jwt = require('jsonwebtoken');
const fs = require('fs');

const privateKey = fs.readFileSync('AuthKey_XXXXXXXXXX.p8', 'utf8');

const token = jwt.sign(
  {},
  privateKey,
  {
    algorithm: 'ES256',
    expiresIn: '6months',
    issuer: 'YOUR_TEAM_ID',
    header: {
      alg: 'ES256',
      kid: 'YOUR_KEY_ID',
    },
  }
);

console.log(token);
```

### Supabase Issues

#### Error: Invalid provider

**Cause**: Provider not enabled or misconfigured in Supabase dashboard.

**Solution**:
1. Go to Authentication → Providers
2. Ensure Google/Apple provider is enabled (toggle is ON)
3. Verify all fields are filled correctly
4. Click Save

#### Error: Invalid session

**Cause**: Token expired or auth state not properly managed.

**Solution**:
1. Check if user is actually signed in: `supabase.auth.currentSession`
2. Implement refresh logic:
   ```dart
   try {
     await supabase.auth.refreshSession();
   } catch (e) {
     // Re-authenticate
     await supabase.auth.signOut();
   }
   ```

#### Deep linking not working

**Cause**: URL scheme not properly registered or redirect URL mismatch.

**Solutions**:

**iOS**:
1. Verify `CFBundleURLSchemes` in Info.plist
2. For Flutter 3.27+: Deep linking is enabled by default
3. For older versions: Add `FlutterDeepLinkingEnabled = YES`
4. Clean and rebuild: `flutter clean && flutter run`

**Android**:
1. Verify intent filter in AndroidManifest.xml
2. Check scheme matches Supabase redirect URL
3. Ensure `android:autoVerify="true"` is set
4. Test with ADB:
   ```bash
   adb shell am start -W -a android.intent.action.VIEW -d "your-scheme://login-callback"
   ```

### General Debugging Tips

#### Enable Debug Logging

```dart
// In main.dart
Supabase.initialize(
  url: 'YOUR_URL',
  anonKey: 'YOUR_KEY',
  debug: true,  // Enable debug logs
);
```

#### Check Supabase Auth Logs

1. Go to Supabase Dashboard → Authentication → Logs
2. View recent authentication attempts
3. Look for error messages or failed attempts

#### Verify Token Flow

```dart
// Add logging to your auth methods
Future<AuthResponse> signInWithGoogle() async {
  print('Starting Google Sign-In');

  final googleUser = await googleSignIn.signIn();
  print('Google user: ${googleUser?.email}');

  final googleAuth = await googleUser!.authentication;
  print('Got Google tokens: accessToken=${googleAuth.accessToken != null}, idToken=${googleAuth.idToken != null}');

  final response = await supabase.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: googleAuth.idToken!,
    accessToken: googleAuth.accessToken!,
  );

  print('Supabase session: ${response.session?.user.email}');
  return response;
}
```

#### Test on Real Devices

OAuth flows often don't work properly on emulators/simulators. Always test on:
- Physical iOS device
- Physical Android device

#### Clear App Data

Sometimes cached credentials cause issues:

**iOS**: Delete app and reinstall
**Android**: Settings → Apps → Your App → Storage → Clear Data

---

## Additional Resources

### Official Documentation

**Google Cloud Platform**:
- [OAuth 2.0 Overview](https://developers.google.com/identity/protocols/oauth2)
- [OAuth for Mobile Apps](https://developers.google.com/identity/protocols/oauth2/native-app)
- [Client Authentication](https://developers.google.com/android/guides/client-auth)
- [Google Cloud Console](https://console.cloud.google.com/)

**Apple Developer**:
- [Sign in with Apple](https://developer.apple.com/sign-in-with-apple/)
- [Services IDs](https://developer.apple.com/help/account/configure-app-capabilities/about-sign-in-with-apple/)
- [Apple Developer Portal](https://developer.apple.com/account/)

**Supabase**:
- [Social Login with Google](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Social Login with Apple](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Native Mobile Deep Linking](https://supabase.com/docs/guides/auth/native-mobile-deep-linking)
- [Flutter Client Library](https://supabase.com/docs/reference/dart)

### Flutter Packages

**Google Sign-In**:
- [google_sign_in](https://pub.dev/packages/google_sign_in) - Official Google Sign-In plugin
- [Documentation](https://pub.dev/documentation/google_sign_in/latest/)

**Apple Sign-In**:
- [sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple) - Sign in with Apple plugin
- [Documentation](https://pub.dev/documentation/sign_in_with_apple/latest/)

**Supabase Flutter**:
- [supabase_flutter](https://pub.dev/packages/supabase_flutter) - Official Supabase client
- [Documentation](https://pub.dev/documentation/supabase_flutter/latest/)

**Deep Linking**:
- [app_links](https://pub.dev/packages/app_links) - Universal & custom links handler
- [uni_links](https://pub.dev/packages/uni_links) - Alternative deep linking plugin

### Helpful Articles & Tutorials

**Google OAuth**:
- [Medium: Learn how to integrate Google Sign-In in Flutter (2025)](https://medium.com/@allwayssbijoy/learn-how-to-integrate-google-sign-in-in-your-flutter-app-step-by-step-using-google-cloud-console-691873b1b522)
- [FlutterFlow: Google OAuth Login](https://docs.flutterflow.io/integrations/authentication/firebase/google-oauth-login/)

**Apple Sign-In**:
- [Medium: Integrate Apple Sign-In on Android using Flutter](https://medium.com/blocship/integrate-apple-sign-in-on-android-using-flutter-bf5d61c85332)
- [DHiWise: Setting Up Sign In with Apple in Flutter](https://www.dhiwise.com/post/setting-up-sign-in-with-apple-package-in-flutter)

**Supabase + Flutter**:
- [Medium: Implementing Google Sign-In with Supabase in Flutter](https://medium.com/@fianto74/implementing-google-sign-in-authentication-in-flutter-with-supabase-acf7f33a98b1)
- [LeanCode: Flutter Auth Providers & Supabase](https://leancode.co/blog/flutter-app-with-3-auth-providers-and-supabase)

**Deep Linking**:
- [Code with Andrea: Flutter Deep Linking Guide](https://codewithandrea.com/articles/flutter-deep-links/)
- [Flutter Cookbook: Universal Links for iOS](https://docs.flutter.dev/cookbook/navigation/set-up-universal-links)

### Troubleshooting Resources

- [Stack Overflow: google_sign_in tag](https://stackoverflow.com/questions/tagged/google_sign_in)
- [Stack Overflow: sign_in_with_apple tag](https://stackoverflow.com/questions/tagged/sign-in-with-apple)
- [Supabase GitHub Discussions](https://github.com/supabase/supabase/discussions)
- [Flutter GitHub Issues](https://github.com/flutter/flutter/issues)

### Video Tutorials

- [YouTube: Flutter Google Sign-In Tutorial](https://www.youtube.com/results?search_query=flutter+google+sign+in+2024)
- [YouTube: Flutter Apple Sign-In Tutorial](https://www.youtube.com/results?search_query=flutter+apple+sign+in+2024)
- [YouTube: Supabase Flutter Authentication](https://www.youtube.com/results?search_query=supabase+flutter+auth+2024)

---

## Maintenance Checklist

### Regular Maintenance

- [ ] **Every 6 months**: Rotate Apple OAuth secret key
- [ ] **Quarterly**: Review and update SHA-1 fingerprints for new release builds
- [ ] **After app updates**: Test OAuth flows on both platforms
- [ ] **Monthly**: Check Supabase auth logs for failed attempts

### Version Updates

- [ ] Update `google_sign_in` package: `flutter pub upgrade google_sign_in`
- [ ] Update `sign_in_with_apple` package: `flutter pub upgrade sign_in_with_apple`
- [ ] Update `supabase_flutter` package: `flutter pub upgrade supabase_flutter`
- [ ] Review breaking changes in changelogs
- [ ] Test OAuth flows after updates

### Security Best Practices

- [ ] Store `.p8` Apple signing key securely (password manager or secrets vault)
- [ ] Never commit OAuth secrets to version control
- [ ] Use environment variables for sensitive keys in CI/CD
- [ ] Regularly review Google Cloud Console OAuth consent screen
- [ ] Monitor Supabase auth logs for suspicious activity
- [ ] Keep backup of all Client IDs and configurations
- [ ] Document any custom configurations for team members

---

## Quick Reference

### Required Files & Locations

| Configuration | Location | Purpose |
|--------------|----------|---------|
| Google Services JSON | `android/app/google-services.json` | Android OAuth config |
| Info.plist | `ios/Runner/Info.plist` | iOS deep linking |
| AndroidManifest.xml | `android/app/src/main/AndroidManifest.xml` | Android deep linking |
| .p8 Signing Key | Secure storage (not in repo) | Apple OAuth secret generation |

### Environment Variables (Optional)

Create `.env` file (add to `.gitignore`):

```env
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=your_anon_key
GOOGLE_WEB_CLIENT_ID=your_web_client_id.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=your_ios_client_id.apps.googleusercontent.com
APPLE_SERVICES_ID=com.example.app.auth
```

### Console Quick Links

| Service | URL |
|---------|-----|
| Google Cloud Console | https://console.cloud.google.com/ |
| Google OAuth Credentials | https://console.cloud.google.com/apis/credentials |
| Apple Developer Portal | https://developer.apple.com/account/ |
| Apple Identifiers | https://developer.apple.com/account/resources/identifiers/list |
| Supabase Dashboard | https://supabase.com/dashboard |
| Supabase Auth Settings | https://supabase.com/dashboard/project/_/auth/providers |

---

**Last Updated**: January 2025

**Version**: 1.0.0

**Maintained By**: Mealvana Development Team

For questions or issues, please refer to the [Troubleshooting](#troubleshooting-common-issues) section or consult the [Additional Resources](#additional-resources).
