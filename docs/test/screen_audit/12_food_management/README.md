# 12 Food Management

Food preferences, allergies, dietary preference, food likes/dislikes, custom food creation.

---

## food_preferences (root)
**Screenshot:** `screenshots/01_food_preferences.png`
**Reached by:** Settings → tap **Food Preferences**.

### Visible elements
| Role             | Label / Text                       | mobile-mcp coords  | Proposed ValueKey                       |
|------------------|------------------------------------|--------------------|-----------------------------------------|
| Button (back)    | Arrow circle                       | (4, 63)            | `food_prefs.back_button`                |
| Heading          | "Food Preferences"                 | center             | `food_prefs.title`                      |
| Row              | "Dietary Preference / Omnivore"    | (16, 250, 398x110) | `food_prefs.dietary_row`                |
| Row              | "Allergies / No allergies"         | (16, 380, 398x110) | `food_prefs.allergies_row`              |
| Row              | "Food Likes & Dislikes / Manage your food preferences" | (16, 510, 398x110) | `food_prefs.likes_dislikes_row` |

---

## dietary_preference_edit
**Screenshot:** `screenshots/07_dietary_edit.png`
Identical scaffold to onboarding dietary preference (see `02_onboarding/README.md`). Keys:

| Role          | Proposed ValueKey                        |
|---------------|------------------------------------------|
| Heading       | `dietary_edit.title`                     |
| Each radio    | `dietary_edit.<diet>_chip` (e.g. `dietary_edit.omnivore_chip`) |
| Button (back) | `dietary_edit.back_button`               |
| Button (primary) | `dietary_edit.save_button`            |

---

## allergies_edit
**Screenshot:** `screenshots/06_allergies_edit.png`
Identical scaffold to onboarding allergies screen (see `02_onboarding/README.md`). Keys:

| Role          | Proposed ValueKey                        |
|---------------|------------------------------------------|
| Heading       | `allergies_edit.title`                   |
| Each checkbox | `allergies_edit.<allergen>_chip`         |
| Button (back) | `allergies_edit.back_button`             |
| Button (primary) | `allergies_edit.save_button`          |

---

## food_likes_dislikes
**Screenshot:** `screenshots/02_food_likes.png`
**Reached by:** Food Preferences → **Food Likes & Dislikes**.

### Visible elements
| Role             | Label / Text                       | mobile-mcp coords  | Proposed ValueKey                       |
|------------------|------------------------------------|--------------------|-----------------------------------------|
| Button (back)    | Arrow circle                       | (4, 63)            | `food_likes.back_button`                |
| Heading          | "Food Preferences"                 | center             | `food_likes.title`                      |
| Field (search)   | "Search foods..."                  | (32, 215, 366x66)  | `food_likes.search_field`               |
| Button (icon)    | Barcode scanner (right of search)  | (370, 215, 36x36)  | `food_likes.barcode_button`             |
| Link             | "+ Create Custom Food"             | (32, 300, 366x40)  | `food_likes.create_custom_button`       |
| Row              | Food name + slider                 | per food           | `food_likes.row_<slug>`                 |
| Slider           | 5-step Avoid <-> Like              | per food           | `food_likes.slider_<slug>`              |
| Button (primary) | "Save Changes"                     | bottom             | `food_likes.save_button`                |

### Notes
- Slider has 5 positions (default middle / neutral). Labels "X Avoid" left, "Like ♥" right.
- Visible foods: BAGEL (LARGE), BANANA, BLUEBERRIES, CARB DRINK MIX (more on scroll).

---

## barcode_scanner
**Screenshot:** `screenshots/03_barcode_scanner.png`, `screenshots/04_camera_denied.png`
**Reached by:** Food Likes & Dislikes → tap barcode icon.

### Visible elements
| Role             | Label / Text                       | mobile-mcp coords  | Proposed ValueKey                       |
|------------------|------------------------------------|--------------------|-----------------------------------------|
| Button (back)    | Arrow (top-left)                   | top-left           | `barcode.back_button`                   |
| Heading          | "Scan to Add Food"                 | top                | `barcode.title`                         |
| Button (icon)    | Flash / lightning (top-right)      | (382, 63, 48x48)   | `barcode.flash_button`                  |
| Body             | "Position the barcode within the scanning area" | (36, 136, 358x21) | `barcode.instructions` |
| Camera frame     | Bracket-bordered region            | center             | `barcode.camera_frame`                  |
| Empty state      | "Camera permission denied." (when denied) | center      | `barcode.permission_denied_label`       |
| Button (icon)    | Reset (rotating arrow)             | (105, 790, 55x56)  | `barcode.reset_button`                  |
| Button (icon)    | Switch (camera flip)               | (268, 790, 56x56)  | `barcode.switch_button`                 |

### Notes
- When permission not yet granted: iOS native dialog shown ("'Endurance Dev' Would Like to Access the Camera" with Don't Allow / Allow). Proposed key for the in-app permission denied label: `barcode.permission_denied_label`.

---

## create_custom_food
**Screenshot:** `screenshots/05_create_custom_food.png`
**Reached by:** Food Likes & Dislikes → **"+ Create Custom Food"**.

### Visible elements
| Role             | Label / Text                       | Proposed ValueKey                       |
|------------------|------------------------------------|-----------------------------------------|
| Button (back)    | Arrow circle                       | `custom_food.back_button`               |
| Heading          | "Create Custom Food"               | `custom_food.title`                     |
| Section heading  | "FOOD NAME"                        | `custom_food.name_section`              |
| Field            | "Enter food name"                  | `custom_food.name_field`                |
| Section heading  | "SERVING SIZE"                     | `custom_food.serving_section`           |
| Field (number)   | Amount (default 1)                 | `custom_food.amount_field`              |
| Field            | Unit (default "serving")           | `custom_food.unit_field`                |
| Section heading  | "NUTRITION INFORMATION"            | `custom_food.nutrition_section`         |
| Field (number)   | Calories                           | `custom_food.calories_field`            |
| Field (number)   | Carbs                              | `custom_food.carbs_field`               |
| Field (number)   | Protein                            | `custom_food.protein_field`             |
| Field (number)   | Fat                                | `custom_food.fat_field`                 |
| Field (number)   | Sodium                             | `custom_food.sodium_field`              |
| Section heading  | "WHEN WOULD YOU EAT THIS?"         | `custom_food.timing_section`            |
| Body             | "Select one or more categories (at least one required)" | `custom_food.timing_body` |
| Checkbox (default selected) | "BEFORE RUN / Fuel up before your workout" | `custom_food.timing_before_run` |
| Checkbox (presumed) | "DURING RUN"                    | `custom_food.timing_during_run`         |
| Checkbox (presumed) | "AFTER RUN"                     | `custom_food.timing_after_run`          |
| (presumed)       | similar for bike/swim              | `custom_food.timing_<sport>_<phase>`    |
| Button (primary) | "Create Food"                      | `custom_food.create_button`             |

### Notes
- The list of timing checkboxes extends below the fold (only "BEFORE RUN" was visible). All endurance + general-meal categories should be present.
