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
- **[schema.md](drift/schema.md)**: Complete v1 schema with updated tables and relationships
- **[migration-strategy.md](drift/migration-strategy.md)**: Schema migration strategies and best practices
- **[sync-service.md](drift/sync-service.md)**: 24-hour refresh cycle and sync coordination
- **[repositories.md](drift/repositories.md)**: Repository pattern implementation with Riverpod

### 📁 [Supabase (Cloud Backend)](supabase/)  
PostgreSQL backend with real-time and serverless capabilities:
- **[schema.sql](supabase/schema.sql)**: Complete PostgreSQL schema with RLS policies
- **[tables.md](supabase/tables.md)**: Detailed table documentation and usage patterns
- **[edge-functions.md](supabase/edge-functions.md)**: AI nutrition plan generation and dynamic code deployment
- **[rls-policies.md](supabase/rls-policies.md)**: Row Level Security implementation for privacy protection

## Current Status: V1 Clean Schema Implementation

The app has been updated with a clean v1 schema implementation aligned with the new Supabase backend:

### V1 Current Implementation
- ✅ Clean Drift schema matching Supabase structure
- ✅ Product types table for standardized food categorization
- ✅ Simplified foods table with display names and product type references
- ✅ Enhanced nutrition plans with complete versioning and metadata
- ✅ Device-based authentication (no traditional user accounts)
- ✅ Local food caching with Supabase sync capability

### Key Schema Updates
- **Product Types**: New standardized categorization system (16 types)
- **Foods Table**: Simplified serving logic, added display names and product type references
- **Nutrition Plans**: Complete overhaul with versioning, conflict resolution, and device-based tracking
- **Database Methods**: Updated to work with new field names and structures

### Fresh Start Approach
**V1 Fresh Implementation**: Starting with a clean v1 schema that mirrors the updated Supabase backend structure, ensuring consistency between local and cloud storage from the beginning.

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
- Consult `drift/schema.md` for current v1 table structure
- Check `drift/repositories.md` for repository patterns
- Use `architecture/data-flow.md` for sync logic understanding
- Reference `supabase/tables.md` for backend table relationships

**🚨 CRITICAL: Enum Format Requirements**

**When working with enum values in database operations:**

```dart
// ✅ CORRECT - For LOCAL database operations, use .value
await database.saveFoodPreferences(deviceId, preferences.map(
  (key, value) => MapEntry(key, value.value), // Stores: willing_to_try
));

// ✅ CORRECT - For reading from LOCAL database, match against .value
final preference = FoodPreference.values.firstWhere(
  (p) => p.value == row.preference, // Expects: willing_to_try
  orElse: () => FoodPreference.dislike,
);

// ❌ WRONG - Don't use .name for database operations
await database.saveFoodPreferences(deviceId, preferences.map(
  (key, value) => MapEntry(key, value.name), // Would store: willingToTry - FAILS!
));
```

**Why this matters:**
- Database CHECK constraints expect underscore format: `preference IN ('like', 'dislike', 'willing_to_try')`
- Edge Functions expect underscore format for consistency
- Local database mirrors cloud database format exactly
- Using `.name` instead of `.value` causes CHECK constraint failures

**When making schema changes:**
- Follow migration strategy in `drift/migration-strategy.md`
- Implement backup procedures from `architecture/backup-strategy.md`
- Update both Drift and Supabase documentation
- Test enum format consistency across all database operations

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

### **Simplified Serving Data & Product Types**
```sql
-- Simplified serving structure with standardized product categories
CREATE TABLE foods (
  serving_amount NUMERIC,               -- e.g., 1, 0.5, 2
  serving_description TEXT,             -- e.g., "1 medium", "1 cup cooked"
  display_name VARCHAR(100),            -- e.g., "gel", "banana"
  display_name_plural VARCHAR(100),     -- e.g., "gels", "bananas"
  product_type_id UUID REFERENCES product_types(id)
);

CREATE TABLE product_types (
  id UUID PRIMARY KEY,
  code TEXT UNIQUE,                     -- e.g., "gel", "fruit_fresh"
  name TEXT,                           -- e.g., "Gel", "Fresh Fruit"
  name_plural TEXT                     -- e.g., "Gels", "Fresh Fruits"
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
-- Device-based nutrition plans with optimistic concurrency control
CREATE TABLE nutrition_plans (
  id UUID PRIMARY KEY,
  device_id TEXT NOT NULL,              -- Device-based authentication
  plan_id TEXT NOT NULL,                -- User-defined plan identifier
  plan_name TEXT NOT NULL,              -- Display name
  plan_data TEXT NOT NULL,              -- JSON plan content
  version INTEGER DEFAULT 1,
  last_modified_by TEXT,
  client_updated_at TIMESTAMPTZ,
  is_deleted BOOLEAN DEFAULT FALSE,
  conflict_resolution TEXT,
  UNIQUE(device_id, plan_id)            -- One plan per device per plan_id
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