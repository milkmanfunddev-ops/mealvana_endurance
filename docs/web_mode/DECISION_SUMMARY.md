# Web Deployment Decision Summary

**Date:** 2025-12-16
**Decision:** Simplified to Web-Specific Repositories + In-Memory Cache Only

---

## What Changed

### Previous Decision (2025-12-15)
**Option C: Hybrid IndexedDB Cache + Supabase**
- Three-tier caching (In-Memory → IndexedDB → Supabase)
- idb_shim dependency
- ~400 lines of cache management code
- 3-week timeline

### New Decision (2025-12-16)
**Web Repositories + In-Memory Cache Only**
- Two-tier architecture (In-Memory → Supabase)
- Zero dependencies beyond Supabase
- ~500 lines total (including repositories)
- **2-week timeline**

---

## Why We Simplified Further

### Key Realizations

1. **IndexedDB adds complexity without clear benefit for MVP**
   - Persistent cache across refresh is nice-to-have, not must-have
   - Web users expect to be online
   - Can add later if users complain

2. **In-memory cache is sufficient**
   - 67KB dataset is negligible for browser memory
   - TTL-based expiration is simple
   - Lost on refresh is acceptable trade-off

3. **Fastest path to market wins**
   - 2 weeks vs 3 weeks = 33% faster delivery
   - Zero dependencies = zero maintenance overhead
   - Clear upgrade path if persistence is needed

---

## Architecture Comparison

### Previous (Option C)
```
User Request
    ↓
In-Memory Cache (<1ms)
    ↓ (miss)
IndexedDB Cache (<10ms) ← Requires idb_shim
    ↓ (miss/expired)
Supabase API (200-500ms)
```

### Current (Simplified)
```
User Request
    ↓
In-Memory Cache (<10ms) ← Simple Dart Map
    ↓ (miss/expired)
Supabase API (200-500ms)
```

**Eliminated:**
- idb_shim dependency
- IndexedDB initialization and management
- Persistent storage quota handling
- Storage API calls
- ~300 lines of IndexedDB-specific code

**Added:**
- Nothing! Just simpler code.

---

## Implementation Comparison

| Aspect | Option C (IndexedDB) | Simplified (Memory Only) |
|--------|---------------------|--------------------------|
| **Dependencies** | +idb_shim | None |
| **Code Lines** | ~800 total | ~500 total |
| **Complexity** | Medium | Low |
| **Timeline** | 3 weeks | **2 weeks** |
| **Persistence** | Yes | No (Phase 2) |
| **Maintenance** | Medium | Minimal |

---

## What We Keep

1. **Web repositories pattern** - New `*_repository_web.dart` files
2. **Conditional providers** - `kIsWeb` logic in providers
3. **In-memory caching** - Simple `CachedData<T>` class
4. **Zero controller changes** - Same controllers work on both platforms
5. **Vercel deployment** - Edge CDN for static assets

---

## What We Defer to Phase 2

### IndexedDB Persistent Caching

**When to add:**
- Users complain about slow page refresh
- Analytics show high page refresh rates
- Offline features become a user request

**Estimated effort:** 1 additional week

**Implementation path:**
```dart
// Current (MVP)
class WebFoodRepository {
  CachedData<List<Food>>? _memoryCache;
  // Direct Supabase calls
}

// Future (Phase 2)
class WebFoodRepositoryWithPersistence {
  CachedData<List<Food>>? _memoryCache;
  late Database _indexedDb;

  Future<List<Food>> getAllFoods() {
    // 1. Try memory (instant)
    // 2. Try IndexedDB (10ms)
    // 3. Fetch from Supabase (200-500ms)
  }
}
```

### Service Workers

**When to add:**
- User requests for offline app functionality
- PWA install prompts become desired

**Estimated effort:** 1 additional week

---

## Risk Assessment

### Low-Risk Decision

**Why this is safe:**
1. **No breaking changes** - Mobile app completely untouched
2. **Incremental approach** - Can add IndexedDB later without refactoring
3. **User-driven** - Only add complexity based on actual user feedback
4. **Fast validation** - Get web version in users' hands 33% faster

### Contingency Plan

**If users complain about page refresh performance:**
- Week 3: Implement IndexedDB persistence layer
- Estimated: 5-7 days to add
- Zero refactoring needed (repositories already abstracted)

---

## Documentation Updated

### Files Modified

1. **CLAUDE.md**
   - Updated web deployment section with simplified approach
   - Changed timeline from 3 weeks to 2 weeks
   - Moved IndexedDB to Phase 2

2. **docs/web_mode/README.md**
   - Updated decision rationale
   - Simplified architecture diagrams
   - Changed estimated effort to 2 weeks

3. **docs/web_mode/cache-strategy.md**
   - Simplified from three-tier to two-tier caching
   - Removed IndexedDB implementation details from main sections
   - Moved IndexedDB to appendix for future reference

4. **docs/web_mode/roadmap-simplified.md** (NEW)
   - Complete 2-week implementation plan
   - Day-by-day breakdown
   - Simple code examples
   - Clear Phase 2 upgrade path

### Key Messages

**Emphasized throughout:**
- "Simplest possible implementation"
- "Web users expect to be online"
- "Start simple, add complexity only if needed"
- "2-week MVP, 1-week Phase 2 if needed"

---

## Next Steps

### Immediate (Week 1)
1. Extract repository interfaces (Days 1-2)
2. Create web repository implementations (Days 3-5)
3. Update conditional providers (Days 6-7)
4. Testing and bug fixes (Days 8-10)

### Near-term (Week 2)
1. Add in-memory caching (Days 11-12)
2. Determine optimal TTLs (Days 13-14)
3. Performance testing and optimization (Day 15)

### Future (Phase 2, if needed)
1. IndexedDB persistence (1 week)
2. Service workers and PWA (1 week)

---

## Approval and Sign-off

**Decision maker:** Lee Martin (Development Team)
**Date approved:** 2025-12-16
**Status:** Active - ready for implementation

**Reasoning:** Prioritize speed to market and simplicity. Add complexity only when justified by user feedback, not proactively.

---

**Document Version:** 1.0
**Last Updated:** 2025-12-16
**Related:** [roadmap-simplified.md](./roadmap-simplified.md), [cache-strategy.md](./cache-strategy.md)
