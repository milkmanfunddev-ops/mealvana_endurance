# 02 Onboarding

Screens covered: 7-step anonymous onboarding from Welcome → Calendar.

Onboarding step count: 4 progress segments visible at top (the form, sports, diet, allergies+foods are folded — exact mapping shown below).

---

## connect_training (step 1)
**Screenshot:** `screenshots/01_connect_training.png` and `screenshots/02_connect_training_scrolled.png`
**Reached by:** Tap **Get Started** on welcome.

### Visible elements
| Role        | Label / Text       | mobile-mcp coords   | Proposed ValueKey                          |
|-------------|--------------------|---------------------|--------------------------------------------|
| Heading     | "Connect Your Training" | (20, 78, 250x26) | `connect_training.title`                   |
| Body        | "Import your upcoming workouts…" | (20, 122, 390x32) | `connect_training.description` |
| Card        | FinalSurge "Connect"  | (16, 207, 398x67)   | `connect_training.finalsurge_connect_button` |
| Card        | TrainingPeaks "Connect" | (16, 290, 398x70)  | `connect_training.trainingpeaks_connect_button` |
| Card        | Garmin "Connect"   | (16, 376, 398x72)   | `connect_training.garmin_connect_button`   |
| Card        | TriDot "Notify Me" | (285, 480, 112x44)  | `connect_training.tridot_notify_button`    |
| Card        | Runna "Notify Me"  | (285, 598, 112x44)  | `connect_training.runna_notify_button`     |
| Card        | VDOT "Notify Me"   | scroll              | `connect_training.vdot_notify_button`      |
| Card        | Strava "Notify Me" | scroll              | `connect_training.strava_notify_button`    |
| Link        | "Skip for now"     | (163, 745, 102x48)  | `connect_training.skip_button`             |
| Button (primary) | "Continue"    | (20, 825, 390x48)   | `connect_training.continue_button`         |

### Notes
- TriDot/Runna/VDOT/Strava show "Coming soon".

---

## profile_form (step 2)
**Screenshot:** `screenshots/03_profile_form.png` (empty), `screenshots/06_profile_form_filled.png` (filled with Audit/User, 5'10", 170 lbs).
**Reached by:** Tap **Continue** on Connect Your Training (or **Skip for now**).

### Visible elements
| Role           | Label / Text                  | mobile-mcp coords    | Proposed ValueKey                  |
|----------------|-------------------------------|----------------------|------------------------------------|
| Heading        | "Tell us about yourself"      | (20, 92, 242x26)     | `profile.title`                    |
| Field          | First name                    | (36, 236, 171x53)    | `profile.first_name_field`         |
| Field          | Last name                     | (223, 236, 171x53)   | `profile.last_name_field`          |
| Field (email)  | Email address                 | (36, 305, 358x53)    | `profile.email_field`              |
| Selector       | MALE                          | (36, 407, 111x80)    | `profile.gender_male_button`       |
| Selector       | FEMALE                        | (159, 407, 111x80)   | `profile.gender_female_button`     |
| Selector       | NON-BINARY                    | (282, 407, 111x80)   | `profile.gender_non_binary_button` |
| Selector       | Birth Year                    | (36, 536, 358x55)    | `profile.birth_year_button`        |
| Field (number) | Height ft                     | (36, 714, 171x53)    | `profile.height_ft_field`          |
| Field (number) | Height in                     | (223, 714, 171x53)   | `profile.height_in_field`          |
| Field (number) | Enter your weight             | (36, 783, 358x53)    | `profile.weight_field`             |
| Toggle         | IMPERIAL (selected)           | (44, 843, 171x42)    | `profile.units_imperial_button`    |
| Toggle         | METRIC                        | (215, 843, 171x42)   | `profile.units_metric_button`      |
| Button (back)  | (back arrow circle)           | (20, 859, 48x48)     | `profile.back_button`              |
| Button (primary)| "Continue"                   | (80, 859, 330x48)    | `profile.continue_button`          |

### Variant: birth year picker
**Screenshot:** `screenshots/05_birth_year_picker_open.png`
- Modal at bottom shows wheel picker of years (default 1990).
- Cancel button at (16, 652, 67x48) → `profile.birth_year_cancel_button`
- Done button at (350, 652, 64x48) → `profile.birth_year_done_button`

### Notes
- Default selected gender is MALE (no explicit "unselected" state shown).
- Weight unit label changes between "lbs" (IMPERIAL) and "kg" (METRIC).
- "Required" validation labels appear under fields after focus is moved without entry; this becomes the assertion target ("no Required visible when form fully valid").
- **Throwaway email used for audit run:** `audit_1778613869@example.com`.

---

## sport_selection (step 2b)
**Screenshot:** `screenshots/07_sport_selection.png` (Running default selected), `screenshots/07b_sport_selection_all.png` (all three selected variant).
**Reached by:** Continue from profile form.

### Visible elements
| Role           | Label / Text  | mobile-mcp coords        | Proposed ValueKey                |
|----------------|---------------|--------------------------|----------------------------------|
| Heading        | "Which sports do you train for?" | (20, 76, 390x26)| `sport_selection.title`          |
| Card (toggle)  | Running       | (20, 158, 390x60)        | `sport_selection.running_chip`   |
| Card (toggle)  | Cycling       | (20, 230, 390x58)        | `sport_selection.cycling_chip`   |
| Card (toggle)  | Swimming      | (20, 300, 390x58)        | `sport_selection.swimming_chip`  |
| Button (back)  | (back arrow)  | (20, 859, 48x48)         | `sport_selection.back_button`    |
| Button (primary)| "Continue"   | (80, 859, 330x48)        | `sport_selection.continue_button`|

### Notes
- Running is pre-selected by default. **Multiple sports can be selected** (checkbox style, not radio).
- After this step, the next screen is dietary preference — **no sport-specific detail screens are interjected during onboarding** (those exist only under Settings > Sport Preferences).

---

## dietary_preference (step 3)
**Screenshot:** `screenshots/08_dietary_preference.png`, `screenshots/09_dietary_omnivore_selected.png` (Omnivore selected variant)
**Reached by:** Continue from sport selection.

### Visible elements
| Role           | Label / Text     | mobile-mcp coords       | Proposed ValueKey                       |
|----------------|------------------|-------------------------|-----------------------------------------|
| Heading        | "What is your dietary preference?" | (20, 178, 375x26) | `dietary_preference.title`     |
| Radio (card)   | Omnivore         | (20, 232, 390x58)       | `dietary_preference.omnivore_chip`      |
| Radio (card)   | Vegetarian       | (20, 302, 390x58)       | `dietary_preference.vegetarian_chip`    |
| Radio (card)   | Pescatarian      | (20, 372, 390x58)       | `dietary_preference.pescatarian_chip`   |
| Radio (card)   | Vegan            | (20, 442, 390x58)       | `dietary_preference.vegan_chip`         |
| Radio (card)   | Mediterranean    | (20, 512, 390x58)       | `dietary_preference.mediterranean_chip` |
| Radio (card)   | Paleo            | (20, 582, 390x58)       | `dietary_preference.paleo_chip`         |
| Radio (card)   | Keto             | (20, 652, 390x58)       | `dietary_preference.keto_chip`          |
| Radio (card)   | Low-Carb         | (20, 722, 390x58)       | `dietary_preference.low_carb_chip`      |
| Button (back)  | (back arrow)     | (20, 859, 48x48)        | `dietary_preference.back_button`        |
| Button (primary)| "Continue"      | (80, 859, 330x48)       | `dietary_preference.continue_button`    |

### Notes
- Single-select (radio behavior).

---

## allergies (step 4)
**Screenshot:** `screenshots/10_allergies.png`
**Reached by:** Continue from dietary preference.

### Visible elements
| Role           | Label / Text  | mobile-mcp coords  | Proposed ValueKey                  |
|----------------|---------------|--------------------|------------------------------------|
| Heading        | "Do you have any allergies?" | (20, 94, 302x26) | `allergies.title`         |
| Checkbox       | No allergies  | (20, 142, 390x58)  | `allergies.none_chip`              |
| Checkbox       | Dairy         | (20, 212, 390x58)  | `allergies.dairy_chip`             |
| Checkbox       | Eggs          | (20, 282, 390x58)  | `allergies.eggs_chip`              |
| Checkbox       | Fish          | (20, 352, 390x58)  | `allergies.fish_chip`              |
| Checkbox       | Gluten        | (20, 422, 390x58)  | `allergies.gluten_chip`            |
| Checkbox       | Peanuts       | (20, 492, 390x58)  | `allergies.peanuts_chip`           |
| Checkbox       | Sesame        | (20, 562, 390x58)  | `allergies.sesame_chip`            |
| Checkbox       | Shellfish     | (20, 632, 390x58)  | `allergies.shellfish_chip`         |
| Checkbox       | Soy           | (20, 702, 390x58)  | `allergies.soy_chip`               |
| Checkbox       | Tree nuts     | (20, 772, 390x58)  | `allergies.tree_nuts_chip`         |
| Button (back)  | (back arrow)  | (20, 859, 48x48)   | `allergies.back_button`            |
| Button (primary)| "Continue"   | (80, 859, 330x48)  | `allergies.continue_button`        |

### Notes
- Multi-select. Selecting "No allergies" presumably clears the others (not exhaustively tested).

---

## food_selection (step 5)
**Screenshot:** `screenshots/11_food_selection.png`, `screenshots/12_food_selection_chosen.png` (3 selected), `screenshots/11b_food_search_no_results.png` (searched "apple", no results).
**Reached by:** Continue from allergies.

### Visible elements
| Role             | Label / Text                  | mobile-mcp coords  | Proposed ValueKey                  |
|------------------|-------------------------------|--------------------|------------------------------------|
| Heading          | "What foods fuel your training?" | (20, 86, 348x26) | `food_selection.title`          |
| Field (search)   | "Search"                      | (21, 165, 388x48)  | `food_selection.search_field`      |
| Section heading  | "Common foods"                | (20, 234, 159x24)  | `food_selection.common_section`    |
| Chip             | Each food (e.g. "Banana")     | varies             | `food_selection.chip_<slug>` (e.g. `food_selection.chip_banana`) |
| Button (back)    | (back arrow)                  | (20, 859, 48x48)   | `food_selection.back_button`       |
| Button (primary) | "Continue"                    | (80, 859, 330x48)  | `food_selection.continue_button`   |

### Notes
- Common foods (visible): Bagel (large), Banana, Blueberries, Carb Drink Mix, Cereal (low-fiber type), Chocolate Milk, Coconut Water, Electrolyte Capsule, Electrolyte Packet, Energy Chews, Energy Chews (mini pack), Energy Gel, Granola, Granola Bar, High-Carb Drink Mix, High-Sodium Electrolyte Mix, Milk (whole), Oatmeal (½ cup dry).
- Search for "apple" shows **"No foods available"** — the common-food list does NOT include fresh-fruit apple. Likely intentional (endurance fueling focus) but worth flagging.
- Multi-select chips. Selected chips visually highlighted (green-tinted background).

---

## create_account (step 6 / final)
**Screenshot:** `screenshots/13_create_account.png`
**Reached by:** Continue from food selection. This is the **last** onboarding step before app entry.

### Visible elements
| Role             | Label / Text                  | mobile-mcp coords  | Proposed ValueKey                       |
|------------------|-------------------------------|--------------------|-----------------------------------------|
| Heading          | "Create Your Account"         | (16, 139, 398x36)  | `create_account.title`                  |
| Body             | "Secure your data and sync…"  | (16, 187, 398x21)  | `create_account.subtitle`               |
| Body             | "Save your nutrition plans…"  | (16, 240, 398x48)  | `create_account.description`            |
| Card             | "Account Benefits" + 4 bullets| (16, 320, 398x230) | `create_account.benefits_card`          |
| Button           | "Continue with Apple"         | (16, 618, 398x56)  | `create_account.apple_button`           |
| Button           | "Continue with Google"        | (16, 690, 398x56)  | `create_account.google_button`          |
| Button (primary) | "Sign up with Email"          | (16, 762, 398x56)  | `create_account.email_button`           |
| Link             | "Continue without signing in" | (16, 850, 398x48)  | `create_account.skip_button`            |

### Notes
- The **back arrow at top-left** (not in WDA element list, at ~(38, 95)) returns to food selection. → `create_account.back_button`.
- "Continue without signing in" produces the anonymous-onboarded state and lands at Calendar.
