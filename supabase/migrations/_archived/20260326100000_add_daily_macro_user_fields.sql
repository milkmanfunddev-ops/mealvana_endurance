-- Add daily macro calculation fields to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS body_fat_pct real;
ALTER TABLE users ADD COLUMN IF NOT EXISTS lifestyle text DEFAULT 'mixed';
ALTER TABLE users ADD COLUMN IF NOT EXISTS typical_weekly_hours real;
ALTER TABLE users ADD COLUMN IF NOT EXISTS carb_cycle_opt_in boolean DEFAULT false NOT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS training_phase text DEFAULT 'base';
