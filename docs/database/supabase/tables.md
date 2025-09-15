# Supabase Database Tables

## Overview

The Supabase PostgreSQL database serves as the backend for Mealvana Endurance, providing data persistence, sync capabilities, and content management. This document details all tables, their relationships, and usage patterns.

## Core Tables

### 1. users

**Purpose**: Device-based user profiles and preferences
**Primary Key**: id (UUID)
**Unique Constraint**: device_id

```sql
CREATE TABLE public.users (
    id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id                  text UNIQUE NOT NULL,
    created_at                 timestamptz DEFAULT now(),
    updated_at                 timestamptz DEFAULT now(),
    
    -- Demographics
    gender                     text CHECK (gender IN ('male', 'female', 'other')),
    birthday                   date,
    height_feet                integer,
    height_inches              integer,
    weight_pounds              numeric(5, 2),
    
    -- Preferences
    runs_with_water_bottle     boolean DEFAULT false,
    food_preferences           jsonb DEFAULT '{}',
    preferred_distance_unit    text DEFAULT 'miles' CHECK (preferred_distance_unit IN ('miles', 'kilometers')),
    preferred_pace_unit        text DEFAULT 'min_per_mile' CHECK (preferred_pace_unit IN ('min_per_mile', 'min_per_km')),
    gut_training_level         text DEFAULT 'moderate' CHECK (gut_training_level IN ('low', 'moderate', 'high')),
    
    -- State tracking
    onboarding_completed       boolean DEFAULT false,
    last_active_at             timestamptz DEFAULT now(),
    app_version                text,
    
    -- Notification preferences
    notifications_enabled      boolean DEFAULT false,
    default_reminder_day       integer DEFAULT 4,    -- Thursday
    default_reminder_hour      integer DEFAULT 17,   -- 5 PM
    default_reminder_minute    integer DEFAULT 0,
    default_reminder_recurring boolean DEFAULT false
);
```

**Key Features**:
- **Device-Based Authentication**: Users identified by device_id, no traditional accounts
- **Privacy-First**: Minimal personal data collection
- **Comprehensive Preferences**: Food, units, notifications, gut training levels
- **Onboarding Tracking**: State management for user setup flow

**Indexes**:
- `idx_users_device_id`: Fast device_id lookups
- `idx_users_updated_at`: Sync ordering
- `idx_users_onboarding`: Filter completed users
- `idx_users_last_active`: Activity tracking

### 2. nutrition_plans

**Purpose**: Generated nutrition plans with versioning and conflict resolution
**Primary Key**: id (UUID)
**Foreign Key**: device_id → users(device_id)

```sql
CREATE TABLE public.nutrition_plans (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id             text NOT NULL REFERENCES users(device_id) ON DELETE CASCADE,
    plan_data             jsonb NOT NULL,
    
    -- Plan metadata
    plan_id               text NOT NULL,
    plan_name             text NOT NULL,
    distance_miles        numeric(5, 2),
    pace_minutes_per_mile numeric(5, 2),
    total_calories        integer,
    notes                 text,
    
    -- Versioning and sync
    version               integer DEFAULT 1,
    last_modified_by      text,
    client_updated_at     timestamptz,
    is_deleted            boolean DEFAULT false,
    conflict_resolution   text,
    
    -- Timestamps
    created_at            timestamptz DEFAULT now(),
    updated_at            timestamptz DEFAULT now(),
    
    UNIQUE(device_id, plan_id)
);
```

**Key Features**:
- **Complete Plan Storage**: JSON plan data with structured metadata
- **Version Control**: Optimistic concurrency control for sync conflicts
- **Soft Deletion**: is_deleted flag preserves data while hiding from users
- **Device Association**: All plans tied to specific devices

**Indexes**:
- `idx_nutrition_plans_device_id`: User's plans lookup
- `idx_nutrition_plans_created_at`: Chronological ordering
- `idx_nutrition_plans_device_updated`: Sync queries
- `idx_nutrition_plans_active`: Active plans only

### 3. foods

**Purpose**: Master food database with nutritional information and affiliate data
**Primary Key**: id (UUID)
**Foreign Key**: brand_id → brands(id)

```sql
CREATE TABLE public.foods (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name                  text,
    image_address         text,
    description           text,
    instructions          text,
    nutritional_info      jsonb DEFAULT '{}',
    created_at            timestamptz DEFAULT now(),
    
    -- Serving information
    serving_amount        numeric,
    serving_unit          text,
    serving_unit_plural   text,
    serving_qualifier     text,
    serving_size          text,
    
    -- Suitability flags
    before_run_suitable   boolean DEFAULT false,
    during_run_suitable   boolean DEFAULT false,
    after_run_suitable    boolean DEFAULT false,
    run_portable          boolean DEFAULT false,
    requires_preparation  boolean DEFAULT false,
    aid_station_available boolean DEFAULT false,
    is_electrolyte        boolean DEFAULT false,
    max_servings_before   integer,
    max_servings_during   integer,
    max_servings_after    integer,
    
    -- Nutritional values per serving
    sodium_mg             integer,
    caffeine_mg           integer,
    potassium_mg          integer,
    fat_per_serving       numeric(10, 2),
    carbs_per_serving     numeric(10, 2),
    protein_per_serving   numeric(10, 2),
    calories_per_serving  integer,
    fluid_ml_per_serving  numeric(10, 1),
    
    -- Branding and purchasing
    brand_id              uuid REFERENCES brands(id),
    product_type          text CHECK (product_type IN (
        'gel', 'chew', 'drink_mix', 'electrolyte_only', 'sports_drink',
        'bar', 'waffle', 'capsule', 'real_food', 'recovery_shake'
    )),
    purchase_url          text,
    affiliate_source      text,
    
    -- Food preferences filtering (added in v2.1)
    show_in_preferences   boolean DEFAULT false,
    preference_priority   integer DEFAULT 999
);
```

**Key Features**:
- **Comprehensive Nutrition Data**: Complete macro and micronutrient information
- **Serving Flexibility**: Structured serving size data (no more parsing!)
- **Timing Suitability**: Boolean flags for before/during/after run appropriateness
- **Affiliate Integration**: Purchase URLs and affiliate tracking
- **Brand Relationships**: Optional brand association for monetization
- **Food Preferences Filtering**: Curated subset for onboarding with priority ordering (v2.1)

**Indexes**:
- `uq_foods_lower_name`: Case-insensitive unique names
- `idx_foods_suitability_before`: Fast before-run food queries
- `idx_foods_suitability_during`: Fast during-run food queries
- `idx_foods_brand`: Brand-specific queries
- `idx_foods_preferences`: Fast food preferences filtering
- `idx_foods_preference_priority`: Ordered display for preferences screen

### 4. categories

**Purpose**: Food timing categories (before_run, during_run, after_run)
**Primary Key**: id (integer)

```sql
CREATE TABLE public.categories (
    id   integer PRIMARY KEY,
    name text NOT NULL
);

-- Default data
INSERT INTO categories (id, name) VALUES 
(1, 'before_run'),
(2, 'during_run'),
(3, 'after_run');
```

**Key Features**:
- **Simple Lookup Table**: Integer IDs for performance
- **Fixed Categories**: Three timing phases for nutrition planning
- **Extensible**: Can add new categories (post_run, hydration_only, etc.)

### 5. food_categories

**Purpose**: Many-to-many relationship between foods and categories
**Primary Key**: Composite (food_id, category_id)

```sql
CREATE TABLE public.food_categories (
    food_id     uuid NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
    category_id integer NOT NULL REFERENCES categories(id),
    PRIMARY KEY (food_id, category_id)
);
```

**Key Features**:
- **Multi-Category Foods**: Foods can be suitable for multiple timing phases
- **Referential Integrity**: Cascading deletes maintain consistency
- **Performance Optimized**: Composite primary key and targeted indexes

**Indexes**:
- `idx_food_categories_food`: Food → categories lookups
- `idx_food_categories_category_id`: Category → foods lookups

### 6. food_preferences

**Purpose**: User food preferences (like, dislike, willing_to_try)
**Primary Key**: id (UUID)
**Foreign Key**: device_id → users(device_id)
**Unique Constraint**: (device_id, food_name)

```sql
CREATE TABLE public.food_preferences (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id  text NOT NULL REFERENCES users(device_id) ON DELETE CASCADE,
    food_name  text NOT NULL,
    preference text NOT NULL CHECK (preference IN ('like', 'dislike', 'willing_to_try')),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);
```

**Key Features**:
- **Three-Tier Preference System**: Like > Willing to Try > Neutral > Dislike
- **Flexible Food Reference**: References food by name (not ID) for flexibility
- **Device Association**: Each user has their own preference set
- **Audit Trail**: Created/updated timestamps for preference changes

**Indexes**:
- `idx_food_preferences_device_food`: Unique constraint enforcement
- `idx_food_preferences_device_id`: User preference queries
- `idx_food_preferences_preference`: Preference-based filtering

### 7. brands

**Purpose**: Brand information for affiliate marketing
**Primary Key**: id (UUID)

```sql
CREATE TABLE public.brands (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name                  text UNIQUE NOT NULL,
    website_url           text,
    affiliate_program_url text,
    affiliate_network     text,
    default_affiliate_url text,
    notes                 text
);
```

**Key Features**:
- **Affiliate Marketing Support**: URLs and network tracking
- **Brand Management**: Centralized brand information
- **Monetization Ready**: Integration points for affiliate revenue
- **Flexible Notes**: Additional brand context and partnerships

### 8. app_content

**Purpose**: Dynamic content management system
**Primary Key**: id (UUID)

```sql
CREATE TABLE public.app_content (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    version     integer DEFAULT 1 NOT NULL,
    environment text DEFAULT 'production' NOT NULL,
    locale      text DEFAULT 'en' NOT NULL,
    content     jsonb NOT NULL,
    is_active   boolean DEFAULT true NOT NULL,
    created_at  timestamptz DEFAULT now(),
    updated_at  timestamptz DEFAULT now(),
    created_by  uuid,
    updated_by  uuid
);
```

**Key Features**:
- **Multi-Environment Support**: Development, staging, production
- **Localization Ready**: Content for multiple locales
- **Version Control**: Incremental version numbers
- **A/B Testing**: Multiple active versions per environment
- **Audit Trail**: Track who made changes and when

**Indexes**:
- `idx_app_content_env_locale`: Environment/locale queries
- `idx_app_content_active`: Active content filtering
- `idx_app_content_version`: Version-based queries
- `idx_app_content_latest`: Latest active content per env/locale

### 9. feedback

**Purpose**: User feedback and satisfaction tracking
**Primary Key**: id (UUID)

```sql
CREATE TABLE public.feedback (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Satisfaction metrics
    satisfaction_level   integer,          -- 1-3 scale
    satisfaction_emoji   text,
    satisfaction_label   text,
    confidence_level     integer,
    confidence_label     text,
    reuse_intent         text,
    
    -- Missed nutrition tracking
    missed_reasons       text,
    missed_other         text,
    
    -- Reminder preferences
    reminder_requested   boolean DEFAULT false,
    reminder_day_of_week integer,
    reminder_hour        integer DEFAULT 17,
    reminder_minute      integer DEFAULT 0,
    reminder_recurring   boolean DEFAULT false,
    
    -- Context
    plan_name            text,
    user_name            text,
    timestamp            timestamptz,
    created_at           timestamptz DEFAULT now()
);
```

**Key Features**:
- **Comprehensive Metrics**: Satisfaction, confidence, reuse intent
- **Missed Nutrition Tracking**: Why users didn't follow the plan
- **Reminder Integration**: User-requested follow-up reminders
- **Analytics Ready**: Structured data for improvement insights

**Indexes**:
- `idx_feedback_created_at`: Temporal analysis
- `idx_feedback_satisfaction_level`: Satisfaction trending
- `idx_feedback_user_name`: User-specific feedback
- `idx_feedback_timestamp`: Event-time analysis

### 10. edge_functions

**Purpose**: Dynamic edge function code deployment
**Primary Key**: id (UUID)

```sql
CREATE TABLE public.edge_functions (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name       text UNIQUE NOT NULL,
    code       text NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);
```

**Key Features**:
- **Dynamic Code Deployment**: Update edge function code without redeployment
- **Version Control**: Track code changes over time
- **Hot Swapping**: Enable/disable functions dynamically
- **Development Support**: Test new function versions

## Row Level Security (RLS) Policies

### Public Read Access
- **app_content**: Anyone can read active content
- **foods**: Anyone can read food database
- **categories**: Anyone can read categories
- **food_categories**: Anyone can read food-category relationships
- **brands**: Anyone can read brand information

### User Data Protection
- **users**: Users can read/write their own data only
- **nutrition_plans**: Users can access their own plans only
- **food_preferences**: Users can manage their own preferences only

### Development Policies
- **Dev Environment**: Anonymous users can modify content/foods for development
- **Production Environment**: Only authenticated users can modify data

## Database Functions

### Automatic Timestamp Updates
```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

Applied to tables:
- users
- nutrition_plans  
- app_content
- food_preferences

### Custom Helper Functions
```sql
-- Get active content for environment/locale
CREATE OR REPLACE FUNCTION get_active_content(env text, loc text)
RETURNS TABLE(content jsonb, version integer) AS $$
BEGIN
    RETURN QUERY
    SELECT ac.content, ac.version
    FROM app_content ac
    WHERE ac.environment = env 
      AND ac.locale = loc 
      AND ac.is_active = true
    ORDER BY ac.version DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;
```

## Common Query Patterns

### User Management
```sql
-- Get user by device ID
SELECT * FROM users WHERE device_id = $1;

-- Update user preferences
UPDATE users 
SET food_preferences = $2, updated_at = now() 
WHERE device_id = $1;
```

### Food Queries
```sql
-- Get foods by category
SELECT f.*, array_agg(c.name) as categories
FROM foods f
JOIN food_categories fc ON f.id = fc.food_id
JOIN categories c ON fc.category_id = c.id
WHERE c.name = 'before_run'
GROUP BY f.id, f.name
ORDER BY f.name;

-- Get user's preferred foods for category
SELECT f.*, fp.preference
FROM foods f
JOIN food_categories fc ON f.id = fc.food_id
JOIN categories c ON fc.category_id = c.id
LEFT JOIN food_preferences fp ON f.name = fp.food_name 
                              AND fp.device_id = $1
WHERE c.name = $2
ORDER BY 
  CASE fp.preference 
    WHEN 'like' THEN 1
    WHEN 'willing_to_try' THEN 2
    WHEN NULL THEN 3
    WHEN 'dislike' THEN 4
  END,
  f.name;
```

### Plan Management
```sql
-- Get user's latest plan
SELECT * FROM nutrition_plans 
WHERE device_id = $1 AND is_deleted = false
ORDER BY created_at DESC 
LIMIT 1;

-- Get plan history with pagination
SELECT * FROM nutrition_plans
WHERE device_id = $1 AND is_deleted = false
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;
```

### Content Management
```sql
-- Get latest active content
SELECT content FROM app_content
WHERE environment = $1 AND locale = $2 AND is_active = true
ORDER BY version DESC
LIMIT 1;

-- Update content version
INSERT INTO app_content (environment, locale, content, version)
VALUES ($1, $2, $3, (
  SELECT COALESCE(MAX(version), 0) + 1 
  FROM app_content 
  WHERE environment = $1 AND locale = $2
));
```

## Performance Considerations

### Indexing Strategy
- **Primary Keys**: Automatic unique indexes for fast lookups
- **Foreign Keys**: Indexes on all foreign key columns
- **Composite Indexes**: Multi-column indexes for common query patterns
- **Partial Indexes**: Filtered indexes for common WHERE conditions

### Query Optimization
- **Avoid N+1 Queries**: Use JOINs or batch queries
- **Limit Result Sets**: Always use LIMIT for large tables
- **Use Proper Data Types**: Numeric for numbers, JSONB for JSON
- **Index Foreign Keys**: All foreign key columns should be indexed

### Monitoring and Maintenance
- **Query Performance**: Monitor slow queries and add indexes as needed
- **Table Sizes**: Monitor growth and plan for partitioning if needed
- **Connection Pooling**: Use pgBouncer for connection management
- **Regular VACUUM**: Keep table statistics current

This comprehensive table structure provides a solid foundation for Mealvana Endurance's backend functionality while supporting future growth and feature expansion.