# Supabase Migrations

## Structure

- **Active migrations**: Migration files in this directory will be applied to new environments
- **`_archive/`**: Historical migrations already deployed to dev/prod (kept for reference)

## Local Development Setup

Since you're in active development, you have two options for setting up your local Supabase:

### Option 1: Use Production Baseline (Recommended)
Pull the latest schema from your dev/prod Supabase instance:

```bash
supabase db pull
```

This creates a snapshot of your current production schema.

### Option 2: Fresh Local Setup
Reset your local Supabase to match the baseline:

```bash
supabase db reset
```

This will apply only the active migrations (cycling/swimming support).

## Deployment

### Dev Environment
```bash
supabase db push --linked
```

### Production Environment
When ready to ship to production users, migrations will be applied automatically via GitHub Actions or manual deployment.

## Migration History

All migrations prior to `20251015000000` have been archived. They were already deployed to dev/prod and are kept for historical reference only.

Current active migrations:
- `20251015000000_add_cycling_swimming_support.sql` - Adds cycling/swimming sport types, FTP/CSS preferences, and sport-specific food suitability
