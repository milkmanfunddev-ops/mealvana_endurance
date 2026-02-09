Design mobile UI components and an empty state for a nutrition tracking app for endurance athletes.

App style: Clean, modern fitness app. Orange (CTAs), cream (backgrounds), teal (success). Rounded elements, sans-serif typography.

---

COMPONENT 1: EMPTY DAY STATE
Centered vertically in the timeline area (between calendar and input bar):
- Illustration: Simple line-art plate with fork and knife, muted gray/cream tones, ~120px
- "No meals logged today" in 17px medium, dark text, centered
- "Type what you ate below or tap the camera to snap a photo" in 14px muted gray, centered, max 2 lines
- Small downward arrow icon (animated bounce) pointing toward the AI input bar below
- Cream background

---

COMPONENT 2: MEAL CARD (for timeline)
White card, full width (16px horizontal margins), 12px border radius, subtle shadow:
- Left edge: 3px vertical accent bar (warm amber/orange)
- Top row: fork-knife icon (16px, muted) + "Lunch" in 15px semibold + spacer + "12:30 PM" in 13px muted + "580 cal" small pill badge (orange bg, white text, rounded, 11px)
- Middle: 2 lines of food items in 14px regular:
  "Grilled chicken breast (6 oz)"
  "Brown rice (1 cup), Steamed broccoli"
- If more than 3 items: "+2 more" in 13px muted orange
- If photo attached: 28px circular photo thumbnail in top-right corner of card
- Bottom row: "C: 45g | P: 52g | F: 8g" in 11px muted gray
- Card padding: 12px vertical, 14px horizontal (right of accent bar)
- Tap: navigates to meal detail. Swipe left: reveals red delete button.

---

COMPONENT 3: QUANTITY STEPPER
Inline horizontal control:
- [ - ] button: 28px circle, light gray background, minus icon, dark gray
- Value: "1.5" in 15px semibold, centered in 40px width
- [ + ] button: 28px circle, light gray background, plus icon, dark gray
- Below value: "servings" in 10px muted gray text
- Total width: ~120px. Height: ~40px including label.
- Tapping the value number opens a small number input popover.

---

COMPONENT 4: DAILY MACRO DASHBOARD
Horizontal card, full width (16px margins), white bg, subtle border, 12px radius:
- Height: ~56px
- 6 values equally spaced in a row:
  Each value: number in 15px semibold on top, label in 9px muted gray caps below
  "2,040" / CAL | "245g" / CARBS | "125g" / PROTEIN | "62g" / FAT | "1.8g" / SODIUM | "2.4L" / HYDRATION
- Thin vertical divider lines between each value (1px, light gray)
- 12px vertical padding

---

COMPONENT 5: AI TEXT INPUT BAR
Docked at bottom of screen, above tab bar:
- White background, top shadow (0px -2px 8px rgba(0,0,0,0.06))
- Height: 56px + safe area bottom padding
- Contains: Rounded pill text field (40px height, light gray 1px border, cream fill)
  - Left: 12px padding
  - Placeholder: "What did you eat?" in 14px muted gray
  - Right inside field: camera icon button (32px circular, muted gray icon)
- When text entered: send arrow button appears (circular, 32px, orange fill, white arrow icon) replacing camera or to its left
- 8px padding all around the text field within the bar
