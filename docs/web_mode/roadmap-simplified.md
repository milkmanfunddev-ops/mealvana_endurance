# Flutter Web Deployment Roadmap (drift_web Approach)

**Timeline: 1 week (30 minutes setup + 5 days testing)**

**Decision:** Use `drift_web` to make existing Drift code work on web with minimal changes.

**Why This Approach:**
- ✅ Simplest: 2 commands, 1 code change
- ✅ Fastest: 30 minutes setup vs 2-3 hours
- ✅ Zero duplication: Same code works on mobile + web
- ✅ Zero risk: All existing code unchanged
- ✅ Battle-tested: drift_web is production-ready

---

## Week 0: Prerequisites (30 minutes)

### Step 1: Enable Web Platform
```bash
flutter create . --platforms=web
```

**What this does:**
- Adds `web/` directory
- Creates `index.html`, `manifest.json`, icons
- Does NOT modify existing Dart code

---

### Step 2: Add drift_web
```bash
flutter pub add drift_web
```

**That's it!** drift_web includes sql.js (JavaScript SQLite) built-in. No additional dependencies needed.

---

### Step 3: Update Database Initialization

**File:** `lib/shared/database/app_database.dart`

**Add imports:**
```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:drift/web.dart';
```

**Update `_openConnection()` method:**
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

    return NativeDatabase.createInBackground(file);
  });
}
```

**Done!** That's the only code change needed.

---

### Step 4: Test Locally
```bash
flutter run -d chrome
```

---

### Step 5: Create vercel.json

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
- drift_web uses sql.js (JavaScript SQLite) - no WebAssembly SQLite needed

---

## Week 1: Testing & Bug Fixes (5 days)

### Day 1-2: Core Functionality Testing
Test all major flows in browser:
- User authentication (Supabase OAuth works on web)
- Activity creation/editing
- Nutrition plan generation (Edge Functions work on web)
- Food preferences management
- Calendar view

### Day 3-4: Platform-Specific Code Review
Review and fix any platform-specific issues:
- `dart:io` imports (use `kIsWeb` checks)
- Platform.isAndroid checks (wrap in `!kIsWeb`)
- Native-only packages (notifications, barcode scanner)

**Example fixes:**
```dart
// Before
import 'dart:io';
if (Platform.isAndroid) { ... }

// After
import 'package:flutter/foundation.dart' show kIsWeb;
if (!kIsWeb && Platform.isAndroid) { ... }
```

### Day 5: Deploy to Vercel Preview
```bash
# Connect GitHub repo to Vercel
vercel

# Deploy preview
git push origin develop  # Auto-deploys to preview URL
```

Test preview deployment thoroughly:
- Cross-browser testing (Chrome, Firefox, Safari, Edge)
- Mobile browser testing
- Performance testing (Lighthouse)

---

## Week 2 (Optional): Performance Optimization

**Only do this if performance testing shows issues.**

### Option A: In-Memory Cache Layer
Add caching to frequently-accessed data:

```dart
class CachedFoodRepository {
  final AppDatabase _db;
  List<Food>? _cachedFoods;

  Future<List<Food>> getAllFoods() async {
    if (_cachedFoods != null) return _cachedFoods!;
    _cachedFoods = await _db.getAllFoods();
    return _cachedFoods!;
  }

  void clearCache() => _cachedFoods = null;
}
```

### Option B: Lazy Loading
Defer loading large datasets until needed.

---

## Post-Launch Monitoring

### Performance Metrics
- First Contentful Paint: Target <2s
- Time to Interactive: Target <3s
- Database query latency: Should match mobile (~10-50ms)

### Analytics
- Track web vs mobile usage
- Monitor error rates
- Watch for IndexedDB quota issues

---

## Phase 2 Enhancements (Future)

If user feedback indicates need:

### Service Worker (Offline Support)
Add Workbox for offline app shell:
```bash
npm install -g workbox-cli
workbox generateSW workbox-config.js
```

### Progressive Web App
Enable install prompts and offline functionality.

### Push Notifications
Add web push notifications (if needed).

---

## Troubleshooting

### "Failed to load sqlite3.wasm"
- Verify `web/sqlite3.wasm` exists
- Check Vercel headers include `Content-Type: application/wasm`
- Try re-downloading WASM file

### "Platform.isAndroid not defined on web"
- Add `kIsWeb` checks before Platform calls
- Wrap in `if (!kIsWeb)` conditionals

### Database queries slow on web
- IndexedDB queries are async and may be slower than native
- Add caching for frequently-accessed data
- Use Drift's batch operations

### CORS errors with Supabase
- Verify Supabase CORS settings allow your Vercel domain
- Check auth headers are being sent correctly

---

## Summary

**Setup time:** 30 minutes
**Development time:** 5 days testing
**Code changes:** ~10 lines (1 file)
**Commands:** 2 (flutter create, flutter pub add)
**New files:** 0 (just web/ directory from flutter create)
**Maintenance burden:** Zero (same code works everywhere)

This is the **simplest possible approach** to get your Flutter app working on web.

---

## Optional: WebAssembly Backend (Phase 2)

**Only if** sql.js performance proves insufficient, add WebAssembly backend:

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

**When to add:** Based on performance testing, not proactively. Most apps don't need this.
