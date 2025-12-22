# CLAUDE.md Update - Flutter Flavors Section

Add this section to your `/CLAUDE.md` file under the "Development Practices" section:

---

### Flutter Flavors

The app uses Flutter flavors to separate development and production environments:

**Flavors:**
- **dev**: Development environment (dev Supabase, dev Mixpanel, development Sentry)
- **prod**: Production environment (prod Supabase, prod Mixpanel, production Sentry)

**Key Characteristics:**
- **Side-by-side installation**: Both flavors can be installed on the same device
- **Build-time configuration**: Environment determined at compile time (no runtime switching)
- **Flavor-specific entry points**: `main_dev.dart` and `main_prod.dart`
- **Environment files**: `.env.dev.local` and `.env.prod.local` must include `APP_ENVIRONMENT` variable

**Running Flavors:**
```bash
# Development
flutter run --flavor dev -t lib/main_dev.dart

# Production
flutter run --flavor prod -t lib/main_prod.dart
```

**Building Flavors:**
```bash
# Dev release
flutter build appbundle --flavor dev -t lib/main_dev.dart --release

# Prod release
flutter build appbundle --flavor prod -t lib/main_prod.dart --release
```

**App Identification:**
- Dev: "Mealvana Endurance Dev" (com.mealvana.endurance.dev / com.milkman.mealvanaendurance.dev)
- Prod: "Mealvana Endurance" (com.mealvana.endurance / com.milkman.mealvanaendurance)

**Visual Indicators:**
- Dev flavor shows amber wrench icon (top-right corner)
- Prod flavor has clean interface (no indicator)

**Shorebird Integration:**
- Dev flavor: No Shorebird (not needed for development)
- Prod flavor: Standard Shorebird workflow with `--flavor prod -t lib/main_prod.dart` flags

**iOS Setup:**
- Requires one-time Xcode configuration (see `/docs/flavors/XCODE_SETUP_INSTRUCTIONS.md`)
- Build configurations: dev-Debug, dev-Profile, dev-Release, prod-Debug, prod-Profile, prod-Release
- Schemes: dev and prod (must be marked as "Shared")

**Architecture Notes:**
- Removed runtime environment switching (no more secret settings panel)
- `AppConfig` simplified (no SharedPreferences dependency for environment)
- Follows Andrea Bizzotto's initialization pattern
- Compatible with FOA architecture

📚 **Full Documentation**: [/docs/flavors/README.md](/docs/flavors/README.md)
📖 **Usage Guide**: [/docs/flavors/USAGE.md](/docs/flavors/USAGE.md)
🔧 **iOS Setup**: [/docs/flavors/XCODE_SETUP_INSTRUCTIONS.md](/docs/flavors/XCODE_SETUP_INSTRUCTIONS.md)

---

## Alternative: Just add this concise version

If you prefer a shorter note, use this instead:

---

### Flutter Flavors

The app supports **dev** and **prod** flavors for environment separation:

```bash
# Run dev
flutter run --flavor dev -t lib/main_dev.dart

# Run prod
flutter run --flavor prod -t lib/main_prod.dart
```

**Key Points:**
- Both flavors installable side-by-side (different bundle IDs)
- Environment determined at build time (no runtime switching)
- Dev: shows wrench indicator, dev Supabase
- Prod: clean interface, prod Supabase, Shorebird enabled

📚 **Documentation**: [/docs/flavors/](/docs/flavors/)

---

## Location in CLAUDE.md

Insert this after the "Build & Deployment" section or create a new "Flavors & Environments" section under "Development Practices".
