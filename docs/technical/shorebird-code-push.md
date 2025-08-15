# Shorebird Code Push Integration

## Overview

Shorebird enables over-the-air (OTA) updates for Flutter applications, allowing instant deployment of code changes without App Store/Play Store approval. This is particularly valuable for bug fixes and small feature updates.

## What is Shorebird?

Shorebird is a code push service that allows developers to push updates directly to users' devices, bypassing the traditional app store review process. It uses a modified Flutter engine that checks for updates on app startup.

### Key Benefits

- **Instant Updates**: Deploy fixes and features immediately
- **No Store Review**: Bypass App Store/Play Store approval delays
- **Store Compliant**: Adheres to all store guidelines
- **Full Dart Support**: Update any Dart code in your application
- **Easy Integration**: Setup takes minutes

## How It Works

### Core Concepts

1. **Release**: Full app binary with modified Flutter engine
   - Contains complete Flutter app
   - Includes custom engine with update capabilities
   - Must go through normal store review process

2. **Patch**: Code-only update delivered over-the-air
   - Contains only changed Dart code
   - Delivered instantly to users
   - Applied on next app restart

### Update Process

1. App starts with modified Flutter engine
2. Engine checks for available patches
3. If patch available, downloads in background
4. User sees update on next app restart
5. Fallback to original code if patch fails

## What Can Be Updated

### Supported Changes
- ✅ Any Dart code changes
- ✅ Dependencies in `pubspec.yaml`
- ✅ Generated code (including localizations)
- ✅ Business logic and UI updates
- ✅ Bug fixes and optimizations

### Limitations
- ❌ Flutter version changes (e.g., 3.24 → 3.25)
- ❌ Native code changes (iOS/Android platform code)
- ❌ New native permissions
- ❌ Structural app changes requiring store review

## Platform Support

- ✅ **iOS**: Full support
- ✅ **Android**: Full support
- 🔄 **Desktop**: Planned for future release
- ❌ **Web**: Not supported (browser security restrictions)

## Installation & Setup

### 1. Install Shorebird CLI

```bash
curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | sh
```

### 2. Authentication

```bash
shorebird login
```

### 3. Initialize Project

```bash
# In your Flutter project root
shorebird init
```

This creates a `shorebird.yaml` file with your unique `app_id`.

### 4. Verify Setup

```bash
shorebird doctor
```

## Development Workflow

### Creating a Release

```bash
# Build and upload initial release
shorebird release android
shorebird release ios
```

### Creating Patches

```bash
# Create and deploy a patch
shorebird patch android
shorebird patch ios
```

### Preview Changes

```bash
# Test patches locally before deployment
shorebird preview
```

## Integration Considerations

### Bundle ID Requirements
- Ensure your bundle ID is properly configured
- Current: `com.milkman.mealvanaendurance`
- Must match across releases and patches

### Testing Strategy
- Test patches thoroughly in staging
- Use `shorebird preview` for local testing
- Consider gradual rollout strategies

### Monitoring
- Monitor patch adoption rates
- Track download success/failure rates
- Have rollback plan for problematic patches

## CI/CD Integration

Shorebird integrates well with CI/CD pipelines:

```yaml
# Example GitHub Actions integration
- name: Install Shorebird
  run: |
    curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | sh
    echo "$HOME/.shorebird/bin" >> $GITHUB_PATH

- name: Create Patch
  run: shorebird patch android --force
  env:
    SHOREBIRD_TOKEN: ${{ secrets.SHOREBIRD_TOKEN }}
```

## Security & Compliance

### Store Guidelines
- **App Store**: Compliant with App Store Review Guidelines
- **Play Store**: Uses Dart VM (interpreter-based updates allowed)
- **Code Signing**: All patches are cryptographically signed

### Best Practices
- Only patch critical bugs and small features
- Avoid major UI/UX changes in patches
- Test patches extensively before deployment
- Maintain audit trail of all deployments

## MVP Implementation Plan

### Phase 1: Setup (Current Phase)
1. ✅ Install Shorebird CLI
2. ✅ Update bundle ID configuration
3. 🔄 Initialize Shorebird in project
4. 🔄 Create initial release builds

### Phase 2: Testing
1. Create test patches for minor changes
2. Validate patch deployment process
3. Test rollback procedures
4. Verify analytics integration

### Phase 3: Production
1. Deploy initial release to stores
2. Monitor for critical bugs
3. Use patches for quick fixes
4. Establish update cadence

## Cost Considerations

- Free tier available for development/testing
- Usage-based pricing for production
- Monitor patch installation counts with:
  ```bash
  shorebird account usage
  ```

## Emergency Procedures

### Rolling Back Patches
```bash
# Promote previous patch to rollback
shorebird patch promote --patch-number <previous_number>
```

### Debug Issues
```bash
# Check environment and connectivity
shorebird doctor

# View patch history
shorebird patches list
```

## Future Enhancements

- Desktop support (coming soon)
- Enhanced analytics integration
- Gradual rollout capabilities
- A/B testing for patches

## Resources

- [Official Documentation](https://docs.shorebird.dev/)
- [GitHub Repository](https://github.com/shorebirdtech/shorebird)
- [Community Discord](https://discord.gg/shorebird)

---

**Status**: Ready for implementation  
**Last Updated**: 2024-08-15  
**Bundle ID**: `com.milkman.mealvanaendurance`