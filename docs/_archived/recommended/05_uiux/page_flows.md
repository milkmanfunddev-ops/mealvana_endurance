# Mealvana Endurance UI/UX Page Flows

## Overview
This document defines the complete page flow architecture for Mealvana Endurance, a personalized nutrition planning app for endurance athletes. The flows are designed around an offline-first mobile experience with Flutter Material Design 3 components.

## App Navigation Architecture

### Navigation Pattern
- **Primary Navigation**: Bottom tab navigation (3 tabs)
- **Secondary Navigation**: Stack-based navigation within each tab
- **Deep Navigation**: Modal overlays and bottom sheets
- **Router**: GoRouter with nested navigation support

### Tab Structure
```
Bottom Navigation:
├── 🏃 Plan (Tab 1) - Primary flow
├── 📖 Recipes (Tab 2) - Secondary content  
└── ⚙️ Settings (Tab 3) - Configuration
```

## Core User Flows

### 1. First-Time User Flow (Onboarding)

#### 1.1 App Launch → Welcome Screen
**Screen**: `OnboardingWelcomeScreen`
**Purpose**: Introduce app value proposition
**Components**:
- Hero image (runner illustration)
- App value proposition (3 key benefits)
- "Get Started" primary button
- "Skip" text button (direct to main app)

**User Actions**:
- Tap "Get Started" → Personal Info Screen
- Tap "Skip" → Main App (Plan Tab)

#### 1.2 Personal Info Collection
**Screen**: `OnboardingPersonalInfoScreen`
**Purpose**: Collect essential biometric data
**Components**:
- Progress indicator (Step 1 of 3)
- Form fields:
  - Gender selection (Male/Female/Other)
  - Birthday picker
  - Height input (cm/ft-in toggle)
  - Weight input (kg/lbs toggle)
- "Continue" primary button
- Back button

**User Actions**:
- Fill required fields → Enable "Continue"
- Tap "Continue" → Running Habits Screen
- Tap "Back" → Welcome Screen

**Validation**:
- All fields required
- Age must be 13+ years
- Reasonable height/weight ranges

#### 1.3 Running Habits Assessment
**Screen**: `OnboardingRunningHabitsScreen`
**Purpose**: Understand user's running experience
**Components**:
- Progress indicator (Step 2 of 3)
- Question: "Do you run with a water bottle?"
- Toggle switch (Yes/No)
- Visual representation (runner with/without bottle)
- "Continue" primary button
- Back button

**User Actions**:
- Toggle selection → Update UI visual
- Tap "Continue" → Food Preferences Screen
- Tap "Back" → Personal Info Screen

#### 1.4 Food Preferences (Checklist Screen)
**Screen**: `OnboardingFoodPreferencesScreen`
**Purpose**: Capture detailed food preferences
**Components**:
- Progress indicator (Step 3 of 3)
- Completion percentage bar
- Categorized food list:
  - Pre-run Foods (8 items)
  - During-run Foods (4 items)
- Three-state selection per food:
  - ❤️ Like (green)
  - 🤔 Open to Try (orange) 
  - ❌ Dislike (red)
- "Complete Setup" primary button
- Back button

**Food Categories**:

**Pre-run Foods**:
- Oatmeal
- Banana
- Greek Yogurt
- Coffee
- Bagel
- Dates
- Greek Yogurt with Berries
- Protein Bar

**During-run Foods**:
- Sports Drink
- Water
- Energy Gels
- Energy Chews

**User Actions**:
- Tap food item → Cycle through preference states
- Progress bar updates with completion percentage
- Minimum 70% completion required for "Complete Setup"
- Tap "Complete Setup" → Main App (Plan Tab)
- Tap "Back" → Running Habits Screen

**Validation**:
- Must set preference for at least 70% of foods
- Cannot have all foods set to "Dislike"

### 2. Main App Flow (Plan Tab)

#### 2.1 Distance/Pace Input Screen
**Screen**: `DistancePaceGutEntryScreen`
**Purpose**: Core input for nutrition plan generation
**Components**:
- Screen title: "Plan Your Run"
- Distance input:
  - Number picker or text field
  - Unit toggle (km/miles)
  - Range: 5-100 km / 3-62 miles
- Pace input:
  - Time picker (MM:SS format)
  - Unit display (/km or /mile)
  - Range: 4:00-12:00 per unit
- Gut training level:
  - Segmented control (Beginner/Experienced)
  - Info tooltip explaining impact
- "Generate Plan" primary button (prominent)
- Optional: "Load Previous Plan" secondary button

**User Actions**:
- Adjust distance → Validate range, update button state
- Adjust pace → Validate range, update button state  
- Select gut training → Update calculation parameters
- Tap "Generate Plan" → Plan Generation Loading → Current Plan Screen
- Tap "Load Previous Plan" → Plan history modal

**Validation**:
- Distance: 5-100km (3-62 miles)
- Pace: 4:00-12:00 per distance unit
- Gut training: Required selection

**Loading State**:
- Replace screen with loading overlay
- Progress animation
- "Calculating your personalized plan..."
- Duration: 1-3 seconds

#### 2.2 Current Plan Screen (Results)
**Screen**: `CurrentPlanScreen`
**Purpose**: Display generated nutrition plan
**Components**:
- Plan header:
  - Run details (distance, pace, duration)
  - "Generate New Plan" secondary button
- Macro summary card:
  - Total calories with progress bar
  - Carbs, Sodium, Fluids with targets
- Expandable plan sections:
  - **Before Run** (1-2 hours before)
  - **During Run** (every 30 minutes)
  - Each section shows:
    - Food items with quantities
    - Nutritional breakdown
    - Timing guidance
- Action buttons:
  - "How did this work?" (feedback)
  - "Adjust Macros" (advanced users)
  - Share icon (future)

**User Actions**:
- Tap section headers → Expand/collapse details
- Tap "Generate New Plan" → Distance/Pace Input Screen
- Tap "How did this work?" → Feedback Flow
- Tap "Adjust Macros" → Adjust Macros Screen
- Swipe actions on food items → Swap Food Screen

#### 2.3 Adjust Macros Screen (Advanced)
**Screen**: `AdjustMacrosScreen`
**Purpose**: Fine-tune macro targets for advanced users
**Components**:
- Current targets display
- Adjustable sliders:
  - Carb rate (g/hour): 30-90g
  - Sodium rate (mg/hour): 200-700mg  
  - Fluid rate (ml/hour): 400-800ml
- Impact preview:
  - "This will affect your plan by..."
  - Updated food recommendations preview
- "Update Plan" primary button
- "Reset to Defaults" secondary button

**User Actions**:
- Adjust sliders → Real-time preview updates
- Tap "Update Plan" → Regenerate plan → Current Plan Screen
- Tap "Reset to Defaults" → Restore original targets
- Back button → Current Plan Screen (no changes)

#### 2.4 Swap Food Screen
**Screen**: `SwapFoodScreen`
**Purpose**: Replace specific food items in plan
**Components**:
- Header: "Replace [Food Name]"
- Current food card (to be replaced)
- Replacement options:
  - Filtered by category and preferences
  - Similar nutritional profile
  - Availability indicator
- Nutritional comparison table
- "Replace" primary button
- "Cancel" secondary button

**User Actions**:
- Browse replacement options
- Tap food option → Select replacement
- Compare nutritional values
- Tap "Replace" → Update plan → Current Plan Screen
- Tap "Cancel" → Current Plan Screen (no changes)

### 3. Feedback Flow

#### 3.1 Plan Feedback Screen
**Screen**: `PlanFeedbackScreen`
**Purpose**: Collect feedback on generated plan quality
**Components**:
- Question: "How was this nutrition plan?"
- Rating options:
  - "Pretty close to what I think I should use" (positive)
  - "Much more than what I think I should use" (too much)
  - "Much less than what I think I should use" (too little)
- Continue button (enabled after selection)

**User Actions**:
- Select rating option → Enable continue
- Tap "Continue" → App Feedback Screen

#### 3.2 App Feedback Screen
**Screen**: `AppFeedbackScreen`
**Purpose**: Collect overall app experience feedback
**Components**:
- Question: "How do you feel about the app overall?"
- Response options (based on previous answer):
  - "I like it! Remind me to use it" (positive flow)
  - "It has potential but I need it to..." → Text input
  - "Not interested" → Optional reason chips
- Submit button
- Skip option

**User Actions**:
- Select response → Show appropriate follow-up
- Fill optional text input
- Tap "Submit" → Thank you message → Return to Plan Tab
- Tap "Skip" → Return to Plan Tab

### 4. Secondary Flows

#### 4.1 Recipes Tab Flow
**Screen**: `RecipesScreen`
**Purpose**: Browse nutrition-focused recipes (future feature)
**Current State**: Placeholder screen
**Components**:
- "Coming Soon" message
- Preview of future recipe functionality
- "Back to Plan" button

#### 4.2 Settings Tab Flow
**Screen**: `SettingsScreen`
**Purpose**: App configuration and user management
**Components**:
- User profile section:
  - Basic info display
  - "Edit Profile" button
- Preferences section:
  - "Food Preferences" → Food Preferences Screen
  - "Units" → Metric/Imperial toggle
- App section:
  - "About" → App info modal
  - "Privacy Policy" → WebView
  - "Terms of Service" → WebView
- Account section (future):
  - Sync status
  - Account management

**User Actions**:
- Tap "Edit Profile" → Profile Edit Screen
- Tap "Food Preferences" → Food Preferences Management
- Toggle units → Update app-wide units
- Tap legal links → Open in WebView

#### 4.3 Food Preferences Management
**Screen**: `FoodPreferencesManagementScreen`
**Purpose**: Modify food preferences after onboarding
**Components**:
- Same food list as onboarding
- Current preferences highlighted
- "Reset All" button
- "Save Changes" button
- Category filters (Pre-run, During-run)

**User Actions**:
- Modify food preferences
- Apply category filters
- Tap "Reset All" → Confirmation dialog
- Tap "Save Changes" → Update preferences → Settings Screen

## Error States and Edge Cases

### Network Error States
**Offline Mode**: 
- App functions completely offline
- No network error messages needed
- All core functionality available

### Data Error States
**Invalid Input**:
- Real-time validation with inline error messages
- Disabled action buttons until valid input
- Clear error recovery instructions

**No Plan Generated**:
- Too many food dislikes → Guidance to adjust preferences
- Invalid parameters → Suggestion to modify inputs
- System error → Retry option with support contact

### Empty States
**No Previous Plans**:
- First-time user guidance
- Prominent "Generate Your First Plan" CTA

**No Preferences Set**:
- Guidance to complete food preferences
- Quick link to preferences screen

## Animation and Transitions

### Screen Transitions
- **Standard navigation**: Slide in from right (iOS) / Fade (Android)
- **Modal presentations**: Slide up from bottom
- **Tab changes**: Fade transition with content persistence

### Micro-interactions
- **Button press**: Scale down slightly (0.95x)
- **Loading states**: Shimmer animation for content areas
- **Success actions**: Brief checkmark animation
- **Progress indicators**: Smooth animated progress bars

### Content Animations
- **Plan generation**: Loading spinner with percentage
- **Food preference selection**: Color transition animation
- **Macro adjustments**: Real-time value updates
- **Plan sections**: Smooth expand/collapse

## Accessibility Considerations

### Screen Reader Support
- Semantic labels for all interactive elements
- Screen reader announcements for state changes
- Logical focus order for navigation

### Visual Accessibility
- High contrast color combinations
- Minimum 44dp touch targets
- Scalable text (supports Dynamic Type)
- Color-independent information design

### Motor Accessibility
- Large, well-spaced touch targets
- Gesture alternatives for swipe actions
- Voice control compatibility

## Platform-Specific Considerations

### iOS Specific
- Navigation bar styling matches iOS conventions
- Cupertino widgets where appropriate
- iOS-specific gestures (swipe back)
- Safe area handling for notched devices

### Android Specific
- Material Design 3 component library
- Android back button handling
- Material motion transitions
- Adaptive icons and splash screens

## Performance Considerations

### Screen Loading
- Pre-load next screens during onboarding
- Cache generated plans for instant display
- Lazy loading for food preference lists

### Memory Management
- Dispose controllers when screens unmount
- Image caching for food icons
- Efficient list rendering for large datasets

### Battery Optimization
- Minimal background processing
- Efficient local database queries
- Optimized animation performance

## Future Enhancements

### Planned Flow Additions
- Plan history and favorites
- Social sharing of plans
- Coach/trainer collaboration
- Advanced customization options

### Analytics Integration
- User flow completion rates
- Feature usage tracking
- Error state frequency
- A/B testing framework

## Source Reference

Based on: `../../uiux/README.md`, `../03_architecture/app_architecture.md`, `../02_requirements/app_overview.md`