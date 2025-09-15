# Database Documentation

## Overview

Mealvana Endurance implements a sophisticated dual database architecture combining local-first storage with cloud synchronization. This design ensures the app works seamlessly offline while providing data backup, synchronization, and content management capabilities.

## Architecture Summary

### Dual Database System
- **[Drift (SQLite)](drift/)**: Local offline-first storage with type-safe migrations
- **[Supabase (PostgreSQL)](supabase/)**: Cloud backend with real-time capabilities and content management

### Key Principles
- **Offline-First**: App fully functional without internet connection
- **Device-Based Authentication**: No traditional user accounts, privacy-focused
- **Content-Driven**: UI text and algorithm parameters managed server-side
- **Safe Migrations**: Backup and rollback strategies for schema changes

## Documentation Structure

### 📁 [Architecture](architecture/)
Foundational design principles and data flow patterns:
- **[offline-first.md](architecture/offline-first.md)**: Local-first design principles and ownership patterns
- **[data-flow.md](architecture/data-flow.md)**: Data synchronization flows between local and cloud storage
- **[backup-strategy.md](architecture/backup-strategy.md)**: Migration safety and rollback procedures

### 📁 [Drift (Local Database)](drift/)
SQLite implementation with Dart code generation:
- **[schema.md](drift/schema.md)**: Complete v2 schema with 10 tables and relationships
- **[migration-strategy.md](drift/migration-strategy.md)**: "Fake History" migration approach from v1→v2
- **[sync-service.md](drift/sync-service.md)**: 24-hour refresh cycle and sync coordination
- **[repositories.md](drift/repositories.md)**: Repository pattern implementation with Riverpod

### 📁 [Supabase (Cloud Backend)](supabase/)  
PostgreSQL backend with real-time and serverless capabilities:
- **[schema.sql](supabase/schema.sql)**: Complete PostgreSQL schema with RLS policies
- **[tables.md](supabase/tables.md)**: Detailed table documentation and usage patterns
- **[edge-functions.md](supabase/edge-functions.md)**: AI nutrition plan generation and dynamic code deployment
- **[rls-policies.md](supabase/rls-policies.md)**: Row Level Security implementation for privacy protection

## Current Status: V1 → V2 Migration

The app is currently transitioning from a broken v1 implementation to a proper v2 architecture:

### V1 Issues (Current State)
- ❌ Hardcoded schema version (always 1)
- ❌ No real migrations (`m.createAll()` approach)
- ❌ Manual schema management bypasses Drift
- ❌ Food data not cached locally
- ❌ Content stored in SharedPreferences

### V2 Target State (Documented)
- ✅ Proper Drift migrations with versioning
- ✅ 10 tables mirroring Supabase structure
- ✅ Local food caching with 24-hour refresh
- ✅ Content management in database
- ✅ Backup and rollback protection

### Migration Approach
**"Fake History" Strategy**: Treat v1 as if it was always a proper Drift migration while preserving all user data. See [migration-strategy.md](drift/migration-strategy.md) for complete implementation details.

## Quick Start

### For Developers

1. **Understanding the Architecture**:
   ```bash
   # Start with architectural principles
   docs/database/architecture/offline-first.md
   docs/database/architecture/data-flow.md
   ```

2. **Working with Local Storage**:
   ```bash
   # Drift implementation details
   docs/database/drift/schema.md
   docs/database/drift/repositories.md
   ```

3. **Backend Integration**:
   ```bash
   # Supabase setup and policies
   docs/database/supabase/tables.md
   docs/database/supabase/rls-policies.md
   ```

### For AI Assistants

**When working with database code:**
- Consult `drift/schema.md` for current v2 table structure
- Check `drift/repositories.md` for repository patterns
- Use `architecture/data-flow.md` for sync logic understanding
- Reference `supabase/tables.md` for backend table relationships

**When making schema changes:**
- Follow migration strategy in `drift/migration-strategy.md`
- Implement backup procedures from `architecture/backup-strategy.md`
- Update both Drift and Supabase documentation

## 🏗️ **Schema Highlights**

### **Device-Centric Architecture**
- **No traditional user accounts** - Everything tied to device identifiers
- **Privacy-first** - No email/phone collection required
- **Offline-capable** - Local Drift SQLite database with Supabase sync

### **Multi-Category Food System**
```sql
-- Foods can belong to multiple timing categories
SELECT f.name, array_agg(c.name) as categories
FROM foods f
JOIN food_categories fc ON f.id = fc.food_id  
JOIN categories c ON fc.category_id = c.id
GROUP BY f.id, f.name;
```

### **Structured Serving Data**
```sql
-- No more hardcoded parsing - proper database fields
CREATE TABLE foods (
  serving_amount NUMERIC,     -- e.g., 1, 0.5, 2
  serving_unit TEXT,         -- e.g., "cup", "medium"  
  serving_unit_plural TEXT,  -- e.g., "cups", "medium"
  serving_qualifier TEXT     -- e.g., "cooked", "sliced"
);
```

### **Food Preferences System**
```sql
-- Three-level preference system
CREATE TABLE food_preferences (
  preference TEXT CHECK (preference IN ('like', 'dislike', 'willing_to_try'))
);

-- Helper function for batch updates
SELECT upsert_food_preferences(device_id, preferences_jsonb);
```

### **Versioning & Conflict Resolution**
```sql
-- Optimistic concurrency control for nutrition plans
CREATE TABLE nutrition_plans (
  version INTEGER DEFAULT 1,
  conflict_resolution TEXT DEFAULT 'last_write_wins',
  client_updated_at TIMESTAMPTZ
);
```

## 🔧 **Database Functions**

### **`upsert_food_preferences(device_id, preferences_jsonb)`**
Replaces all food preferences for a user with new preferences.

**Usage:**
```sql
SELECT upsert_food_preferences(
  'device123',
  '{"Oatmeal": "like", "Gels": "willing_to_try", "Coffee": "dislike"}'::jsonb
);
```

### **`upsert_nutrition_plan_versioned(...)`**
Inserts nutrition plan with conflict detection and versioning.

### **`get_active_app_content(environment, locale)`**
Retrieves active app content for localization.

## 📊 **Performance Features**

### **Strategic Indexes**
- **Primary keys** - Automatic unique indexes
- **Foreign keys** - Automatic relationship indexes
- **Query optimization** - device_id, timestamps, active flags  
- **Composite indexes** - Multi-column lookups

### **Automatic Triggers**
- **Updated timestamps** - Auto-update `updated_at` columns
- **Data validation** - Constraint checks
- **Referential integrity** - Foreign key enforcement

### **Row Level Security (RLS)**
- **User data isolation** - Users can only access their own data
- **Edge function access** - Service role bypasses RLS
- **Public data** - Foods and categories are publicly readable

## 🔍 **Common Queries**

### **Get User's Food Preferences**
```sql
SELECT food_name, preference 
FROM food_preferences 
WHERE device_id = 'device123';
```

### **Get Foods by Category**
```sql
SELECT f.* FROM foods f
JOIN food_categories fc ON f.id = fc.food_id
JOIN categories c ON fc.category_id = c.id  
WHERE c.name = 'before_run';
```

### **Get User's Latest Nutrition Plan**
```sql
SELECT * FROM nutrition_plans
WHERE device_id = 'device123' AND is_deleted = FALSE
ORDER BY updated_at DESC
LIMIT 1;
```

### **Get Multi-Category Foods**
```sql
SELECT f.name, count(*) as category_count
FROM foods f
JOIN food_categories fc ON f.id = fc.food_id
GROUP BY f.id, f.name
HAVING count(*) > 1;
```

## 🚨 **Migration Notes**

### **Hive to Drift Migration**
- **Hive Boxes** → **Drift Tables**: Structured SQL tables with relationships
- **Type Adapters** → **Schema Classes**: Generated Dart classes with type safety
- **Manual Migrations** → **Automated Migrations**: Built-in schema versioning

### **Local Storage Migration Steps**
1. **Export Hive Data**: Backup existing user data from Hive boxes
2. **Initialize Drift Database**: Create SQLite database with schema version 1
3. **Migrate Data**: Import user profiles, food preferences, and nutrition plans
4. **Verify Integrity**: Run generated migration tests
5. **Remove Hive Dependencies**: Clean up old Hive storage files

### **Schema Migration Commands**
```bash
# Generate new schema version after changes
dart run drift_dev make-migrations

# Export schema for version control
dart run drift_dev schema dump lib/database/database.dart drift_schemas/

# Generate migration test code
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
```

## 📚 **Further Reading**

### **Core Documentation**
- **[`DRIFT.md`](DRIFT.md)** - 📘 **COMPREHENSIVE DRIFT GUIDE** - Complete implementation guide with examples, patterns, and best practices
- **`schema-overview.md`** - Detailed table structures and relationships
- **`DEPLOYMENT-GUIDE.md`** - Complete deployment walkthrough

### **Technical Implementation**  
- **`/docs/technical/README.md`** - Architecture overview and patterns
- **`/docs/technical/drift-migration-guide.md`** - Migration from Hive to Drift
- **`/docs/technical/drift-implementation.md`** - Implementation details and examples
- **`/lib/shared/database/`** - Drift database classes and migrations

### **Business Logic**
- **`/docs/business_logic/`** - Edge functions that use this schema
- **`/supabase/functions/`** - Server-side functions and API endpoints