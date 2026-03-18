-- Athlete pairing codes for coach-athlete connections
-- A 6-character alphanumeric code that athletes generate and share with coaches.
-- Codes expire after 24 hours and can only be used once.

CREATE TABLE IF NOT EXISTS athlete_pairing_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  code VARCHAR(6) NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  used_by_coach_id UUID REFERENCES auth.users(id),
  used_at TIMESTAMPTZ
);

-- Index for fast code lookups
CREATE INDEX IF NOT EXISTS idx_pairing_codes_code ON athlete_pairing_codes(code);

-- Index for finding active codes by user
CREATE INDEX IF NOT EXISTS idx_pairing_codes_user ON athlete_pairing_codes(user_id, expires_at);

-- RLS policies
ALTER TABLE athlete_pairing_codes ENABLE ROW LEVEL SECURITY;

-- Athletes can manage their own codes
CREATE POLICY "Users can manage own pairing codes"
  ON athlete_pairing_codes
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Coaches can read valid (unexpired, unused) codes for connection
CREATE POLICY "Coaches can read valid pairing codes"
  ON athlete_pairing_codes
  FOR SELECT
  USING (
    expires_at > now()
    AND used_at IS NULL
  );

-- Coaches can update codes to mark them as used
CREATE POLICY "Coaches can use pairing codes"
  ON athlete_pairing_codes
  FOR UPDATE
  USING (
    expires_at > now()
    AND used_at IS NULL
  )
  WITH CHECK (used_by_coach_id = auth.uid());
