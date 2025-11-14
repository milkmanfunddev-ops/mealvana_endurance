# Kyle's Design System for Mealvana Endurance
## Complete UI Redesign Documentation

**Last Updated:** 2025-11-12
**Status:** Ready for Implementation
**Figma Source:** [Kyle's Mockups](https://www.figma.com/design/4FvaeGejofuETyP5LUIxQK/Kyle-s-Mockups)

---

## 📋 Overview

This folder contains complete documentation for implementing Kyle's UI redesign for the Mealvana Endurance app. The design features a sophisticated dark/light theme system with three custom typefaces, a vibrant color palette, and a comprehensive component library.

### Design Highlights
- **🎨 Dual Themes:** Rich purple "Blackberry" dark mode and clean "Cream" light mode
- **✍️ Three Typefaces:** Sansita Bold, Compadre Wide, and Apercu
- **🌈 Vibrant Colors:** Orange primary actions, Electrolyte (cyan) accents, Dragonfruit (pink) warnings
- **📦 50+ Components:** Buttons, cards, inputs, navigation, and more
- **📱 Mobile-First:** Optimized for iOS and Android

### ✅ P0 Restoration Status (Updated 2025-11-12)
**MILESTONE ACHIEVED:** All Priority 0 (P0) screens have been successfully restored with full database integration while maintaining Kyle's design system.

**Completed Screens:**
- ✅ **Activity Detail Screen** - Full functionality restored (database persistence, CRUD operations, state management)
- ✅ **User Profile Screen** - Onboarding flow restored (database persistence, form validation, navigation)
- ✅ **Settings Screen** - Auto-save functionality restored (database persistence, provider integration)

**Achievement:** Proved that Kyle's design system can deliver both aesthetic excellence and complete backend integration.

📖 **See:** [P0 Restoration Complete Summary](./P0_RESTORATION_COMPLETE.md) for detailed completion report

---

## 📚 Documentation Index

### 0. [P0 Restoration Complete](./P0_RESTORATION_COMPLETE.md) ✅ NEW - MILESTONE ACHIEVED
**Complete summary of database integration restoration for P0 screens**

**Contains:**
- Executive summary of P0 completion (Activity Detail, User Profile, Settings)
- Before/after comparison showing restoration approach
- Technical implementation details (AsyncNotifier, database persistence, router integration)
- Files modified and testing status
- Lessons learned and best practices established
- Next steps for P1/P2 screens

**Use when:** Understanding what was accomplished, learning restoration patterns, planning P1/P2 work
**Status:** ✅ Complete - Updated 2025-11-12

---

### 1. [Parameter Restoration Roadmap](./PARAMETER_RESTORATION_ROADMAP.md) 🎯 ACTIVE RESTORATION GUIDE
**Complete roadmap for restoring database integration to Kyle-designed screens**

**Contains:**
- P0 screens COMPLETED status (Activity Detail, User Profile, Settings) ✅
- P1/P2 screen restoration plans (Help & Feedback, Sport Preferences, Distance Pace Gut Entry)
- Technical implementation details for each screen
- Router integration requirements
- Controller integration tasks
- Testing checklist and acceptance criteria

**Use when:** Planning restoration work, understanding what needs to be done
**Status:** ✅ P0 Complete, P1/P2 In Progress

---

### 2. [Refactoring Inventory](./REFACTORING_INVENTORY.md) ⭐ ORIGINAL PLANNING DOC
**Complete screen and widget mapping for refactoring**

**Contains:**
- Screenshot analysis (14 Figma screens mapped to codebase)
- Theme system changes (dark/light mode implementation)
- Widget refactoring inventory (7 existing widgets to refactor, 8 new components)
- Screen refactoring inventory (6 screens)
- Implementation phases (6 phases, 50 days for all 51 screens)
- Priority breakdown (Critical/Medium/Low)
- Outstanding questions for decision making

**Use when:** Planning refactoring work, need to know what to refactor
**Status:** ✅ Complete - Updated with existing widget analysis

---

### 3. [Design Tokens](./DESIGN_TOKENS.md)
**Complete design system specification with exact values**

**Contains:**
- Typography system (3 font families, exact px sizes from Figma)
- Color palette (6 colors with exact hex values)
- Spacing & layout (8pt grid system)
- Border radius specifications (15px cards, 100px buttons)
- Icon sizes and mapping (36px circles, 20px controls)
- ✅ All values extracted from Figma via MCP

**Use when:** Setting up theme files, need exact values

---

### 4. [Components Catalog](./COMPONENTS_CATALOG.md)
**Visual reference for all UI components with exact specs**

**Contains:**
- Button specifications (Primary, Secondary, Tertiary, Icon) ✅ Exact values
  - 7 existing widgets identified for refactoring
- Form inputs (Text fields, sliders, date/time pickers, plus/minus controls) ✅ Exact values
  - 5 existing widgets identified for refactoring
- Cards (Activity cards, food items, nutrition sections)
  - 4 existing widgets identified for refactoring
- Navigation (App bar, bottom nav, tab selectors, week selector)
  - 5 existing widgets identified for refactoring
- Lists & items (Calendar grid, section headers, food preferences) ✅ Exact values
  - 4 existing widgets identified for refactoring
- Icons & badges (Activity 36px, food 36px with Electrolyte background) ✅ Exact values
  - 2 existing widgets identified for refactoring
- Data display (Stats, macros, nutritional facts)
  - 3 existing widgets identified for refactoring
- Feedback components (Loading, empty, error states)

**Use when:** Implementing a specific component, need visual specs
**Status:** ✅ Complete - Updated with existing widget locations

---

### 5. [Implementation Guide](./IMPLEMENTATION_GUIDE.md)
**Step-by-step Flutter implementation instructions**

**Contains:**
- Phase 0: Setup (fonts, icons, dependencies)
- Phase 1: Theme foundation (colors, typography, spacing)
- Phase 2: Core components (building the library)
- Phase 3: Screen migration (updating existing screens)
- Testing strategy (unit, widget, integration, visual regression)
- Deployment plan (rollout strategies, rollback)
- Troubleshooting guide

**Use when:** Actually implementing the redesign

---

### 6. [Extracted Exact Values](./EXTRACTED_EXACT_VALUES.md)
**Raw extraction data from Figma MCP**

**Contains:**
- Exact hex color values from Figma variables
- Code extracts from Figma design context
- Component dimensions (px-perfect)
- Before/after color comparisons
- Critical change notes (Electrolyte color)

**Use when:** Need to verify exact values, reference extraction source

---

## 🚀 Quick Start

### For Developers

**1. Review the documentation:**
```bash
# Read in this order:
1. This README (you are here)
2. DESIGN_TOKENS.md - Understand the system
3. COMPONENTS_CATALOG.md - See what's available
4. IMPLEMENTATION_GUIDE.md - Follow the steps
```

**2. Start implementation:**
```bash
# Phase 0: Setup (Day 1)
- Install fonts
- Set up icon library
- Install dependencies

# Phase 1: Theme Foundation (Days 2-3)
- Create theme files
- Apply to app
- Test light/dark switching

# Phase 2: Component Library (Week 2-3)
- Build reusable widgets
- Write tests
- Document usage

# Phase 3: Screen Migration (Week 3-5)
- Migrate one screen at a time
- Test thoroughly
- Get designer approval
```

**3. Run the project:**
```bash
# Generate code
dart run build_runner build --delete-conflicting-outputs

# Run app
flutter run

# Run tests
flutter test
```

---

## 🎨 Design System Summary

### Typography
| Font | Usage | Example |
|------|-------|---------|
| **Sansita Bold** | Titles, buttons, dates | "Activity Details", "GENERATE PLAN" |
| **Compadre Wide** | Subtitles, food names | "10 MILE RUN", "ENERGY BAR" |
| **Apercu** | Body text, data | Long descriptions, "823 calories" |

### Colors
| Name | Hex | Usage |
|------|-----|-------|
| **Blackberry** | #3D1F47 | Dark theme background |
| **Cream** | #F5F3ED | Light theme background |
| **Orange** | #FF8B3D | Primary buttons, CTAs |
| **Electrolyte** | #5DE4D3 | Activity/food icons, positive actions |
| **Dragonfruit** | #E84393 | Warnings, tertiary actions |

### Component Count
- **8** Button variants
- **5** Input types
- **7** Card styles
- **4** Navigation components
- **4** List types
- **3** Icon types
- **3** Data displays
- **4** Feedback states

**Total: 38 core components**

---

## 📸 Screenshot Reference

All design screenshots are stored in this folder:

```
docs/kyle/
├── Screenshot 2025-11-12 at 5.17.34 AM.png  # New Activity (Light)
├── Screenshot 2025-11-12 at 5.18.03 AM.png  # New Activity (Dark)
├── Screenshot 2025-11-12 at 5.18.18 AM.png  # Activity Details (Light)
├── Screenshot 2025-11-12 at 5.18.50 AM.png  # Activity Details (Dark)
├── Screenshot 2025-11-12 at 5.19.05 AM.png  # Activity Details Alt (Dark)
├── Screenshot 2025-11-12 at 5.19.23 AM.png  # Calendar Month (Light)
├── Screenshot 2025-11-12 at 5.19.32 AM.png  # Calendar Month (Dark)
├── Screenshot 2025-11-12 at 5.19.40 AM.png  # Calendar Week (Light)
├── Screenshot 2025-11-12 at 5.19.50 AM.png  # Calendar Week (Dark)
├── Screenshot 2025-11-12 at 5.20.04 AM.png  # Adjust Macros (Light)
├── Screenshot 2025-11-12 at 5.20.17 AM.png  # Adjust Macros (Dark)
├── Screenshot 2025-11-12 at 5.20.24 AM.png  # Food Preferences (Light)
├── Screenshot 2025-11-12 at 5.20.31 AM.png  # Food Preferences (Dark)
├── Screenshot 2025-11-12 at 5.20.41 AM.png  # Style Guide
└── Screenshot 2025-11-12 at 5.20.48 AM.png  # Style Guide (continued)
```

---

## 🎯 Implementation Timeline

### Phase 0: P0 Screen Restoration (COMPLETED ✅)
**Duration:** 2 days (2025-11-12)
**Status:** ✅ Complete

- [x] Activity Detail Screen - Full database integration restored
- [x] User Profile Screen - Onboarding flow restored
- [x] Settings Screen - Auto-save functionality restored
- [x] Router parameter passing fixed
- [x] AsyncNotifier pattern integration
- [x] Database persistence verified
- [x] All screens pass `flutter analyze`

**Achievement:** Proved Kyle design system + full functionality is achievable

### Phase 1: P1 Screen Restoration (NEXT)
**Duration:** 1-2 days
**Status:** 🟡 In Progress

- [ ] Help & Feedback Screen - Sentry integration, feedback form backend
- [ ] Sport Preferences Screen - Full functional audit, database persistence
- [ ] Comprehensive testing on device

### Phase 2: Theme Foundation
**Duration:** 2-3 days
**Status:** 🟡 Partially complete (Kyle design tokens in use)

- [x] Colors established (Blackberry, Cream, Orange, Electrolyte, Dragonfruit)
- [x] Typography established (Sansita, Compadre, Apercu)
- [x] Theme toggle working (light/dark/system)
- [ ] Formalize in centralized theme files
- [ ] Create comprehensive spacing system
- [ ] Create reusable component library

### Phase 3: Core Components
**Duration:** 1-2 weeks
**Status:** 🟡 In Use (ad-hoc in screens, needs formalization)

- [x] Buttons (Primary, Secondary, Tertiary) - Used in restored screens
- [x] Inputs (Text fields, Dropdowns) - Used in restored screens
- [x] Cards (BaseCard) - Used in Settings screen
- [ ] Formalize component library structure
- [ ] Extract reusable components
- [ ] Write component tests
- [ ] Create component documentation

### Phase 4: Screen Migration
**Duration:** 2-3 weeks
**Status:** 🟡 In Progress (3/51 screens complete)

**Completed:**
- [x] Activity Detail Screen ✅
- [x] User Profile Screen ✅
- [x] Settings Screen ✅

**Remaining Critical Screens:**
- [ ] Home/Dashboard
- [ ] Calendar (Month & Week views)
- [ ] Activity Input screens (Running, Cycling, Swimming)
- [ ] Carb Loading screens
- [ ] Events screens
- [ ] Food Preferences
- [ ] Remaining Onboarding screens

### Phase 5: Polish & Testing
**Duration:** 1 week
**Status:** ⏳ Not started

- [ ] Add animations & transitions
- [ ] Accessibility audit
- [ ] Performance optimization
- [ ] Cross-platform testing (iOS + Android)
- [ ] Designer approval
- [ ] Final QA

**Total Estimated Time:** 8-10 weeks (50 days for all 51 screens)
**Progress:** 3/51 screens complete (6%) - P0 milestone achieved ✅

---

## 📦 Project Structure

```
lib/
├── theme/                          # NEW
│   ├── app_theme.dart             # Main theme config
│   ├── colors.dart                # Color palette
│   ├── text_styles.dart           # Typography
│   ├── spacing.dart               # Spacing & layout
│   └── theme_provider.dart        # Theme state (optional)
│
├── shared/
│   └── widgets/
│       └── kyle_design/           # NEW - Component library
│           ├── buttons/
│           │   ├── primary_button.dart
│           │   ├── secondary_button.dart
│           │   ├── tertiary_button.dart
│           │   ├── circular_icon_button.dart
│           │   ├── activity_type_selector.dart
│           │   └── segmented_control.dart
│           │
│           ├── inputs/
│           │   ├── text_field.dart
│           │   ├── plus_minus_control.dart
│           │   ├── preference_slider.dart
│           │   ├── date_picker.dart
│           │   └── time_picker.dart
│           │
│           ├── cards/
│           │   ├── base_card.dart
│           │   ├── activity_hero_card.dart
│           │   ├── nutrition_section_card.dart
│           │   ├── food_item_card.dart
│           │   ├── todays_activity_card.dart
│           │   ├── upcoming_event_card.dart
│           │   └── macro_targets_table.dart
│           │
│           ├── navigation/
│           │   ├── custom_app_bar.dart
│           │   ├── bottom_nav_bar.dart
│           │   ├── tab_selector.dart
│           │   └── week_selector.dart
│           │
│           ├── lists/
│           │   ├── section_header.dart
│           │   └── food_preference_item.dart
│           │
│           ├── icons/
│           │   ├── activity_icon.dart
│           │   └── food_icon.dart
│           │
│           ├── data/
│           │   ├── large_stat.dart
│           │   ├── macro_summary.dart
│           │   └── nutrition_fact_grid.dart
│           │
│           └── feedback/
│               ├── loading_indicator.dart
│               ├── empty_state.dart
│               ├── error_state.dart
│               └── success_toast.dart
│
└── features/
    └── [existing features...]
```

---

## ✅ Component Implementation Checklist

### Phase 0: Foundation (Days 1-3)
- [ ] Update app_theme.dart with Kyle's colors
- [ ] Add dark theme support
- [ ] Update pubspec.yaml for fonts
- [ ] Set up Font Awesome package
- [ ] Create theme provider for switching

### Phase 1: Refactor Existing Widgets (Days 4-10)
- [ ] PrimaryButton (refactor existing)
- [ ] SecondaryButton (refactor existing)
- [ ] TertiaryButton (refactor existing)
- [ ] CircularIconButton (refactor existing)
- [ ] IncrementDecrementWidget (refactor existing)
- [ ] SportCategorySelector (refactor existing)
- [ ] FoodIcon (refactor existing)
- [ ] ActivityIcon (refactor existing)

### Phase 2: Major Refactors (Days 11-15)
- [ ] FoodPreferenceWidget (convert chips to slider)
- [ ] ExpandableFoodItem (update styling)
- [ ] MacroTargetsWidget (convert to table)
- [ ] CustomAppBar (update styling)
- [ ] BottomNavBar (update colors)

### Phase 3: New Components (Days 16-20)
- [ ] SegmentedControl (replace dropdown/slider)
- [ ] LargeStatDisplay
- [ ] AddFoodButton
- [ ] DatePicker (refactor existing)
- [ ] TimePicker (refactor existing)

### Phase 4: Screen Migration (Days 21-50)
- [ ] New Activity Screen (Day 21-25)
- [ ] Activity Detail Screen (Day 26-30)
- [ ] Calendar Views (Day 31-35)
- [ ] Adjust Macros Screen (Day 36-40)
- [ ] Food Preferences Screen (Day 41-45)
- [ ] All remaining screens (Day 46-50)

### Phase 5: Testing & Polish (Days 51-60)
- [ ] Test all screens in light mode
- [ ] Test all screens in dark mode
- [ ] Cross-platform testing
- [ ] Performance optimization
- [ ] Designer approval

---

## 🧪 Testing Requirements

### Per Component
- [ ] Unit tests (logic)
- [ ] Widget tests (rendering)
- [ ] Golden tests (visual regression)
- [ ] Light mode test
- [ ] Dark mode test

### Per Screen
- [ ] Integration test (full flow)
- [ ] iOS test
- [ ] Android test
- [ ] Accessibility test
- [ ] Performance test

### Pre-Release
- [ ] All tests passing (100%)
- [ ] No analyzer warnings
- [ ] Designer approval
- [ ] Product owner approval
- [ ] QA sign-off

---

## 🎨 Design Resources

### Fonts
**Available in Project:**
- Sansita → Available in assets/fonts/Sansita/
- Compadre → Demo versions in assets/fonts/Compadre/
- Apercu → Pro versions in assets/fonts/Apercu/

**Note:** Compadre fonts are demo versions. Full commercial license may be needed for production.

### Icons
**Using:** Font Awesome Free (via font_awesome_flutter package)
**Note:** Sufficient icons available without Pro subscription

### Assets
All exported assets should be placed in:
```
assets/
├── fonts/           # Custom fonts
├── icons/           # SVG icons
└── images/
    └── kyle_redesign/
        ├── runner@2x.png
        ├── runner@3x.png
        ├── cyclist@2x.png
        ├── cyclist@3x.png
        └── ... (other hero images)
```

---

## 🚨 Common Issues & Solutions

### Fonts Not Showing
**Problem:** Text appears in default font
**Solution:**
```bash
flutter clean
flutter pub get
flutter run
```
Verify `pubspec.yaml` font paths are correct

### Colors Look Different
**Problem:** Colors don't match Figma
**Solution:** Use exact hex values from DESIGN_TOKENS.md. Check device brightness and color profile.

### Dark Mode Not Working
**Problem:** Theme doesn't switch
**Solution:** Verify `ThemeMode` is set to `system` or controlled by provider. Check system theme settings.

### Components Look Off
**Problem:** Spacing or sizing issues
**Solution:** Verify using 8pt grid. Check padding vs margin. Use Flutter Inspector to debug.

---

## 📞 Getting Help

### Documentation Questions
- **Design Tokens:** See [DESIGN_TOKENS.md](./DESIGN_TOKENS.md)
- **Component Specs:** See [COMPONENTS_CATALOG.md](./COMPONENTS_CATALOG.md)
- **Implementation Steps:** See [IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md)

### Technical Issues
- Flutter docs: https://docs.flutter.dev
- Riverpod docs: https://riverpod.dev
- Project CLAUDE.md: `/CLAUDE.md`

### Design Questions
- Figma file: [Kyle's Mockups](https://www.figma.com/design/4FvaeGejofuETyP5LUIxQK/Kyle-s-Mockups)
- Contact designer: Kyle

---

## 📝 Notes

### Design Philosophy
- **Mobile-first:** Optimized for iOS and Android
- **Accessible:** WCAG 2.1 AA compliant
- **Performant:** 60fps target on all devices
- **Athletic:** Colors and imagery reflect athletic brand
- **Clean:** Minimal, uncluttered interfaces
- **Dual-mode:** Sophisticated dark + clean light

### Architecture Compliance
- **FOA Pattern:** All changes in presentation layer only
- **Riverpod:** State management with `@riverpod` AsyncNotifier
- **No Breaking Changes:** Existing business logic untouched
- **Backward Compatible:** Can coexist with old components during migration

### Future Considerations
- Animation library for micro-interactions
- Component documentation site (Storybook-style)
- Design system package for reuse
- Automated visual regression testing

---

## 🎉 Success Criteria

### Definition of Done
- ✅ 95%+ visual match with Figma designs
- ✅ Both themes (light & dark) working perfectly
- ✅ All existing features functional (no regressions)
- ✅ Zero analyzer errors or warnings
- ✅ 80%+ test coverage on refactored components
- ✅ Works on iOS and Android
- ✅ Passes accessibility audit
- ✅ No performance degradation
- ✅ Designer approval obtained
- ✅ User feedback positive
- ✅ All 51 screens migrated to new design

### Metrics to Track
- **Visual Accuracy:** 95%+ match
- **Performance:** <16ms frame render time (60fps)
- **Test Coverage:** 80%+ on new components
- **Bug Count:** <10 critical issues
- **User Satisfaction:** 4.5/5+ rating

---

## 📅 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-12 | Initial documentation from Figma analysis |
| - | - | Implementation begins |

---

**Ready to start? Head to [IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md) for step-by-step instructions!** 🚀

---

**Document Maintainer:** Development Team
**Last Reviewed:** 2025-11-12
**Status:** Complete ✅
