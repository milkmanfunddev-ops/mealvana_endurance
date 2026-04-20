-- Coach pairing codes table for reversed pairing flow:
-- Coaches generate codes, athletes enter them to connect.
CREATE TABLE IF NOT EXISTS coach_pairing_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_user_id UUID NOT NULL REFERENCES users(id),
  code VARCHAR(6) NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '24 hours'),
  used_by_athlete_id UUID REFERENCES users(id),
  used_at TIMESTAMPTZ
);

-- Index for fast lookup by code
CREATE INDEX IF NOT EXISTS idx_coach_pairing_codes_code ON coach_pairing_codes(code);

-- Index for looking up active codes by coach
CREATE INDEX IF NOT EXISTS idx_coach_pairing_codes_coach ON coach_pairing_codes(coach_user_id, expires_at)
  WHERE used_at IS NULL;

-- RLS policies
ALTER TABLE coach_pairing_codes ENABLE ROW LEVEL SECURITY;

-- Coaches can manage their own codes
CREATE POLICY coach_pairing_codes_coach_select ON coach_pairing_codes
  FOR SELECT TO authenticated
  USING (coach_user_id = auth.uid());

CREATE POLICY coach_pairing_codes_coach_insert ON coach_pairing_codes
  FOR INSERT TO authenticated
  WITH CHECK (coach_user_id = auth.uid());

CREATE POLICY coach_pairing_codes_coach_update ON coach_pairing_codes
  FOR UPDATE TO authenticated
  USING (coach_user_id = auth.uid());

-- Athletes can read valid codes (to validate them) and update (to mark as used)
CREATE POLICY coach_pairing_codes_athlete_select ON coach_pairing_codes
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY coach_pairing_codes_athlete_update ON coach_pairing_codes
  FOR UPDATE TO authenticated
  USING (used_by_athlete_id IS NULL OR used_by_athlete_id = auth.uid());
