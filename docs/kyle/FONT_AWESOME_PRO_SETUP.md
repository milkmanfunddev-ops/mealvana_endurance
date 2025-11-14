# Font Awesome Pro Setup Guide
**For Kyle's Design System Implementation**

---

## Overview

Kyle's design system uses **Font Awesome 7 Pro Sharp Regular** for all icons throughout the app. This includes:
- Food icons (36px circles with Electrolyte background)
- Activity icons (36px circles with Electrolyte background)
- UI icons (navigation, actions, controls)

---

## Package Installation

### 1. Add Font Awesome Pro Flutter Package

Add to `pubspec.yaml`:

```yaml
dependencies:
  font_awesome_flutter_pro: ^1.0.2  # Or latest version
```

### 2. Configure Font Awesome Pro Credentials

You'll need Font Awesome Pro credentials. Two options:

**Option A: Using API Token**
```yaml
# In your CI/CD or local environment
export FA_PRO_TOKEN=your_token_here
```

**Option B: Manual Font Files**
If you have the Pro font files, you can add them directly:
```yaml
flutter:
  fonts:
    - family: Font Awesome 7 Sharp
      fonts:
        - asset: fonts/fa-sharp-solid-900.ttf
```

### 3. Run Flutter Pub Get

```bash
flutter pub get
```

---

## Icon Usage

### Food Icons (from Figma)

```dart
import 'package:font_awesome_flutter_pro/font_awesome_flutter_pro.dart';

// Icon mapping from Kyle's designs:
const foodIconMap = {
  'energy_bar': FontAwesomeIcons.bars,           // or similar
  'sports_drink': FontAwesomeIcons.bottleWater,
  'banana': FontAwesomeIcons.appleWhole,
  'salt_packets': FontAwesomeIcons.square,
  'water': FontAwesomeIcons.droplet,
  'gel': FontAwesomeIcons.bag,
  'electrolyte': FontAwesomeIcons.circle,
  'trail_mix': FontAwesomeIcons.bowlFood,
};

// Usage in widget:
Container(
  width: 36,
  height: 36,
  decoration: BoxDecoration(
    color: Color(0xFF1CF9CF), // Electrolyte background
    shape: BoxShape.circle,
  ),
  child: Icon(
    foodIconMap['energy_bar'],
    size: 18,
    color: Color(0xFF381633), // Blackberry icon color
  ),
)
```

### Activity Icons

```dart
const activityIconMap = {
  'running': FontAwesomeIcons.personRunning,
  'cycling': FontAwesomeIcons.personBiking,
  'swimming': FontAwesomeIcons.personSwimming,
};

// Same 36px circle with Electrolyte background
```

### UI Icons (from extracted Figma code)

| Icon | Font Awesome | Size | Usage |
|------|--------------|------|-------|
| Plus | `FontAwesomeIcons.plus` | 20px | Plus/minus controls, add buttons |
| Minus | `FontAwesomeIcons.minus` | 20px | Plus/minus controls |
| Heart | `FontAwesomeIcons.heart` | 20px | Love preference |
| X Mark | `FontAwesomeIcons.xmark` | 15px | Avoid preference, remove |
| Check | `FontAwesomeIcons.check` | 20px | Complete action |
| Chevron Down | `FontAwesomeIcons.chevronDown` | 16px | Expandable items |
| Chevron Up | `FontAwesomeIcons.chevronUp` | 16px | Expanded items |
| Arrow Left | `FontAwesomeIcons.arrowLeft` | 20px | Back button |
| Calendar | `FontAwesomeIcons.calendar` | 24px | Calendar view |
| Ellipsis | `FontAwesomeIcons.ellipsis` | 24px | Menu |

---

## Icon Component (Reusable)

Create a reusable icon component:

```dart
// lib/shared/widgets/kyle_design/icons/circular_icon.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter_pro/font_awesome_flutter_pro.dart';

class CircularIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color backgroundColor;
  final Color iconColor;
  final double iconSize;

  const CircularIcon({
    Key? key,
    required this.icon,
    this.size = 36.0,
    this.backgroundColor = const Color(0xFF1CF9CF), // Electrolyte
    this.iconColor = const Color(0xFF381633), // Blackberry
    this.iconSize = 18.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: iconColor,
        ),
      ),
    );
  }
}

// Usage:
CircularIcon(
  icon: FontAwesomeIcons.personRunning,
  size: 36,
  backgroundColor: AppColors.electrolyte,
  iconColor: AppColors.blackberry,
  iconSize: 18,
)
```

---

## Icon Sizes from Kyle's Design

| Context | Container Size | Icon Size | Notes |
|---------|---------------|-----------|-------|
| Food/Activity Icon | 36px circle | 18px | Main icon system |
| Plus/Minus Control | 36px container | 20px | With 8px padding |
| Navigation Icons | N/A | 24px | Bottom nav |
| Small UI Icons | N/A | 15-16px | Inline actions |
| Large UI Icons | N/A | 20px | Prominent actions |

---

## Font Awesome 7 Sharp Regular

**Important:** Kyle's design specifically uses **Font Awesome 7 Sharp Regular**

The "Sharp" style has:
- Clean, geometric edges
- Consistent line weights
- Modern look

Make sure you're using the Sharp variant, not Solid or Brands.

```dart
// Correct:
import 'package:font_awesome_flutter_pro/font_awesome_flutter_pro.dart';

Icon(
  FontAwesomeIcons.sharpRegular.personRunning, // Sharp Regular
  size: 18,
)

// NOT:
Icon(
  FontAwesomeIcons.solid.personRunning, // Wrong style
  size: 18,
)
```

---

## Troubleshooting

### Icons Not Showing
1. Verify Font Awesome Pro credentials are configured
2. Run `flutter clean && flutter pub get`
3. Restart your IDE/editor
4. Check that you're using the Pro package, not the free version

### Wrong Icon Style
- Make sure you're using `sharpRegular` variant
- Kyle's design uses Sharp Regular, not Solid or Light

### Icon Size Issues
- Use exact sizes from Kyle's design:
  - Food/Activity icons: 18px (in 36px circle)
  - Control icons: 20px
  - Navigation icons: 24px
- Don't use relative sizes like `IconTheme` sizes

---

## Complete Icon Mapping Reference

Once Font Awesome Pro is set up, create a comprehensive icon map:

```dart
// lib/shared/constants/icon_map.dart

import 'package:font_awesome_flutter_pro/font_awesome_flutter_pro.dart';

class AppIcons {
  // Food Icons
  static const energyBar = FontAwesomeIcons.sharpRegular.bars;
  static const sportsDrink = FontAwesomeIcons.sharpRegular.bottleWater;
  static const banana = FontAwesomeIcons.sharpRegular.appleWhole;
  static const water = FontAwesomeIcons.sharpRegular.droplet;
  static const gel = FontAwesomeIcons.sharpRegular.bag;
  static const saltPacket = FontAwesomeIcons.sharpRegular.square;
  static const electrolyte = FontAwesomeIcons.sharpRegular.circle;
  static const trailMix = FontAwesomeIcons.sharpRegular.bowlFood;

  // Activity Icons
  static const running = FontAwesomeIcons.sharpRegular.personRunning;
  static const cycling = FontAwesomeIcons.sharpRegular.personBiking;
  static const swimming = FontAwesomeIcons.sharpRegular.personSwimming;

  // UI Icons
  static const plus = FontAwesomeIcons.sharpRegular.plus;
  static const minus = FontAwesomeIcons.sharpRegular.minus;
  static const heart = FontAwesomeIcons.sharpRegular.heart;
  static const xmark = FontAwesomeIcons.sharpRegular.xmark;
  static const check = FontAwesomeIcons.sharpRegular.check;
  static const chevronDown = FontAwesomeIcons.sharpRegular.chevronDown;
  static const chevronUp = FontAwesomeIcons.sharpRegular.chevronUp;
  static const arrowLeft = FontAwesomeIcons.sharpRegular.arrowLeft;
  static const calendar = FontAwesomeIcons.sharpRegular.calendar;
  static const ellipsis = FontAwesomeIcons.sharpRegular.ellipsis;
  static const search = FontAwesomeIcons.sharpRegular.magnifyingGlass;
  static const barcode = FontAwesomeIcons.sharpRegular.barcode;
  static const clock = FontAwesomeIcons.sharpRegular.clock;
  static const fire = FontAwesomeIcons.sharpRegular.fire;
}
```

---

## Next Steps

1. Add Font Awesome Pro package to `pubspec.yaml`
2. Configure credentials
3. Create `AppIcons` constant class
4. Create `CircularIcon` reusable component
5. Replace all existing icon implementations with Font Awesome Pro
6. Verify all icons use Electrolyte (#1CF9CF) background

---

**Status:** Ready for implementation in Phase 0
