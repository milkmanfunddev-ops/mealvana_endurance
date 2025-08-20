# Database Schema & Migrations

This directory contains the complete database schema, migrations, and documentation for the Mealvana Endurance nutrition planning system.

## 📁 **Files Overview**

### **Migrations**
- **`migrations/01-create-core-tables.sql`** - Creates all core tables with indexes and triggers
- **`migrations/02-create-functions-and-rls.sql`** - Creates database functions and Row Level Security policies

### **Documentation**  
- **`schema-overview.md`** - Complete database schema documentation
- **`DEPLOYMENT-GUIDE.md`** - Step-by-step deployment instructions

## 🗄️ **Database Schema Overview**

### **Core Tables**

| Table | Purpose | Key Features |
|-------|---------|--------------|
| `users` | User profiles and biometric data | Device-based auth, onboarding status |
| `foods` | Food database | Structured serving data, nutritional info |
| `categories` | Food timing categories | before_run, during_run, after_run |
| `food_categories` | Food-to-category mapping | Many-to-many relationships |
| `food_preferences` | User food preferences | like/dislike/willing_to_try |
| `nutrition_plans` | Generated nutrition plans | Versioning, conflict resolution |
| `feedback` | User feedback | Satisfaction ratings (1-3 scale) |
| `app_content` | Dynamic app content | Localization, A/B testing |

### **Key Relationships**

```sql
users (device_id) ←→ food_preferences (device_id)
users (device_id) ←→ nutrition_plans (device_id)  
foods (id) ←→ food_categories (food_id)
categories (id) ←→ food_categories (category_id)
```

## 🚀 **Quick Start**

### **1. Run Migrations**
Execute these in order in your Supabase SQL Editor:

```sql
-- Step 1: Create all core tables
-- Copy and run: migrations/01-create-core-tables.sql

-- Step 2: Create functions and RLS policies  
-- Copy and run: migrations/02-create-functions-and-rls.sql
```

### **2. Verify Installation**
```sql
-- Check all tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Test key functions
SELECT upsert_food_preferences('test_device', '{"Oatmeal": "like"}'::jsonb);
SELECT get_active_app_content('production', 'en-US');
```

## 🏗️ **Schema Highlights**

### **Device-Centric Architecture**
- **No traditional user accounts** - Everything tied to device identifiers
- **Privacy-first** - No email/phone collection required
- **Offline-capable** - Local Hive storage with Supabase sync

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

### **Breaking Changes**
- **Old single-category foods** → New multi-category system
- **Hardcoded serving parsing** → Structured serving fields
- **Text-based categories** → Integer-based with join table

### **Data Migration**
If migrating from an older schema:
1. Export existing food preferences
2. Run new migrations
3. Convert category references to new format
4. Re-import food data with structured serving fields

## 📚 **Further Reading**

- **`schema-overview.md`** - Detailed table structures and relationships
- **`DEPLOYMENT-GUIDE.md`** - Complete deployment walkthrough
- **`/docs/business_logic/`** - Edge functions that use this schema
- **`/docs/technical/`** - Integration guides and best practices