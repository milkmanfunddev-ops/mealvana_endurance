# Web Caching Strategy (drift_web Approach)

**Decision:** Use drift_web to leverage existing Drift database on web with IndexedDB storage.

**Why:** Simplest approach - all existing database code works unchanged.

---

## Architecture Overview

```
┌─────────────────────────────────────┐
│  Browser Cache (automatic)          │ ← Static assets (JS, WASM)
│  Via Vercel Cache-Control headers   │
└─────────────────┬───────────────────┘
                  ↓
┌─────────────────────────────────────┐
│  Drift Database (same code!)        │ ← All your existing queries
│  Uses IndexedDB on web              │   work unchanged
│  Uses SQLite on mobile              │
└─────────────────┬───────────────────┘
                  ↓
┌─────────────────────────────────────┐
│  Supabase Backend                   │ ← Sync (existing logic)
└─────────────────────────────────────┘
```

**Key insight:** Your existing sync logic (DataSyncService) works on web too!

---

## How drift_web Works

**Under the hood:**
- drift_web uses sql.js (SQLite compiled to JavaScript)
- Data stored in browser's IndexedDB
- Same Drift API works on web and mobile
- Zero additional configuration needed

**Performance:**
- Query latency: 10-100ms (acceptable for most use cases)
- Initial load: No extra download (sql.js is bundled)
- Storage limit: 50MB-1GB depending on browser

**When to optimize:**
- If performance testing shows sql.js is too slow
- Can upgrade to WebAssembly backend (Phase 2)
- Most apps won't need this

**Storage:**
- Chrome/Edge: ~60% of available disk space
- Safari: ~1GB
- Firefox: ~50% of available disk space (max 2GB per origin)

**Persistence:**
- Data persists across page refreshes
- Cleared when user clears browser data
- No manual cache invalidation needed

---

## Optional: In-Memory Cache (Phase 2)

**Only add if** IndexedDB queries prove too slow (unlikely).

drift_web already caches data in memory, but you can add additional caching:

```dart
class CachedRepository {
  final AppDatabase _db;
  final Map<String, CachedData> _cache = {};

  Future<List<Food>> getFoods() async {
    final cached = _cache['foods'];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    final foods = await _db.getAllFoods();
    _cache['foods'] = CachedData(foods, Duration(minutes: 5));
    return foods;
  }
}
```

**When to add:** Based on performance metrics, not proactively.

---

## Build Command (2025 Recommended)

```bash
flutter build web --release --wasm --pwa-strategy=none
```

**Important clarification:**
- `--wasm` flag enables Flutter's Skwasm renderer (faster UI rendering)
- This is NOT for SQLite - drift_web uses sql.js (JavaScript) by default
- The Skwasm renderer automatically falls back to CanvasKit on unsupported browsers
- Smaller bundle size: 1.1MB vs 1.5MB (CanvasKit)

---

## Vercel Configuration

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

**Header Explanation:**
- **index.html**: Always check for updates (max-age=0)
- **Static assets**: Cache forever (max-age=31536000) - filename changes on rebuild

**Note:** No WASM header needed for drift_web - it uses sql.js (JavaScript)

---

## Monitoring & Performance

### Key Metrics to Track

```dart
// Track IndexedDB usage
Future<void> checkStorageQuota() async {
  if (!kIsWeb) return;

  final estimate = await html.window.navigator.storage?.estimate();
  if (estimate != null) {
    final usage = estimate.usage ?? 0;
    final quota = estimate.quota ?? 0;
    final usagePercent = (usage / quota * 100).toInt();

    print('Storage: ${(usage / 1024 / 1024).toStringAsFixed(2)} MB used of ${(quota / 1024 / 1024).toStringAsFixed(2)} MB');

    if (usagePercent > 80) {
      print('WARNING: Storage quota at $usagePercent%');
    }
  }
}
```

### Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| First load (uncached) | 2-3s | Includes sql.js (bundled) |
| Subsequent loads | 200-500ms | Assets cached |
| Database query | 10-100ms | IndexedDB performance |
| Storage limit | 50MB-1GB | Browser-dependent |

---

## Troubleshooting

### Storage Quota Exceeded

**Symptom:** App stops saving data
**Cause:** Browser storage limit reached

**Solution:**
```dart
// Implement cleanup of old data
Future<void> cleanupOldData() async {
  final db = AppDatabase();

  // Delete old nutrition plans (keep last 30 days)
  await db.delete(db.nutritionPlans)
    .where((p) => p.createdAt.isSmallerThan(
      DateTime.now().subtract(Duration(days: 30))
    ))
    .go();

  // Delete old activities (keep last 90 days)
  await db.delete(db.activities)
    .where((a) => a.activityDate.isSmallerThan(
      DateTime.now().subtract(Duration(days: 90))
    ))
    .go();
}
```

### IndexedDB Not Available

**Symptom:** Database fails to initialize
**Cause:** Private browsing or browser doesn't support IndexedDB

**Solution:**
```dart
static QueryExecutor _openConnection() {
  if (kIsWeb) {
    try {
      return WebDatabase('mealvana_db', logStatements: kDebugMode);
    } catch (e) {
      print('IndexedDB not available, using in-memory database');
      return WebDatabase.withStorage(
        DriftWebStorage.volatile(),
        logStatements: kDebugMode,
      );
    }
  }

  // Native database code...
}
```

---

## Comparison: drift_web vs Web Repositories

### Code Complexity

**drift_web:**
```dart
// Single change in app_database.dart
if (kIsWeb) {
  return WebDatabase('mealvana_db');
}
```
- **Lines of code:** 10
- **Files modified:** 1
- **Maintenance:** Zero

**Web Repositories:**
```dart
// 14 new repository files
class WebFoodRepository implements IFoodRepository {
  // ~150 lines per repository
  // Must manually sync with Supabase
  // Must maintain JSON serialization
  // Must handle errors manually
}
```
- **Lines of code:** 2,100+
- **Files created:** 14+
- **Maintenance:** Forever

### Feature Comparison

| Feature | drift_web | Web Repositories |
|---------|-----------|------------------|
| Offline support | ✅ Full | ❌ None |
| Code changes | 1 file | 14+ files |
| Query performance | 10-50ms | 200-500ms |
| Data persistence | ✅ Automatic | ❌ None (or manual) |
| Maintenance | Zero | High |
| Risk of bugs | Very Low | Medium |

---

## Summary

**drift_web is the clear winner:**
- 2 commands, 1 code change vs 14+ new files
- Full offline support included
- All existing code works unchanged
- Production-ready and battle-tested
- Zero ongoing maintenance burden

**Implementation checklist:**
- [ ] Add `drift_web` dependency (1 command)
- [ ] Add `kIsWeb` check to database initialization
- [ ] Configure Vercel (no WASM headers needed)
- [ ] Test in Chrome
- [ ] Deploy to Vercel

**Total time:** 30 minutes setup + 5 days testing = 1 week to production

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

**When to add:** Based on performance testing, not proactively.
