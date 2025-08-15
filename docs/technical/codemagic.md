# Codemagic CI/CD Platform Research

## Overview

This document summarizes research findings on Codemagic CI/CD platform for Flutter app automation, based on comprehensive investigation using Context7 documentation and CLI tools analysis.

## Platform Capabilities

### Core Features
- **Dedicated Flutter CI/CD**: Native Flutter support with optimized build pipelines
- **Multi-platform builds**: iOS, Android, Web, macOS, Windows, and Linux
- **Mac and Linux runners**: Mac Mini M1 instances for iOS builds, Linux for Android
- **YAML configuration**: Declarative workflow definition with `codemagic.yaml`
- **GUI Workflow Builder**: Alternative visual workflow editor interface

### Build Environment
- **Instance Types**: `mac_mini_m1`, `linux_x2`, `windows_x2`
- **Flutter versions**: Flexible Flutter SDK version management
- **Build duration**: Configurable max build time (up to 120 minutes)
- **Parallel execution**: Multiple workflows can run simultaneously

## Workflow Configuration Structure

### Basic Workflow Template
```yaml
workflows:
  ios-workflow:
    name: iOS Production Build
    instance_type: mac_mini_m1
    max_build_duration: 120
    environment:
      flutter: "3.24.0"
      vars:
        VARIABLE_NAME: $ENVIRONMENT_VALUE
    cache:
      cache_paths:
        - $FLUTTER_ROOT/.pub-cache
        - ~/.gradle/caches
    scripts:
      - name: Setup
        script: flutter pub get
    artifacts:
      - build/**/*.ipa
    publishing:
      app_store_connect:
        submit_to_testflight: true
```

### Environment Management
- **Environment groups**: Organized credential management
- **Variables**: Runtime environment variables with encryption
- **Integrations**: Direct API integrations (App Store Connect, Google Play)
- **Secrets**: Secure credential storage with access controls

## Build Automation Features

### Automatic Build Versioning
```bash
# iOS - Get latest build number and increment
BUILD_NUMBER=$(($(app-store-connect get-latest-app-store-build-number "$APP_STORE_APPLE_ID") + 1))

# Android - Get latest from Google Play
BUILD_NUMBER=$(($(google-play get-latest-build-number --package-name "$PACKAGE_NAME" --tracks="$GOOGLE_PLAY_TRACK") + 1))
```

### Code Signing
- **iOS**: Automatic certificate and provisioning profile management
- **Android**: Secure keystore management with automatic signing
- **Certificate rotation**: Automated certificate renewal workflows

### Testing Integration
```yaml
scripts:
  - name: Flutter unit tests
    script: |
      mkdir -p test-results
      flutter test --machine > test-results/flutter.json
  - name: Flutter analyze
    script: flutter analyze
```

## Deployment Strategies

### iOS App Store Connect
```yaml
publishing:
  app_store_connect:
    auth: integration
    submit_to_testflight: true
    beta_groups:
      - "Internal Testers"
      - "External Testers"
    submit_to_app_store: false
```

### Android Google Play
```yaml
publishing:
  google_play:
    credentials: $GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS
    track: $GOOGLE_PLAY_TRACK
    submit_as_draft: true
    rollout_fraction: 0.05  # Staged rollout starting at 5%
```

## Advanced Features

### Multi-Environment Workflows
- **Development**: Continuous deployment on develop branch
- **Staging**: Pre-production validation on staging branch  
- **Production**: Tagged releases with manual approval

### Build Triggers
```yaml
triggering:
  events:
    - push
    - pull_request
    - tag
  branch_patterns:
    - pattern: "main"
      include: true
  tag_patterns:
    - pattern: "*"
      include: true
```

### Notifications
```yaml
publishing:
  slack:
    channel: "#builds"
    notify_on_build_start: true
  email:
    recipients:
      - developer@example.com
    notify:
      success: true
      failure: true
```

## CLI Tools Research

### App Store Connect CLI
The Codemagic CLI tools provide comprehensive App Store Connect automation:

```bash
# Certificate management
app-store-connect certificates list --save
app-store-connect certificates get CERTIFICATE_ID

# Build submission
app-store-connect publish \
  --testflight \
  --beta-group "External Testers" \
  --path build/ios/ipa/*.ipa

# Build versioning
app-store-connect get-latest-app-store-build-number APP_ID
```

### Android CLI Tools
```bash
# Keystore management  
android-keystore verify -k keystore.jks -p password -a alias

# App bundle operations
android-app-bundle sign --bundle app.aab --ks keystore.jks

# Google Play publishing
google-play tracks set-release \
  --package-name com.example.app \
  --track production \
  --version-code 123
```

## Performance Optimizations

### Caching Strategy
```yaml
cache:
  cache_paths:
    # Flutter dependencies
    - $FLUTTER_ROOT/.pub-cache
    - ~/.pub-cache
    
    # Platform caches
    - ~/.gradle/caches      # Android
    - ~/Library/Caches/CocoaPods  # iOS
    
    # Build artifacts
    - build/
    - .dart_tool/
```

### Build Time Optimization
- **Incremental builds**: Leverages dependency caching
- **Parallel execution**: Concurrent iOS/Android builds
- **Selective building**: Platform-specific triggering
- **Code generation**: Cache generated Dart files

## Security and Compliance

### Credential Management
- **Environment groups**: Organized secret management
- **API key rotation**: Automated credential updates  
- **Access controls**: Role-based team permissions
- **Audit logging**: Complete build and access logs

### Code Signing Security
- **Certificate storage**: HSM-backed certificate management
- **Key rotation**: Automated signing credential updates
- **Profile management**: Automatic provisioning profile updates

## Integration Capabilities

### Third-Party Integrations
- **Slack**: Build notifications and status updates
- **GitHub/Bitbucket**: Repository webhooks and status checks
- **Jira**: Ticket linking and build tracking
- **Firebase**: App Distribution and Crashlytics

### API Access
```bash
# REST API for external automation
curl -H "x-auth-token: ${CM_API_KEY}" \
  --data '{"appId": "app-id", "workflowId": "workflow-id"}' \
  https://api.codemagic.io/builds
```

## Monitoring and Analytics

### Build Metrics
- **Success rates**: Track deployment success across environments
- **Build duration**: Monitor and optimize build performance
- **Cache effectiveness**: Measure dependency caching benefits
- **Resource utilization**: CPU, memory, and storage metrics

### Deployment Analytics
- **Release tracking**: Monitor app store submission status
- **Version analytics**: Track version adoption and rollbacks
- **Error monitoring**: Build failure analysis and trends

## Cost Optimization

### Resource Management
- **Instance sizing**: Right-sized compute resources
- **Build scheduling**: Optimize resource usage patterns
- **Cache utilization**: Reduce build times and costs
- **Parallel limits**: Balance speed vs. cost

### Usage Monitoring
```yaml
# Track build minutes and optimize usage
scripts:
  - name: Build performance metrics
    script: |
      echo "Build started at: $(date)"
      # Monitor cache effectiveness
      du -sh $FLUTTER_ROOT/.pub-cache
```

## Migration Considerations

### From Other CI/CD Platforms
- **Configuration migration**: YAML workflow conversion
- **Secret migration**: Environment variable transfer  
- **Integration updates**: Webhook and API endpoint changes
- **Team migration**: User access and permission setup

### Best Practices
1. **Start with simple workflows** and gradually add complexity
2. **Use environment groups** for credential organization
3. **Implement caching strategies** for build performance
4. **Monitor build metrics** for continuous optimization
5. **Test workflows** in staging before production deployment

## Specific Flutter Optimizations

### Flutter-Specific Features
```yaml
environment:
  flutter: stable  # or specific version like "3.24.0"
scripts:
  - name: Flutter packages
    script: flutter pub get
  - name: Code generation
    script: flutter packages pub run build_runner build
  - name: Build iOS
    script: flutter build ipa --release
  - name: Build Android  
    script: flutter build appbundle --release
```

### Asset Generation
```yaml
scripts:
  - name: Generate launcher icons
    script: flutter pub run flutter_launcher_icons:main
  - name: Generate splash screens
    script: flutter pub run flutter_native_splash:create
```

## Integration with Shorebird

### Code Push Workflow
```yaml
scripts:
  - name: Install Shorebird
    script: |
      curl --proto '=https' --tlsv1.2 \
        https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash
      shorebird login --token $SHOREBIRD_TOKEN
      
  - name: Create Shorebird release
    script: |
      if [ ! -z ${CM_TAG} ]; then
        shorebird release ios --no-confirm
        shorebird release android --no-confirm
      fi
```

## Conclusion

Codemagic provides a comprehensive, Flutter-optimized CI/CD platform with:
- **Native Flutter support** with optimized build environments
- **Comprehensive automation** for iOS and Android deployment
- **Advanced features** like automatic versioning and staged rollouts
- **Strong security** with HSM-backed code signing
- **Extensive integrations** with development and monitoring tools

The platform is particularly well-suited for Flutter applications requiring:
- Multi-platform deployment automation
- Complex code signing requirements  
- Advanced deployment strategies
- Integration with existing development workflows

This research provides the foundation for implementing Codemagic CI/CD for the Mealvana Run Flutter application with Shorebird code push integration.