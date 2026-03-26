-- Add TSS (Training Stress Score) column to activities table
ALTER TABLE activities ADD COLUMN IF NOT EXISTS tss real;
