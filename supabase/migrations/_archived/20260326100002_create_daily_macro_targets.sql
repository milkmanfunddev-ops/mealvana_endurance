-- Create daily_macro_targets table for caching daily macro calculations
CREATE TABLE IF NOT EXISTS daily_macro_targets (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_date date NOT NULL,
    carb_g real NOT NULL,
    prot_g real NOT NULL,
    fat_g real NOT NULL,
    tdee real NOT NULL,
    rmr real NOT NULL,
    session_kcal real NOT NULL DEFAULT 0,
    neat_kcal real,
    tef_kcal real,
    mode text NOT NULL DEFAULT 'prospective',
    ea real,
    ea_status text,
    calculation_input jsonb,
    algorithm_version text NOT NULL DEFAULT 'v4',
    needs_upload boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    UNIQUE(user_id, target_date)
);

ALTER TABLE daily_macro_targets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own macro targets"
    ON daily_macro_targets FOR ALL USING (auth.uid() = user_id);

CREATE INDEX idx_daily_macro_targets_user_date ON daily_macro_targets(user_id, target_date);
