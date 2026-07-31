# TrainingPeaks OAuth - Web Platform Setup

**Date:** January 2026
**App URL:** https://mealvanaendurancecoachmode-abrgl2ueg-lee-martins-projects.vercel.app

---

## Overview

This document describes the TrainingPeaks OAuth configuration needed for the **web version** of Mealvana Endurance.

The web platform uses a different OAuth callback mechanism than mobile apps:
- **Mobile**: Custom URL scheme (`com.milkman.mealvanaendurance://callback`)
- **Web**: HTTPS URL (`https://your-domain.com/auth.html`)

---

## Required TrainingPeaks Configuration

### Callback URL Registration

TrainingPeaks must whitelist the following callback URLs for the `mealvana` client:

#### Production Web App
```
https://mealvanaendurancecoachmode-abrgl2ueg-lee-martins-projects.vercel.app/auth.html
```

#### Development (if testing locally)
```
http://localhost:PORT/auth.html
```
*Replace PORT with your local dev server port (usually 8080 or 3000)*

#### Mobile Apps (existing)
```
com.milkman.mealvanaendurance://callback
```

---

## Implementation Details

### Web Callback Mechanism

The web platform uses `flutter_web_auth_2` which requires a special HTML file to handle OAuth callbacks:

**File Location:** `/web/auth.html`

**How it works:**
1. User clicks "Connect TrainingPeaks" button
2. App opens TrainingPeaks authorization page in a popup window
3. User logs in and approves permissions
4. TrainingPeaks redirects to `https://your-domain.com/auth.html?code=ABC123&state=XYZ`
5. The `auth.html` page uses JavaScript `postMessage()` to send the callback URL back to the main app
6. App extracts the authorization code and exchanges it for tokens

### Code Changes Made

#### 1. Updated `app_config.dart`
Added TrainingPeaks credentials to web builds via `--dart-define`:

```dart
trainingPeaksClientId: const String.fromEnvironment(
  'TRAININGPEAKS_CLIENT_ID',
  defaultValue: 'mealvana',
),
trainingPeaksClientSecret: const String.fromEnvironment(
  'TRAININGPEAKS_CLIENT_SECRET',
  defaultValue: '',
),
```

#### 2. Updated `training_peaks_oauth_service.dart`
Added platform detection for redirect URI:

```dart
final redirectUri = kIsWeb
    ? '${Uri.base.origin}/auth.html'  // Web: https://domain.com/auth.html
    : '$_callbackUrlScheme://callback';  // Mobile: com.milkman.mealvanaendurance://callback

final callbackScheme = kIsWeb
    ? Uri.base.scheme  // Web: "https"
    : _callbackUrlScheme;  // Mobile: "com.milkman.mealvanaendurance"
```

#### 3. Created `/web/auth.html`
OAuth callback handler page that uses `postMessage()` to communicate with the Flutter app.

---

## Build & Deploy Instructions

### Local Testing

```bash
# Set environment variables
export TRAININGPEAKS_CLIENT_ID="mealvana"
export TRAININGPEAKS_CLIENT_SECRET="your_secret_here"

# Run web app
flutter run -d chrome
```

**Note:** For local testing, you may need to register `http://localhost:PORT/auth.html` with TrainingPeaks.

### Production Build (Vercel)

Add environment variables in Vercel dashboard:

1. Go to Vercel project settings
2. Navigate to "Environment Variables"
3. Add the following:

```
TRAININGPEAKS_CLIENT_ID=mealvana
TRAININGPEAKS_CLIENT_SECRET=your_secret_here
TRAININGPEAKS_USE_SANDBOX=true  # or false for production
```

4. Build command:
```bash
flutter build web \
  --release \
  --wasm \
  --pwa-strategy=none \
  --dart-define=TRAININGPEAKS_CLIENT_ID=$TRAININGPEAKS_CLIENT_ID \
  --dart-define=TRAININGPEAKS_CLIENT_SECRET=$TRAININGPEAKS_CLIENT_SECRET \
  --dart-define=TRAININGPEAKS_USE_SANDBOX=$TRAININGPEAKS_USE_SANDBOX
```

---

## Testing Checklist

After TrainingPeaks registers the callback URL:

- [ ] OAuth flow opens TrainingPeaks login page
- [ ] After login, redirects to `/auth.html`
- [ ] Auth page automatically posts message back to app
- [ ] App receives authorization code
- [ ] Token exchange succeeds
- [ ] Athlete profile is fetched and displayed
- [ ] Integration is saved to database

---

## Troubleshooting

### "Invalid Redirect URI" Error

**Cause:** TrainingPeaks hasn't whitelisted the callback URL.

**Solution:** Contact TrainingPeaks support and request they add:
```
https://mealvanaendurancecoachmode-abrgl2ueg-lee-martins-projects.vercel.app/auth.html
```

### Empty Client ID in Auth URL

**Cause:** Environment variable not passed during build.

**Solution:** Verify `--dart-define=TRAININGPEAKS_CLIENT_ID=mealvana` is included in build command.

### "Authentication Timeout"

**Cause:** The `auth.html` page isn't properly posting the message.

**Solution:**
1. Check browser console for JavaScript errors
2. Verify `/auth.html` file exists in deployed build
3. Check that TrainingPeaks is redirecting to the correct URL

### Popup Blocked

**Cause:** Browser is blocking the OAuth popup window.

**Solution:** User needs to allow popups for the app domain.

---

## Security Considerations

### Client Secret on Web

**⚠️ IMPORTANT:** The TrainingPeaks client secret is embedded in the compiled JavaScript bundle on web. This is inherent to client-side OAuth flows.

**Mitigation:**
- Client secret is still required for token exchange
- TrainingPeaks validates the redirect URI matches the registered callback
- Use PKCE (Proof Key for Code Exchange) if TrainingPeaks supports it
- Rotate client secret if compromised

### CORS Configuration

The app must be hosted on the same origin as the callback URL. Cross-origin OAuth callbacks will not work due to `postMessage()` restrictions.

---

## References

- [flutter_web_auth_2 Package](https://pub.dev/packages/flutter_web_auth_2)
- [flutter_web_auth_2 Web Setup Guide](https://github.com/ThexXTURBOXx/flutter_web_auth_2#web)
- [TrainingPeaks OAuth Documentation](https://github.com/TrainingPeaks/PartnersAPI/wiki/OAuth)

---

## Contact TrainingPeaks

To register the web callback URL, submit a request via:

**Support Portal:** https://sportsbrands.atlassian.net/servicedesk/customer/portal/2

**Request Template:**
```
Subject: Add Web Callback URL for Mealvana Client

Hello,

We are developing the web version of Mealvana Endurance (client_id: mealvana)
and need to register an additional OAuth callback URL.

Current registered callback:
com.milkman.mealvanaendurance://callback

Please add the following callback URLs:

Production:
https://mealvanaendurancecoachmode-abrgl2ueg-lee-martins-projects.vercel.app/auth.html

Development (optional):
http://localhost:8080/auth.html
http://localhost:3000/auth.html

The web app uses the same client_id (mealvana) but requires an HTTPS
callback URL instead of a custom URL scheme.

Thank you!
```

---

*Last Updated: January 9, 2026*
