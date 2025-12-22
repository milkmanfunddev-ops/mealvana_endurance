# Sport Settings Screen - Layout Visualization

## Screen Hierarchy

```
┌─────────────────────────────────────────┐
│  ← Back    Sport Settings               │  AppBar
├─────────────────────────────────────────┤
│                                         │
│  🔄 GI Sensitivity           [Toggle]   │  General Setting
│  Do you have a sensitive stomach...     │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Cycling                                │  Section Header
│  ─────────────────────────────          │
│                                         │
│  FTP (Functional Threshold Power)       │
│  ┌─────────────────────────────────┐   │
│  │ 250                    │ watts  │   │  Number Input
│  └─────────────────────────────────┘   │
│                                         │
│  Water Bottles                          │
│  ┌─────┬─────┬─────┐                   │
│  │  1  │  2  │ 3+  │                   │  Horizontal Selector
│  └─────┴─────┴─────┘                   │
│                                         │
│  🔄 Aero Bottle              [Toggle]   │
│  Do you have an aero bottle?            │
│                                         │
│  🔄 Bento Box                [Toggle]   │
│  Do you have a bento box for food?      │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Swimming                               │  Section Header
│  ─────────────────────────────          │
│                                         │
│  CSS (Critical Swim Speed)              │
│  ┌─────────────────────────────────┐   │
│  │ 2:00              │ per 100m   │   │  Text Input (MM:SS)
│  └─────────────────────────────────┘   │
│                                         │
│  🔄 Wetsuit                  [Toggle]   │
│  Do you typically wear a wetsuit?       │
│                                         │
│  Swim Cap Type                          │
│  ┌─────────────────────────────────┐   │
│  │         None                    │   │
│  ├─────────────────────────────────┤   │
│  │         Latex                   │   │  Vertical Selector
│  ├─────────────────────────────────┤   │
│  │         Silicone                │   │
│  ├─────────────────────────────────┤   │
│  │         Neoprene                │   │
│  └─────────────────────────────────┘   │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐   │
│  │      Save Changes               │   │  Save Button
│  └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

## Spacing Details

```
GI Sensitivity
    ↓ 32.h (major section spacing)
Cycling Section Header
    ↓ 16.h (after section header)
FTP Input
    ↓ 20.h (between fields)
Water Bottles Selector
    ↓ 20.h
Aero Bottle Toggle
    ↓ 20.h
Bento Box Toggle
    ↓ 32.h (major section spacing)
Swimming Section Header
    ↓ 16.h (after section header)
CSS Pace Input
    ↓ 20.h
Wetsuit Toggle
    ↓ 20.h
Swim Cap Selector
    ↓ 32.h (before save button)
Save Button
    ↓ 40.h (bottom padding)
```

## Widget Types

### Toggle Fields (Switch)
- **Used for**: Boolean values
- **Examples**: GI Sensitivity, Aero Bottle, Bento Box, Wetsuit
- **Layout**: Label on left, toggle on right
- **Visual**: iOS-style switch (white thumb, colored track)

### Number Input (TextFormField)
- **Used for**: Integer values
- **Examples**: FTP Watts
- **Features**:
  - Number keyboard
  - Suffix text ("watts")
  - Hint text ("e.g., 250")
  - Rounded border
- **Validation**: Accepts 0+ integers

### Time Input (TextFormField)
- **Used for**: Time values
- **Examples**: CSS Pace
- **Features**:
  - Text keyboard (for MM:SS format)
  - Suffix text ("per 100m")
  - Hint text ("e.g., 2:00")
  - Rounded border
- **Validation**: MM:SS format with seconds < 60

### Horizontal Selector (Row of Buttons)
- **Used for**: Small set of mutually exclusive options
- **Examples**: Water Bottles (1, 2, 3+)
- **Layout**: Equal-width buttons in a row
- **Visual**: Selected = filled primary color, unselected = white with border

### Vertical Selector (Column of Buttons)
- **Used for**: Larger set of mutually exclusive options
- **Examples**: Swim Cap Type (None, Latex, Silicone, Neoprene)
- **Layout**: Full-width buttons stacked vertically
- **Visual**: Selected = filled primary color, unselected = white with border

## Typography Hierarchy

```
Section Headers (Cycling, Swimming)
├─ Font Size: 20.sp
├─ Weight: w600 (Semibold)
└─ Color: baseBlack

Field Labels
├─ Font Size: 16.sp
├─ Weight: w500 (Medium)
└─ Color: baseBlack

Descriptions
├─ Font Size: 13.sp
├─ Weight: normal
└─ Color: baseGrey

Input Text
├─ Font Size: 14.sp
├─ Weight: w500 (Medium)
└─ Color: baseBlack (selected) / baseWhite (unselected)
```

## Color Scheme

- **Primary**: `AppTheme.primary600` (selected states, focused borders)
- **Background**: `AppTheme.baseCream` (scaffold background)
- **Card/Input**: `AppTheme.baseWhite` (input fields, unselected buttons)
- **Text**: `AppTheme.baseBlack` (labels, headers)
- **Secondary Text**: `AppTheme.baseGrey` (descriptions, hints)
- **Borders**: `AppTheme.baseGrey.withValues(alpha: 0.3)` (input borders)
- **Success**: `AppTheme.primary600` (snackbar)

## Interaction Flow

```
User Interaction Flow:
┌──────────────────────────────────────────┐
│ 1. User changes any setting              │
│    (toggle, input, selector)             │
└─────────────┬────────────────────────────┘
              ↓
┌──────────────────────────────────────────┐
│ 2. onChange callback fires               │
│    - updateGISensitivity()               │
│    - updateCyclingPreferences()          │
│    - updateSwimmingPreferences()         │
└─────────────┬────────────────────────────┘
              ↓
┌──────────────────────────────────────────┐
│ 3. Controller updates state              │
│    state = AsyncData(currentState        │
│      .copyWith(newValue, isSaving: true))│
└─────────────┬────────────────────────────┘
              ↓
┌──────────────────────────────────────────┐
│ 4. Controller calls _saveProfile()       │
│    - Updates local Drift database        │
│    - Invalidates currentUserProvider     │
└─────────────┬────────────────────────────┘
              ↓
┌──────────────────────────────────────────┐
│ 5. State updated with isSaving: false    │
│    - UI reflects saved state             │
└──────────────────────────────────────────┘

Save Button Flow:
┌──────────────────────────────────────────┐
│ 1. User taps "Save Changes"              │
└─────────────┬────────────────────────────┘
              ↓
┌──────────────────────────────────────────┐
│ 2. saveSportSettings() called            │
│    - Sets isSaving: true                 │
│    - Button shows "Saving..."            │
│    - Button disabled                     │
└─────────────┬────────────────────────────┘
              ↓
┌──────────────────────────────────────────┐
│ 3. _saveProfile() persists all changes   │
└─────────────┬────────────────────────────┘
              ↓
┌──────────────────────────────────────────┐
│ 4. Success snackbar shown                │
│    "Sport settings saved!"               │
│    - Green background                    │
│    - 2 second duration                   │
└──────────────────────────────────────────┘
```

## State Management

### SettingsState Fields (Sport-Related)

```dart
// Section Labels (from ContentService)
sportSettingsSectionTitle: String    // "Sport Settings"
giSensitivityLabel: String           // "GI Sensitivity"
cyclingSectionTitle: String          // "Cycling"
swimmingSectionTitle: String         // "Swimming"
saveButtonText: String               // "Save Changes"

// UI State
isSaving: bool                       // Shows loading state
errorMessage: String?                // Shows error if save fails

// General Sport Settings
giSensitivity: bool?                 // Sensitive stomach toggle

// Cycling Settings
ftpWatts: int?                       // FTP in watts
typicalBikeBottles: int?             // 1, 2, or 3+
hasAeroBottle: bool?                 // Aero bottle toggle
hasBentoBox: bool?                   // Bento box toggle

// Swimming Settings
cssPacePer100mSeconds: int?          // CSS pace (total seconds)
typicalWetsuit: bool?                // Wetsuit toggle
typicalSwimCapType: String?          // "none", "latex", "silicone", "neoprene"
```

### Controller Methods

```dart
// Individual Updates (auto-save)
updateGISensitivity(bool giSensitivity)
updateCyclingPreferences({
  int? ftpWatts,
  int? typicalBikeBottles,
  bool? hasAeroBottle,
  bool? hasBentoBox,
})
updateSwimmingPreferences({
  int? cssPacePer100mSeconds,
  bool? typicalWetsuit,
  String? typicalSwimCapType,
})

// Consolidated Save (called by Save button)
saveSportSettings()

// Internal Save Method
_saveProfile() // Persists to Drift database
```

## Accessibility Considerations

- ✅ All fields have descriptive labels
- ✅ All fields have helper text explaining purpose
- ✅ Toggles show clear on/off states
- ✅ Selectors show clear selected state
- ✅ Loading state prevents double-submission
- ✅ Error messages shown in snackbar
- ✅ Success feedback provided

## Future Enhancements (Optional)

### Collapsible Sections
If the screen becomes too long (e.g., adding running settings):
```
┌─────────────────────────────────────────┐
│  ▼ Cycling                              │  ← Expandable
│     (FTP, bottles, aero, bento)         │
│                                         │
│  ▶ Swimming                             │  ← Collapsed
│                                         │
│  ▶ Running                              │  ← Collapsed
└─────────────────────────────────────────┘
```

### Field Validation
- FTP: 0-500 watts (typical range)
- CSS Pace: 0:30 - 5:00 (typical range)
- Real-time validation with error messages

### Help Icons
Add "?" icons next to technical terms:
- FTP → Explains functional threshold power
- CSS → Explains critical swim speed

---

**Document Version**: 1.0
**Last Updated**: December 18, 2025
