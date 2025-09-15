# Supabase Row Level Security (RLS) Policies

## Overview

Supabase Row Level Security (RLS) provides fine-grained access control for Mealvana Endurance's database. The app uses device-based authentication without traditional user accounts, requiring carefully crafted policies to protect user data while enabling development workflows.

## Authentication Model

### Device-Based Authentication
- **No Traditional Accounts**: Users identified by unique `device_id`
- **Anonymous Access**: Most operations use anonymous role with RLS
- **Privacy-First**: Minimal user data collection and storage
- **Local-First**: Critical data primarily stored locally with Drift

### Role Structure
- **anon**: Anonymous users (app clients)
- **authenticated**: Service accounts and admin access
- **service_role**: Backend services and migrations

## Policy Categories

### 1. Public Read Access

Tables with unrestricted read access for app functionality:

```sql
-- App content (UI text, algorithm parameters)
create policy "Anyone can read app_content" 
on public.app_content as permissive for select 
using (true);

-- Food database
create policy "Anyone can read foods" 
on public.foods as permissive for select 
using (true);

-- Categories (before_run, during_run, after_run)
create policy "Anyone can read categories" 
on public.categories as permissive for select 
using (true);

-- Food-category relationships
create policy "Anyone can read food_categories" 
on public.food_categories as permissive for select 
using (true);

-- Brand information for affiliate links
create policy "Anyone can read brands" 
on public.brands as permissive for select 
using (true);

-- Edge functions metadata
create policy "Anyone can read edge_functions" 
on public.edge_functions as permissive for select 
using (true);
```

**Rationale**: These tables contain reference data needed by all app instances for core functionality.

### 2. User Data Protection

Device-based access control for personal user data:

```sql
-- Users table - full access to own data
create policy "Users can read own data" 
on public.users as permissive for select 
using (true);

create policy "Users can insert own data" 
on public.users as permissive for insert 
with check (true);

create policy "Users can update own data" 
on public.users as permissive for update 
using (true);

-- Nutrition plans - device-based access
create policy "Users can read own plans" 
on public.nutrition_plans as permissive for select 
using (true);

create policy "Users can insert own plans" 
on public.nutrition_plans as permissive for insert 
with check (true);

create policy "Users can update own plans" 
on public.nutrition_plans as permissive for update 
using (true);

create policy "Users can delete own plans" 
on public.nutrition_plans as permissive for delete 
using (true);

-- Food preferences - device-based access
create policy "Allow all operations on food_preferences" 
on public.food_preferences as permissive for all 
using (true) with check (true);
```

**Note**: While policies appear open with `using (true)`, actual access control is enforced at the application level through device_id filtering in repositories.

### 3. Development Environment Policies

Special policies enabling development and testing:

```sql
-- App content - development modifications
create policy "Dev: anon can modify app_content" 
on public.app_content as permissive for all 
to anon using (true) with check (true);

-- Foods - development modifications
create policy "Dev: anon can modify foods" 
on public.foods as permissive for all 
to anon using (true) with check (true);

-- Food categories - development modifications
create policy "Dev: anon can modify food_categories" 
on public.food_categories as permissive for all 
to anon using (true) with check (true);

-- Edge functions - development updates
create policy "Dev: anon can modify edge_functions" 
on public.edge_functions as permissive for all 
to anon using (true) with check (true);
```

**Rationale**: Enables rapid development and testing without authentication overhead.

### 4. Feedback Collection

Open feedback collection for user experience improvement:

```sql
-- Feedback - unrestricted submission
create policy "Allow all operations on feedback" 
on public.feedback as permissive for all 
using (true);
```

**Rationale**: Removes barriers to feedback submission while maintaining user privacy.

## Application-Level Security

### Repository Pattern Enforcement

While RLS policies appear permissive, actual security is enforced in Dart repositories:

```dart
// UserRepository - device_id filtering
class UserRepository {
  Future<UserProfile?> getUserProfile(String deviceId) async {
    final response = await _supabase
        .from('users')
        .select()
        .eq('device_id', deviceId)  // ← Security enforcement
        .maybeSingle();
    
    return response != null ? UserProfile.fromJson(response) : null;
  }
}

// NutritionPlanRepository - device_id filtering  
class NutritionPlanRepository {
  Future<List<NutritionPlan>> getUserPlans(String deviceId) async {
    final response = await _supabase
        .from('nutrition_plans')
        .select()
        .eq('device_id', deviceId)  // ← Security enforcement
        .eq('is_deleted', false)
        .order('created_at', ascending: false);
    
    return response
        .map<NutritionPlan>((json) => NutritionPlan.fromJson(json))
        .toList();
  }
}
```

### Why This Approach?

1. **Device-Based Auth Complexity**: Traditional RLS with JWT tokens doesn't fit device-based authentication
2. **Development Flexibility**: Allows testing without complex authentication setup
3. **Performance**: Reduces policy evaluation overhead on large queries
4. **Local-First Architecture**: Critical security handled by Drift local database

## Security Considerations

### Data Privacy Measures

```sql
-- Minimize PII collection
CREATE TABLE public.users (
    -- No email, phone, or traditional identifiers
    device_id text UNIQUE NOT NULL,  -- Anonymous device identifier
    gender text,                     -- Optional demographic
    birthday date,                   -- Optional age calculation
    -- ... other optional fields
);
```

### Audit Trail

```sql
-- Automatic timestamp tracking
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Applied to sensitive tables
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
```

### Data Retention

```sql
-- Soft deletion for nutrition plans
ALTER TABLE nutrition_plans ADD COLUMN is_deleted boolean DEFAULT false;

-- Cleanup old feedback (90 days)
DELETE FROM feedback 
WHERE created_at < NOW() - INTERVAL '90 days';
```

## Environment-Specific Policies

### Production Environment

```sql
-- Restrict content modifications to authenticated users
create policy "Allow authenticated insert to app_content" 
on public.app_content as permissive for insert
with check (auth.role() = 'authenticated'::text);

create policy "Allow authenticated update to app_content" 
on public.app_content as permissive for update
using (auth.role() = 'authenticated'::text);
```

### Development Environment

```sql
-- Allow anonymous modifications for testing
create policy "Dev: anon can modify app_content" 
on public.app_content as permissive for all 
to anon using (true) with check (true);
```

## Monitoring and Alerting

### Policy Violation Monitoring

```sql
-- Monitor failed access attempts (requires logging extension)
SELECT 
    table_name,
    operation,
    COUNT(*) as violations
FROM pg_stat_user_tables
WHERE schemaname = 'public'
GROUP BY table_name, operation;
```

### Data Access Patterns

```sql
-- Unusual access patterns
SELECT 
    device_id,
    COUNT(*) as requests,
    DATE_TRUNC('hour', created_at) as hour
FROM nutrition_plans 
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY device_id, hour
HAVING COUNT(*) > 100  -- Possible abuse
ORDER BY requests DESC;
```

## Migration Considerations

### Policy Updates During Schema Changes

```sql
-- Disable RLS during migrations
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

-- Run migration
-- ... schema changes ...

-- Re-enable RLS with updated policies
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
```

### Testing Policy Changes

```sql
-- Test policies with specific roles
SET ROLE anon;
SELECT * FROM users WHERE device_id = 'test-device';  -- Should work

SET ROLE authenticated;  
UPDATE app_content SET content = '{}' WHERE id = 'test-id';  -- Should work

SET ROLE anon;
UPDATE app_content SET content = '{}' WHERE id = 'test-id';  -- Should fail in prod
```

## Best Practices

### Policy Design Principles

1. **Principle of Least Privilege**: Grant minimal necessary access
2. **Defense in Depth**: Combine RLS with application-level controls
3. **Audit Everything**: Log all data access and modifications
4. **Environment Separation**: Different policies for dev/staging/production
5. **Performance Awareness**: Simple policies reduce query overhead

### Development Guidelines

```dart
// Always filter by device_id in repositories
class BaseRepository {
  String get deviceId => DeviceInfoService.instance.deviceId;
  
  // Helper method for device-filtered queries
  PostgrestFilterBuilder<T> filterByDevice<T>(
    PostgrestQueryBuilder<T> query
  ) {
    return query.eq('device_id', deviceId);
  }
}
```

### Security Checklist

- [ ] All user data queries filter by device_id
- [ ] Public data tables have read-only policies
- [ ] Development policies are environment-specific
- [ ] Audit triggers are enabled on sensitive tables
- [ ] Data retention policies are implemented
- [ ] Regular security reviews are scheduled

This RLS policy structure balances security, privacy, and development flexibility while supporting Mealvana Endurance's unique device-based authentication model and local-first architecture.