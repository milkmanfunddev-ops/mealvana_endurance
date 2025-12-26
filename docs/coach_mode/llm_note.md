# Coach Mode Implementation Handoff

**Created**: 2025-12-26
**Purpose**: Context and instructions for continuing coach mode implementation in the correct worktree
**Target Worktree**: `/Users/leemartin/development/mealvana_endurance_coach_mode` (branch: `feature/coach-mode`)

---

## Session Summary

A planning session was conducted to clarify requirements and simplify the coach mode MVP. This document contains all decisions made and implementation instructions.

---

## Key Decisions Made

| Decision | Answer | Notes |
|----------|--------|-------|
| **Hosting** | Vercel | Not Cloudflare (simpler) |
| **Domain** | enduranceapp.mealvana.io | |
| **Database approach** | Switch to `drift/web.dart` | Simpler than drift/wasm, no COOP/COEP headers needed |
| **Billing** | Free during beta | No Stripe initially |
| **Coach registration** | Invite-only beta | No public registration UI needed |
| **Coach verification** | Manual only | Owner approves each coach personally |
| **Invitation method** | Both email AND shareable link | Coach chooses |
| **Coach permissions** | Full CRUD | Create, view, edit, delete athlete data |
| **Athlete auth** | Require account upgrade | Athletes must be authenticated users |
| **Email notifications** | Skip for MVP | Add later |
| **Data access** | Everything | Plans, activities, preferences, biometrics |
| **Beta coaches** | 5-10 ready | Owner has contacts |
| **Availability** | Full-time focus | |
| **Testing** | Parallel | Test web while building coach mode |

---

## Technical Approach: Database

### Current State (drift/wasm)
The codebase currently uses `drift/wasm.dart` with `WasmDatabase`:
- Requires `sqlite3.wasm` and `drift_worker.dart.js` files
- Requires COOP/COEP HTTP headers for SharedArrayBuffer
- More complex setup

### Recommended Change (drift/web)
Switch to `drift/web.dart` with `WebDatabase`:
- Uses sql.js (JavaScript SQLite)
- Stores data in IndexedDB
- **No special HTTP headers required**
- Simpler setup

### Code Change Required

**File**: `lib/shared/database/connection_web.dart`

**FROM** (current):
```dart
// Web platform database connection implementation
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';

/// Web platform connection using WebAssembly SQLite
LazyDatabase openNativeConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'mealvana_db',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );

    if (kDebugMode && result.missingFeatures.isNotEmpty) {
      debugPrint('[DRIFT_WEB] Storage: ${result.chosenImplementation}');
      debugPrint('[DRIFT_WEB] Missing features: ${result.missingFeatures}');
    }

    return result.resolvedExecutor;
  });
}

/// Create in-memory web database for testing
QueryExecutor createNativeMemoryDatabase() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'test_db_${DateTime.now().millisecondsSinceEpoch}',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );
    return result.resolvedExecutor;
  });
}
```

**TO** (new):
```dart
// Web platform database connection implementation
// Uses drift/web.dart with sql.js - simpler approach, no WASM headers required
import 'package:drift/drift.dart';
import 'package:drift/web.dart';
import 'package:flutter/foundation.dart';

/// Web platform connection using sql.js (JavaScript SQLite)
/// Stores data in IndexedDB for persistence across sessions
/// No special COOP/COEP headers required (unlike drift/wasm.dart)
LazyDatabase openNativeConnection() {
  return LazyDatabase(() async {
    if (kDebugMode) {
      debugPrint('[DRIFT_WEB] Opening database with sql.js backend');
    }

    // WebDatabase uses sql.js and stores data in IndexedDB
    return WebDatabase('mealvana_db');
  });
}

/// Create in-memory web database for testing
QueryExecutor createNativeMemoryDatabase() {
  return LazyDatabase(() async {
    // Use a unique name for each test to avoid conflicts
    final testDbName = 'test_db_${DateTime.now().millisecondsSinceEpoch}';
    if (kDebugMode) {
      debugPrint('[DRIFT_WEB] Creating test database: $testDbName');
    }
    return WebDatabase(testDbName);
  });
}
```

---

## Vercel Configuration

**Create file**: `vercel.json` in project root

```json
{
  "buildCommand": "flutter build web --release --wasm --pwa-strategy=none",
  "outputDirectory": "build/web",
  "framework": null,
  "rewrites": [
    {
      "source": "/((?!assets|icons|favicon|manifest|flutter).*)",
      "destination": "/index.html"
    }
  ],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        },
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        },
        {
          "key": "X-XSS-Protection",
          "value": "1; mode=block"
        }
      ]
    },
    {
      "source": "/assets/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=31536000, immutable"
        }
      ]
    }
  ]
}
```

**Note**: No COOP/COEP headers needed since we're using drift/web.dart

---

## Simplified MVP Scope

### What to Build

**Week 1: Web Foundation**
1. Switch to drift/web.dart (code change above)
2. Test `flutter run -d chrome`
3. Set up Vercel deployment
4. Add role infrastructure (`is_coach` flag on users table)

**Week 2: Coach-Athlete Linking**
1. Create `coach_athlete_relationships` table
2. Simple invitation flow (link generation)
3. Basic coach dashboard (list of linked athletes)

**Week 3: Data Access**
1. Coach can view athlete data (plans, activities, preferences, biometrics)
2. Coach can create/edit nutrition plans for athletes
3. Basic mode toggle (if coach, show coach UI)

### What to Skip (for MVP)

- Public coach registration UI (invite-only)
- Email notifications
- Admin dashboard (create coaches via Supabase directly)
- Messaging (can add later)
- Stripe billing (free beta)
- Real-time features

---

## Role Infrastructure

Add `is_coach` column to users table:

**Drift migration** (in `lib/shared/database/tables/user_profiles.dart`):
```dart
/// Whether this user has coach privileges
BoolColumn get isCoach => boolean().withDefault(const Constant(false)).named('is_coach')();
```

**Supabase migration**:
```sql
ALTER TABLE users ADD COLUMN is_coach BOOLEAN DEFAULT false;
```

---

## Coach-Athlete Relationship Table

**Create new table** `coach_athlete_relationships`:

```sql
CREATE TABLE coach_athlete_relationships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_user_id UUID NOT NULL REFERENCES users(id),
  athlete_user_id UUID NOT NULL REFERENCES users(id),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'declined', 'archived')),
  permission_level TEXT NOT NULL DEFAULT 'full_access' CHECK (permission_level IN ('view_only', 'full_access')),
  invitation_token TEXT UNIQUE,
  invitation_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  accepted_at TIMESTAMPTZ,

  UNIQUE(coach_user_id, athlete_user_id)
);

-- RLS Policies
ALTER TABLE coach_athlete_relationships ENABLE ROW LEVEL SECURITY;

-- Coaches can see their own relationships
CREATE POLICY "Coaches can view own relationships" ON coach_athlete_relationships
  FOR SELECT USING (coach_user_id = auth.uid() OR athlete_user_id = auth.uid());

-- Coaches can create invitations
CREATE POLICY "Coaches can create invitations" ON coach_athlete_relationships
  FOR INSERT WITH CHECK (coach_user_id = auth.uid());

-- Athletes can update (accept/decline) their invitations
CREATE POLICY "Athletes can update their invitations" ON coach_athlete_relationships
  FOR UPDATE USING (athlete_user_id = auth.uid());
```

---

## Existing Documentation

The following documentation already exists and has been updated:

- `/docs/coach_mode/README.md` - Full implementation roadmap (updated with Vercel, free beta)
- `/docs/coach_mode/DEPLOYMENT_ROADMAP.md` - Simplified ASAP timeline
- `/docs/coach_mode/IMPLEMENTATION_CHECKLIST.md` - Step-by-step tasks
- `/docs/coach_mode/STATUS.md` - Current implementation status
- `/docs/features/coach_mode/schema_analysis.md` - Complete database schema (2,000+ lines)

---

## Implementation Order

1. **First**: Update `connection_web.dart` (drift/web change)
2. **Second**: Create `vercel.json`
3. **Third**: Test web build: `flutter run -d chrome`
4. **Fourth**: Add `is_coach` column to users table
5. **Fifth**: Create `coach_athlete_relationships` table
6. **Sixth**: Build invitation flow (generate link, accept link)
7. **Seventh**: Build coach dashboard (list athletes)
8. **Eighth**: Build athlete detail view
9. **Ninth**: Add mode toggle widget

---

## Testing Commands

```bash
# Test web build locally
flutter run -d chrome

# Build for production
flutter build web --release --wasm --pwa-strategy=none

# Deploy to Vercel (after setup)
vercel --prod
```

---

## Environment Variables (Vercel Dashboard)

```
SUPABASE_URL=https://[project-ref].supabase.co
SUPABASE_ANON_KEY=[anon-key]
SENTRY_DSN=[sentry-dsn]
```

---

## Questions Answered During Planning

1. **Why drift/web instead of drift/wasm?**
   - Simpler setup, no COOP/COEP headers required
   - User was concerned about header complexity

2. **Why invite-only beta?**
   - Skip public registration UI complexity
   - Owner has 5-10 coaches ready to try it
   - Can add registration later

3. **Why skip email notifications?**
   - Adds complexity (SendGrid/SES setup)
   - Users can check app manually for MVP
   - Add later based on feedback

4. **Why free beta?**
   - Skip Stripe integration initially
   - Focus on core functionality
   - Add billing when scaling (20+ coaches)

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Web deployment | Working on Vercel |
| Beta coaches | 5-10 verified |
| Coach-athlete connections | 20+ active |
| Error rate | <5% on core flows |
| Page load time | <3 seconds |

---

**End of Handoff Document**
