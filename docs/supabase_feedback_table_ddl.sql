-- Corrected Supabase feedback table DDL
-- This table stores user survey responses for analytics and feedback tracking

CREATE TABLE IF NOT EXISTS feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    satisfaction_level INTEGER,
    satisfaction_emoji TEXT,
    satisfaction_label TEXT,
    confidence_level INTEGER,
    confidence_label TEXT,
    reuse_intent TEXT,
    reminder_requested BOOLEAN DEFAULT false,
    missed_reasons TEXT,
    missed_other TEXT,
    reminder_day_of_week INTEGER,
    reminder_hour INTEGER DEFAULT 17,
    reminder_minute INTEGER DEFAULT 0,
    reminder_recurring BOOLEAN DEFAULT false,
    plan_name TEXT,
    user_name TEXT, -- Using deviceId as user identifier
    timestamp TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Create indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_feedback_created_at ON feedback (created_at);
CREATE INDEX IF NOT EXISTS idx_feedback_user_name ON feedback (user_name);
CREATE INDEX IF NOT EXISTS idx_feedback_satisfaction_level ON feedback (satisfaction_level);
CREATE INDEX IF NOT EXISTS idx_feedback_timestamp ON feedback (timestamp);

-- Enable Row Level Security (RLS)
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all operations for now (adjust as needed for your security requirements)
CREATE POLICY "Allow all operations on feedback" ON feedback
    FOR ALL USING (true);

-- Grant permissions to authenticated users
GRANT ALL ON feedback TO authenticated;
GRANT ALL ON feedback TO anon;