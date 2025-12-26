# Screen Mapping for Integration Tests

**Purpose:** Maps current UI screens to integration test expectations and identifies what needs updating.

**Last Updated:** 2025-12-18

---

## Onboarding Flow (NEW DESIGN)

Based on Figma screenshots (`figma_1.png` through `figma_7.png`):

### Screen 1: Dietary Preference
- **Screenshot:** `figma_1.png`
- **Header:** "What is your dietary preference?"
- **Elements:**
  - Progress bar (3 segments at top - 1st filled)
  - Radio buttons: Omnivore, Vegetarian, Pescatarian, Vegan, Mediterranean, Paleo, Keto, Low-Carb
  - Back button (left arrow)
  - "Continue" button (orange)
- **Test Actions Needed:**
  - Select dietary preference
  - Tap Continue
- **Current Test Status:** ❌ Not implemented

### Screen 2: Allergies
- **Screenshot:** `figma_2.png`
- **Header:** "Do you have any allergies?"
- **Elements:**
  - Progress bar (3 segments - 2nd filled)
  - Checkboxes: Dairy, Eggs, Fish, Gluten, Peanuts, Sesame, Shellfish, Soy, Tree nuts
  - Back button
  - "Continue" button (orange)
- **Test Actions Needed:**
  - Select allergies (optional)
  - Tap Continue
- **Current Test Status:** ❌ Not implemented

### Screen 3: Food Selection
- **Screenshot:** `figma_3.png`
- **Header:** "What foods fuel your training?"
- **Subtext:** "You can add more later in settings."
- **Elements:**
  - Progress bar (3 segments - 3rd filled)
  - Search bar
  - Selected food chips: "Gatorade", "hard-boiled eggs" (with X to remove)
  - Common foods section with chips:
    - berries, bagels, banana
    - coconut water, coffee, dates
    - electrolyte tablets, energy bar
    - energy chews, fig bars
    - fruit purée pouches, gels
    - orange juice, peanut butter
    - pickle juice shots, protein bars
    - protein drinks, trail mix, yogurt
  - Back button
  - "Continue" button (orange)
- **Test Actions Needed:**
  - Search for foods (optional)
  - Tap food chips to select
  - Remove selected foods by tapping X
  - Tap Continue
- **Current Test Status:** ❌ Not implemented

### Screen 4: Sports Selection
- **Screenshot:** `figma_4.png`
- **Header:** "Which sports do you train for?"
- **Subtext:** "We'll customize your nutrition plans for each sport."
- **Elements:**
  - Progress bar (1 segment filled)
  - Checkboxes: Running ✓, Cycling, Swimming
  - Back button
  - "Continue" button (orange)
- **Test Actions Needed:**
  - Select one or more sports
  - Tap Continue
- **Current Test Status:** ❌ Not implemented

### Screen 5: Running Details (Conditional)
- **Screenshot:** `figma_5.png`
- **Header:** "Running details"
- **Subtext:** "Help us estimate your hydration needs."
- **Elements:**
  - Progress bar (2 segments filled)
  - Toggle: "I run with a water bottle" (ON)
  - Back button
  - "Continue" button (orange)
- **Test Actions Needed:**
  - Toggle water bottle preference
  - Tap Continue
- **Current Test Status:** ❌ Not implemented
- **Condition:** Only shown if Running selected

### Screen 6: Cycling Details (Conditional)
- **Screenshot:** `figma_6.png`
- **Header:** "Cycling details"
- **Elements:**
  - Progress bar (2 segments filled)
  - FTP input field (watts) - "Maximum power you can sustain for ~1 hour. Enter 0 if unknown."
  - Water bottles selector: 1 / 2 / 3+ (2 selected)
  - Toggle: "I use Aero Bottles" (ON)
  - Toggle: "I use a Bento Box for food" (OFF)
  - Back button
  - "Continue" button (orange)
- **Test Actions Needed:**
  - Enter FTP (optional, can be 0)
  - Select water bottle count
  - Toggle aero bottles
  - Toggle bento box
  - Tap Continue
- **Current Test Status:** ❌ Not implemented
- **Condition:** Only shown if Cycling selected

### Screen 7: Swimming Details (Conditional)
- **Screenshot:** `figma_7.png`
- **Header:** "Swimming details"
- **Elements:**
  - Progress bar (2 segments filled)
  - CSS (Critical Swim Speed) input: "Fastest pace per 100 meters you can sustain for ~30 minutes. MM:SS format"
    - Minutes input
    - Seconds input
  - Toggle: "I typically wear a wetsuit" (ON)
  - Swim Cap Type radio buttons: None, Latex, Silicone, Neoprene ✓
  - Back button
  - "Continue" button (orange)
- **Test Actions Needed:**
  - Enter CSS time (optional)
  - Toggle wetsuit
  - Select swim cap type
  - Tap Continue
- **Current Test Status:** ❌ Not implemented
- **Condition:** Only shown if Swimming selected

---

## OLD Onboarding Flow (What Tests Currently Expect)

From `integration_test/README.md`:

1. **Welcome Screen** → "Get Started" / "Log In"
2. **Your Profile** → Gender, Birthday, Height, Weight
3. **Sport Preferences** → Running/Cycling/Swimming, Gut Sensitivity, "Continue"
4. **Food Preferences** → Sliders (Avoid ↔ Love), "Save Changes"
5. **Create Account** → Apple/Google/Email, "Continue without signing in"

**Status:** ⚠️ **COMPLETELY OUTDATED** - New flow is totally different

---

## Main App Screens (NEED SCREENSHOTS)

### Calendar Screen
- **Current Test Expectations:**
  - BY WEEK / BY MONTH toggle
  - "CREATE AN EVENT" button
  - FAB (Floating Action Button)
- **Screenshot Needed:** ❓ Main calendar view
- **Test Status:** ⚠️ Unknown if UI changed

### New Event Screen
- **Current Test Expectations:**
  - Sport Category selector
  - Race Distance selector
  - Event Name field
  - Location field
  - Date picker
- **Screenshot Needed:** ❓ Event creation form
- **Test Status:** ⚠️ Unknown if UI changed

### Event Details Screen
- **Current Test Expectations:**
  - "Create Nutrition Plan" button
  - "Create Carb Loading Plan" button
- **Screenshot Needed:** ❓ Event detail view
- **Test Status:** ⚠️ Unknown if UI changed

### Create Activity Plan Screen
- **Current Test Expectations:**
  - Distance input
  - Pace input
  - Gut Training level selector
  - "Generate Plan" button
- **Screenshot Needed:** ❓ Activity plan creation
- **Test Status:** ⚠️ Unknown if UI changed

### Adjust Macros Screen
- **Current Test Expectations:**
  - PRE/DURING/POST table with carb/protein/fat values
  - "Create Plan" button
- **Screenshot Needed:** ❓ Macro adjustment interface
- **Test Status:** ⚠️ Unknown if UI changed

### Nutrition Plan Screen
- **Current Test Expectations:**
  - "BEFORE RUN" section
  - Food items list with swipe actions
  - "+ ADD FOOD" button
- **Screenshot Needed:** ❓ Nutrition plan view
- **Test Status:** ⚠️ Unknown if UI changed

### Settings Screen
- **Current Test Expectations:**
  - Profile & Preferences
  - Appearance settings
  - Food Preferences link
- **Screenshot Needed:** ❓ Settings menu
- **Test Status:** ⚠️ Unknown if UI changed

---

## Integration Test Update Requirements

### Critical Updates Needed

1. **Onboarding Flow Tests** (`flows/onboarding_auth_flow_test.dart`)
   - ❌ Complete rewrite required
   - New screens: Dietary preference, Allergies, Food selection chips
   - New conditional screens: Sport-specific details (Running/Cycling/Swimming)
   - Different navigation flow

2. **Screen Element Selectors**
   - ❌ All button text, widget keys need verification
   - Orange "Continue" button used throughout
   - Progress bars instead of step indicators
   - Chip-based selection vs sliders

3. **Test Data**
   - ✅ Can reuse sport selection data
   - ❌ Need dietary preference test data
   - ❌ Need allergy test data
   - ❌ Need food chip selection data
   - ❌ Need sport-specific details (FTP, CSS, water bottles, etc.)

### Potentially Unchanged (Need Verification)

- Email login flow (probably same)
- Calendar/Event management (need screenshots)
- Nutrition plan generation (need screenshots)
- Settings screens (need screenshots)

---

## Next Steps

1. ✅ **Onboarding Screens Documented** - Have Figma designs
2. ❓ **Main App Screens** - Need screenshots or confirmation they're unchanged
3. ❓ **Bug Documentation** - Fill in `BUG_REGRESSION_TRACKING.md`
4. ⏳ **Test Account Setup** - Define exact data needed
5. ⏳ **Rewrite Tests** - Update for new UI
6. ⏳ **Add Bug Tests** - Fail-fast assertions
7. ⏳ **Codemagic Integration** - Update CI/CD workflow

---

## Questions for User

1. **Did the main app screens (Calendar, Events, Nutrition Plans, Settings) also change?**
   - If yes, need screenshots
   - If no, can keep existing test code for those flows

2. **Do you want me to take screenshots of the main app for you by running it?**
   - No - I cannot run the app
   - Yes - You'll need to provide them

3. **Is the Welcome/Profile screen gone completely?**
   - It appears dietary preference is now the first screen
   - Tests expect a Welcome screen with "Get Started"

4. **What should the complete onboarding flow be?**
   - Dietary Preference → Allergies → Food Selection → Sports → [Sport Details] → Auth Screen?
   - Or is there a Welcome/Profile screen before these?
