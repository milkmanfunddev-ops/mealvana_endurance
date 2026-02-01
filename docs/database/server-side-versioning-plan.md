# Server-Side Data Versioning Plan

> **Status:** Implemented
> **Created:** January 2026
> **Last Updated:** January 2026

## Executive Summary

This document outlines a comprehensive plan to migrate from client-side Drift migrations to server-controlled data versioning. The goal is to simplify schema management by:

1. **Eliminating Drift migration files** - No more `migration_v1_to_v2.dart`
2. **Server controls versioning** - Supabase determines what action the app should take
3. **Delete and resync for non-breaking changes** - Instead of complex migrations
4. **Force app updates for breaking changes** - Simple version gate
5. **Lightweight server compatibility layer** - Transform data for older app versions

**Expected outcomes:**
- Delete 500+ lines of migration code
- Add ~200 lines of simpler version-checking code
- Faster development cycle for schema changes
- Clearer mental model for handling versions

---

## Table of Contents

1. [Current State Analysis](#1-current-state-analysis)
2. [Problems with Current Approach](#2-problems-with-current-approach)
3. [Target Architecture](#3-target-architecture)
4. [Detailed Implementation Plan](#4-detailed-implementation-plan)
5. [Server Components](#5-server-components)
6. [App Components](#6-app-components)
7. [Files to Create, Modify, and Delete](#7-files-to-create-modify-and-delete)
8. [Data Migration Strategy](#8-data-migration-strategy)
9. [Testing Strategy](#9-testing-strategy)
10. [Rollback Plan](#10-rollback-plan)
11. [Future Schema Changes Workflow](#11-future-schema-changes-workflow)
12. [Open Questions and Decisions](#12-open-questions-and-decisions)

---

## 1. Current State Analysis

### 1.1 Current Schema Version

- **Drift Schema Version:** v3
- **Total Tables:** 22
- **Tables with `needs_upload` tracking:** 8

### 1.2 Current Migration System

The app uses Drift's `stepByStep` migration system with extracted migration files:

```dart
// Current app_database.dart
onUpgrade: stepByStep(
  from1To2: (m, schema) => runMigrationV1ToV2(this, m, schema),
  from2To3: (m, schema) => runMigrationV2ToV3(this, m, schema),
)
```

**Migration Files:**
- `lib/shared/database/migrations/migration_v1_to_v2.dart` (~300 lines)
- `lib/shared/database/migrations/migration_v2_to_v3.dart` (~200 lines)

### 1.3 Current App Startup Flow

```
main.dart
    ↓
ProviderScope → RootAppWidget
    ↓
MaterialApp.router (GoRouter)
    ↓
AppStartupWidget (watches appStartupProvider)
    ↓
appStartupProvider.build()
    ├── initializeDatabase()     ← Drift migrations run HERE
    ├── initializeSupabaseAuth()
    └── setSentryUserContext()
    ↓
Navigation decision
```

### 1.4 Current Sync Architecture

- **Sync Trigger:** OAuth sign-in only (not on app startup)
- **Sync Strategy:** Hybrid (edge function first, client-side fallback)
- **Dirty Record Tracking:** 8 tables with `needs_upload` column
- **Upload-First Pattern:** Dirty records uploaded before downloading

### 1.5 Current Edge Functions (Sync-Related)

| Function | Purpose |
|----------|---------|
| `sync-all-data` | Downloads all user data (incremental via timestamp) |
| `upload-all-data` | Uploads dirty records from 9 tables |

**Current limitation:** No compatibility layer - direct upserts without transformation.

---

## 2. Problems with Current Approach

### 2.1 Migration Complexity

- **500+ lines** of migration code across two files
- **Idempotent checks everywhere:** `if (!columns.contains('foo'))`
- **Brittle:** Easy to introduce bugs in migration logic
- **Hard to test:** Complex state transitions

### 2.2 Version Mismatch Risk

- Local Drift schema can get out of sync with Supabase
- No server-side awareness of client schema versions
- Dev vs. Prod Supabase have different schemas

### 2.3 No Graceful Handling of Old Clients

- Old apps sending data with missing columns can fail
- No transformation layer between client and server
- No clear "please update" mechanism

### 2.4 Documentation Sprawl

- Schema versions tracked in 3+ locations
- Migration files scattered across directories
- Hard to understand current state

---

## 3. Target Architecture

### 3.1 High-Level Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    SERVER-SIDE VERSIONING                       │
└─────────────────────────────────────────────────────────────────┘

App Startup
    ↓
Call edge function: check-version
    ├── Send: app_version, schema_version, has_dirty_records
    │
    ↓
Server responds with action:
    ├── "ok"          → Normal startup, sync normally
    ├── "resync"      → Delete local DB, download fresh
    ├── "upload_first"→ Upload dirty records, then resync
    └── "update_app"  → Show "Please Update" screen

For "resync":
    ↓
Delete local SQLite database
    ↓
Recreate fresh DB (Drift onCreate runs)
    ↓
Download all data from server
    ↓
Server transforms data to match client's schema version
    ↓
App continues with fresh data
```

### 3.2 Key Principles

1. **Server is source of truth** for versioning decisions
2. **Version check runs before Drift opens** using SharedPreferences-backed sync state
3. **Local-only UX state stays out of SQLite** (SharedPreferences) so resyncs don't wipe it
4. **No Drift migrations** - only `onCreate` for fresh databases
5. **Delete and resync** for non-breaking schema changes
6. **Force app update** for breaking schema changes
7. **Server transforms data** for older (but supported) clients
8. **Offline-first** - if version check fails, continue with cached data and retry later

### 3.3 Version Support Strategy

```
Server Schema: v4

┌──────────────────────────────────────────────────────────────┐
│  SUPPORTED (server transforms data)                          │
├──────────────────────────────────────────────────────────────┤
│  v3 apps → Server strips v4-only columns on download         │
│            Server adds defaults for v4 columns on upload     │
│                                                              │
│  v4 apps → Full compatibility, no transformation             │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  NOT SUPPORTED (forced to update)                            │
├──────────────────────────────────────────────────────────────┤
│  v1, v2 apps → "Please update your app"                      │
└──────────────────────────────────────────────────────────────┘
```

**Configuration is server-side:** Change which versions are supported by updating database, not code.

---

## 4. Detailed Implementation Plan

### 4.1 Phase 1: Server Infrastructure

**Duration:** 1-2 days

1. Create `app_config` table in Supabase
2. Create `schema_column_registry` table for tracking column changes
3. Create `check-version` edge function
4. Add compatibility layer to `sync-all-data` edge function
5. Add compatibility layer to `upload-all-data` edge function

### 4.2 Phase 2: App Changes

**Duration:** 2-3 days

1. Create `VersionCheckService` in app
2. Create `LocalSyncStateStore` (SharedPreferences) for dirty flag + schema metadata
3. Move local-only UX flags (e.g., `swipe_hint_shown`, `temp_plan_data`) out of Drift
4. Modify `AppStartupService` to check version before database init using `LocalSyncStateStore`
5. Update write paths and upload completion to set/clear dirty flag (replace DB scan)
6. Simplify `MigrationStrategy` (remove `onUpgrade`)
7. Add schema version to sync requests
8. Create `UpdateRequiredScreen` widget

### 4.3 Phase 3: Cleanup

**Duration:** 1 day

1. Delete migration files
2. Update documentation
3. Update CLAUDE.md

### 4.4 Phase 4: Testing & Validation

**Duration:** 2-3 days

1. Test fresh install flow
2. Test upgrade flow (resync)
3. Test dirty records flow (upload_first)
4. Test force update flow
5. Test compatibility layer transformations

---

## 5. Server Components

### 5.1 Database Tables

#### `app_config` Table

Stores global configuration including version requirements.

```sql
-- Supabase SQL
CREATE TABLE app_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS with public read
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read access" ON app_config
  FOR SELECT USING (true);

CREATE POLICY "Service role write access" ON app_config
  FOR ALL USING (auth.role() = 'service_role');

-- Initial data
INSERT INTO app_config (key, value, description) VALUES
  ('current_schema_version', '3', 'Current server schema version'),
  ('min_app_version', '1.2.0', 'Minimum app version required'),
  ('min_supported_schema', '2', 'Oldest schema version we transform for');
```

#### `schema_column_registry` Table

Tracks which columns were added in which schema version (for transformation).

```sql
CREATE TABLE schema_column_registry (
  id SERIAL PRIMARY KEY,
  added_in_version INTEGER NOT NULL,
  table_name TEXT NOT NULL,
  column_name TEXT NOT NULL,
  default_value JSONB,  -- JSON-encoded default for uploads from old clients
  transform_type TEXT DEFAULT 'nullable',  -- 'nullable', 'default', 'computed'
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(table_name, column_name)
);

-- Enable RLS with public read
ALTER TABLE schema_column_registry ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read access" ON schema_column_registry
  FOR SELECT USING (true);

-- Seed with current schema changes
INSERT INTO schema_column_registry (added_in_version, table_name, column_name, default_value, notes) VALUES
  -- V2 additions
  (2, 'food_preferences', 'preference_level', '2', 'Default to neutral (2)'),
  (2, 'food_preferences', 'preference_source', '"manual"', 'Default to manual'),
  (2, 'users', 'dietary_preference', 'null', 'Nullable'),
  (2, 'users', 'allergies', 'null', 'Nullable'),
  (2, 'users', 'needs_upload', 'false', 'Default false'),

  -- V3 additions
  (3, 'users', 'sweat_rate', '"medium"', 'Default to medium'),
  (3, 'users', 'is_coach', 'false', 'Default false'),
  (3, 'users', 'first_name', 'null', 'Nullable'),
  (3, 'users', 'last_name', 'null', 'Nullable'),
  (3, 'activities', 'synced_from_provider', 'null', 'Nullable'),
  (3, 'activities', 'provider_workout_id', 'null', 'Nullable'),
  (3, 'activities', 'provider_workout_url', 'null', 'Nullable'),
  (3, 'activities', 'last_synced_at', 'null', 'Nullable'),
  (3, 'activities', 'workout_subtype', 'null', 'Nullable'),
  (3, 'activities', 'pace_min_minutes_per_mile', 'null', 'Nullable'),
  (3, 'activities', 'pace_max_minutes_per_mile', 'null', 'Nullable'),
  (3, 'activities', 'distance_meters', 'null', 'Nullable');
```

### 5.2 Edge Function: `check-version`

**Purpose:** Called on app startup to determine what action the app should take.

**Request:**
```typescript
{
  app_version: string;       // "1.2.3"
  schema_version: number;    // 3
  has_dirty_records: boolean;
  device_id?: string;        // For logging
}
```

**Response:**
```typescript
{
  action: 'ok' | 'resync' | 'upload_first' | 'update_app';
  server_schema_version: number;
  min_app_version?: string;      // Only for 'update_app'
  message?: string;              // Human-readable explanation
}
```

**Implementation:**

```typescript
// supabase/functions/check-version/index.ts

import { createClient } from 'npm:@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

interface VersionCheckRequest {
  app_version: string;
  schema_version: number;
  has_dirty_records: boolean;
  device_id?: string;
}

interface VersionCheckResponse {
  action: 'ok' | 'resync' | 'upload_first' | 'update_app';
  server_schema_version: number;
  min_app_version?: string;
  message?: string;
}

function compareVersions(current: string, minimum: string): number {
  const currentParts = current.split('.').map(Number);
  const minParts = minimum.split('.').map(Number);

  for (let i = 0; i < Math.max(currentParts.length, minParts.length); i++) {
    const c = currentParts[i] || 0;
    const m = minParts[i] || 0;
    if (c < m) return -1;
    if (c > m) return 1;
  }
  return 0;
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body: VersionCheckRequest = await req.json();
    const { app_version, schema_version, has_dirty_records, device_id } = body;

    // Validate required fields
    if (!app_version || schema_version === undefined) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: app_version, schema_version' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // Fetch configuration
    const { data: configRows, error: configError } = await supabase
      .from('app_config')
      .select('key, value')
      .in('key', ['current_schema_version', 'min_app_version', 'min_supported_schema']);

    if (configError) {
      console.error('[CHECK_VERSION] Config fetch error:', configError);
      // Fail open - allow app to continue
      return new Response(
        JSON.stringify({ action: 'ok', server_schema_version: schema_version }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const config = Object.fromEntries(configRows.map(r => [r.key, r.value]));
    const serverSchemaVersion = parseInt(config.current_schema_version || '3');
    const minAppVersion = config.min_app_version || '1.0.0';
    const minSupportedSchema = parseInt(config.min_supported_schema || '1');

    const response: VersionCheckResponse = {
      action: 'ok',
      server_schema_version: serverSchemaVersion,
    };

    // Check 1: Is app version too old?
    if (compareVersions(app_version, minAppVersion) < 0) {
      response.action = 'update_app';
      response.min_app_version = minAppVersion;
      response.message = `Please update to version ${minAppVersion} or later`;

      console.log(`[CHECK_VERSION] ${device_id || 'unknown'}: App ${app_version} too old, needs ${minAppVersion}`);
      return new Response(
        JSON.stringify(response),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check 2: Is schema version too old to transform?
    if (schema_version < minSupportedSchema) {
      response.action = 'update_app';
      response.min_app_version = minAppVersion;
      response.message = `Your app version is no longer supported. Please update.`;

      console.log(`[CHECK_VERSION] ${device_id || 'unknown'}: Schema ${schema_version} below minimum supported ${minSupportedSchema}`);
      return new Response(
        JSON.stringify(response),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check 3: Schema mismatch - need to resync
    if (schema_version < serverSchemaVersion) {
      if (has_dirty_records) {
        response.action = 'upload_first';
        response.message = `Upload pending changes before schema upgrade (v${schema_version} → v${serverSchemaVersion})`;
        console.log(`[CHECK_VERSION] ${device_id || 'unknown'}: Schema ${schema_version} → ${serverSchemaVersion}, has dirty records`);
      } else {
        response.action = 'resync';
        response.message = `Schema upgrade required (v${schema_version} → v${serverSchemaVersion})`;
        console.log(`[CHECK_VERSION] ${device_id || 'unknown'}: Schema ${schema_version} → ${serverSchemaVersion}, clean resync`);
      }
      return new Response(
        JSON.stringify(response),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // All good
    console.log(`[CHECK_VERSION] ${device_id || 'unknown'}: OK (app ${app_version}, schema v${schema_version})`);
    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('[CHECK_VERSION] Error:', error);
    // Fail open - allow app to continue
    return new Response(
      JSON.stringify({ action: 'ok', server_schema_version: 3, message: 'Version check failed, continuing' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
```

### 5.3 Shared Compatibility Module

**Purpose:** Transform data between schema versions.

```typescript
// supabase/functions/_shared/schema_compat.ts

import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2'

interface ColumnRegistryEntry {
  added_in_version: number;
  table_name: string;
  column_name: string;
  default_value: any;
}

// Cache for column registry (refreshed per request)
let columnRegistryCache: ColumnRegistryEntry[] | null = null;

/**
 * Fetch the column registry from database
 */
async function getColumnRegistry(supabase: SupabaseClient): Promise<ColumnRegistryEntry[]> {
  if (columnRegistryCache) return columnRegistryCache;

  const { data, error } = await supabase
    .from('schema_column_registry')
    .select('added_in_version, table_name, column_name, default_value')
    .order('added_in_version', { ascending: true });

  if (error) {
    console.error('[SCHEMA_COMPAT] Failed to fetch column registry:', error);
    return [];
  }

  columnRegistryCache = data || [];
  return columnRegistryCache;
}

/**
 * Get columns that need to be stripped when sending data to an older client
 */
function getColumnsToStrip(
  registry: ColumnRegistryEntry[],
  tableName: string,
  clientVersion: number,
  serverVersion: number
): string[] {
  return registry
    .filter(entry =>
      entry.table_name === tableName &&
      entry.added_in_version > clientVersion &&
      entry.added_in_version <= serverVersion
    )
    .map(entry => entry.column_name);
}

/**
 * Get columns that need to be added (with defaults) when receiving data from an older client
 */
function getColumnsToAdd(
  registry: ColumnRegistryEntry[],
  tableName: string,
  clientVersion: number,
  serverVersion: number
): Array<{ column: string; defaultValue: any }> {
  return registry
    .filter(entry =>
      entry.table_name === tableName &&
      entry.added_in_version > clientVersion &&
      entry.added_in_version <= serverVersion
    )
    .map(entry => ({
      column: entry.column_name,
      defaultValue: entry.default_value, // Already JSON, parse if string
    }));
}

/**
 * Transform data for DOWNLOAD (server → client)
 * Strips columns that the client's schema doesn't know about
 */
export async function transformForDownload(
  supabase: SupabaseClient,
  data: any[],
  tableName: string,
  clientSchemaVersion: number,
  serverSchemaVersion: number
): Promise<any[]> {
  // No transformation needed if versions match
  if (clientSchemaVersion >= serverSchemaVersion) {
    return data;
  }

  const registry = await getColumnRegistry(supabase);
  const columnsToStrip = getColumnsToStrip(registry, tableName, clientSchemaVersion, serverSchemaVersion);

  if (columnsToStrip.length === 0) {
    return data;
  }

  console.log(`[SCHEMA_COMPAT] Stripping columns for ${tableName} (client v${clientSchemaVersion}):`, columnsToStrip);

  return data.map(row => {
    const filtered = { ...row };
    for (const col of columnsToStrip) {
      delete filtered[col];
    }
    return filtered;
  });
}

/**
 * Transform data for UPLOAD (client → server)
 * Adds missing columns with default values
 */
export async function transformForUpload(
  supabase: SupabaseClient,
  data: any[],
  tableName: string,
  clientSchemaVersion: number,
  serverSchemaVersion: number
): Promise<any[]> {
  // No transformation needed if versions match
  if (clientSchemaVersion >= serverSchemaVersion) {
    return data;
  }

  const registry = await getColumnRegistry(supabase);
  const columnsToAdd = getColumnsToAdd(registry, tableName, clientSchemaVersion, serverSchemaVersion);

  if (columnsToAdd.length === 0) {
    return data;
  }

  console.log(`[SCHEMA_COMPAT] Adding columns for ${tableName} (client v${clientSchemaVersion}):`,
    columnsToAdd.map(c => c.column));

  return data.map(row => {
    const augmented = { ...row };
    for (const { column, defaultValue } of columnsToAdd) {
      if (!(column in augmented)) {
        // Parse JSON default value if it's a string
        augmented[column] = typeof defaultValue === 'string'
          ? JSON.parse(defaultValue)
          : defaultValue;
      }
    }
    return augmented;
  });
}

/**
 * Clear the column registry cache (call at start of each request)
 */
export function clearRegistryCache(): void {
  columnRegistryCache = null;
}
```

### 5.4 Modify `sync-all-data` Edge Function

Add compatibility transformation to the existing sync function.

```typescript
// In supabase/functions/sync-all-data/index.ts

import { transformForDownload, clearRegistryCache } from '../_shared/schema_compat.ts'

// At the start of the handler:
clearRegistryCache();

// Get client schema version from request
const clientSchemaVersion = body.client_schema_version ?? 999; // Default high = no transform
const serverSchemaVersion = 3; // Or fetch from app_config

// After fetching each table, transform before returning:
const activities = await supabase.from('activities').select('*').eq('user_id', userId);
const transformedActivities = await transformForDownload(
  supabase,
  activities.data || [],
  'activities',
  clientSchemaVersion,
  serverSchemaVersion
);

// Return transformed data
return {
  activities: transformedActivities,
  // ... other tables
};
```

### 5.5 Modify `upload-all-data` Edge Function

Add compatibility transformation to the existing upload function.

```typescript
// In supabase/functions/upload-all-data/index.ts

import { transformForUpload, clearRegistryCache } from '../_shared/schema_compat.ts'

// At the start of the handler:
clearRegistryCache();

// Get client schema version from request
const clientSchemaVersion = body.client_schema_version ?? 999;
const serverSchemaVersion = 3; // Or fetch from app_config

// Before upserting each table, transform:
if (dirty_records.activities?.length) {
  const transformedActivities = await transformForUpload(
    supabase,
    dirty_records.activities,
    'activities',
    clientSchemaVersion,
    serverSchemaVersion
  );

  await supabase.from('activities').upsert(transformedActivities, { onConflict: 'id' });
}
```

---

## 6. App Components

### 6.1 Local Sync State Store (SharedPreferences)

**New file:** `lib/shared/services/sync/sync_state_store.dart`

Purpose:
- Track `has_dirty_records` without opening SQLite (so version check can run at true startup).
- Store lightweight sync metadata (last schema version, last sync timestamp).
- Persist local-only UX flags across resyncs (e.g., `swipe_hint_shown`, `temp_plan_data`).

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'sync_state_store.g.dart';

@riverpod
class SyncStateStore extends _$SyncStateStore {
  static const _dirtyKey = 'has_dirty_records';
  static const _schemaKey = 'last_known_schema_version';
  static const _swipeHintKey = 'swipe_hint_shown';
  static const _tempPlanKey = 'temp_plan_data';
  static const _defaultSchemaVersion = 3; // Keep in sync with Drift schemaVersion

  late final SharedPreferences _prefs;

  @override
  Future<void> build() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<bool> hasDirtyRecords() async => _prefs.getBool(_dirtyKey) ?? false;
  Future<void> markDirty() async => _prefs.setBool(_dirtyKey, true);
  Future<void> clearDirty() async => _prefs.setBool(_dirtyKey, false);

  Future<int> getLastKnownSchemaVersion() async =>
      _prefs.getInt(_schemaKey) ?? _defaultSchemaVersion;
  Future<void> setLastKnownSchemaVersion(int version) async =>
      _prefs.setInt(_schemaKey, version);

  Future<bool> getSwipeHintShown() async =>
      _prefs.getBool(_swipeHintKey) ?? false;
  Future<void> setSwipeHintShown(bool value) async =>
      _prefs.setBool(_swipeHintKey, value);

  Future<String?> getTempPlanData() async => _prefs.getString(_tempPlanKey);
  Future<void> setTempPlanData(String? value) async {
    if (value == null) {
      await _prefs.remove(_tempPlanKey);
    } else {
      await _prefs.setString(_tempPlanKey, value);
    }
  }
}
```

**One-time migration (optional):** After Drift opens for the first time on the new app
version, read existing local-only fields and write them into SharedPreferences.

### 6.2 Version Check Service

**New file:** `lib/shared/services/version_check_service.dart`

```dart
import 'dart:async';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'logging_service.dart';
import 'sync/sync_state_store.dart';

part 'version_check_service.g.dart';

/// Actions the server can instruct the app to take
enum VersionAction {
  ok,           // Normal startup
  resync,       // Delete local DB and re-download
  uploadFirst,  // Upload dirty records, then resync
  updateApp,    // Force app update
}

/// Result of version check with server
class VersionCheckResult {
  final VersionAction action;
  final int serverSchemaVersion;
  final String? minAppVersion;
  final String? message;

  const VersionCheckResult({
    required this.action,
    required this.serverSchemaVersion,
    this.minAppVersion,
    this.message,
  });

  factory VersionCheckResult.fromJson(Map<String, dynamic> json) {
    return VersionCheckResult(
      action: _parseAction(json['action'] as String? ?? 'ok'),
      serverSchemaVersion: json['server_schema_version'] as int? ?? 3,
      minAppVersion: json['min_app_version'] as String?,
      message: json['message'] as String?,
    );
  }

  static VersionAction _parseAction(String action) {
    switch (action) {
      case 'resync':
        return VersionAction.resync;
      case 'upload_first':
        return VersionAction.uploadFirst;
      case 'update_app':
        return VersionAction.updateApp;
      default:
        return VersionAction.ok;
    }
  }

  /// Create a default "ok" result for when version check fails
  factory VersionCheckResult.ok() {
    return const VersionCheckResult(
      action: VersionAction.ok,
      serverSchemaVersion: 3,
    );
  }
}

@riverpod
class VersionCheckService extends _$VersionCheckService {
  /// The schema version compiled into this app (matches Drift schemaVersion)
  static const int localSchemaVersion = 3;

  late final LoggingService _logger;

  @override
  FutureOr<VersionCheckResult> build() {
    _logger = ref.read(loggingServiceProvider);
    // Don't auto-check on build; call checkVersion() explicitly
    return VersionCheckResult.ok();
  }

  /// Check with server what action the app should take
  ///
  /// Returns [VersionCheckResult] with action:
  /// - `ok`: Normal startup
  /// - `resync`: Delete local DB and re-download all data
  /// - `uploadFirst`: Upload dirty records first, then resync
  /// - `updateApp`: Show "please update" screen
  Future<VersionCheckResult> checkVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;

      final syncState = ref.read(syncStateStoreProvider.notifier);
      final hasDirtyRecords = await syncState.hasDirtyRecords();

      _logger.info(
        'Checking version: app=$appVersion, schema=$localSchemaVersion, dirty=$hasDirtyRecords',
        context: 'VERSION_CHECK',
      );

      final response = await Supabase.instance.client.functions.invoke(
        'check-version',
        body: {
          'app_version': appVersion,
          'schema_version': localSchemaVersion,
          'has_dirty_records': hasDirtyRecords,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );

      if (response.status != 200) {
        _logger.warning(
          'Version check returned status ${response.status}, continuing normally',
          context: 'VERSION_CHECK',
        );
        return VersionCheckResult.ok();
      }

      final result = VersionCheckResult.fromJson(response.data as Map<String, dynamic>);

      _logger.info(
        'Version check result: ${result.action.name} (server v${result.serverSchemaVersion})',
        context: 'VERSION_CHECK',
      );

      state = AsyncData(result);
      return result;

    } catch (e, stackTrace) {
      _logger.error(
        'Version check failed, continuing normally',
        context: 'VERSION_CHECK',
        error: e,
        stackTrace: stackTrace,
      );
      // Fail open - don't block app if version check fails
      return VersionCheckResult.ok();
    }
  }

  /// Get the App Store / Play Store URL for this app
  String getStoreUrl() {
    if (Platform.isIOS) {
      return 'https://apps.apple.com/app/id[YOUR_APP_ID]'; // TODO: Replace with actual ID
    } else {
      return 'https://play.google.com/store/apps/details?id=[YOUR_PACKAGE_NAME]'; // TODO: Replace
    }
  }
}
```

### 6.3 Modify App Startup Service

**File:** `lib/features/app_startup/application/app_startup_service.dart`

Add version check early in the initialization flow:

```dart
// Add import
import '../../../shared/services/version_check_service.dart';

// In the class, add method:

/// Check server version and handle schema mismatches
///
/// This should be called BEFORE initializing the database.
/// It uses SharedPreferences-backed sync state, so it can run at true startup.
/// Returns normally if app can continue, throws if update required.
Future<void> _handleVersionCheck() async {
  final versionService = ref.read(versionCheckServiceProvider.notifier);
  final result = await versionService.checkVersion();

  switch (result.action) {
    case VersionAction.ok:
      // All good, continue normally
      _logger.info('Version check passed', context: 'APP_STARTUP');
      return;

    case VersionAction.updateApp:
      // App too old - throw to show update screen
      _logger.warning(
        'App update required: ${result.message}',
        context: 'APP_STARTUP',
      );
      throw AppUpdateRequiredException(
        minVersion: result.minAppVersion ?? 'latest',
        message: result.message ?? 'Please update your app to continue',
        storeUrl: versionService.getStoreUrl(),
      );

    case VersionAction.uploadFirst:
      // Has dirty records - upload them first
      _logger.info(
        'Uploading dirty records before schema upgrade',
        context: 'APP_STARTUP',
      );
      await _uploadDirtyRecordsOnly();
      // Fall through to resync
      continue resync;

    resync:
    case VersionAction.resync:
      // Delete local database and prepare for fresh sync
      _logger.info(
        'Schema mismatch - deleting local DB for resync',
        context: 'APP_STARTUP',
      );
      await AppDatabase.deleteAndResync();

      // The database will be recreated when we initialize it
      // The full sync will happen after auth is established
      return;
  }
}

/// Upload only dirty records (without full sync)
Future<void> _uploadDirtyRecordsOnly() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _logger.warning('No user ID for dirty record upload', context: 'APP_STARTUP');
      return;
    }

    final dataSyncService = ref.read(dataSyncServiceProvider);
    await dataSyncService.uploadDirtyRecords(userId);

    _logger.info('Dirty records uploaded successfully', context: 'APP_STARTUP');
  } catch (e) {
    _logger.error(
      'Failed to upload dirty records, proceeding anyway',
      context: 'APP_STARTUP',
      error: e,
    );
    // Continue even if upload fails - data will be lost but app can continue
  }
}

// Modify the main initialization method to call version check first:

Future<void> initializeDatabase() async {
  // NEW: Check version FIRST (before touching database)
  await _handleVersionCheck();

  // EXISTING: Rest of database initialization
  await _touchDatabase();
  // ... existing code ...
}
```

### 6.4 Exception for App Update Required

**New file:** `lib/shared/exceptions/app_update_required_exception.dart`

```dart
/// Exception thrown when the app version is too old and must be updated
class AppUpdateRequiredException implements Exception {
  final String minVersion;
  final String message;
  final String storeUrl;

  const AppUpdateRequiredException({
    required this.minVersion,
    required this.message,
    required this.storeUrl,
  });

  @override
  String toString() => 'AppUpdateRequiredException: $message (min version: $minVersion)';
}
```

### 6.5 Track Dirty Records in SharedPreferences

**Files:** `lib/shared/services/sync/sync_state_store.dart` and write/upload paths

```dart
// When any local write marks needs_upload = true:
await ref.read(syncStateStoreProvider.notifier).markDirty();

// After all dirty uploads succeed:
await ref.read(syncStateStoreProvider.notifier).clearDirty();
```

Optional safety: after Drift opens, if any table still has `needs_upload = true`,
set the dirty flag once to keep SharedPreferences accurate.

### 6.6 Simplify Migration Strategy

**File:** `lib/shared/database/app_database.dart`

Replace the complex `stepByStep` migration with a simple strategy:

```dart
@override
MigrationStrategy get migration {
  return MigrationStrategy(
    // Fresh installs create all tables
    onCreate: (Migrator m) async {
      // Create all tables from current Drift schema
      await m.createAll();

      // Preserve seed data from bundled database
      await _preserveSeedData();
    },

    // Always run before opening
    beforeOpen: (details) async {
      // Enable foreign keys
      await customStatement('PRAGMA foreign_keys = ON');

      // If this was a fresh create, we're done
      if (details.wasCreated) {
        return;
      }

      // Run schema validation to catch corruption
      // This will call deleteAndResync() if validation fails
      await _validateSchemaIntegrity();
    },

    // NO MORE COMPLEX MIGRATIONS
    // The server-side version check handles schema mismatches by:
    // 1. Telling app to upload dirty records
    // 2. Telling app to delete local DB
    // 3. App recreates fresh DB (onCreate runs)
    // 4. App downloads all data from server
    onUpgrade: (Migrator m, int from, int to) async {
      // This should rarely run because:
      // - Server version check happens BEFORE database opens
      // - If schema mismatch, we delete DB before getting here
      //
      // But if it does run (edge case), just recreate everything
      // The full sync will restore data

      _logger.warning(
        'Unexpected schema upgrade from v$from to v$to - recreating tables',
        context: 'DATABASE',
      );

      await m.createAll();
    },
  );
}
```

### 6.7 Add Schema Version to Sync Requests

**File:** `lib/shared/services/sync/data_sync_service.dart`

Modify sync methods to include client schema version:

```dart
// Add constant at top of class
static const int _clientSchemaVersion = 3; // Match VersionCheckService.localSchemaVersion

// Modify _tryEdgeFunctionSync:
Future<bool> _tryEdgeFunctionSync(String userId, String? lastSyncTimestamp) async {
  final response = await _supabase.functions.invoke(
    'sync-all-data',
    body: {
      'user_id': userId,
      'last_sync_timestamp': lastSyncTimestamp,
      'client_schema_version': _clientSchemaVersion, // NEW
    },
  );
  // ... rest of method
}

// Modify upload methods similarly:
Future<void> _uploadDirtyRecords(String userId) async {
  // ... gather dirty records ...

  final response = await _supabase.functions.invoke(
    'upload-all-data',
    body: {
      'user_id': userId,
      'dirty_records': dirtyRecords,
      'client_schema_version': _clientSchemaVersion, // NEW
    },
  );
  // ... rest of method
}
```

### 6.8 Update Required Screen

**New file:** `lib/features/app_startup/presentation/screens/update_required_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateRequiredScreen extends StatelessWidget {
  final String minVersion;
  final String message;
  final String storeUrl;

  const UpdateRequiredScreen({
    super.key,
    required this.minVersion,
    required this.message,
    required this.storeUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.system_update_outlined,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 32),
              Text(
                'Update Required',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Minimum version: $minVersion',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: () => _openStore(),
                icon: const Icon(Icons.download),
                label: const Text('Update Now'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStore() async {
    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
```

### 6.9 Handle Update Required in App Startup Widget

**File:** `lib/features/app_startup/presentation/widgets/app_startup_widget.dart`

Modify to catch `AppUpdateRequiredException`:

```dart
// In the build method, check for AppUpdateRequiredException:

@override
Widget build(BuildContext context) {
  final startupState = ref.watch(appStartupProvider);

  return startupState.when(
    loading: () => const AppStartupLoadingWidget(),
    error: (error, stackTrace) {
      // Check if this is an update required error
      if (error is AppUpdateRequiredException) {
        return UpdateRequiredScreen(
          minVersion: error.minVersion,
          message: error.message,
          storeUrl: error.storeUrl,
        );
      }

      // Other errors show retry screen
      return AppStartupErrorWidget(
        message: error.toString(),
        onRetry: () => ref.invalidate(appStartupProvider),
      );
    },
    data: (startupData) => widget.onLoaded(context, startupData),
  );
}
```

---

## 7. Files to Create, Modify, and Delete

### 7.1 Files to Create

| File | Purpose |
|------|---------|
| `supabase/functions/check-version/index.ts` | Version check edge function |
| `supabase/functions/_shared/schema_compat.ts` | Compatibility transformation |
| `lib/shared/services/version_check_service.dart` | App-side version checking |
| `lib/shared/services/version_check_service.g.dart` | Generated Riverpod code |
| `lib/shared/services/sync/sync_state_store.dart` | SharedPreferences-backed sync state |
| `lib/shared/exceptions/app_update_required_exception.dart` | Exception class |
| `lib/features/app_startup/presentation/screens/update_required_screen.dart` | Update UI |

### 7.2 Files to Modify

| File | Changes |
|------|---------|
| `lib/features/app_startup/application/app_startup_service.dart` | Add version check to startup |
| `lib/features/app_startup/presentation/widgets/app_startup_widget.dart` | Handle update exception |
| `lib/shared/database/app_database.dart` | Simplify migrations, stop persisting local-only flags |
| `lib/shared/services/sync/data_sync_service.dart` | Add schema version to requests, clear dirty flag on success |
| `supabase/functions/sync-all-data/index.ts` | Add compatibility transform |
| `supabase/functions/upload-all-data/index.ts` | Add compatibility transform |
| `CLAUDE.md` | Document new versioning system |

### 7.3 Files to Delete

| File | Reason |
|------|--------|
| `lib/shared/database/migrations/migration_v1_to_v2.dart` | No longer needed |
| `lib/shared/database/migrations/migration_v2_to_v3.dart` | No longer needed |

### 7.4 SQL to Run in Supabase

```sql
-- Run this in Supabase SQL Editor

-- 1. Create app_config table
CREATE TABLE IF NOT EXISTS app_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read access" ON app_config FOR SELECT USING (true);
CREATE POLICY "Service role write access" ON app_config FOR ALL USING (auth.role() = 'service_role');

INSERT INTO app_config (key, value, description) VALUES
  ('current_schema_version', '3', 'Current server schema version'),
  ('min_app_version', '1.2.0', 'Minimum app version required'),
  ('min_supported_schema', '2', 'Oldest schema version we transform for')
ON CONFLICT (key) DO NOTHING;

-- 2. Create schema_column_registry table
CREATE TABLE IF NOT EXISTS schema_column_registry (
  id SERIAL PRIMARY KEY,
  added_in_version INTEGER NOT NULL,
  table_name TEXT NOT NULL,
  column_name TEXT NOT NULL,
  default_value JSONB,
  transform_type TEXT DEFAULT 'nullable',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(table_name, column_name)
);

ALTER TABLE schema_column_registry ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read access" ON schema_column_registry FOR SELECT USING (true);

-- 3. Seed column registry with current schema history
INSERT INTO schema_column_registry (added_in_version, table_name, column_name, default_value, notes) VALUES
  -- V2 additions
  (2, 'food_preferences', 'preference_level', '2', 'Default to neutral'),
  (2, 'food_preferences', 'preference_source', '"manual"', 'Default to manual'),
  (2, 'users', 'dietary_preference', 'null', 'Nullable'),
  (2, 'users', 'allergies', 'null', 'Nullable'),
  -- V3 additions
  (3, 'users', 'sweat_rate', '"medium"', 'Default to medium'),
  (3, 'users', 'is_coach', 'false', 'Default false'),
  (3, 'users', 'first_name', 'null', 'Nullable'),
  (3, 'users', 'last_name', 'null', 'Nullable'),
  (3, 'activities', 'synced_from_provider', 'null', 'Nullable'),
  (3, 'activities', 'provider_workout_id', 'null', 'Nullable'),
  (3, 'activities', 'provider_workout_url', 'null', 'Nullable'),
  (3, 'activities', 'last_synced_at', 'null', 'Nullable')
ON CONFLICT (table_name, column_name) DO NOTHING;
```

---

## 8. Data Migration Strategy

### 8.1 For Existing Users

When this system is deployed:

1. **Users on current app version (v3 schema):**
   - Version check returns `ok`
   - No change in behavior

2. **Users who update to new app:**
   - First launch after update does version check
   - If schema matches: `ok`
   - If schema mismatch: `resync` (delete DB, download fresh)

### 8.2 No Data Migration Required

This approach doesn't require migrating existing user data because:
- Server schema doesn't change
- Existing Supabase data is already v3
- Client just redownloads existing data

### 8.3 Handling Dirty Records During Transition

If a user has dirty records when they update:
1. Version check returns `upload_first`
2. App uploads dirty records (server accepts v3 data)
3. App deletes local DB
4. App downloads fresh data

### 8.4 Preserving Local-Only State

1. **Before enabling server-side versioning**, move local-only flags to SharedPreferences.
   - `swipe_hint_shown`, `temp_plan_data`, and other UX-only values should no longer live in Drift.
2. **One-time migration** on first launch:
   - After Drift opens, read existing values and write them into SharedPreferences.
   - Future reads use SharedPreferences only.
3. **Resync-safe:** Deleting SQLite no longer wipes local-only UX state.

---

## 9. Testing Strategy

### 9.1 Unit Tests

```dart
// test/services/version_check_service_test.dart

void main() {
  group('VersionCheckResult', () {
    test('parses ok action', () {
      final result = VersionCheckResult.fromJson({
        'action': 'ok',
        'server_schema_version': 3,
      });
      expect(result.action, VersionAction.ok);
    });

    test('parses resync action', () {
      final result = VersionCheckResult.fromJson({
        'action': 'resync',
        'server_schema_version': 4,
        'message': 'Schema upgrade required',
      });
      expect(result.action, VersionAction.resync);
      expect(result.serverSchemaVersion, 4);
    });

    test('parses update_app action', () {
      final result = VersionCheckResult.fromJson({
        'action': 'update_app',
        'server_schema_version': 4,
        'min_app_version': '2.0.0',
      });
      expect(result.action, VersionAction.updateApp);
      expect(result.minAppVersion, '2.0.0');
    });
  });
}
```

### 9.2 Edge Function Tests

```typescript
// supabase/functions/check-version/test.ts

Deno.test('returns ok for matching versions', async () => {
  const response = await invoke('check-version', {
    app_version: '1.2.0',
    schema_version: 3,
    has_dirty_records: false,
  });

  assertEquals(response.action, 'ok');
});

Deno.test('returns resync for schema mismatch', async () => {
  const response = await invoke('check-version', {
    app_version: '1.2.0',
    schema_version: 2,
    has_dirty_records: false,
  });

  assertEquals(response.action, 'resync');
});

Deno.test('returns upload_first when dirty records exist', async () => {
  const response = await invoke('check-version', {
    app_version: '1.2.0',
    schema_version: 2,
    has_dirty_records: true,
  });

  assertEquals(response.action, 'upload_first');
});

Deno.test('returns update_app for old app version', async () => {
  const response = await invoke('check-version', {
    app_version: '1.0.0',
    schema_version: 1,
    has_dirty_records: false,
  });

  assertEquals(response.action, 'update_app');
});
```

### 9.3 Integration Tests

| Scenario | Steps | Expected Outcome |
|----------|-------|------------------|
| Fresh install | Install app, open | DB created, normal sync |
| Same version | Open existing app | Version check returns `ok` |
| Schema upgrade (clean) | Update app, open | `resync`, DB deleted, data redownloaded |
| Schema upgrade (dirty) | Create offline data, update app | `upload_first`, data uploaded, then resync |
| App too old | Open very old app | `update_app`, shown update screen |
| Offline | Open without network | Version check fails, continues normally |
| Local-only state | Set swipe hint + temp plan, trigger resync | Local-only flags preserved in SharedPreferences |

### 9.4 Manual Testing Checklist

- [ ] Fresh install creates database correctly
- [ ] Existing app opens normally (version match)
- [ ] Schema mismatch triggers resync
- [ ] Dirty records are uploaded before resync
- [ ] Update required screen shows correct info
- [ ] Update button opens correct store
- [ ] Offline mode continues working
- [ ] Resync downloads all data correctly
- [ ] No data loss during resync (after upload)
- [ ] Local-only flags persist after resync (e.g., swipe hint, temp plan)

---

## 10. Rollback Plan

### 10.1 If Server-Side Versioning Fails

1. **Revert edge function** to version without version check
2. **Update `min_app_version`** to force users to older app version
3. **Re-enable Drift migrations** in app code

### 10.2 If Compatibility Layer Has Bugs

1. **Set `min_supported_schema`** to current version (disable transforms)
2. **Set `min_app_version`** to latest (force all users to update)
3. Fix bugs, then re-enable transforms

### 10.3 Keeping Migration Files (Optional)

If desired, migration files can be kept but not used:

```dart
// In app_database.dart - keep but don't call
onUpgrade: (Migrator m, int from, int to) async {
  // Migration files exist but we don't call them
  // Server-side versioning handles everything
  await m.createAll();
}
```

---

## 11. Future Schema Changes Workflow

### 11.1 Adding a New Column (Non-Breaking)

1. **Add column to Supabase:**
   ```sql
   ALTER TABLE activities ADD COLUMN new_field TEXT;
   ```

2. **Register in column registry:**
   ```sql
   INSERT INTO schema_column_registry
     (added_in_version, table_name, column_name, default_value)
   VALUES (4, 'activities', 'new_field', 'null');
   ```

3. **Update server schema version:**
   ```sql
   UPDATE app_config SET value = '4' WHERE key = 'current_schema_version';
   ```

4. **Update Drift schema in app:**
   - Add column to `activities_table.dart`
   - Update `schemaVersion` to 4
   - Release new app version

5. **Old apps automatically:**
   - Get `resync` action on next open
   - Delete local DB, download fresh
   - Receive data without new column (server strips it)

### 11.2 Making a Breaking Change

1. **Make schema changes in Supabase**
2. **Update Drift schema in app**
3. **Release new app version**
4. **Update minimum app version:**
   ```sql
   UPDATE app_config SET value = '2.0.0' WHERE key = 'min_app_version';
   ```
5. **Old apps get `update_app` action**

### 11.3 Dropping Support for Old Schema

```sql
-- Old v2 apps will now be forced to update
UPDATE app_config SET value = '3' WHERE key = 'min_supported_schema';
```

---

## 12. Open Questions and Decisions

### 12.1 Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Version support | Server-configurable | Flexibility without code deploys |
| UX on resync | Background, longer startup | Less disruptive to user |
| Migration files | Delete | Cleaner codebase |
| Fail behavior | Fail open | Don't block app if version check fails |
| Version check timing | Before DB init via SharedPreferences | Enables true startup check without Drift |
| Local-only UX state | SharedPreferences | Preserves UX flags across resync |
| Offline behavior | Continue with cached data | Offline-first app requirement |

### 12.2 Open Questions

| Question | Options | Recommendation |
|----------|---------|----------------|
| How long to support old schemas? | 2 versions, 3 versions, indefinite | 2 versions (current + N-1) |
| Show progress during resync? | Silent, progress bar, message | Brief message: "Updating data..." |
| What if upload fails before resync? | Retry, skip, ask user | Retry once, then skip with warning |
| Store URLs | Hardcode, fetch from server | Hardcode initially, can add server fetch later |

### 12.3 Future Enhancements

- **Progress indicator** during resync
- **Retry logic** for failed uploads
- **Analytics** for version distribution
- **A/B testing** different minimum versions
- **Gradual rollout** of schema changes

---

## Appendix A: Version Comparison Logic

```dart
/// Compare two semantic version strings
/// Returns: -1 if a < b, 0 if a == b, 1 if a > b
int compareVersions(String a, String b) {
  final aParts = a.split('.').map(int.parse).toList();
  final bParts = b.split('.').map(int.parse).toList();

  final maxLength = max(aParts.length, bParts.length);

  for (var i = 0; i < maxLength; i++) {
    final aVal = i < aParts.length ? aParts[i] : 0;
    final bVal = i < bParts.length ? bParts[i] : 0;

    if (aVal < bVal) return -1;
    if (aVal > bVal) return 1;
  }

  return 0;
}
```

---

## Appendix B: Related Documentation

- [Database Architecture](/docs/database/README.md)
- [Drift Implementation](/docs/technical/drift-implementation.md)
- [Sync System Analysis](/docs/app_startup/02-sync-system-analysis.md)
- [App Startup Architecture](/docs/app_startup/README.md)

---

## Changelog

| Date | Change |
|------|--------|
| January 2026 | Initial plan created |
