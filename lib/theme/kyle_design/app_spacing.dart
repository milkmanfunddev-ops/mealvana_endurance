import 'package:flutter/material.dart';

/// Kyle's Design System Spacing & Layout
/// 8pt grid system with exact specifications
class AppSpacing {
  AppSpacing._();

  // === Spacing Scale (8pt grid) ===
  static const double unit = 8.0;
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double huge = 48.0;

  // === Common Paddings ===

  // Screen padding
  static const EdgeInsets screenPadding = EdgeInsets.all(md);
  static const EdgeInsets screenPaddingHorizontal = EdgeInsets.symmetric(
    horizontal: md,
  );
  static const EdgeInsets screenPaddingVertical = EdgeInsets.symmetric(
    vertical: md,
  );

  // Card padding
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPaddingHorizontal = EdgeInsets.symmetric(
    horizontal: md,
  );
  static const EdgeInsets cardPaddingVertical = EdgeInsets.symmetric(
    vertical: md,
  );

  // Button padding
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: sm,
  );

  // List item padding
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  // Input padding
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: md,
  );

  // Section padding
  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: lg,
  );
}

/// Border radius specifications
class AppRadius {
  AppRadius._();

  // === Standard Radius Values ===
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double circular = 999.0;

  // === Pre-defined BorderRadius ===
  static const BorderRadius xxsRadius = BorderRadius.all(Radius.circular(xxs));
  static const BorderRadius xsRadius = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlRadius = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlRadius = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius circularRadius = BorderRadius.all(
    Radius.circular(circular),
  );

  // === Component-specific Radius ===

  // Buttons (100px fully rounded from Figma)
  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(100.0),
  );

  // Cards (15px from Figma)
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(15.0),
  );

  // Input fields (15px from Figma)
  static const BorderRadius inputRadius = BorderRadius.all(
    Radius.circular(15.0),
  );

  // Activity type selector (15px from Figma)
  static const BorderRadius activitySelectorRadius = BorderRadius.all(
    Radius.circular(15.0),
  );

  // Segmented control (15px from Figma)
  static const BorderRadius segmentedControlRadius = BorderRadius.all(
    Radius.circular(15.0),
  );
}

/// Shadow specifications
class AppShadows {
  AppShadows._();

  // === Light Theme Shadows ===

  // Light card shadow
  static List<BoxShadow> get lightCardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // Light elevated shadow
  static List<BoxShadow> get lightElevatedShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // === Dark Theme Shadows ===

  // Dark cards (no shadow per design)
  static List<BoxShadow> get darkCardShadow => [];

  // Dark elevated shadow
  static List<BoxShadow> get darkElevatedShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

/// Icon size specifications
class AppIconSizes {
  AppIconSizes._();

  // === Standard Icon Sizes ===
  static const double xxs = 12.0;
  static const double xs = 16.0;
  static const double sm = 20.0;
  static const double md = 24.0;
  static const double lg = 32.0;
  static const double xl = 48.0;
  static const double xxl = 64.0;

  // === Component-specific Icon Sizes ===

  // Tab bar icons
  static const double tabBar = 24.0;

  // List item icons
  static const double listItem = 24.0;

  // Button icons
  static const double button = 20.0;

  // Food icons (36px from Figma)
  static const double foodIcon = 36.0;

  // Activity icons (36px from Figma)
  static const double activityIcon = 36.0;

  // Plus/minus control icons (20px from Figma)
  static const double controlIcon = 20.0;

  // Info icons
  static const double info = 20.0;

  // Chevron icons
  static const double chevron = 20.0;
}

/// Component size specifications
class AppSizes {
  AppSizes._();

  // === Button Sizes ===

  // Primary button height (auto from content)
  static const double buttonHeightPrimary = 56.0;

  // Icon button size (48px from Figma)
  static const double buttonIconSize = 48.0;

  // Plus/minus control size (36px from Figma)
  static const double controlSize = 36.0;

  // === Input Sizes ===

  // Text field height (46px from Figma)
  static const double inputHeight = 46.0;

  // === Card Sizes ===

  // Activity type selector (62x74px from Figma)
  static const double activitySelectorWidth = 62.0;
  static const double activitySelectorHeight = 74.0;

  // === Icon Container Sizes ===

  // Food/activity icon container (36px from Figma)
  static const double iconContainerSize = 36.0;

  // === Calendar Sizes ===

  // Calendar day cell minimum size
  static const double calendarDayCellMin = 48.0;

  // Event indicator dot (6px from Figma)
  static const double eventDotSize = 6.0;
}
