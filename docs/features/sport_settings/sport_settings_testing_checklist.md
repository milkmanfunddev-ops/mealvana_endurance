# Sport Settings - Manual Testing Checklist

**Date**: December 18, 2025
**Screen**: Sport Settings (`/settings/sport-settings`)

---

## Pre-Testing Setup

- [ ] Build and run the app: `flutter run`
- [ ] Navigate to Settings menu
- [ ] Tap "Sport Settings"

---

## Section 1: Navigation

### From Settings Menu
- [ ] "Sport Settings" tile is visible
- [ ] Description reads "Cycling, swimming, GI sensitivity"
- [ ] Tap opens Sport Settings screen
- [ ] Screen title shows "Sport Settings"

### Back Navigation
- [ ] Back button (←) is visible in AppBar
- [ ] Tap back button returns to Settings menu
- [ ] Previous state is preserved

---

## Section 2: GI Sensitivity

### Toggle Behavior
- [ ] Toggle switch is visible
- [ ] Label reads "GI Sensitivity"
- [ ] Description reads "Do you have a sensitive stomach during exercise?"
- [ ] Toggle OFF → ON works
- [ ] Toggle ON → OFF works
- [ ] Visual state change is immediate

### State Persistence
- [ ] Toggle to ON, save, restart app → Still ON
- [ ] Toggle to OFF, save, restart app → Still OFF

---

## Section 3: Cycling Settings

### Section Header
- [ ] "Cycling" section header is visible
- [ ] Bold, larger font than field labels
- [ ] Clear visual separation from other sections

### FTP Watts Input
- [ ] Label reads "FTP (Functional Threshold Power)"
- [ ] Description explains "Maximum power you can sustain for ~1 hour..."
- [ ] Input field shows placeholder "e.g., 250"
- [ ] Suffix shows "watts"
- [ ] Keyboard shows number pad
- [ ] Can enter positive numbers (0+)
- [ ] Cannot enter negative numbers
- [ ] Cannot enter letters

**Test Values**:
- [ ] Enter 0 → Accepts
- [ ] Enter 250 → Accepts
- [ ] Enter -50 → Rejects or converts to 50
- [ ] Enter "abc" → No change

### Water Bottles Selector
- [ ] Label reads "Water Bottles"
- [ ] Three buttons visible: "1", "2", "3+"
- [ ] Buttons in horizontal row
- [ ] Tap "1" → Highlights
- [ ] Tap "2" → Highlights, "1" unhighlights
- [ ] Tap "3+" → Highlights, "2" unhighlights
- [ ] Selected button has primary color background
- [ ] Unselected buttons have white background with border

### Aero Bottle Toggle
- [ ] Label reads "Aero Bottle"
- [ ] Description reads "Do you have an aero bottle?"
- [ ] Toggle OFF → ON works
- [ ] Toggle ON → OFF works

### Bento Box Toggle
- [ ] Label reads "Bento Box"
- [ ] Description reads "Do you have a bento box for food?"
- [ ] Toggle OFF → ON works
- [ ] Toggle ON → OFF works

---

## Section 4: Swimming Settings

### Section Header
- [ ] "Swimming" section header is visible
- [ ] Bold, larger font than field labels
- [ ] Clear visual separation from Cycling section

### CSS Pace Input
- [ ] Label reads "CSS (Critical Swim Speed)"
- [ ] Description explains "Fastest pace per 100m..."
- [ ] Input field shows placeholder "e.g., 2:00"
- [ ] Suffix shows "per 100m"
- [ ] Keyboard shows text keyboard (for MM:SS)

**Test MM:SS Format**:
- [ ] Enter "2:00" → Accepts (valid)
- [ ] Enter "1:30" → Accepts (valid)
- [ ] Enter "3:59" → Accepts (valid)
- [ ] Enter "2:60" → Rejects (invalid, seconds >= 60)
- [ ] Enter "abc" → Rejects (invalid format)
- [ ] Enter "2:5" → Accepts as "2:05"

### Wetsuit Toggle
- [ ] Label reads "Wetsuit"
- [ ] Description reads "Do you typically wear a wetsuit?"
- [ ] Toggle OFF → ON works
- [ ] Toggle ON → OFF works

### Swim Cap Type Selector
- [ ] Label reads "Swim Cap Type"
- [ ] Four buttons visible vertically:
  - [ ] "None"
  - [ ] "Latex"
  - [ ] "Silicone"
  - [ ] "Neoprene"
- [ ] Tap each option → Highlights correctly
- [ ] Only one option selected at a time
- [ ] Selected button has primary color background
- [ ] Unselected buttons have white background with border

---

## Section 5: Save Functionality

### Save Button - Normal State
- [ ] Button shows "Save Changes" text
- [ ] Button is enabled (tappable)
- [ ] Button is full width
- [ ] Button at bottom of screen with spacing

### Save Button - Loading State
- [ ] Tap "Save Changes"
- [ ] Button text changes to "Saving..."
- [ ] Button becomes disabled (grayed out)
- [ ] Cannot tap button again while saving

### Save Button - Success
- [ ] After save completes:
  - [ ] Button returns to "Save Changes"
  - [ ] Button becomes enabled again
  - [ ] Green snackbar appears
  - [ ] Snackbar shows "Sport settings saved!"
  - [ ] Snackbar disappears after 2 seconds

### Save Button - Error (Simulate by disconnecting network)
- [ ] Tap "Save Changes" with no network
- [ ] Red/error snackbar appears
- [ ] Error message is shown
- [ ] Button returns to "Save Changes"
- [ ] Can retry save

---

## Section 6: Data Persistence

### After Save
- [ ] Make changes to all fields
- [ ] Tap "Save Changes"
- [ ] Navigate back to Settings menu
- [ ] Navigate to Sport Settings again
- [ ] All changes are preserved

### After App Restart
- [ ] Make changes to all fields
- [ ] Tap "Save Changes"
- [ ] Close app completely
- [ ] Restart app
- [ ] Navigate to Sport Settings
- [ ] All changes are still preserved

### Cross-Screen Persistence
- [ ] Change FTP in Sport Settings → Save
- [ ] Navigate to another screen (e.g., Profile)
- [ ] Return to Sport Settings
- [ ] FTP value is preserved

---

## Section 7: Auto-Save Behavior

### Individual Field Changes
- [ ] Change GI Sensitivity toggle
- [ ] Wait 1 second
- [ ] Navigate away without tapping "Save Changes"
- [ ] Return to Sport Settings
- [ ] Verify: Change WAS saved (auto-save worked)

**Note**: Each field change auto-saves via controller methods. The "Save Changes" button is for final confirmation and user feedback.

---

## Section 8: Error Handling

### Invalid Input
- [ ] Enter invalid FTP (negative) → No crash
- [ ] Enter invalid CSS pace (wrong format) → No crash
- [ ] Leave required fields empty → No crash

### Network Errors (Simulate)
- [ ] Turn off WiFi/cellular
- [ ] Make changes and tap "Save Changes"
- [ ] Error snackbar appears (not app crash)
- [ ] Turn on network and retry → Works

---

## Section 9: UI/UX Quality

### Layout
- [ ] No overflow errors
- [ ] All text is readable
- [ ] Proper spacing between elements
- [ ] Scrolling works if content is tall

### Typography
- [ ] Section headers are bold and larger
- [ ] Field labels are medium weight
- [ ] Descriptions are smaller and gray
- [ ] All text uses proper font sizes

### Colors
- [ ] Primary color used for selected states
- [ ] White background for inputs/buttons
- [ ] Cream background for screen
- [ ] Gray for descriptions and borders

### Interactions
- [ ] All buttons respond to taps
- [ ] Visual feedback on button press
- [ ] Toggles animate smoothly
- [ ] Loading states are clear

---

## Section 10: Edge Cases

### Empty/Null Values
- [ ] New user with no sport settings → Defaults work
- [ ] Clear FTP (set to empty) → Saves as null
- [ ] Clear CSS pace → Saves as null

### Extreme Values
- [ ] FTP = 0 → Accepts
- [ ] FTP = 500 → Accepts
- [ ] CSS pace = 0:30 → Accepts
- [ ] CSS pace = 10:00 → Accepts

### Rapid Changes
- [ ] Toggle GI on/off/on/off quickly → No crash
- [ ] Select different swim caps rapidly → No crash
- [ ] Type in FTP quickly → No lag

---

## Section 11: Integration with Other Features

### Profile Screen
- [ ] Height/weight in Profile affects calculations
- [ ] Changes in Profile don't reset Sport Settings

### Preferences Screen
- [ ] Distance units, gut training don't conflict
- [ ] Changes in Preferences don't reset Sport Settings

### Nutrition Plan
- [ ] Sport settings (GI, cycling gear) used in plan generation
- [ ] Verify nutrition plan reflects sport settings

---

## Section 12: Accessibility

### Screen Reader (VoiceOver/TalkBack)
- [ ] All labels are read correctly
- [ ] Toggles announce on/off state
- [ ] Buttons announce their purpose
- [ ] Input fields announce placeholder text

### Touch Targets
- [ ] All buttons are large enough to tap (44pt minimum)
- [ ] No accidental taps on nearby elements

---

## Bug Reporting Template

If you find a bug, use this template:

```
**Bug**: [Brief description]
**Steps to Reproduce**:
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Expected Behavior**: [What should happen]
**Actual Behavior**: [What actually happens]
**Screenshot**: [Attach if applicable]
**Device**: [iOS/Android, version]
```

---

## Pass Criteria

To pass testing, the following must be true:
- ✅ All sections above are checked with no failures
- ✅ No crashes or errors
- ✅ Data persists correctly
- ✅ Save functionality works
- ✅ UI is clean and readable
- ✅ No major bugs found

---

## Testing Sign-Off

**Tester**: _________________________
**Date**: _________________________
**Result**: [ ] Pass  [ ] Fail (with notes)
**Notes**:
_____________________________________________
_____________________________________________
_____________________________________________

---

**Document Version**: 1.0
**Last Updated**: December 18, 2025
