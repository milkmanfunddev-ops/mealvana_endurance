-- ============================================================================
-- COACH INVITE CODES TABLE
-- ============================================================================
-- Single-use invite codes for coach registration
-- Admin creates codes in Supabase, shares with coaches
-- Coaches enter code in app to unlock coach mode

CREATE TABLE IF NOT EXISTS coach_invite_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- The invite code itself (e.g., "COACH-ABC123")
    code TEXT NOT NULL UNIQUE,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    expires_at TIMESTAMPTZ, -- NULL = never expires

    -- Usage tracking
    used_by TEXT REFERENCES users(id) ON DELETE SET NULL, -- user_id who redeemed
    used_at TIMESTAMPTZ, -- when it was redeemed

    -- Status
    is_active BOOLEAN DEFAULT true NOT NULL, -- can be deactivated by admin

    -- Admin notes (e.g., "For Coach John Smith")
    notes TEXT
);

-- Index for code lookup
CREATE INDEX IF NOT EXISTS idx_coach_invite_codes_code ON coach_invite_codes(code);

-- Index for finding active, unused codes
CREATE INDEX IF NOT EXISTS idx_coach_invite_codes_active ON coach_invite_codes(is_active, used_at)
    WHERE is_active = true AND used_at IS NULL;

-- Comments
COMMENT ON TABLE coach_invite_codes IS 'Single-use invite codes for coach registration';
COMMENT ON COLUMN coach_invite_codes.code IS 'The invite code string (e.g., COACH-ABC123)';
COMMENT ON COLUMN coach_invite_codes.expires_at IS 'When the code expires. NULL means never expires';
COMMENT ON COLUMN coach_invite_codes.used_by IS 'User ID who redeemed this code';
COMMENT ON COLUMN coach_invite_codes.used_at IS 'Timestamp when the code was redeemed';
COMMENT ON COLUMN coach_invite_codes.is_active IS 'Whether the code can be used. Admin can deactivate';
COMMENT ON COLUMN coach_invite_codes.notes IS 'Admin notes about who this code is for';

-- RLS Policies
ALTER TABLE coach_invite_codes ENABLE ROW LEVEL SECURITY;

-- Users can only read codes (to validate them) - actual redemption happens via function
CREATE POLICY "Users can read invite codes for validation"
    ON coach_invite_codes
    FOR SELECT
    USING (true);

-- Only service role can insert/update/delete (admin operations)
-- This means codes are managed via Supabase dashboard or edge functions

-- ============================================================================
-- FUNCTION: Redeem Coach Invite Code
-- ============================================================================
-- Validates and redeems a coach invite code atomically
-- Returns the user's updated is_coach status

CREATE OR REPLACE FUNCTION redeem_coach_invite_code(
    p_code TEXT,
    p_user_id TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_code_record coach_invite_codes%ROWTYPE;
    v_result JSON;
BEGIN
    -- Find the code
    SELECT * INTO v_code_record
    FROM coach_invite_codes
    WHERE code = UPPER(TRIM(p_code))
    FOR UPDATE; -- Lock the row

    -- Check if code exists
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Invalid invite code'
        );
    END IF;

    -- Check if code is active
    IF NOT v_code_record.is_active THEN
        RETURN json_build_object(
            'success', false,
            'error', 'This invite code has been deactivated'
        );
    END IF;

    -- Check if code is already used
    IF v_code_record.used_at IS NOT NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'This invite code has already been used'
        );
    END IF;

    -- Check if code is expired
    IF v_code_record.expires_at IS NOT NULL AND v_code_record.expires_at < NOW() THEN
        RETURN json_build_object(
            'success', false,
            'error', 'This invite code has expired'
        );
    END IF;

    -- Check if user is already a coach
    IF EXISTS (SELECT 1 FROM users WHERE id = p_user_id AND is_coach = true) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'You are already registered as a coach'
        );
    END IF;

    -- Mark code as used
    UPDATE coach_invite_codes
    SET used_by = p_user_id,
        used_at = NOW()
    WHERE id = v_code_record.id;

    -- Update user to be a coach
    UPDATE users
    SET is_coach = true,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Return success
    RETURN json_build_object(
        'success', true,
        'message', 'Welcome! You are now registered as a coach.'
    );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION redeem_coach_invite_code(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION redeem_coach_invite_code(TEXT, TEXT) TO anon;

COMMENT ON FUNCTION redeem_coach_invite_code IS 'Validates and redeems a coach invite code, granting coach privileges to the user';

-- ============================================================================
-- HELPER: Generate a random invite code
-- ============================================================================
-- Use this in Supabase SQL editor to generate codes:
-- SELECT generate_coach_invite_code();

CREATE OR REPLACE FUNCTION generate_coach_invite_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Exclude confusing chars (0, O, 1, I)
    v_code TEXT := 'COACH-';
    v_i INTEGER;
BEGIN
    FOR v_i IN 1..6 LOOP
        v_code := v_code || substr(v_chars, floor(random() * length(v_chars) + 1)::integer, 1);
    END LOOP;
    RETURN v_code;
END;
$$;

COMMENT ON FUNCTION generate_coach_invite_code IS 'Generates a random coach invite code like COACH-ABC123';

-- ============================================================================
-- SAMPLE: How to create invite codes (run in Supabase SQL editor)
-- ============================================================================
--
-- Create a single code:
-- INSERT INTO coach_invite_codes (code, notes)
-- VALUES (generate_coach_invite_code(), 'For Coach John Smith');
--
-- Create a code with expiration:
-- INSERT INTO coach_invite_codes (code, expires_at, notes)
-- VALUES (generate_coach_invite_code(), NOW() + INTERVAL '30 days', 'Beta coach - expires in 30 days');
--
-- Create multiple codes:
-- INSERT INTO coach_invite_codes (code, notes)
-- SELECT generate_coach_invite_code(), 'Beta batch ' || generate_series
-- FROM generate_series(1, 10);
--
-- View all codes:
-- SELECT code, notes, is_active, used_at, expires_at FROM coach_invite_codes ORDER BY created_at DESC;
