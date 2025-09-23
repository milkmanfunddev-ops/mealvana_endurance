# Endurance Branding Update Roadmap

**Version**: 1.0
**Target Platform**: iOS (Primary)
**Date**: September 2025

## Overview

This document outlines the comprehensive branding update from "Mealvana Endurance" to "Endurance" with the new Blackberry-based color palette. The update includes app name changes, new logo implementation, complete theme color migration, and asset updates.

---

## 🎨 New Brand Identity

### Color Palette Mapping

| **Element** | **Current** | **New Endurance** | **Hex Code** |
|-------------|-------------|-------------------|--------------|
| **Primary Dark** | primary900 (#001C71) | **Blackberry** | `#381633` |
| **Primary** | primary600 (#3366FF) | **Blackberry** | `#381633` |
| **Primary Light** | primary100 (#D6E0FF) | **Blackberry Light** | `#6B4C57` |
| **Background** | baseCream (#F8F6EB) | **Cream** | `#F8F6EB` |
| **Secondary** | highlight600 (#D92D20) | **Orange** | `#F798B4` |
| **Accent** | N/A | **Electrolyte** | `#1CF9CF` |

### Logo Assets Available

```
docs/features/update_branding/Endurance Logos/
├── Mealvana Endurance Blackberry.svg     # Full wordmark (primary)
├── Mealvana Endurance Cream.svg          # Full wordmark (light)
├── Mealvana Logomark Blackberry.svg      # Icon only (launcher)
├── Mealvana Logomark Cream.svg           # Icon only (light)
└── Mealvana Reversed - Blackberry.svg    # Reversed version
```

---

## 📋 Implementation Phases

### Phase 1: Asset Preparation & Backup
**Estimated Time**: 2 hours

#### 1.1 Backup Current Assets
```bash
# Create backup directory
mkdir -p assets/backup/old_branding_$(date +%Y%m%d)

# Backup current assets
cp assets/images/main_icon.png assets/backup/old_branding_$(date +%Y%m%d)/
cp assets/images/main_icon_no_text.png assets/backup/old_branding_$(date +%Y%m%d)/
cp assets/images/app_icon_background.png assets/backup/old_branding_$(date +%Y%m%d)/
cp assets/images/app_icon_foreground.png assets/backup/old_branding_$(date +%Y%m%d)/

# Backup theme file
cp lib/theme/app_theme.dart assets/backup/old_branding_$(date +%Y%m%d)/
```

#### 1.2 Convert SVG Assets to Required Formats

**Launcher Icon (Logomark)**:
```bash
# Convert logomark to PNG for launcher icons
# Required sizes for iOS:
# - 1024x1024 (App Store)
# - 180x180 (@3x)
# - 120x120 (@2x)
# - 60x60 (@1x)

# Using ImageMagick or similar tool:
convert "docs/features/update_branding/Endurance Logos/Mealvana Logomark Blackberry.svg" \
  -resize 1024x1024 assets/images/endurance_launcher_icon_1024.png

convert "docs/features/update_branding/Endurance Logos/Mealvana Logomark Blackberry.svg" \
  -resize 180x180 assets/images/endurance_launcher_icon_180.png

# Generate adaptive icon components for Android (future use)
convert "docs/features/update_branding/Endurance Logos/Mealvana Logomark Blackberry.svg" \
  -resize 432x432 assets/images/endurance_adaptive_foreground.png
```

**Splash Screen (Full Wordmark)**:
```bash
# Convert full wordmark for splash screen
convert "docs/features/update_branding/Endurance Logos/Mealvana Endurance Blackberry.svg" \
  -resize 300x100 assets/images/endurance_splash_logo.png

# High-res version for @3x
convert "docs/features/update_branding/Endurance Logos/Mealvana Endurance Blackberry.svg" \
  -resize 900x300 assets/images/endurance_splash_logo@3x.png
```

**Welcome Screen Logo**:
```bash
# Convert logomark for welcome screen (smaller size)
convert "docs/features/update_branding/Endurance Logos/Mealvana Logomark Blackberry.svg" \
  -resize 120x120 assets/images/endurance_welcome_logo.png
```

### Phase 2: App Name Updates
**Estimated Time**: 30 minutes

#### 2.1 iOS App Name Changes

**File**: `ios/Runner/Info.plist`
```xml
<!-- BEFORE -->
<key>CFBundleDisplayName</key>
<string>Mealvana Endurance</string>

<!-- AFTER -->
<key>CFBundleDisplayName</key>
<string>Endurance</string>
```

**File**: `ios/Runner.xcodeproj/project.pbxproj`
```diff
# Replace all instances (3 locations):
- INFOPLIST_KEY_CFBundleDisplayName = "Mealvana Endurance";
+ INFOPLIST_KEY_CFBundleDisplayName = "Endurance";
```

#### 2.2 Android App Name Changes (Future)
**File**: `android/app/src/main/AndroidManifest.xml`
```xml
<!-- BEFORE -->
<application android:label="Mealvana Run" ...>

<!-- AFTER -->
<application android:label="Endurance" ...>
```

### Phase 3: Theme Color Migration
**Estimated Time**: 3 hours

#### 3.1 Update Core Theme File

**File**: `lib/theme/app_theme.dart`

**New Color Constants**:
```dart
class AppTheme {
  // NEW ENDURANCE BRAND COLORS
  // Primary Blackberry Palette
  static const Color primary900 = Color(0xFF381633);  // Blackberry Dark
  static const Color primary600 = Color(0xFF381633);  // Blackberry
  static const Color primary400 = Color(0xFF6B4C57);  // Blackberry Medium
  static const Color primary100 = Color(0xFF9A7A85);  // Blackberry Light
  static const Color primary50 = Color(0xFFC8B3BC);   // Blackberry Very Light

  // Secondary Colors
  static const Color highlight600 = Color(0xFFF798B4); // Orange (was coral)
  static const Color highlight490 = Color(0xFFF798B4); // Orange
  static const Color highlight400 = Color(0xFFFBB1C9); // Orange Light
  static const Color highlight290 = Color(0xFFFDCADC); // Orange Lighter
  static const Color highlight100 = Color(0xFFFEE4EE); // Orange Very Light
  static const Color highlight50 = Color(0xFFFFF2F7);  // Orange Background

  // Accent Color
  static const Color accent600 = Color(0xFF1CF9CF);    // Electrolyte
  static const Color accent400 = Color(0xFF4CFBDD);    // Electrolyte Light
  static const Color accent100 = Color(0xFFB7FDF1);    // Electrolyte Very Light

  // Base Colors (unchanged)
  static const Color baseBlack = Color(0xFF000000);
  static const Color baseCream = Color(0xFFF8F6EB);    // Matches new Cream
  static const Color baseWhite = Color(0xFFFFFFFF);
  static const Color baseGrey = Color(0xFF667085);

  // Keep existing macro colors for now (as requested)
  static const Color proteinColor = Color(0xFFDC2597);
  static const Color carbsColor = Color(0xFFFFC629);
  static const Color fatsColor = Color(0xFF3366FF);
  static const Color caloriesColor = Color(0xFF001C71);
  static const Color sodiumColor = Color(0xFFFFC629);
  static const Color fluidsColor = Color(0xFF3366FF);

  // Status colors (update to use new palette)
  static const Color successColor = Color(0xFF1CF9CF);     // Electrolyte for success
  static const Color warningColor = Color(0xFFF798B4);     // Orange for warnings
  static const Color infoColor = Color(0xFF381633);        // Blackberry for info
```

#### 3.2 Theme Migration Impact Analysis

**Files Requiring Updates**: 60+ files using `AppTheme.primary600`, `AppTheme.primary900`, `AppTheme.primary100`

**High-Priority Files** (UI-critical):
1. `lib/features/onboarding/presentation/screens/welcome_screen.dart`
2. `lib/shared/widgets/primary_button.dart`
3. `lib/shared/widgets/tabs_screen.dart`
4. `lib/features/nutrition_plan/presentation/screens/current_plan_screen.dart`

**Medium-Priority Files** (Interactive elements):
- All files in `lib/features/settings/presentation/`
- All files in `lib/features/nutrition_plan/presentation/`
- All files in `lib/shared/widgets/`

**Low-Priority Files** (Detail elements):
- Files in `lib/features/feedback/presentation/`
- Files in `lib/features/user_journal/presentation/`

### Phase 4: Asset Implementation
**Estimated Time**: 1 hour

#### 4.1 Update Launcher Icons

**File**: `pubspec.yaml`
```yaml
# Flutter Launcher Icons configuration
flutter_launcher_icons:
  ios: true
  android: false  # Disable for now (iOS focus)
  image_path_ios: "assets/images/endurance_launcher_icon_1024.png"
  remove_alpha_ios: true
  # Comment out Android for now
  # android: true
  # image_path_android: "assets/images/endurance_launcher_icon_1024.png"
  # adaptive_icon_background: "assets/images/endurance_adaptive_background.png"
  # adaptive_icon_foreground: "assets/images/endurance_adaptive_foreground.png"
```

**Generate Icons**:
```bash
dart run flutter_launcher_icons
```

#### 4.2 Update Splash Screen

**File**: `pubspec.yaml`
```yaml
# Flutter Native Splash configuration
flutter_native_splash:
  color: "#381633"  # Blackberry background
  image: "assets/images/endurance_splash_logo.png"
  ios: true
  android: false  # Disable for iOS focus
```

**Generate Splash**:
```bash
dart run flutter_native_splash:create
```

#### 4.3 Update Welcome Screen Logo

**File**: `lib/features/onboarding/presentation/screens/welcome_screen.dart`

**Replace current icon with new logo**:
```dart
// BEFORE (lines 25-39)
Container(
  width: 120.w,
  height: 120.h,
  decoration: BoxDecoration(
    color: AppTheme.primary100,
    borderRadius: BorderRadius.circular(60.r),
    boxShadow: [AppTheme.dropShadow],
  ),
  child: Icon(
    Icons.run_circle,
    size: 64.w,
    color: AppTheme.primary600,
  ),
),

// AFTER
Container(
  width: 120.w,
  height: 120.h,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16.r),
    boxShadow: [AppTheme.dropShadow],
  ),
  child: Image.asset(
    'assets/images/endurance_welcome_logo.png',
    width: 120.w,
    height: 120.h,
    fit: BoxFit.contain,
  ),
),
```

### Phase 5: Content Management Updates
**Estimated Time**: 30 minutes

#### 5.1 Update UI Text via Content Service

**File**: `assets/config/content_defaults.json`

**Update welcome screen content**:
```json
{
  "ui_text": {
    "welcome_screen": {
      "title": "Endurance",
      "subtitle": "Personalized Nutrition Plans\nfor Long Run Days",
      // ... keep other fields
    }
  }
}
```

**Key Files Using Content Service**:
- `lib/features/onboarding/presentation/providers/welcome_screen_controller.dart`
- Content key: `ContentKeys.welcomeScreenTitle`

### Phase 6: Testing & Validation
**Estimated Time**: 2 hours

#### 6.1 Build and Test Process

**Analyze Code**:
```bash
flutter analyze
```

**Build iOS (Debug)**:
```bash
flutter build ios --debug
```

**Test on iOS Simulator**:
```bash
flutter run -d "iPhone 15 Pro"
```

#### 6.2 Visual Validation Checklist

**App Icon & Launch**:
- [ ] New Endurance logomark appears in iOS home screen
- [ ] App name displays as "Endurance" in iOS
- [ ] Splash screen shows full wordmark on Blackberry background

**Welcome Screen**:
- [ ] New logomark displays correctly (120x120)
- [ ] App title shows "Endurance"
- [ ] Colors use new Blackberry palette
- [ ] Feature icons use new primary colors

**Navigation & Buttons**:
- [ ] Primary buttons use Blackberry background (#381633)
- [ ] Tab bar icons use Blackberry color
- [ ] App bar backgrounds use correct colors

**Screens to Test**:
1. Welcome/Onboarding flow
2. Main nutrition plan screen
3. Settings screen
4. Current plan screen

#### 6.3 Automated Testing

**Color Verification Test**:
```dart
// Add to test/theme_test.dart
void main() {
  group('Endurance Theme Tests', () {
    test('Primary colors match Endurance brand', () {
      expect(AppTheme.primary900, const Color(0xFF381633));
      expect(AppTheme.primary600, const Color(0xFF381633));
    });

    test('Accent colors match Endurance brand', () {
      expect(AppTheme.accent600, const Color(0xFF1CF9CF));
    });
  });
}
```

---

## 🔄 Rollback Procedures

### Emergency Rollback (if critical issues found)

#### 1. Restore Theme File
```bash
cp assets/backup/old_branding_YYYYMMDD/app_theme.dart lib/theme/
```

#### 2. Restore App Name
```bash
# Revert iOS Info.plist changes
git checkout -- ios/Runner/Info.plist
git checkout -- ios/Runner.xcodeproj/project.pbxproj
```

#### 3. Restore Assets
```bash
# Restore old launcher icons
cp assets/backup/old_branding_YYYYMMDD/main_icon_no_text.png assets/images/
dart run flutter_launcher_icons

# Restore old splash
cp assets/backup/old_branding_YYYYMMDD/main_icon.png assets/images/
dart run flutter_native_splash:create
```

#### 4. Revert Code Changes
```bash
# If using git
git stash
# or
git reset --hard HEAD~1
```

---

## 📊 Progress Tracking

### Implementation Checklist

**Phase 1: Asset Preparation**
- [ ] Backup current assets
- [ ] Convert SVG to PNG (launcher icons)
- [ ] Convert SVG to PNG (splash screen)
- [ ] Convert SVG to PNG (welcome screen)

**Phase 2: App Name Updates**
- [ ] Update iOS Info.plist
- [ ] Update iOS project.pbxproj
- [ ] Verify name change in Xcode

**Phase 3: Theme Migration**
- [ ] Update app_theme.dart color constants
- [ ] Test theme compilation
- [ ] Verify no breaking changes

**Phase 4: Asset Implementation**
- [ ] Update pubspec.yaml launcher icons config
- [ ] Generate new launcher icons
- [ ] Update pubspec.yaml splash config
- [ ] Generate new splash screen
- [ ] Update welcome_screen.dart logo

**Phase 5: Content Updates**
- [ ] Update content_defaults.json
- [ ] Verify content service integration

**Phase 6: Testing & Validation**
- [ ] Run flutter analyze
- [ ] Build iOS debug
- [ ] Test on simulator
- [ ] Visual validation checklist
- [ ] Performance testing

---

## 🚨 Risk Mitigation

### Potential Issues & Solutions

**Issue**: SVG to PNG conversion quality loss
**Solution**: Use high-resolution source SVGs, convert at 2x-3x target size

**Issue**: Theme color conflicts in complex UI
**Solution**: Gradual rollout - test one feature at a time

**Issue**: Content management system caching
**Solution**: Clear app data/reinstall during testing

**Issue**: Build failures after asset changes
**Solution**: Clean build folder: `flutter clean && flutter pub get`

### Testing Device Matrix

**Primary Testing**:
- iPhone 15 Pro (iOS Simulator)
- Physical iPhone (if available)

**Secondary Testing**:
- iPad (iOS Simulator)
- Different iOS versions (15.0+)

---

## 📈 Success Metrics

### Completion Criteria

**Functional Requirements**:
- [ ] App launches with "Endurance" name
- [ ] New Blackberry color scheme throughout UI
- [ ] New logo assets display correctly
- [ ] No visual regressions or breaking changes
- [ ] App passes flutter analyze without new issues

**Visual Requirements**:
- [ ] Brand consistency across all screens
- [ ] Proper contrast ratios maintained
- [ ] Logo legibility at all sizes
- [ ] Smooth transitions and animations

**Performance Requirements**:
- [ ] No impact on app startup time
- [ ] Asset loading times remain acceptable
- [ ] Memory usage stays within normal ranges

---

## 🔧 Commands Reference

### Quick Setup Commands
```bash
# Backup and prepare
mkdir -p assets/backup/old_branding_$(date +%Y%m%d)
cp -r assets/images/* assets/backup/old_branding_$(date +%Y%m%d)/

# Generate new assets
dart run flutter_launcher_icons
dart run flutter_native_splash:create

# Test build
flutter clean
flutter pub get
flutter analyze
flutter build ios --debug
flutter run
```

### Asset Generation Commands
```bash
# Install ImageMagick (if needed)
brew install imagemagick

# Convert SVG to PNG at various sizes
convert input.svg -resize 1024x1024 output_1024.png
convert input.svg -resize 180x180 output_180.png
convert input.svg -resize 120x120 output_120.png
```

---

## 📝 Notes & Considerations

### Design Decisions Made

1. **Blackberry as Primary**: Using #381633 for both primary600 and primary900 to create strong brand consistency
2. **Logomark for Launcher**: Using logomark-only for launcher icons due to space constraints
3. **Full Wordmark for Splash**: Using complete "Mealvana Endurance" branding for splash screen
4. **iOS First**: Focusing on iOS implementation before Android
5. **Macro Colors Preserved**: Keeping existing nutrition-specific colors for user familiarity

### Future Considerations

1. **Android Implementation**: Follow similar process for Android branding
2. **A/B Testing**: Consider testing user response to new branding
3. **Marketing Materials**: Update app store screenshots and descriptions
4. **Documentation**: Update any developer documentation with new brand guidelines
5. **Analytics**: Track user engagement metrics before/after rebrand

---

**Document Version**: 1.0
**Last Updated**: September 2025
**Next Review**: After Phase 6 completion
