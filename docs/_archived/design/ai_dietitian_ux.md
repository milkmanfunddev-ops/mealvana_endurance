# AI Dietitian - User Experience Specification

## The "Coach" Concept
The AI Dietitian acts as a proactive, context-aware endurance nutrition coach. It doesn't just ask "what do you want to eat?"; it knows your training schedule, your body composition, the weather forecast for your race, and what's in your pantry.

## Core Experience Flow

### 1. Entry & Context
**Screen:** `AiDietitianScreen`
*   **State:** The user enters the screen.
*   **Auto-Detection:** The "Coach" immediately analyzes the context.
    *   *Scenario:* "I see you have a 15-mile long run this Saturday, and it's going to be 85°F."
*   **Default View:** A pre-generated "Draft Plan" for the most relevant upcoming event (e.g., Saturday's Long Run) is already visible or loading.
*   **Selector:** A dropdown at the top allows the user to switch focus:
    *   "Long Run (Sat, Dec 12)"
    *   "Race Day (Mar 4)"
    *   "Daily Nutrition (Today)"

### 2. The Timeline View (The "Plan")
**Visual:** A vertical, time-based list (like a calendar day view).
*   **Structure:**
    *   **06:00 AM - Breakfast:** [Oatmeal with Berries] (45g Carbs)
    *   **07:30 AM - Pre-Run Fuel:** [Gel] (25g Carbs)
    *   **08:00 AM - START RUN** (Target: 15 miles)
    *   **08:45 AM - Mile 4:** [Gel] (25g Carbs)
    *   **09:30 AM - Mile 8:** [Chews] (20g Carbs) + [Electrolytes]
    *   **10:30 AM - Finish:** [Recovery Shake] (20g Protein)
*   **Micro-Interactions:**
    *   **Tap Item:** Opens a "Swap" sheet. User can tap "Oatmeal" and choose "Bagel" from their Favorites. The macros update instantly.

### 3. Hybrid Refinement (Chat + Edit)
**Location:** Bottom Floating Bar
*   **Action:** The user wants to change the *strategy*, not just a single food.
*   **Input:** Text field "Ask the Coach..."
*   **User Types:** "It's going to be hotter than expected, increase the fluids."
*   **System Action:**
    1.  Shows "Refining plan..." animation.
    2.  Regenerates the plan.
    3.  **Result:** The Timeline updates. The "Electrolytes" entry frequency increases, and fluid targets go up. A small "Coach Note" appears: *"Updated fluid targets to 24oz/hr due to heat."*

### 4. Review & Save
**Action:** "Save Plan" button (Bottom Right)
*   **Modal:** `ReviewModal` pops up.
*   **Summary:**
    *   "Total Carbs: 320g"
    *   "Sodium: 2500mg"
*   **Scheduling:** "Save this for [Saturday, Dec 12]?" (Date picker defaults to the relevant event date).
*   **Confirmation:** Tapping "Confirm" saves the plan to the database and links it to the calendar activity.
*   **Feedback:** Toast message: "Plan saved to your calendar!"

## Key UX Principles
1.  **Zero-Shot First:** Don't ask 20 questions. Provide a good default based on the data we already have.
2.  **Visual > Text:** Show a Timeline, not a wall of text.
3.  **Hybrid Control:** Allow broad strokes via Chat ("Make it vegan") and fine details via Touch (Tap to swap specific item).

