# iOS Xcode Configuration for Flavors

## Overview
The xcconfig files and Info.plist have been updated. You now need to configure Xcode to use these files.

## Prerequisites
- Xcode installed
- Project files updated (xcconfig files created, Info.plist modified)

## Step 1: Open Project in Xcode
```bash
open ios/Runner.xcworkspace
```

**Important:** Open the `.xcworkspace` file, NOT the `.xcodeproj` file (required for CocoaPods).

## Step 2: Create Build Configurations

1. In Xcode, select the **Runner** project in the left sidebar (blue icon)
2. Select the **Runner** project (not target) in the main editor
3. Click the **Info** tab
4. Under **Configurations**, you'll see Debug, Release, and Profile

### Duplicate Configurations for Dev Flavor:

For each existing configuration, create a dev variant:

**Debug:**
1. Click the **+** button below the configurations list
2. Select **Duplicate "Debug" Configuration**
3. Name it: `dev-Debug`

**Profile:**
1. Click the **+** button
2. Select **Duplicate "Profile" Configuration**
3. Name it: `dev-Profile`

**Release:**
1. Click the **+** button
2. Select **Duplicate "Release" Configuration**
3. Name it: `dev-Release`

### Duplicate Configurations for Prod Flavor:

**Debug:**
1. Click the **+** button
2. Select **Duplicate "Debug" Configuration**
3. Name it: `prod-Debug`

**Profile:**
1. Click the **+** button
2. Select **Duplicate "Profile" Configuration**
3. Name it: `prod-Profile`

**Release:**
1. Click the **+** button
2. Select **Duplicate "Release" Configuration**
3. Name it: `prod-Release`

### Final Configuration List:

You should now have 9 configurations total:
- Debug (original)
- Profile (original)
- Release (original)
- dev-Debug
- dev-Profile
- dev-Release
- prod-Debug
- prod-Profile
- prod-Release

## Step 3: Associate xcconfig Files with Configurations

1. In the **Configurations** section, you'll see a disclosure triangle next to each configuration
2. Click the triangle to expand and see "Runner" target
3. For each configuration, click on the value column (should show "None" or a previous config)

**Associate the xcconfig files:**

- **dev-Debug** → `dev-Debug.xcconfig` (in Flutter folder)
- **dev-Profile** → `dev-Profile.xcconfig` (in Flutter folder)
- **dev-Release** → `dev-Release.xcconfig` (in Flutter folder)
- **prod-Debug** → `prod-Debug.xcconfig` (in Flutter folder)
- **prod-Profile** → `prod-Profile.xcconfig` (in Flutter folder)
- **prod-Release** → `prod-Release.xcconfig` (in Flutter folder)

**Leave the original configurations as-is:**
- Debug → `Debug.xcconfig`
- Profile → `Profile.xcconfig`
- Release → `Release.xcconfig`

## Step 4: Create Schemes

### Create Dev Scheme:

1. In Xcode menu: **Product** → **Scheme** → **Manage Schemes...**
2. Click the **+** button at bottom left
3. Name: `dev`
4. Target: `Runner`
5. Click **OK**

### Configure Dev Scheme:

1. Select the `dev` scheme and click **Edit...**
2. For each action on the left (Run, Test, Profile, Analyze, Archive):
   - **Run**: Build Configuration = `dev-Debug`
   - **Test**: Build Configuration = `dev-Debug`
   - **Profile**: Build Configuration = `dev-Profile`
   - **Analyze**: Build Configuration = `dev-Debug`
   - **Archive**: Build Configuration = `dev-Release`
3. Click **Close**

### Create Prod Scheme:

1. Click the **+** button again
2. Name: `prod`
3. Target: `Runner`
4. Click **OK**

### Configure Prod Scheme:

1. Select the `prod` scheme and click **Edit...**
2. For each action:
   - **Run**: Build Configuration = `prod-Debug`
   - **Test**: Build Configuration = `prod-Debug`
   - **Profile**: Build Configuration = `prod-Profile`
   - **Analyze**: Build Configuration = `prod-Debug`
   - **Archive**: Build Configuration = `prod-Release`
3. Click **Close**

## Step 5: Mark Schemes as Shared (CRITICAL!)

**This step is required for Flutter CLI to detect the flavors.**

1. In **Manage Schemes** window, check the **Shared** checkbox for:
   - ✅ `dev` scheme
   - ✅ `prod` scheme
   - ✅ `Runner` scheme (if not already checked)
2. Click **Close**

## Step 6: Verify Bundle Identifiers

1. Select the **Runner** target (not project)
2. Go to **Build Settings** tab
3. Search for "Product Bundle Identifier"
4. Click the disclosure triangles to expand and verify:
   - `dev-Debug`: `com.mealvana.endurance.dev`
   - `dev-Profile`: `com.mealvana.endurance.dev`
   - `dev-Release`: `com.mealvana.endurance.dev`
   - `prod-Debug`: `com.mealvana.endurance`
   - `prod-Profile`: `com.mealvana.endurance`
   - `prod-Release`: `com.mealvana.endurance`

If these don't match, the xcconfig files aren't being applied correctly. Go back to Step 3.

## Step 7: Run Pod Install

The flavor configurations may require CocoaPods to regenerate its files:

```bash
cd ios
pod install
cd ..
```

## Verification

Test that Xcode can build each flavor:

### Command Line (from project root):

```bash
# Dev flavor
flutter run --flavor dev

# Prod flavor
flutter run --flavor prod
```

### Xcode IDE:

1. Select `dev` scheme from the scheme selector (top toolbar)
2. Select a simulator or device
3. Click **Run** (⌘R)
4. App should launch with name "Mealvana Endurance Dev"

5. Select `prod` scheme
6. Click **Run**
7. App should launch with name "Mealvana Endurance"

Both apps can be installed side-by-side since they have different bundle IDs.

## Troubleshooting

### "No flavor named 'dev' found"

**Cause:** Schemes not marked as Shared.

**Fix:**
1. Product → Scheme → Manage Schemes
2. Check "Shared" for dev and prod schemes
3. Commit the scheme files to git:
   ```bash
   git add ios/Runner.xcodeproj/xcshareddata/xcschemes/
   ```

### "Failed to register bundle identifier"

**Cause:** Bundle ID already in use or not configured in Apple Developer Portal.

**Fix:**
1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list)
2. Register `com.mealvana.endurance.dev` as a new App ID
3. Create development provisioning profile for dev flavor
4. Download and install provisioning profile in Xcode

### "Build configuration file not found"

**Cause:** xcconfig files not in correct location or not associated.

**Fix:**
1. Verify files exist in `ios/Flutter/` folder
2. Re-associate in Xcode (Step 3 above)
3. Clean build folder: **Product** → **Clean Build Folder** (⇧⌘K)

## Next Steps

After completing Xcode configuration:
1. Test builds for both flavors
2. Continue with Flutter code updates (main_dev.dart, main_prod.dart)
3. Update AppConfig service
4. Test end-to-end

## Reference

- Bundle IDs:
  - Dev: `com.mealvana.endurance.dev`
  - Prod: `com.mealvana.endurance`
- App Names:
  - Dev: "Mealvana Endurance Dev"
  - Prod: "Mealvana Endurance"
- Schemes: `dev`, `prod`
- Build Configurations: `dev-Debug`, `dev-Profile`, `dev-Release`, `prod-Debug`, `prod-Profile`, `prod-Release`
