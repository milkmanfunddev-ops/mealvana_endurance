# Flutter Web Setup Guide (drift_web Approach)

**Timeline:** 30 minutes for complete setup

**Approach:** Use drift_web to make your existing Drift database work on web with minimal changes.

---

## Prerequisites

- Flutter 3.8+ installed
- Existing Flutter app with Drift database
- Git repo connected to Vercel (or ready to connect)

---

## Setup Steps

### Step 1: Enable Web Platform

```bash
flutter create . --platforms=web
```

**What this does:**
- Creates `web/` directory with `index.html`, `manifest.json`, icons
- Does NOT modify any existing Dart code
- Safe to run on existing project

**Verify:**
```bash
ls web/
# Should show: index.html, manifest.json, favicon.png, icons/
```

---

### Step 2: Add drift_web

```bash
flutter pub add drift_web
```

**That's it!** drift_web includes sql.js (JavaScript SQLite) built-in. No additional dependencies needed.

**Verify:**
```bash
grep drift_web pubspec.yaml
```

---

### Step 3: Update Database Initialization

**File:** `lib/shared/database/app_database.dart`

**Add imports at top:**
```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:drift/web.dart';
```

**Update `_openConnection()` method:**

Find this method (around line 79):
```dart
static QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    // ... existing code
  });
}
```

**Replace with:**
```dart
static QueryExecutor _openConnection() {
  if (kIsWeb) {
    return WebDatabase('mealvana_db', logStatements: kDebugMode);
  }

  // Existing native database code (unchanged)
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'mealvana_endurance_db.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    final db = NativeDatabase.createInBackground(file);
    return db;
  });
}
```

**Done!** This is the ONLY code change needed for drift_web.

**Total setup time:** 30 minutes

---

### Step 4: Test Locally

```bash
flutter run -d chrome
```

**Expected result:**
- App opens in Chrome
- Database initializes (check console logs)
- All features work (reading/writing data)
- No CORS errors with Supabase

**Debug tips:**
```bash
# Check for errors
# Open Chrome DevTools → Console tab
# Look for database initialization messages
```

---

### Step 5: Configure Vercel

**Create `vercel.json` in project root:**
```json
{
  "buildCommand": "flutter/bin/flutter build web --release --wasm --pwa-strategy=none",
  "installCommand": "if cd flutter; then git pull && cd ..; else git clone https://github.com/flutter/flutter.git --depth 1 --branch stable; fi && flutter/bin/flutter doctor",
  "outputDirectory": "build/web",
  "framework": null,
  "headers": [
    {
      "source": "/index.html",
      "headers": [
        {"key": "Cache-Control", "value": "public, max-age=0, must-revalidate"}
      ]
    },
    {
      "source": "/(.*)\\.(?:js|css|png|jpg|svg|woff2|ttf)",
      "headers": [
        {"key": "Cache-Control", "value": "public, max-age=31536000, immutable"}
      ]
    }
  ]
}
```

**Key points:**
- `--wasm` flag: Uses Flutter's Skwasm renderer for faster UI rendering (NOT related to SQLite)
- Cache headers: Optimizes CDN performance

**Note:** drift_web uses sql.js (JavaScript SQLite) - no WebAssembly SQLite needed.

---

### Step 6: Handle Platform-Specific Code

Update any `dart:io` Platform checks:

**Before:**
```dart
import 'dart:io';

if (Platform.isAndroid) {
  // Android code
}
```

**After:**
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

if (!kIsWeb && Platform.isAndroid) {
  // Android code
}
```

**Common files needing updates:**
- `lib/shared/providers/device_info_provider.dart`
- `lib/shared/services/app_startup_service.dart`
- Any file importing `dart:io`

---

### Step 7: Build for Production

```bash
flutter build web --release --wasm --pwa-strategy=none
```

**Expected output:**
```
✓ Built build/web
Bundle size: ~2-3MB (includes sql.js)
```

**Verify build:**
```bash
ls -lh build/web/
# Should contain: index.html, main.dart.js, canvaskit/ or skwasm/
```

---

### Step 8: Deploy to Vercel

**Option A: GitHub Integration (Recommended)**

1. Push code to GitHub
2. Go to [vercel.com](https://vercel.com)
3. Click "Import Project"
4. Select your GitHub repository
5. Vercel auto-detects `vercel.json` and deploys

**Option B: Vercel CLI**

```bash
npm install -g vercel
vercel --prod
```

---

### Step 9: Add Environment Variables (Security)

⚠️ **CRITICAL:** Never include `.env` files in web builds (they become public).

**In Vercel dashboard:**
1. Go to Project Settings → Environment Variables
2. Add your secrets:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SENTRY_DSN`
   - etc.

**Update code to use environment variables:**
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

String getSupabaseUrl() {
  if (kIsWeb) {
    return const String.fromEnvironment('SUPABASE_URL');
  }
  return dotenv.env['SUPABASE_URL']!;
}
```

---

## Troubleshooting

### "Platform.isAndroid not defined on web"

**Cause:** Using `Platform` checks without `kIsWeb` guard

**Solution:**
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

if (!kIsWeb && Platform.isAndroid) {
  // Android code
}
```

---

### Database initialization fails

**Cause:** IndexedDB not available (private browsing mode)

**Solution:**
```dart
static QueryExecutor _openConnection() {
  if (kIsWeb) {
    try {
      return WebDatabase('mealvana_db', logStatements: kDebugMode);
    } catch (e) {
      print('IndexedDB unavailable, using in-memory DB');
      return WebDatabase.withStorage(
        DriftWebStorage.volatile(),
        logStatements: kDebugMode,
      );
    }
  }
  // Native code...
}
```

**Note:** drift_web uses sql.js (JavaScript SQLite) which stores data in IndexedDB. This works in all modern browsers except private browsing mode.

---

### CORS errors with Supabase

**Cause:** Supabase not allowing your Vercel domain

**Solution:**
1. Go to Supabase dashboard
2. Settings → API
3. Add your Vercel domain to allowed origins
4. Example: `https://your-app.vercel.app`

---

## Verification Checklist

After setup, verify:

- [ ] `flutter run -d chrome` works without errors
- [ ] Database initializes (check console logs)
- [ ] Can read/write data in browser
- [ ] Supabase authentication works
- [ ] No console errors
- [ ] `flutter build web` completes successfully

---

## What's Next?

After successful setup:

1. **Test thoroughly** (see roadmap-simplified.md)
2. **Deploy to Vercel preview**
3. **Cross-browser testing**
4. **Performance monitoring**
5. **Production deployment**

---

## Performance Expectations

| Metric | Target | Notes |
|--------|--------|-------|
| Initial load | 2-3s | Includes sql.js (bundled) |
| Cached load | 200-500ms | Assets cached |
| Database query | 10-100ms | IndexedDB performance |
| Bundle size | 2-3MB | With Skwasm renderer |

---

## Summary

**Setup completed in 30 minutes:**
- ✅ Web platform enabled (`flutter create`)
- ✅ drift_web dependency added (1 command)
- ✅ Database initialization updated (~10 lines)
- ✅ Vercel configured
- ✅ Local testing successful
- ✅ Production build working

**2 commands, 1 code change - that's it!**

**No new repositories created.**
**No controller changes needed.**
**All existing code works unchanged.**

This is the simplest possible approach to get your Flutter app working on web with full database support.

---

## Optional: WebAssembly Backend (Phase 2)

**Only if** sql.js performance proves insufficient, you can add WebAssembly backend:

```bash
flutter pub add sqlite3_web
curl -L -o web/sqlite3.wasm https://github.com/simolus3/sqlite3.dart/releases/download/0.1.0/sqlite3.wasm
```

**Update vercel.json to add WASM content-type header:**
```json
{
  "source": "/(.*)\\.wasm",
  "headers": [
    {"key": "Content-Type", "value": "application/wasm"}
  ]
}
```

**When to add:** Based on performance testing showing sql.js is too slow. Most apps won't need this.
