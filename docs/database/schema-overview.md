# Database Schema Overview

## 📊 Tables Summary

| Table | Purpose | Key Features |
|-------|---------|--------------|
| `users` | User profiles and preferences | Device-based auth, demographic data |
| `nutrition_plans` | Nutrition plan storage | Versioning, conflict resolution, JSONB data |
| `food_items` | Food database | Nutritional info, categories, search |
| `app_content` | Dynamic content | Localization, A/B testing, remote config |
| `feedback` | User feedback | Satisfaction tracking, suggestions |

## 🔗 Relationships Diagram

```sql
┌─────────────────┐    1:N    ┌──────────────────────┐
│     users       │──────────▶│   nutrition_plans    │
│                 │           │                      │
│ • device_id (PK)│           │ • id (PK)           │
│ • gender        │           │ • device_id (FK)    │
│ • birthday      │           │ • plan_data (JSONB) │
│ • height_*      │           │ • version           │
│ • weight_pounds │           │ • created_at        │
│ • food_prefs    │           │ • updated_at        │
└─────────────────┘           └──────────────────────┘
         │                              │
         │                              │
         │ 1:N                          │ N:N
         ▼                              ▼
┌─────────────────┐           ┌──────────────────────┐
│  food_preferences│           │     food_items      │
│                 │           │                      │
│ • user_id (FK)  │           │ • id (PK)           │
│ • liked_foods   │           │ • name              │
│ • disliked_foods│           │ • category          │
└─────────────────┘           │ • nutrition (JSONB) │
                              │ • tags              │
                              └──────────────────────┘

┌─────────────────┐           ┌──────────────────────┐
│   app_content   │           │      feedback        │
│                 │           │                      │
│ • id (PK)       │           │ • id (PK)           │
│ • environment   │           │ • satisfaction_level│
│ • locale        │           │ • app_feedback      │
│ • content (JSONB)│           │ • suggestions       │
│ • version       │           │ • plan_name         │
│ • is_active     │           │ • timestamp         │
└─────────────────┘           └──────────────────────┘
```

## 🏗️ Core Design Principles

### 1. Device-Centric Architecture
- **No traditional user accounts** - Everything tied to device identifiers
- **Privacy-first** - No email/phone collection required
- **Offline-capable** - Local Hive storage with Supabase sync

### 2. Versioning & Conflict Resolution
- **Optimistic concurrency** - Version numbers on mutable data
- **Conflict detection** - Client/server version comparison
- **Resolution strategies** - Last-write-wins, manual, client-wins, server-wins
- **Soft deletes** - Maintain history, support rollback

### 3. Flexible Schema
- **JSONB columns** - Nutrition plans stored as flexible JSON
- **Evolution-ready** - Schema can grow without migrations
- **Type safety** - Dart models provide compile-time checks

### 4. Performance Optimized
- **Strategic indexes** - Fast lookups by device_id, timestamps
- **Query optimization** - Efficient joins and filters
- **Pagination support** - Large dataset handling

## 📋 Column Conventions

### Standard Audit Columns
All main tables include:
```sql
created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
```

### Versioning Columns
Versionable tables include:
```sql
version INTEGER DEFAULT 1
last_modified_by TEXT
client_updated_at TIMESTAMP WITH TIME ZONE
is_deleted BOOLEAN DEFAULT FALSE
conflict_resolution TEXT DEFAULT 'last_write_wins'
```

### Device Identification
User-scoped tables include:
```sql
device_id TEXT NOT NULL REFERENCES users(device_id)
```

## 🔍 Query Patterns

### Common Queries

**Get user's latest nutrition plan:**
```sql
SELECT * FROM nutrition_plans 
WHERE device_id = $1 AND is_deleted = FALSE 
ORDER BY updated_at DESC 
LIMIT 1;
```

**Get all foods by category:**
```sql
SELECT * FROM food_items 
WHERE category = $1 
ORDER BY name;
```

**Get active app content:**
```sql
SELECT * FROM app_content 
WHERE environment = $1 AND locale = $2 AND is_active = true
ORDER BY version DESC 
LIMIT 1;
```

### Sync Queries

**Detect conflicts:**
```sql
SELECT version FROM nutrition_plans 
WHERE device_id = $1 AND plan_id = $2;
-- Compare with client version
```

**Upsert with versioning:**
```sql
SELECT upsert_nutrition_plan_versioned($1, $2, $3, $4, $5);
```

## 🚀 Performance Considerations

### Indexes
- **Primary keys** - Automatic unique indexes
- **Foreign keys** - Automatic relationship indexes  
- **Query optimization** - device_id, timestamps, active flags
- **Composite indexes** - Multi-column lookups

### Data Size Management
- **JSONB compression** - Efficient storage for nutrition plans
- **Soft delete cleanup** - Periodic cleanup of old deleted records
- **Content versioning** - Keep limited history of app content

### Scaling Strategy
- **Read replicas** - Supabase handles read scaling
- **Connection pooling** - PgBouncer for connection management
- **Caching layers** - App-level caching for static data (foods, content)