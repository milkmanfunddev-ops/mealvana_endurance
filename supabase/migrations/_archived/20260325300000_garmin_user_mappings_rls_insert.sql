-- Allow authenticated users to manage their own garmin_user_mappings rows
-- Required for the Flutter client to upsert/delete mappings during
-- Garmin Connect OAuth connect/disconnect flow.

CREATE POLICY "Users can insert own garmin mappings"
  ON garmin_user_mappings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own garmin mappings"
  ON garmin_user_mappings FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own garmin mappings"
  ON garmin_user_mappings FOR DELETE
  USING (auth.uid() = user_id);
