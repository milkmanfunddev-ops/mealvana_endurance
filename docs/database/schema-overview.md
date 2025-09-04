# Database Schema Overview - Drift Implementation

## 🎆 **Local Database Implementation**

The app uses **Drift** (SQLite) for local data storage with the following benefits:
- **Type-Safe Migrations**: Automatic schema versioning with generated migration code
- **Compile-Time Query Validation**: SQL queries validated at compile time
- **Strong Type System**: Generated Dart classes for all tables and queries
- **Transaction Support**: ACID transactions with rollback support
- **Offline-First**: Full functionality without network connection

## 📊 Tables Summary

| Table | Purpose | Key Features |
|-------|---------|--------------|
| `users` | User profiles and preferences | Device-based auth, demographic data, onboarding status |
| `nutrition_plans` | Nutrition plan storage | Versioning, conflict resolution, JSONB data |
| `foods` | Food database | Enhanced nutritional info, serving data, suitability flags, online images, product info |
| `categories` | Food category definitions | Integer ID-based category lookup |
| `food_categories` | Food-to-category mapping | Many-to-many via category_id |
| `food_preferences` | User food preferences | Device-scoped like/willingToTry/dislike tracking |
| `app_content` | Dynamic content | Localization, A/B testing, remote config |
| `feedback` | User feedback | Satisfaction tracking (1-3 scale), suggestions |

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
         │                              
         │                              
         │ 1:N                          
         ▼
┌─────────────────┐
│ food_preferences│
│                 │
│ • device_id (FK)│
│ • food_name     │
│ • preference    │
└─────────────────┘                              
                              ┌──────────────────────┐
                              │       foods          │
                              │                      │
                              │ • id (PK)           │
                              │ • name              │
                              │ • image_address     │
                              │ • description       │
                              │ • instructions      │
                              │ • nutritional_info  │
                              │ • serving_amount    │
                              │ • serving_unit      │
                              │ • serving_unit_plural │
                              │ • serving_qualifier │
                              │ • before_run_suitable│
                              │ • during_run_suitable│
                              │ • run_portable      │
                              │ • requires_preparation│
                              │ • aid_station_available│
                              │ • max_servings_before│
                              │ • max_servings_during│
                              │ • sodium_mg         │
                              │ • caffeine_mg       │
                              │ • potassium_mg      │
                              │ • carbs_per_serving │
                              │ • protein_per_serving│
                              │ • fat_per_serving   │
                              │ • calories_per_serving│
                              │ • fluid_ml_per_serving│
                              │ • brand_id (FK)     │
                              │ • product_type      │
                              │ • purchase_url      │
                              │ • affiliate_source  │
                              └──────────────────────┘
┌─────────────────┐                    │
│   categories    │                    │ N:N
│                 │                    ▼
│ • id (PK)       │           ┌──────────────────────┐
│ • name          │           │   food_categories    │
│                 │           │                      │
│ Values:         │◀──────────│ • food_id (FK)      │
│ - before_run    │           │ • category_id (FK)  │
│ - during_run    │           │ • PRIMARY KEY:      │
│ - after_run     │           │   (food_id,         │
└─────────────────┘           │    category_id)     │
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
- **Offline-capable** - Local Drift SQLite database with Supabase sync
- **Migration-safe** - Built-in schema versioning prevents data corruption

### 2. Versioning & Conflict Resolution
- **Optimistic concurrency** - Version numbers on mutable data
- **Conflict detection** - Client/server version comparison
- **Resolution strategies** - Last-write-wins, manual, client-wins, server-wins
- **Soft deletes** - Maintain history, support rollback

### 3. Flexible Schema
- **JSONB columns** - Nutrition plans stored as flexible JSON
- **Evolution-ready** - Drift handles schema migrations automatically
- **Type safety** - Generated Dart classes provide compile-time checks
- **Migration testing** - Auto-generated tests validate schema changes

### 4. Performance Optimized
- **Strategic indexes** - Fast lookups by device_id, timestamps
- **Query optimization** - Efficient joins and filters
- **Pagination support** - Large dataset handling

### 5. Enhanced Food System
- **Explicit nutritional data** - Direct columns for carbs, protein, fat, calories, fluids
- **Suitability flags** - Boolean indicators for before/during run appropriateness
- **Portability tracking** - Run-portable flag for foods easy to carry
- **Preparation requirements** - Indicates foods needing advance preparation
- **Aid station availability** - Tracks foods commonly available at race aid stations
- **Serving constraints** - Max servings recommendations for safety
- **Micronutrient tracking** - Sodium, caffeine, potassium for performance optimization
- **Multi-category support** - Foods can belong to multiple timing categories via join table
- **Branded vs Generic Foods** - Foods with `brand_id` are branded products, foods with `brand_id = NULL` are generic foods
- **Online Images** - All food images loaded from `image_address` URLs (no local assets)

### 6. Food Filtering Rules
- **Food Preferences Screen** - Only shows generic foods (`brand_id IS NULL`) to avoid commercial bias
- **AI Nutrition Plans** - Only recommends generic foods by default (configurable via `RECOMMENDATION_MODE`)
- **Swap Food Screen** - Shows all foods but primarily generic foods for recommendations

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

**Get all foods by category (multi-category support):**
```sql
SELECT f.* FROM foods f
JOIN food_categories fc ON f.id = fc.food_id
JOIN categories c ON fc.category_id = c.id
WHERE c.name = $1
ORDER BY f.name;
```

**Get foods with all their categories:**
```sql
SELECT f.*, 
       ARRAY_AGG(c.name) as categories
FROM foods f
LEFT JOIN food_categories fc ON f.id = fc.food_id
LEFT JOIN categories c ON fc.category_id = c.id
GROUP BY f.id
ORDER BY f.name;
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

## 🔄 Multi-Category Food System Details

### Table Structure

**categories table:**
```sql
CREATE TABLE categories (
  id INTEGER NOT NULL PRIMARY KEY,
  name TEXT NOT NULL  -- 'before_run', 'during_run', 'after_run'
);
```

**food_categories table (join table):**
```sql
CREATE TABLE food_categories (
  food_id UUID NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
  category_id INTEGER NOT NULL REFERENCES categories(id),
  PRIMARY KEY (food_id, category_id)
);
```

### Benefits

1. **Versatile Foods**: Items like "Coconut water" can be recommended for all phases
2. **Algorithm Flexibility**: Better food selection when user preferences are limited
3. **Simplified Shopping**: Multi-phase foods reduce shopping complexity
4. **Enhanced Personalization**: More nuanced recommendations based on timing needs

### Implementation Details

- ✅ **Clean Design**: Pure multi-category system without legacy fields
- ✅ **Data Integrity**: Foreign key constraints ensure category validity
- ✅ **Performance**: Optimized indexes on join table for fast lookups
- ✅ **Flexibility**: Foods can belong to any combination of categories

## 📝 Additional Tables

### Food Preferences Table
Tracks user preferences for each food item:
```sql
CREATE TABLE food_preferences (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  device_id TEXT NOT NULL REFERENCES users(device_id) ON DELETE CASCADE,
  food_name TEXT NOT NULL,
  preference TEXT NOT NULL CHECK (preference IN ('like', 'dislike', 'willing_to_try')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(device_id, food_name)
);
```

**Features:**
- Three preference levels: `like`, `dislike`, `willing_to_try`
- Unique constraint prevents duplicate preferences per user/food
- Automatic timestamps with update trigger
- Row Level Security enabled
- Helper function `upsert_food_preferences()` for batch updates

### Feedback Table
Stores user satisfaction and feedback:
```sql
CREATE TABLE feedback (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  satisfaction_level INTEGER CHECK (satisfaction_level BETWEEN 1 AND 3),
  satisfaction_emoji TEXT NOT NULL,
  satisfaction_label TEXT NOT NULL,
  app_feedback TEXT,
  suggestions TEXT,
  plan_name TEXT,
  user_name TEXT,
  timestamp TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Foods Table Structure (Enhanced)
Complete food database with nutritional data, serving information, and suitability flags:
```sql
CREATE TABLE foods (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  image_address TEXT,                    -- URL to food image (online)
  description TEXT,                      -- User-friendly description
  instructions TEXT,                     -- Preparation/usage instructions
  nutritional_info JSONB DEFAULT '{}',   -- Legacy field, use explicit columns
  
  -- Serving Information
  serving_amount NUMERIC,                -- Base serving amount (e.g., 1, 0.5, 2)
  serving_unit TEXT,                     -- Unit name singular (e.g., "cup", "packet")
  serving_unit_plural TEXT,              -- Unit name plural (e.g., "cups", "packets")
  serving_qualifier TEXT,                -- Qualifier (e.g., "cooked", "sliced")
  serving_size TEXT,                     -- Legacy field
  
  -- Suitability Flags
  before_run_suitable BOOLEAN DEFAULT false,     -- Suitable for pre-run
  during_run_suitable BOOLEAN DEFAULT false,     -- Suitable for during-run
  run_portable BOOLEAN DEFAULT false,            -- Easy to carry while running
  requires_preparation BOOLEAN DEFAULT false,    -- Needs advance preparation
  aid_station_available BOOLEAN DEFAULT false,   -- Available at aid stations
  
  -- Serving Constraints
  max_servings_before INTEGER,           -- Max servings recommended before run
  max_servings_during INTEGER,           -- Max servings recommended during run
  
  -- Explicit Nutritional Data (per serving)
  carbs_per_serving NUMERIC(10,2),       -- Carbohydrates in grams
  protein_per_serving NUMERIC(10,2),     -- Protein in grams
  fat_per_serving NUMERIC(10,2),         -- Fat in grams
  calories_per_serving INTEGER,          -- Calories per serving
  fluid_ml_per_serving NUMERIC(10,1),    -- Fluid content in mL
  
  -- Micronutrients
  sodium_mg INTEGER,                     -- Sodium in milligrams
  caffeine_mg INTEGER,                   -- Caffeine in milligrams
  potassium_mg INTEGER,                  -- Potassium in milligrams
  
  -- Product Information
  brand_id UUID REFERENCES brands(id),   -- Brand reference
  product_type TEXT CHECK (product_type IN (
    'gel', 'chew', 'drink_mix', 'electrolyte_only', 'sports_drink', 
    'bar', 'waffle', 'capsule', 'real_food', 'recovery_shake'
  )),
  purchase_url TEXT,                     -- Purchase link
  affiliate_source TEXT,                 -- Affiliate tracking
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Unique index on lowercase name for case-insensitive uniqueness
CREATE UNIQUE INDEX uq_foods_lower_name ON foods (LOWER(name));
```

**Example data:**
- Oatmeal: `serving_amount: 1`, `serving_unit: "cup"`, `serving_unit_plural: "cups"`, `serving_qualifier: "cooked"`
- Banana: `serving_amount: 1`, `serving_unit: "medium"`, `serving_unit_plural: "medium"`
- Energy Gel: `serving_amount: 1`, `serving_unit: "packet"`, `serving_unit_plural: "packets"`