# Mealvana Endurance - Database Documentation

This folder contains comprehensive documentation for the Mealvana Endurance database schema and structure.

## 📋 Quick Reference

| Document | Description |
|----------|-------------|
| [Schema Overview](./schema-overview.md) | Complete database schema with tables and relationships |
| [Users Table](./users-table.md) | User profiles and authentication |
| [Nutrition Plans Table](./nutrition-plans-table.md) | Nutrition plan storage with versioning |
| [Food Items Table](./food-items-table.md) | Food database and nutritional information |
| [App Content Table](./app-content-table.md) | Dynamic content and configuration |
| [SQL Functions](./sql-functions.md) | Stored procedures and database functions |
| [Migration Guide](./migrations.md) | Database setup and migration instructions |

## 🗄️ Database Technology

- **Database**: PostgreSQL (via Supabase)
- **ORM/Client**: Supabase Dart client
- **Local Storage**: Hive (Flutter)
- **Versioning**: Custom versioning with conflict resolution

## 🔧 Key Features

- **Offline-First**: Local Hive storage with Supabase sync
- **Device-Based Auth**: No traditional user accounts, device-ID based
- **Version Control**: Comprehensive versioning for nutrition plans
- **Conflict Resolution**: Automatic and manual conflict resolution
- **RLS Security**: Row Level Security policies
- **Real-time**: Supabase real-time subscriptions ready

## 🚀 Quick Setup

1. Run the SQL scripts in order:
   ```sql
   -- 1. Create base tables
   \i users-table.sql
   \i nutrition-plans-table.sql
   \i food-items-table.sql
   \i app-content-table.sql
   
   -- 2. Create functions
   \i sql-functions.sql
   ```

2. Verify setup:
   ```sql
   SELECT * FROM users LIMIT 1;
   SELECT * FROM nutrition_plans LIMIT 1;
   ```

## 📊 Entity Relationships

```
Users (device_id) 
  ├── 1:N → Nutrition Plans
  └── 1:1 → Food Preferences

Nutrition Plans (plan_id)
  ├── N:N → Food Items (via plan sections)
  └── 1:1 → Macro Targets

Food Items
  ├── 1:N → Nutritional Info
  └── N:N → Categories/Tags

App Content
  └── 1:N → Content Versions
```

## 🔐 Security Model

- **Public Access**: Food items, app content
- **Device-Scoped**: Users can only access their own data
- **RLS Policies**: Automatic filtering by device_id
- **API Keys**: Supabase anon key for client access

## 📝 Naming Conventions

- **Tables**: `snake_case` (e.g., `nutrition_plans`)
- **Columns**: `snake_case` (e.g., `device_id`, `created_at`)
- **Functions**: `snake_case` (e.g., `upsert_user_by_device_id`)
- **Indexes**: `idx_table_column` (e.g., `idx_users_device_id`)
- **Constraints**: `table_column_constraint` (e.g., `users_device_id_key`)

## 🏗️ Architecture Patterns

- **Device-First**: All data tied to device identifiers
- **Eventual Consistency**: Local-first with background sync
- **Immutable Events**: Soft deletes with version history
- **JSONB Storage**: Flexible schema for nutrition plan data
- **Upsert Operations**: Conflict-safe data operations