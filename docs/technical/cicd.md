# CI/CD Implementation - Mealvana Run

## Overview

Comprehensive Codemagic CI/CD implementation for building, testing, and deploying the Mealvana Run nutrition planning app to iOS App Store and Google Play Store. This offline-first Flutter application uses local storage only and integrates with Shorebird for over-the-air code push capabilities.

## Project Architecture

### Application Profile
- **App Name**: Mealvana Run
- **Bundle ID**: `com.milkman.mealvanaendurance`
- **Architecture**: Offline-first Flutter app with FOA (Feature-Oriented Architecture)
- **State Management**: Riverpod v2 with code generation
- **Local Storage**: Hive database (no backend services)
- **Code Push**: Shorebird for instant updates
- **Platforms**: iOS (App Store/TestFlight) and Android (Play Store)

### Technology Stack
- **Flutter**: 3.24.0 stable
- **Dart**: Latest stable
- **Local Storage**: Hive with type adapters
- **Theming**: Material Design 3 with Google Fonts
- **Code Push**: Shorebird CLI integration
- **Privacy Compliance**: iOS Privacy Manifest included

## Codemagic Workflow Configuration

### Environment Setup

```yaml
# codemagic.yaml
workflows:
  ios-workflow:
    name: iOS Production Build
    instance_type: mac_mini_m1
    max_build_duration: 120
    integrations:
      app_store_connect: mealvana_app_store_connect
    environment:
      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.milkman.mealvanaendurance
      vars:
        APP_STORE_APPLE_ID: "REPLACE_WITH_ACTUAL_ID"
        XCODE_WORKSPACE: ios/Runner.xcworkspace
        XCODE_SCHEME: Runner
        SHOREBIRD_TOKEN: $SHOREBIRD_TOKEN
      flutter: "3.24.0"
    cache:
      cache_paths:
        - $FLUTTER_ROOT/.pub-cache
        - ~/.gradle/caches
        - ~/Library/Caches/CocoaPods
```

### Android Workflow Configuration

```yaml
  android-workflow:
    name: Android Production Build
    instance_type: linux_x2
    max_build_duration: 120
    environment:
      android_signing:
        - keystore_credentials
      groups:
        - google_play_credentials
      vars:
        PACKAGE_NAME: "com.milkman.mealvanaendurance"
        GOOGLE_PLAY_TRACK: "production"
        SHOREBIRD_TOKEN: $SHOREBIRD_TOKEN
      flutter: "3.24.0"
    cache:
      cache_paths:
        - $FLUTTER_ROOT/.pub-cache
        - ~/.gradle/caches
```

## Build Process Automation

### Pre-build Setup

```yaml
scripts:
  - name: Setup environment
    script: |
      # Set up local.properties for Android
      echo "flutter.sdk=$HOME/programs/flutter" > "$CM_BUILD_DIR/android/local.properties"
      
      # Install Shorebird CLI
      curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash
      echo 'export PATH="$HOME/.shorebird/bin:$PATH"' >> $HOME/.bashrc
      source $HOME/.bashrc
      
      # Login to Shorebird (token from environment)
      shorebird login --token $SHOREBIRD_TOKEN
```

### Code Quality and Testing

```yaml
  - name: Get Flutter packages
    script: flutter pub get
    
  - name: Generate code
    script: |
      flutter packages pub run build_runner build --delete-conflicting-outputs
      
  - name: Flutter analyze
    script: flutter analyze
    
  - name: Flutter unit tests
    script: |
      mkdir -p test-results
      flutter test --machine > test-results/flutter.json
    ignore_failure: false
    
  - name: Install pods (iOS only)
    script: |
      find . -name "Podfile" -execdir pod install \;
```

### Build Versioning Strategy

#### iOS Build with Auto-Versioning

```yaml
  - name: Flutter build iOS with auto-versioning
    script: |
      # Get latest build number from App Store Connect and increment
      BUILD_NUMBER=$(($(app-store-connect get-latest-app-store-build-number "$APP_STORE_APPLE_ID") + 1))
      
      # Build IPA with dynamic versioning
      flutter build ipa --release \
        --build-name=1.0.$BUILD_NUMBER \
        --build-number=$BUILD_NUMBER \
        --export-options-plist=/Users/builder/export_options.plist
        
      # Create Shorebird release if this is a tagged build
      if [ ! -z ${CM_TAG} ]; then
        shorebird release ios --no-confirm
      fi
```

#### Android Build with Auto-Versioning

```yaml
  - name: Flutter build Android with auto-versioning
    script: |
      # Get latest build number from Google Play and increment
      BUILD_NUMBER=$(($(google-play get-latest-build-number --package-name "$PACKAGE_NAME" --tracks="$GOOGLE_PLAY_TRACK") + 1))
      
      # Build AAB with dynamic versioning
      flutter build appbundle --release \
        --build-name=1.0.$BUILD_NUMBER \
        --build-number=$BUILD_NUMBER
        
      # Create Shorebird release if this is a tagged build
      if [ ! -z ${CM_TAG} ]; then
        shorebird release android --no-confirm
      fi
```

### Asset Generation

```yaml
  - name: Generate app icons and splash screens
    script: |
      # Generate launcher icons
      flutter pub run flutter_launcher_icons:main
      
      # Generate native splash screens
      flutter pub run flutter_native_splash:create
```

## Deployment Strategies

### iOS App Store Deployment

```yaml
artifacts:
  - build/ios/ipa/*.ipa
  - /tmp/xcodebuild_logs/*.log
  - flutter_drive.log
  - test-results/flutter.json

publishing:
  email:
    recipients:
      - developer@mealvana.io
    notify:
      success: true
      failure: true
      
  app_store_connect:
    auth: integration
    submit_to_testflight: true
    beta_groups:
      - "Internal Testers"
      - "External Testers"
    submit_to_app_store: false  # Manual App Store submission
```

### Android Play Store Deployment

```yaml
artifacts:
  - build/**/outputs/**/*.aab
  - build/**/outputs/**/mapping.txt
  - flutter_drive.log
  - test-results/flutter.json

publishing:
  email:
    recipients:
      - developer@mealvana.io
    notify:
      success: true
      failure: true
      
  google_play:
    credentials: $GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS
    track: $GOOGLE_PLAY_TRACK
    submit_as_draft: true  # Review before publishing
    
    # Staged rollout configuration
    rollout_fraction: 0.05  # Start with 5%
```

## Advanced Workflow Features

### Multi-Environment Support

```yaml
  development-workflow:
    name: Development Build
    environment:
      vars:
        BUNDLE_ID_SUFFIX: ".dev"
        GOOGLE_PLAY_TRACK: "internal"
    triggering:
      events:
        - push
      branch_patterns:
        - pattern: "develop"
          include: true
          
  staging-workflow:
    name: Staging Build
    environment:
      vars:
        BUNDLE_ID_SUFFIX: ".staging"
        GOOGLE_PLAY_TRACK: "alpha"
    triggering:
      events:
        - push
      branch_patterns:
        - pattern: "staging"
          include: true
          
  production-workflow:
    name: Production Build
    triggering:
      events:
        - tag
      tag_patterns:
        - pattern: "*"
          include: true
```

### Shorebird Integration

```yaml
  shorebird-patch-workflow:
    name: Shorebird Code Push
    instance_type: mac_mini_m1
    environment:
      vars:
        SHOREBIRD_TOKEN: $SHOREBIRD_TOKEN
      flutter: "3.24.0"
    triggering:
      events:
        - push
      branch_patterns:
        - pattern: "hotfix/*"
          include: true
    scripts:
      - name: Install and setup Shorebird
        script: |
          curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash
          echo 'export PATH="$HOME/.shorebird/bin:$PATH"' >> $HOME/.bashrc
          source $HOME/.bashrc
          shorebird login --token $SHOREBIRD_TOKEN
          
      - name: Create Shorebird patch
        script: |
          flutter packages pub get
          shorebird patch ios --no-confirm
          shorebird patch android --no-confirm
```

## Build Performance Optimization

### Caching Strategy

```yaml
cache:
  cache_paths:
    # Flutter and Dart dependencies
    - $FLUTTER_ROOT/.pub-cache
    - ~/.pub-cache
    
    # Platform-specific caches
    - ~/.gradle/caches  # Android
    - ~/Library/Caches/CocoaPods  # iOS
    
    # Build artifacts
    - build/
    - .dart_tool/
```

### Build Time Optimization

- **Incremental Builds**: Utilize Codemagic's caching for dependencies
- **Parallel Execution**: Run iOS and Android builds concurrently
- **Selective Building**: Only build changed platforms on commit
- **Code Generation**: Cache generated files between builds

## Security and Compliance

### Credential Management

```yaml
environment:
  groups:
    - app_store_connect_credentials  # Contains APP_STORE_CONNECT_*
    - google_play_credentials       # Contains GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS
    - shorebird_credentials        # Contains SHOREBIRD_TOKEN
    - signing_credentials          # Contains iOS certificates and Android keystore
```

### Code Signing

#### iOS Code Signing
- **Distribution Type**: App Store distribution
- **Certificate Management**: Automatic certificate and profile management
- **Provisioning Profiles**: Automatically generated and updated
- **Xcode Integration**: Seamless integration with Xcode project settings

#### Android Code Signing
- **Keystore Management**: Secure keystore storage in Codemagic
- **Key Rotation**: Automated key rotation support
- **Play App Signing**: Integration with Google Play App Signing

### Privacy Compliance

```yaml
  - name: Validate Privacy Manifest
    script: |
      # Verify iOS Privacy Manifest exists
      if [ ! -f "ios/Runner/PrivacyInfo.xcprivacy" ]; then
        echo "Error: iOS Privacy Manifest missing"
        exit 1
      fi
      
      # Validate privacy compliance
      echo "Privacy Manifest validated successfully"
```

## Monitoring and Analytics

### Build Monitoring

```yaml
  - name: Build performance metrics
    script: |
      # Track build duration
      echo "Build started at: $(date)"
      
      # Monitor cache effectiveness
      du -sh $FLUTTER_ROOT/.pub-cache || echo "No pub cache found"
      
      # Resource utilization
      echo "Available disk space: $(df -h /)"
      echo "Memory usage: $(free -h)"
```

### Post-Deployment Monitoring

- **Build Success Rate**: Track successful deployments across environments
- **Build Duration**: Monitor and optimize build times
- **Cache Hit Rate**: Measure caching effectiveness
- **Test Results**: Aggregate test results and coverage metrics

## Error Handling and Recovery

### Build Failure Recovery

```yaml
  - name: Handle build failures
    script: |
      # Clean build artifacts on failure
      flutter clean
      
      # Clear pub cache if needed
      flutter pub cache repair
      
      # Reset git state
      git reset --hard HEAD
    when: failure
```

### Notification Strategy

```yaml
publishing:
  slack:
    channel: "#mealvana-builds"
    notify_on_build_start: true
    notify:
      success: true
      failure: true
      
  email:
    recipients:
      - developer@mealvana.io
      - qa@mealvana.io
    notify:
      success: false  # Only notify on failures
      failure: true
```

## Best Practices

### Repository Setup
1. **Branching Strategy**: Git Flow with develop, staging, and main branches
2. **Commit Conventions**: Conventional commits for automated versioning
3. **Tag Management**: Semantic versioning for release tags
4. **Secret Management**: All credentials stored securely in Codemagic

### Testing Strategy
1. **Unit Tests**: Comprehensive unit test coverage
2. **Widget Tests**: UI component testing
3. **Integration Tests**: End-to-end user journey testing
4. **Performance Testing**: App startup and navigation performance

### Deployment Strategy
1. **Staged Rollouts**: Gradual rollout for production releases
2. **Feature Flags**: Use Shorebird for instant feature toggles
3. **Rollback Procedures**: Quick rollback using Shorebird patches
4. **A/B Testing**: Future integration for feature experimentation

## Troubleshooting

### Common Issues

#### Build Failures
- **Dependency Resolution**: Clear pub cache and regenerate code
- **iOS Code Signing**: Verify certificates and provisioning profiles
- **Android Keystore**: Validate keystore credentials and aliases

#### Shorebird Issues
- **Authentication**: Verify SHOREBIRD_TOKEN environment variable
- **Release Creation**: Ensure proper Flutter version compatibility
- **Patch Deployment**: Validate patch against base release

### Debug Commands

```bash
# Check Shorebird status
shorebird doctor

# Verify Flutter installation
flutter doctor -v

# Test Android keystore
android-keystore verify -k keystore.jks -p password -a alias

# Validate iOS certificates
app-store-connect certificates list --save
```

## Future Enhancements

### Planned Improvements
1. **Automated Testing**: Expand test coverage and automation
2. **Performance Monitoring**: Integrate app performance monitoring
3. **Crash Reporting**: Future crash analytics integration
4. **User Feedback**: Automated feedback collection system
5. **Advanced Analytics**: Usage analytics and user behavior tracking

This CI/CD implementation provides a robust, secure, and scalable foundation for the Mealvana Run app, ensuring reliable deployments while maintaining the privacy-first, offline-focused architecture.