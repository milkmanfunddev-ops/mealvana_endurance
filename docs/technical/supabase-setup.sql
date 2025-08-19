-- Mealvana Endurance - Supabase Database Setup
-- This file creates all necessary tables and initial data for the content management system

-- =====================================================
-- 1. CREATE app_content TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS app_content (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version INTEGER NOT NULL DEFAULT 1,
    environment TEXT NOT NULL DEFAULT 'production',
    locale TEXT NOT NULL DEFAULT 'en',
    content JSONB NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    created_by UUID,
    updated_by UUID
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_app_content_active ON app_content(is_active);
CREATE INDEX IF NOT EXISTS idx_app_content_env_locale ON app_content(environment, locale);
CREATE INDEX IF NOT EXISTS idx_app_content_version ON app_content(version);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE TRIGGER update_app_content_updated_at 
    BEFORE UPDATE ON app_content 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 2. ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS
ALTER TABLE app_content ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can read content (public app content)
CREATE POLICY "Allow public read access to app_content" ON app_content
    FOR SELECT USING (true);

-- Policy: Only authenticated users can insert/update (for admin panel later)
CREATE POLICY "Allow authenticated insert to app_content" ON app_content
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated update to app_content" ON app_content
    FOR UPDATE USING (auth.role() = 'authenticated');

-- =====================================================
-- 3. INSERT INITIAL CONTENT DATA
-- =====================================================

-- Insert production content (version 1)
INSERT INTO app_content (version, environment, locale, content, is_active) VALUES (
    1,
    'production',
    'en',
    '{
      "main_screen": {
        "title": "Mealvana Endurance",
        "distance_label": "Distance",
        "pace_label": "Average pace",
        "pre_run_label": "Time before run",
        "gut_training_label": "Gut training level", 
        "generate_button": "Generate Plan",
        "tips_text": "We'\''ll create a personalized nutrition plan\\nbased on your run details"
      },
      "plan_screen": {
        "title": "Plan",
        "before_run": "Before Run",
        "during_run": "During Run", 
        "after_run": "After Run",
        "save_button": "Save",
        "saved_button": "Saved",
        "macro_targets": "Macro targets"
      },
      "user_profile": {
        "title": "Your Profile",
        "subtitle": "Tell us about yourself",
        "description": "This helps us calculate accurate nutrition plans for your runs.",
        "gender_label": "Gender",
        "birthday_label": "Birthday",
        "birthday_hint": "Select your birthday",
        "height_label": "Height",
        "weight_label": "Weight",
        "running_habits_label": "Running Habits",
        "water_bottle_label": "Do you run with a water bottle?",
        "water_bottle_subtitle": "This helps us estimate your hydration needs",
        "continue_button": "Continue"
      },
      "food_preferences": {
        "title": "Food Preferences"
      },
      "gender": {
        "male": "Male",
        "female": "Female", 
        "other": "Other"
      },
      "units": {
        "miles": "mi",
        "kilometers": "km",
        "min_per_mile": "min/mi",
        "min_per_km": "min/km",
        "feet": "ft",
        "inches": "in",
        "pounds": "lbs"
      },
      "gut_training": {
        "low": "Low",
        "moderate": "Moderate",
        "high": "High",
        "low_description": "New to fueling during runs - start conservative",
        "moderate_description": "Some experience with sports nutrition",
        "high_description": "Experienced endurance athlete with high carb tolerance"
      },
      "pre_run_timing": {
        "1_hour": "1 hour before",
        "2_hours": "2 hours before",
        "3_hours": "3 hours before"
      },
      "feedback": {
        "type_suggestions": "Type your suggestions"
      },
      "validation": {
        "required": "Required",
        "invalid_number": "Please enter a valid number",
        "distance_range": "Distance must be between 0 and 200",
        "pace_format": "Format: 8:30 or 8.5",
        "height_feet": "Enter valid feet (3-8)",
        "height_inches": "Enter valid inches (0-11)",
        "weight_range": "Enter valid weight (80-500 lbs)",
        "fill_all_fields": "Please fill in all fields"
      },
      "error": {
        "network": "Network error. Please check your connection.",
        "generic": "Something went wrong. Please try again.",
        "plan_generation": "Failed to generate plan",
        "feedback_submission": "Failed to submit feedback. Please try again."
      },
      "success": {
        "feedback_submitted": "✅ Thank you for your feedback!",
        "profile_saved": "Profile saved successfully!"
      },
      "algorithm": {
        "energy": {
          "net_calories_per_kg_per_km": 1.0,
          "acsm_vo2_constant_a": 0.2,
          "acsm_vo2_constant_b": 3.5,
          "met_divisor": 3.5,
          "mph_to_m_per_min": 26.8224
        },
        "pre_run": {
          "carbs": {
            "time_threshold_1h": 1.0,
            "time_threshold_15min": 0.25,
            "carbs_per_kg_per_hour": 1.0,
            "max_carbs_per_kg": 4.0,
            "medium_window_carbs_per_kg": 0.5,
            "small_topup_carbs_per_kg": 0.25
          },
          "protein": {
            "optional_protein_per_kg": 0.2
          },
          "fat": {
            "fat_cap_short_window_per_kg": 0.1,
            "fat_cap_long_window_per_kg": 0.2,
            "window_threshold_hours": 2.0
          },
          "hydration": {
            "long_window_ml_per_kg": 6,
            "medium_window_ml_per_kg": 4,
            "short_window_ml_per_kg": 2,
            "long_threshold_hours": 2.0,
            "medium_threshold_hours": 1.0
          },
          "sodium": {
            "long_window_mg": 500,
            "short_window_mg": 200,
            "threshold_hours": 2.0
          }
        },
        "during_run": {
          "carbs": {
            "gut_training_multipliers": {
              "low": 0.7,
              "moderate": 0.8,
              "high": 1.0
            },
            "absorption_limit_min_g_per_h": 30,
            "absorption_limit_max_g_per_h": 60,
            "mass_norm_range_min": 0.7,
            "mass_norm_range_max": 1.0
          },
          "hydration": {
            "base_rate_ml_per_h": 500,
            "short_duration_multiplier": 0.8,
            "short_duration_threshold_h": 1.0,
            "high_intensity_rate_ml_per_h": 800,
            "high_intensity_met_threshold": 8.0,
            "moderate_intensity_rate_ml_per_h": 600,
            "moderate_intensity_met_threshold": 6.0
          },
          "sodium": {
            "no_supplementation_threshold_h": 1.0,
            "standard_rate_mg_per_h": 250
          }
        },
        "conversions": {
          "lb_to_kg": 0.45359237,
          "in_to_cm": 2.54,
          "mi_to_km": 1.60934,
          "min_per_mile_to_min_per_km_multiplier": 1.60934
        },
        "safety": {
          "max_carbs_per_hour": 60,
          "max_fluid_ml_per_hour": 800,
          "max_sodium_mg_per_hour": 250
        }
      }
    }'::jsonb,
    true
);

-- Insert development content (version 1) - same as production initially
INSERT INTO app_content (version, environment, locale, content, is_active) VALUES (
    1,
    'development',
    'en',
    '{
      "main_screen": {
        "title": "Mealvana Endurance [DEV]",
        "distance_label": "Distance",
        "pace_label": "Average pace",
        "pre_run_label": "Time before run",
        "gut_training_label": "Gut training level", 
        "generate_button": "Generate Plan",
        "tips_text": "We'\''ll create a personalized nutrition plan\\nbased on your run details"
      },
      "plan_screen": {
        "title": "Plan",
        "before_run": "Before Run",
        "during_run": "During Run", 
        "after_run": "After Run",
        "save_button": "Save",
        "saved_button": "Saved",
        "macro_targets": "Macro targets"
      },
      "user_profile": {
        "title": "Your Profile",
        "subtitle": "Tell us about yourself",
        "description": "This helps us calculate accurate nutrition plans for your runs.",
        "gender_label": "Gender",
        "birthday_label": "Birthday",
        "birthday_hint": "Select your birthday",
        "height_label": "Height",
        "weight_label": "Weight",
        "running_habits_label": "Running Habits",
        "water_bottle_label": "Do you run with a water bottle?",
        "water_bottle_subtitle": "This helps us estimate your hydration needs",
        "continue_button": "Continue"
      },
      "food_preferences": {
        "title": "Food Preferences"
      },
      "gender": {
        "male": "Male",
        "female": "Female", 
        "other": "Other"
      },
      "units": {
        "miles": "mi",
        "kilometers": "km",
        "min_per_mile": "min/mi",
        "min_per_km": "min/km",
        "feet": "ft",
        "inches": "in",
        "pounds": "lbs"
      },
      "gut_training": {
        "low": "Low",
        "moderate": "Moderate",
        "high": "High",
        "low_description": "New to fueling during runs - start conservative",
        "moderate_description": "Some experience with sports nutrition",
        "high_description": "Experienced endurance athlete with high carb tolerance"
      },
      "pre_run_timing": {
        "1_hour": "1 hour before",
        "2_hours": "2 hours before",
        "3_hours": "3 hours before"
      },
      "feedback": {
        "type_suggestions": "Type your suggestions"
      },
      "validation": {
        "required": "Required",
        "invalid_number": "Please enter a valid number",
        "distance_range": "Distance must be between 0 and 200",
        "pace_format": "Format: 8:30 or 8.5",
        "height_feet": "Enter valid feet (3-8)",
        "height_inches": "Enter valid inches (0-11)",
        "weight_range": "Enter valid weight (80-500 lbs)",
        "fill_all_fields": "Please fill in all fields"
      },
      "error": {
        "network": "Network error. Please check your connection.",
        "generic": "Something went wrong. Please try again.",
        "plan_generation": "Failed to generate plan",
        "feedback_submission": "Failed to submit feedback. Please try again."
      },
      "success": {
        "feedback_submitted": "✅ Thank you for your feedback!",
        "profile_saved": "Profile saved successfully!"
      },
      "algorithm": {
        "energy": {
          "net_calories_per_kg_per_km": 1.0,
          "acsm_vo2_constant_a": 0.2,
          "acsm_vo2_constant_b": 3.5,
          "met_divisor": 3.5,
          "mph_to_m_per_min": 26.8224
        },
        "pre_run": {
          "carbs": {
            "time_threshold_1h": 1.0,
            "time_threshold_15min": 0.25,
            "carbs_per_kg_per_hour": 1.0,
            "max_carbs_per_kg": 4.0,
            "medium_window_carbs_per_kg": 0.5,
            "small_topup_carbs_per_kg": 0.25
          },
          "protein": {
            "optional_protein_per_kg": 0.2
          },
          "fat": {
            "fat_cap_short_window_per_kg": 0.1,
            "fat_cap_long_window_per_kg": 0.2,
            "window_threshold_hours": 2.0
          },
          "hydration": {
            "long_window_ml_per_kg": 6,
            "medium_window_ml_per_kg": 4,
            "short_window_ml_per_kg": 2,
            "long_threshold_hours": 2.0,
            "medium_threshold_hours": 1.0
          },
          "sodium": {
            "long_window_mg": 500,
            "short_window_mg": 200,
            "threshold_hours": 2.0
          }
        },
        "during_run": {
          "carbs": {
            "gut_training_multipliers": {
              "low": 0.7,
              "moderate": 0.8,
              "high": 1.0
            },
            "absorption_limit_min_g_per_h": 30,
            "absorption_limit_max_g_per_h": 60,
            "mass_norm_range_min": 0.7,
            "mass_norm_range_max": 1.0
          },
          "hydration": {
            "base_rate_ml_per_h": 500,
            "short_duration_multiplier": 0.8,
            "short_duration_threshold_h": 1.0,
            "high_intensity_rate_ml_per_h": 800,
            "high_intensity_met_threshold": 8.0,
            "moderate_intensity_rate_ml_per_h": 600,
            "moderate_intensity_met_threshold": 6.0
          },
          "sodium": {
            "no_supplementation_threshold_h": 1.0,
            "standard_rate_mg_per_h": 250
          }
        },
        "conversions": {
          "lb_to_kg": 0.45359237,
          "in_to_cm": 2.54,
          "mi_to_km": 1.60934,
          "min_per_mile_to_min_per_km_multiplier": 1.60934
        },
        "safety": {
          "max_carbs_per_hour": 60,
          "max_fluid_ml_per_hour": 800,
          "max_sodium_mg_per_hour": 250
        }
      }
    }'::jsonb,
    true
);

-- =====================================================
-- 4. CREATE HELPER VIEW
-- =====================================================

-- Create a view for easier content access
CREATE OR REPLACE VIEW current_content AS
SELECT 
    id,
    version,
    environment,
    locale,
    content,
    created_at,
    updated_at
FROM app_content 
WHERE is_active = true
ORDER BY environment, locale, version DESC;

-- =====================================================
-- 5. UTILITY FUNCTIONS
-- =====================================================

-- Function to get latest content for a specific environment
CREATE OR REPLACE FUNCTION get_latest_content(env TEXT DEFAULT 'production', loc TEXT DEFAULT 'en')
RETURNS TABLE(
    version INTEGER,
    content JSONB,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT ac.version, ac.content, ac.updated_at
    FROM app_content ac
    WHERE ac.environment = env 
      AND ac.locale = loc 
      AND ac.is_active = true
    ORDER BY ac.version DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function to create a new content version
CREATE OR REPLACE FUNCTION create_content_version(
    env TEXT DEFAULT 'production',
    loc TEXT DEFAULT 'en',
    new_content JSONB
) RETURNS INTEGER AS $$
DECLARE
    next_version INTEGER;
BEGIN
    -- Get next version number
    SELECT COALESCE(MAX(version), 0) + 1
    INTO next_version
    FROM app_content
    WHERE environment = env AND locale = loc;
    
    -- Deactivate current version
    UPDATE app_content
    SET is_active = false
    WHERE environment = env 
      AND locale = loc 
      AND is_active = true;
    
    -- Insert new version
    INSERT INTO app_content (version, environment, locale, content, is_active)
    VALUES (next_version, env, loc, new_content, true);
    
    RETURN next_version;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- SETUP COMPLETE
-- =====================================================

-- Verify setup
SELECT 
    'Setup complete! Content versions created:' as status,
    COUNT(*) as total_versions,
    STRING_AGG(DISTINCT environment, ', ') as environments
FROM app_content;