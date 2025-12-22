# Flutter Web Deployment - Comprehensive Overview

## ARCHITECTURAL DECISION (2025-12-16 - FINAL)

**✅ SELECTED: drift_web - Leverage Existing Drift Database on Web**

After thorough analysis, we've chosen the **simplest possible approach**: Use drift_web to make your existing Drift database work on web with minimal changes.

### Decision Rationale

**Key Insight:** Why create 14+ new repository files when you can change 1 line of code?

**Selected: drift_web (Drift's Web Adapter)**
- **2 commands, 1 code change**: `flutter pub add drift_web` + update database init (~10 lines)
- **Zero new files**: All existing repositories work unchanged
- **Zero controller changes**: Business logic completely untouched
- **Production-ready**: Used by PowerSync and other major projects
- **Battle-tested**: Drift's official web solution since 2020
- **No extra dependencies**: sql.js (JavaScript SQLite) is built into drift_web

**Comparison:**

| Factor | Web Repositories | drift_web ✅ |
|--------|------------------|--------------|
| Code Changes | 14+ files, ~2000 lines | 1 file, ~10 lines |
| Timeline | 2 weeks | 30 minutes setup + 1 week testing |
| Complexity | Medium (500 lines) | Very Low (10 lines) |
| Dependencies | None (but need Supabase repos) | drift_web (includes sql.js) |
| Offline | None | Full read/write |
| Implementation | 14 repositories to create | 1 conditional in _openConnection() |
| Maintenance | Forever maintain 2 versions | Same code works everywhere |

### The Math

**Web Repositories Approach:**
- 14 repositories × ~150 lines each = 2,100 lines
- 14 repositories × ongoing maintenance = forever
- Risk: Duplicate logic between mobile/web repos

**drift_web Approach:**
```dart
if (kIsWeb) {
  return WebDatabase('mealvana_db');
}
```
- 1 conditional statement
- 0 new files
- 0 controller changes
- 0 service changes
- 0 risk of logic divergence

### Why This Works

**What You Keep:**
- ✅ All existing Drift queries work unchanged
- ✅ All repositories work unchanged
- ✅ All controllers work unchanged
- ✅ All services work unchanged
- ✅ All business logic unchanged
- ✅ Full offline support (IndexedDB under the hood)

**What drift_web Does:**
- Uses sql.js (SQLite compiled to JavaScript) - built-in, no extra download
- Stores data in browser's IndexedDB (transparent)
- Same Drift API works on web and mobile
- Queries run at 10-100ms (acceptable for most use cases)

**Trade-offs:**
- Slightly slower queries than native (10-100ms vs 10-50ms)
- Browser storage limits (50MB-1GB depending on browser)
- Can upgrade to WebAssembly backend if needed (Phase 2)

**Architecture:**
```
MOBILE:
Controllers → Drift Repositories → SQLite

WEB (Same Code!):
Controllers → Drift Repositories → drift_web → IndexedDB
                                  (via WebAssembly)
```

**Implementation:**
```bash
# 1. Add drift_web (30 seconds)
flutter pub add drift_web

# 2. Update database initialization (2 minutes)
# Add kIsWeb check to _openConnection()

# 3. Test (5 minutes)
flutter run -d chrome

# DONE. Everything works.
```

**Timeline:** 30 minutes setup + 5 days testing = 1 week to production-ready web app

📚 **Implementation Details**: See [roadmap-simplified.md](./roadmap-simplified.md) for complete guide

---

## Executive Summary

**Web Readiness Score: 9/10** (dramatically improved with drift_web)

Mealvana Endurance is architecturally positioned for web deployment with a clear **1-week path forward** using drift_web.

**Key Breakthrough:** drift_web makes your ENTIRE Drift database work on web with 2 commands and 1 code change. No new repositories needed.

### Key Findings

**Strengths:**
- Strong FOA architecture with good separation of concerns
- Supabase backend already web-compatible
- Riverpod state management fully web-ready
- 75% of dependencies already web-compatible
- **ALL code works unchanged with drift_web**

**Approach:**
- Run `flutter pub add drift_web` (1 command)
- Add `kIsWeb` check to database initialization (~10 lines)
- Configure Vercel (no WASM headers needed)
- Test and deploy

**Estimated Effort:** 30 minutes setup + 5 days testing = 1 week total
**No Phase 2 needed:** Full offline support included from day 1

---

## 1. Current Architecture Analysis

### 1.1 Feature-Oriented Architecture (FOA)

The app follows Andrea Bizzotto's FOA pattern with excellent separation:

```
lib/features/{feature_name}/
├── presentation/   # UI widgets and controllers (100% web-compatible)
├── application/    # Service classes (80% web-compatible)
├── domain/         # Data models (100% web-compatible)
└── data/          # Repositories (0% web-compatible - all use Drift)
```

**Architecture Strengths:**
- Clean layer separation enables targeted refactoring
- Controllers already use AsyncNotifier pattern (web-ready)
- Domain models are platform-agnostic
- No tight coupling between UI and data layers

**Architecture Weaknesses:**
- **No repository abstractions** - All repositories directly instantiate Drift
- **Pervasive Drift usage** - 16 tables used across all features
- **No conditional platform imports** - Single implementation path

### 1.2 Database Architecture (Critical Blocker)

**Current Implementation:**
```dart
// lib/shared/database/app_database.dart
import 'package:drift/native.dart';  // ❌ Not web-compatible

@DriftDatabase(tables: [
  UsersTable, FoodPreferencesTable, NutritionPlans, MacroTargetsTable,
  FeedbackTable, FoodsTable, CategoriesTable, FoodCategoriesTable,
  BrandsTable, AppContentTable, EdgeFunctions, WorkoutNotes,
  UserFoods, UserFoodCategories, UserHiddenFoods, CarbLoadingSimplePlans
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  static QueryExecutor _openConnection() {
    return NativeDatabase.memory();  // ❌ Uses SQLite C library
  }
}
```

**Table Usage Across Features:**

| Table | Features Using It | Read Operations | Write Operations |
|-------|-------------------|-----------------|------------------|
| `user_profiles` | 8 features | 50+ locations | 15+ locations |
| `foods` | 6 features | 100+ locations | 20+ locations |
| `nutrition_plans` | 5 features | 75+ locations | 30+ locations |
| `food_preferences` | 4 features | 40+ locations | 12+ locations |
| `app_content` | 12 features | 200+ locations | 5+ locations |
| `macro_targets` | 3 features | 30+ locations | 10+ locations |
| **TOTAL** | 16 tables | 600+ read ops | 150+ write ops |

**Why This Is A Problem:**
1. **No Abstraction Layer** - Every repository directly depends on Drift
2. **Type-Safe Queries** - Drift code generation creates compile-time dependencies
3. **Migration Complexity** - 600+ read operations need refactoring
4. **Performance Expectations** - Code assumes instant local DB access

### 1.3 Supabase Backend Integration

**Current Implementation (Web-Compatible):**
```dart
// lib/shared/providers/supabase_provider.dart
import 'package:supabase_flutter/supabase_flutter.dart';  // ✅ Web-compatible

@riverpod
SupabaseClient supabase(SupabaseRef ref) {
  return Supabase.instance.client;  // ✅ Works on web
}
```

**Edge Functions (Web-Ready):**
- `generate-ai-nutrition-plan` - AI-powered nutrition generation ✅
- `run-plan` - Fallback deterministic algorithm ✅
- `save-food-preferences` - User preference persistence ✅
- `get-foods` - Food data retrieval ✅
- `barcode-lookup` - Product identification ✅

**Supabase Strengths:**
- All HTTP-based communication (web-compatible)
- Row Level Security already implemented
- Real-time subscriptions work on web
- Edge Functions accessible from browsers

---

## 2. Critical Blockers with Code Examples

### 2.1 Drift Database (Priority 1 - Showstopper)

**Current Code:**
```dart
// lib/features/nutrition_plan/data/nutrition_plan_repository.dart
class DriftNutritionPlanRepository implements NutritionPlanRepository {
  DriftNutritionPlanRepository(this._database);
  final AppDatabase _database;  // ❌ Drift dependency

  @override
  Future<List<NutritionPlan>> getPlans(String deviceId) async {
    return await (_database.select(_database.nutritionPlansTable)
          ..where((p) => p.deviceId.equals(deviceId)))
        .get();  // ❌ Native SQLite query
  }
}
```

**Problem:**
- `NativeDatabase` uses SQLite C library via FFI (Foreign Function Interface)
- Web platform has no FFI support
- Must use `WebDatabase` which uses IndexedDB

**Solution Options:**

**Option A: Supabase-Only (Simplest, No Offline)**
```dart
// lib/features/nutrition_plan/data/supabase_nutrition_plan_repository.dart
class SupabaseNutritionPlanRepository implements NutritionPlanRepository {
  SupabaseNutritionPlanRepository(this._supabase);
  final SupabaseClient _supabase;

  @override
  Future<List<NutritionPlan>> getPlans(String deviceId) async {
    final response = await _supabase
        .from('nutrition_plans')
        .select()
        .eq('device_id', deviceId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => NutritionPlan.fromJson(json))
        .toList();
  }
}
```

**Option B: IndexedDB with Drift Web (Maintains Offline)**
```dart
// lib/shared/database/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';  // ✅ Web-compatible

class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  static QueryExecutor _openConnection() {
    if (kIsWeb) {
      return LazyDatabase(() async {
        final db = await WasmDatabase.open(
          databaseName: 'mealvana_db',
          sqlite3Uri: Uri.parse('sqlite3.wasm'),
          driftWorkerUri: Uri.parse('drift_worker.js'),
        );
        return db.resolvedExecutor;
      });
    } else {
      return NativeDatabase.memory();
    }
  }
}
```

**Option C: Abstraction Layer (Most Flexible, Most Work)**
```dart
// lib/shared/database/database_provider.dart
abstract class DatabaseProvider {
  Future<List<Map<String, dynamic>>> query(String table, {
    String? where,
    List<dynamic>? whereArgs,
  });

  Future<void> insert(String table, Map<String, dynamic> data);
  Future<void> update(String table, Map<String, dynamic> data, String where);
}

// Platform-specific implementations
class DriftDatabaseProvider implements DatabaseProvider { /* ... */ }
class SupabaseDatabaseProvider implements DatabaseProvider { /* ... */ }
```

### 2.2 Platform-Specific Code (Priority 2)

**Problem Files:**

1. **Device Info Provider** (`lib/shared/providers/device_info_provider.dart`)
```dart
import 'dart:io';  // ❌ Not available on web

@riverpod
String deviceInfo(DeviceInfoRef ref) {
  if (Platform.isIOS) {  // ❌ Platform not available on web
    return 'iOS';
  } else if (Platform.isAndroid) {
    return 'Android';
  }
  return 'Unknown';
}
```

**Web-Compatible Solution:**
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

@riverpod
String deviceInfo(DeviceInfoRef ref) {
  if (kIsWeb) {
    return 'Web';
  }
  // Use conditional imports for mobile
  return getMobilePlatformInfo();
}
```

2. **App Startup Service** (`lib/shared/services/app_startup_service.dart`)
```dart
// Current implementation
Future<void> initialize() async {
  final database = AppDatabase();  // ❌ Assumes native DB
  await database.ensureOpen();
  // ...
}
```

**Web-Compatible Solution:**
```dart
Future<void> initialize() async {
  final database = kIsWeb
      ? WebAppDatabase()  // IndexedDB implementation
      : AppDatabase();    // Native SQLite implementation
  await database.ensureOpen();
  // ...
}
```

### 2.3 OAuth Authentication (Priority 3)

**Current Implementation:**
```dart
// lib/features/auth/application/oauth_service.dart
import 'package:sign_in_with_apple/sign_in_with_apple.dart';  // ❌ Native only
import 'package:google_sign_in/google_sign_in.dart';  // ❌ Native only

class OAuthService {
  Future<AuthCredential?> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential();  // ❌ Native SDK
    return credential;
  }
}
```

**Web-Compatible Solution:**
```dart
class OAuthService {
  final SupabaseClient _supabase;

  Future<AuthCredential?> signInWithApple() async {
    if (kIsWeb) {
      // Use Supabase OAuth redirect flow
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'https://mealvana.com/auth/callback',
      );
    } else {
      // Use native SDK
      final credential = await SignInWithApple.getAppleIDCredential();
      return credential;
    }
  }
}
```

### 2.4 Push Notifications (Priority 4)

**Current Implementation:**
```dart
// lib/shared/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';  // ❌ Native only

class NotificationService {
  Future<void> scheduleReminder(DateTime dateTime) async {
    await _plugin.zonedSchedule(/* ... */);  // ❌ Not available on web
  }
}
```

**Web Alternative:**
```dart
class WebNotificationService {
  Future<void> scheduleReminder(DateTime dateTime) async {
    if (kIsWeb) {
      // Use Web Notifications API
      if (html.Notification.permission == 'granted') {
        // Schedule via backend service worker
        await _scheduleViaBackend(dateTime);
      }
    } else {
      await _plugin.zonedSchedule(/* ... */);
    }
  }
}
```

---

## 3. Package Compatibility Matrix

| Package | Mobile | Web | Status | Web Alternative |
|---------|--------|-----|--------|-----------------|
| **Critical Blockers** |
| `sqlite3_flutter_libs` | ✅ | ❌ | Replace | `drift/wasm.dart` or remove |
| `sqlite3` | ✅ | ❌ | Replace | `drift/wasm.dart` or remove |
| `drift/native.dart` | ✅ | ❌ | Replace | `drift/web.dart` |
| `sign_in_with_apple` | ✅ | ❌ | Replace | Supabase OAuth |
| `google_sign_in` | ✅ | ❌ | Replace | Supabase OAuth |
| `flutter_local_notifications` | ✅ | ❌ | Replace | Web Notifications API |
| **Web-Compatible** |
| `supabase_flutter` | ✅ | ✅ | ✅ Ready | - |
| `riverpod` | ✅ | ✅ | ✅ Ready | - |
| `riverpod_annotation` | ✅ | ✅ | ✅ Ready | - |
| `go_router` | ✅ | ✅ | ✅ Ready | - |
| `sentry_flutter` | ✅ | ✅ | ✅ Ready | - |
| `flutter_svg` | ✅ | ✅ | ✅ Ready | - |
| `cached_network_image` | ✅ | ✅ | ✅ Ready | - |
| `shared_preferences` | ✅ | ✅ | ✅ Ready | - |
| `url_launcher` | ✅ | ✅ | ✅ Ready | - |

**Summary:**
- **Total Packages:** 40+
- **Web-Compatible:** 30+ (75%)
- **Critical Blockers:** 6 packages
- **Minor Issues:** 4 packages

---

## 4. Implementation Options Comparison

### ❌ Option A: Supabase-Only (Rejected - Too Slow)

**Description:** Remove local database entirely, use Supabase PostgreSQL for all data access.

**Pros:**
- ✅ Fastest to implement (4-6 weeks)
- ✅ Simplest architecture (no sync logic)
- ✅ Automatically scales
- ✅ Real-time updates built-in
- ✅ No IndexedDB complexity

**Cons:**
- ❌ No offline support
- ❌ Requires constant internet connection
- ❌ Slower than local queries (network latency)
- ❌ Loss of existing offline-first architecture
- ❌ Poor user experience on slow connections

**Estimated Effort:** 8-12 developer weeks

**Implementation Steps:**
1. Create Supabase repository implementations for all 16 tables
2. Add JSON serialization to all domain models
3. Update all service layers to use new repositories
4. Remove Drift dependencies
5. Add connection state management
6. Implement error handling for network failures

### ❌ Option B: IndexedDB with Drift Web (Rejected - Overkill)

**Description:** Use Drift's WASM implementation with IndexedDB storage, maintaining offline-first architecture.

**Pros:**
- ✅ Maintains offline-first architecture
- ✅ Minimal code changes (mostly configuration)
- ✅ Type-safe queries preserved
- ✅ Migration path from mobile
- ✅ Good performance for read-heavy workloads

**Cons:**
- ❌ Complex setup (WASM, web workers)
- ❌ Large bundle size (3-4 MB for SQLite WASM)
- ❌ IndexedDB has browser-specific quirks
- ❌ Sync logic still needed for backend
- ❌ WASM debugging is difficult

**Estimated Effort:** 12-18 developer weeks

**Implementation Steps:**
1. Add `drift/wasm.dart` dependency
2. Create conditional database initialization
3. Host SQLite WASM files
4. Configure web workers
5. Test IndexedDB limits (browser-dependent)
6. Implement sync strategy with Supabase
7. Handle browser storage quotas

### ✅ Option C: Hybrid IndexedDB Cache + Supabase (SELECTED)

**Description:** Three-tier caching architecture with in-memory cache, IndexedDB persistence, and Supabase as authoritative source.

**Pros:**
- ✅ **10x faster than Option A** - Cached reads are instant
- ✅ **80% less complexity than Option B** - Eliminates 2,000 lines of sync code
- ✅ **Web-appropriate architecture** - Stale-while-revalidate pattern
- ✅ **Small bundle size** - No SQLite WASM (+1MB saved vs Option B)
- ✅ **Graceful degradation** - Works offline with cached data
- ✅ **Simple invalidation** - TTL-based cache expiry vs bidirectional sync

**Cons:**
- ❌ Read-only offline (can't create new plans offline)
- ❌ Still requires some cache management code (~400 lines)
- ❌ Browser storage quotas to manage (10MB-50MB typical)

**Estimated Effort:** 3 weeks (vs 8-12 for Option A, 12-18 for Option B)

**Implementation Steps:**
1. **Week 1: Core Cache Layer**
   - Add idb_shim dependency
   - Create WebCacheService class
   - Cache foods database (50KB, 7-day TTL)
   - Cache content/UI text (10KB, 1-day TTL)
   - Cache user profile (2KB, 1-day TTL)
   - **Result**: 80% of reads are instant

2. **Week 2: Smart Invalidation**
   - Implement TTL-based caching
   - Stale-while-revalidate pattern
   - Background sync on cache expiry
   - Test cache invalidation on user actions

3. **Week 3: Optimistic Writes**
   - Implement write queue for background uploads
   - Add retry logic with exponential backoff
   - Sync on network reconnect
   - Simplified dirty flag management

**Skipped for MVP (Optional Phase 2):**
- Service workers (Workbox)
- PWA manifest and install prompts
- Custom offline page
- Background sync for failed requests

**Performance Comparison:**

| Metric | Option A | Option B | Option C ✅ |
|--------|----------|----------|------------|
| Initial load | 3-5s | 6-8s | 2-3s |
| Cached read | 500ms | 50ms | <10ms |
| Bundle size | +0MB | +3-4MB | +0.2MB |
| Code complexity | Medium | High | Low |
| Offline capability | None | Full | Read-only |
| Implementation time | 8-12 weeks | 12-18 weeks | **3 weeks** |

**Why This Is The Sweet Spot:**
1. **Data characteristics match perfectly**: 90% reads, small dataset (87KB), infrequent writes
2. **Use case alignment**: AI generation requires internet anyway
3. **Web patterns**: Stale-while-revalidate is standard for web apps
4. **Maintainability**: 80% less sync code than current architecture
5. **Performance**: 10x faster than pure Supabase, without WASM overhead

---

## 5. Renderer Options (2025 Update)

### ⚠️ Important: `--web-renderer` Flag Deprecated

As of Flutter 3.24+, the `--web-renderer` flag is deprecated. Use `--wasm` instead for the new Skwasm renderer.

### Skwasm Renderer (Recommended for 2025)

**Characteristics:**
- Uses WebAssembly for rendering
- Fastest Flutter web renderer available
- Smaller bundle size (~1.1 MB vs 1.5 MB CanvasKit)
- Automatic fallback to CanvasKit on unsupported browsers
- Better performance than CanvasKit

**Browser Support:**
- Chrome 119+
- Safari 18+
- Firefox (with Wasm GC support)
- Automatic fallback to CanvasKit on older browsers

**Build Command:**
```bash
# Recommended for 2025
flutter build web --release --wasm --pwa-strategy=none
```

### CanvasKit Renderer (Automatic Fallback)

**Characteristics:**
- Uses WebGL for rendering
- Better visual consistency with mobile
- Larger bundle (~1.5 MB)
- Works on all modern browsers
- Automatic fallback when Skwasm not supported

**Build Command:**
```bash
# Default (no need to specify renderer)
flutter build web --release --pwa-strategy=none
```

### Renderer Comparison Table

| Renderer | Command | Size | Browser Support | Performance | Recommendation |
|----------|---------|------|-----------------|-------------|----------------|
| **Skwasm** | `--wasm` | +1.1MB | Chrome 119+, Safari 18+ | Fastest | ✅ Recommended |
| **CanvasKit** | default | +1.5MB | All modern browsers | Good | Auto-fallback |
| ~~HTML~~ | ~~`--web-renderer html`~~ | ~~+1MB~~ | ~~All~~ | ~~Slowest~~ | ⛔ Deprecated |

**Note:** Skwasm automatically falls back to CanvasKit on unsupported browsers, giving you the best of both worlds.

### Recommendation for Mealvana

**Use Skwasm (via `--wasm` flag)** because:
1. ✅ **Fastest renderer** - Better than both CanvasKit and HTML
2. ✅ **Smaller bundle** - 1.1MB vs 1.5MB (CanvasKit) or 1MB (deprecated HTML)
3. ✅ **Automatic fallback** - Users on older browsers still get CanvasKit
4. ✅ **Future-proof** - Flutter's recommended renderer going forward
5. ✅ **No downsides** - Works everywhere with graceful degradation

---

## 6. Bundle Size Optimization

### Expected Web Bundle Sizes (2025 Update)

**Using Skwasm Renderer (Recommended):**
- Without optimization: 3-4 MB
- With optimization: 2-3 MB
- Bundle size reduction: ~0.4MB vs CanvasKit

**Using CanvasKit Renderer (Fallback):**
- Without optimization: 4-5 MB
- With optimization: 3-4 MB

**Key Improvement:** Skwasm reduces bundle size by ~20% compared to CanvasKit.

### Optimization Strategies

1. **Use Skwasm Renderer** (primary optimization)
```bash
flutter build web --release --wasm --pwa-strategy=none
```

2. **Tree Shaking** (automatic in release mode)
```bash
# Tree shaking happens automatically with --release flag
flutter build web --release --wasm --pwa-strategy=none
```

3. **Deferred Loading**
```dart
// lib/features/nutrition_plan/presentation/screens/nutrition_plan_screen.dart
import 'package:flutter/widgets.dart' deferred as nutrition;

Future<void> showNutritionPlan() async {
  await nutrition.loadLibrary();
  Navigator.push(/* ... */);
}
```

4. **Remove Unused Assets**
```yaml
# pubspec.yaml
flutter:
  assets:
    # Only include essential images
    - assets/images/logo.svg
    # Don't include large PNGs or unnecessary files
```

5. **Lazy Load Images**
```dart
CachedNetworkImage(
  imageUrl: food.imageUrl,
  placeholder: (context, url) => Icon(Icons.fastfood),
  errorWidget: (context, url, error) => Icon(Icons.error),
)
```

6. **Code Splitting by Feature**
```dart
// Lazy load entire features
import 'features/barcode_scanning/presentation/barcode_screen.dart'
    deferred as barcode;
```

---

## 7. SEO and Accessibility Considerations

### Current SEO Limitations

Flutter Web is a Single Page Application (SPA), which has inherent SEO challenges:

**Problems:**
- ❌ JavaScript-rendered content (search engines struggle)
- ❌ No server-side rendering (SSR)
- ❌ Limited meta tag control
- ❌ No sitemap generation
- ❌ Poor crawlability of dynamic routes

### SEO Solutions

1. **Flutter Web with Pre-rendering** (Recommended)
```yaml
# Use flutter_web_prerenderer package
dev_dependencies:
  flutter_web_prerenderer: ^1.0.0
```

2. **Add Static Landing Pages** (SEO-focused)
```
web/
├── index.html          # Main SPA
├── about.html          # Static pre-rendered page
├── features.html       # Static pre-rendered page
└── nutrition-guide.html # Static pre-rendered page
```

3. **Meta Tags in index.html**
```html
<!-- web/index.html -->
<head>
  <meta name="description" content="AI-powered nutrition planning for endurance athletes">
  <meta name="keywords" content="nutrition, endurance, running, cycling, triathlon">
  <meta property="og:title" content="Mealvana Endurance">
  <meta property="og:description" content="Personalized nutrition plans for runners and triathletes">
  <meta property="og:image" content="https://mealvana.com/og-image.png">

  <!-- Schema.org markup -->
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "name": "Mealvana Endurance",
    "applicationCategory": "HealthApplication",
    "offers": {
      "@type": "Offer",
      "price": "0"
    }
  }
  </script>
</head>
```

### Accessibility Considerations

**Current Issues:**
- Custom Flutter widgets may not generate proper ARIA labels
- Screen readers struggle with Canvas-rendered content
- Keyboard navigation may not work as expected

**Solutions:**

1. **Use Skwasm Renderer (2025 Recommended)**
```bash
flutter build web --release --wasm --pwa-strategy=none
```

**Note:** The old `--web-renderer html` flag is deprecated. Skwasm provides better accessibility than the old HTML renderer while maintaining good performance.

2. **Add Semantic Labels**
```dart
Semantics(
  label: 'Generate nutrition plan',
  button: true,
  child: ElevatedButton(
    onPressed: () => _generatePlan(),
    child: Text('Generate Plan'),
  ),
)
```

3. **Test with Screen Readers**
- NVDA (Windows)
- JAWS (Windows)
- VoiceOver (macOS)
- TalkBack (Android)

---

## 8. Testing Strategy

### Platform-Specific Testing

**Required Test Environments:**
1. Chrome (primary target)
2. Firefox
3. Safari (macOS, iOS)
4. Edge
5. Mobile browsers (Chrome Mobile, Safari Mobile)

### Test Categories

1. **Database Migration Tests**
```dart
// test/integration/database_migration_test.dart
void main() {
  testWidgets('Web database initializes correctly', (tester) async {
    if (kIsWeb) {
      final db = WebAppDatabase();
      await db.ensureOpen();

      // Verify tables exist
      final users = await db.select(db.userProfilesTable).get();
      expect(users, isNotEmpty);
    }
  });
}
```

2. **Cross-Browser Compatibility Tests**
```yaml
# integration_test/web_test.yaml
name: Web Integration Tests
platforms:
  - chrome
  - firefox
  - safari
  - edge
```

3. **Offline Functionality Tests**
```dart
void main() {
  test('App works offline with cached data', () async {
    // Simulate offline mode
    await mockOfflineMode();

    // Should still load cached nutrition plans
    final plans = await repository.getCachedPlans();
    expect(plans, isNotEmpty);
  });
}
```

---

## 9. Deployment Strategy (Vercel Recommended)

### Why Vercel?

**Advantages:**
- ✅ Automatic HTTPS
- ✅ Global CDN
- ✅ Instant deployments
- ✅ Preview URLs for PRs
- ✅ Environment variables
- ✅ Edge functions support
- ✅ Free tier for startups

### Deployment Configuration

**File:** `vercel.json`
```json
{
  "version": 2,
  "builds": [
    {
      "src": "web/**",
      "use": "@vercel/static"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/web/index.html"
    }
  ],
  "env": {
    "SUPABASE_URL": "@supabase-url",
    "SUPABASE_ANON_KEY": "@supabase-anon-key"
  }
}
```

### Build Configuration

**GitHub Actions Workflow:**
```yaml
# .github/workflows/deploy-web.yml
name: Deploy Web to Vercel

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'

      - name: Build web
        run: |
          flutter pub get
          flutter build web --release --wasm --pwa-strategy=none

      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v20
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          working-directory: ./build/web
```

### Alternative: Firebase Hosting

```yaml
# firebase.json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

---

## 10. Estimated Timeline and Effort

### Option A: Supabase-Only (Online-Only)

| Phase | Duration | Tasks |
|-------|----------|-------|
| Phase 1: Repository Layer | 2-3 weeks | Create Supabase repositories for 16 tables |
| Phase 2: Service Layer | 2-3 weeks | Update services, remove Drift dependencies |
| Phase 3: OAuth & Auth | 1-2 weeks | Implement Supabase OAuth flow |
| Phase 4: Platform Code | 1 week | Replace Platform checks with kIsWeb |
| Phase 5: Testing | 2-3 weeks | Cross-browser testing, bug fixes |
| **TOTAL** | **8-12 weeks** | **40-60 developer days** |

### Option B: IndexedDB with Drift Web (Offline-Capable)

| Phase | Duration | Tasks |
|-------|----------|-------|
| Phase 1: WASM Setup | 2-3 weeks | Configure drift/wasm, web workers |
| Phase 2: Conditional Init | 1-2 weeks | Platform-specific database initialization |
| Phase 3: Sync Strategy | 3-4 weeks | Implement Drift ↔ Supabase sync |
| Phase 4: OAuth & Auth | 1-2 weeks | Supabase OAuth flow |
| Phase 5: Platform Code | 1 week | Replace Platform checks |
| Phase 6: Testing | 3-4 weeks | Cross-browser, offline scenarios |
| **TOTAL** | **12-18 weeks** | **60-90 developer days** |

### Option C: Hybrid IndexedDB + Supabase (SELECTED - MVP)

| Phase | Duration | Tasks |
|-------|----------|-------|
| Phase 1: Core Cache Layer | 1 week | WebCacheService, Foods/Content/User caching |
| Phase 2: Smart Invalidation | 1 week | TTL-based caching, stale-while-revalidate |
| Phase 3: Optimistic Writes | 1 week | Write queue, retry logic, conflict resolution |
| **TOTAL (MVP)** | **3 weeks** | **15 developer days** |

**Optional Phase 2: PWA Features (if needed later)**

| Phase | Duration | Tasks |
|-------|----------|-------|
| Phase 4: Service Workers | 1 week | Workbox setup, PWA manifest, offline page |
| **TOTAL (with PWA)** | **4 weeks** | **20 developer days** |

---

## 11. Risk Assessment

### High-Risk Areas

1. **Data Migration** (Risk Level: HIGH)
   - **Impact:** Data loss or corruption
   - **Mitigation:** Extensive testing, backup strategies, gradual rollout

2. **Performance Degradation** (Risk Level: MEDIUM)
   - **Impact:** Slower web app than mobile
   - **Mitigation:** Performance profiling, optimization, caching strategies

3. **Browser Compatibility** (Risk Level: MEDIUM)
   - **Impact:** App breaks in certain browsers
   - **Mitigation:** Cross-browser testing, progressive enhancement

4. **Bundle Size** (Risk Level: LOW)
   - **Impact:** Slow initial load
   - **Mitigation:** Code splitting, lazy loading, tree shaking

### Recommended Approach

**Use Option C (Hybrid IndexedDB + Supabase) for MVP:**

**Reasoning:**
1. Fastest time to market (3 weeks)
2. Best performance (10x faster than Supabase-only)
3. Lowest complexity (80% less code than full offline sync)
4. Web-appropriate architecture (stale-while-revalidate is standard)
5. Can add PWA features later if needed (Week 4)

**Future Enhancement Path:**
- MVP: 3-week hybrid caching implementation (Option C without PWA)
- Phase 2: Add service workers/PWA if user demand exists (Week 4)
- Phase 3: Enhanced offline features if needed

---

## 12. Success Metrics

### Technical Metrics

- ✅ **Web Build Success:** Flutter web builds without errors
- ✅ **Bundle Size:** < 3 MB for HTML renderer
- ✅ **Initial Load Time:** < 3 seconds on 3G
- ✅ **Lighthouse Score:** > 80 for Performance, Accessibility, Best Practices
- ✅ **Cross-Browser Support:** Works on Chrome, Firefox, Safari, Edge
- ✅ **Mobile Web:** Responsive and functional on mobile browsers

### Business Metrics

- ✅ **Feature Parity:** 100% of core features work on web
- ✅ **User Acquisition:** Web version available for demo/trial
- ✅ **SEO:** Basic search engine discoverability
- ✅ **Analytics:** Full event tracking works on web
- ✅ **Error Rate:** < 1% error rate in production

---

## 13. Next Steps

### Immediate Actions (Week 1)

1. **Decision Meeting:**
   - Review this document with team
   - Choose implementation option (A, B, or C)
   - Get stakeholder buy-in

2. **Proof of Concept:**
   - Create minimal web build
   - Test basic navigation
   - Validate Supabase connectivity

3. **Resource Planning:**
   - Allocate developer time
   - Set milestones
   - Define success criteria

### Phase 1 Kickoff (Week 2)

1. **Setup Development Environment:**
   - Configure web debugging
   - Setup Chrome DevTools
   - Install web-specific dependencies

2. **Create Feature Branch:**
   ```bash
   git checkout -b feature/web-support
   ```

3. **Begin Implementation:**
   - Follow roadmap.md for detailed steps
   - Track progress in GitHub Issues
   - Regular demos to stakeholders

---

## 14. Related Documentation

- 📋 [Implementation Roadmap](./roadmap.md) - Detailed implementation phases
- 🚫 [Technical Blockers](./blockers.md) - Deep dive into code-level issues
- 🏗️ [FOA Architecture](../technical/foa-architecture.md) - Current architecture patterns
- 💾 [Database Overview](../database/README.md) - Current database implementation
- 🔧 [Technical Implementation](../technical/README.md) - General technical guide

---

**Document Version:** 1.0
**Last Updated:** 2025-12-15
**Status:** Draft for Review
**Maintainer:** Development Team
