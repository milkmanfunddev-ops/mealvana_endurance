-- Add serving_size to user_foods for serving notes
ALTER TABLE user_foods
  ADD COLUMN IF NOT EXISTS serving_size text;
