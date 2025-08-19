-- Update app_content table to remove algorithm parameters
-- Run this in your Supabase SQL Editor

UPDATE app_content 
SET content = '{
  "error": {
    "generic": "Something went wrong. Please try again.",
    "network": "Network error. Please check your connection.",
    "plan_generation": "Failed to generate plan",
    "feedback_submission": "Failed to submit feedback. Please try again."
  },
  "units": {
    "feet": "ft",
    "miles": "mi",
    "inches": "in",
    "pounds": "lbs",
    "kilometers": "km",
    "min_per_km": "min/km",
    "min_per_mile": "min/mi"
  },
  "gender": {
    "male": "Male",
    "other": "Other",
    "female": "Female"
  },
  "success": {
    "profile_saved": "Profile saved successfully!",
    "feedback_submitted": "✅ Thank you for your feedback!"
  },
  "feedback": {
    "type_suggestions": "Type your suggestions"
  },
  "validation": {
    "required": "Required",
    "height_feet": "Enter valid feet (3-8)",
    "pace_format": "Format: 8:30 or 8.5",
    "weight_range": "Enter valid weight (80-500 lbs)",
    "height_inches": "Enter valid inches (0-11)",
    "distance_range": "Distance must be between 0 and 200",
    "invalid_number": "Please enter a valid number",
    "fill_all_fields": "Please fill in all fields"
  },
  "main_screen": {
    "title": "Mealvana Endurance",
    "tips_text": "We''ll create a personalized nutrition plan\\nbased on your run details",
    "pace_label": "Average pace",
    "pre_run_label": "Time before run",
    "distance_label": "Distance",
    "generate_button": "Generate Plan",
    "gut_training_label": "Gut training level"
  },
  "plan_screen": {
    "title": "Plan",
    "after_run": "After Run",
    "before_run": "Before Run",
    "during_run": "During Run",
    "save_button": "Save",
    "saved_button": "Saved",
    "macro_targets": "Macro targets"
  },
  "gut_training": {
    "low": "Low",
    "high": "High",
    "moderate": "Moderate",
    "low_description": "New to fueling during runs - start conservative",
    "high_description": "Experienced endurance athlete with high carb tolerance",
    "moderate_description": "Some experience with sports nutrition"
  },
  "user_profile": {
    "title": "Your Profile",
    "subtitle": "Tell us about yourself",
    "description": "This helps us calculate accurate nutrition plans for your runs.",
    "gender_label": "Gender",
    "height_label": "Height",
    "weight_label": "Weight",
    "birthday_hint": "Select your birthday",
    "birthday_label": "Birthday",
    "continue_button": "Continue",
    "water_bottle_label": "Do you run with a water bottle?",
    "running_habits_label": "Running Habits",
    "water_bottle_subtitle": "This helps us estimate your hydration needs"
  },
  "pre_run_timing": {
    "1_hour": "1 hour before",
    "2_hours": "2 hours before",
    "3_hours": "3 hours before"
  },
  "food_preferences": {
    "title": "Food Preferences"
  }
}'::jsonb,
updated_at = NOW()
WHERE environment = 'production' 
  AND locale = 'en' 
  AND is_active = true;

-- Verify the update
SELECT id, environment, locale, is_active, version, updated_at
FROM app_content 
WHERE environment = 'production' AND locale = 'en' AND is_active = true;