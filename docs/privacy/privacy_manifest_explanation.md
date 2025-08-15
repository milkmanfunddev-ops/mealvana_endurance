# Privacy Manifest Explanation

## PrivacyInfo.xcprivacy Details

The Privacy Manifest file (`ios/Runner/PrivacyInfo.xcprivacy`) declares:

### NSPrivacyTracking: false
- App does not track users
- No data collection for advertising/marketing
- No cross-app tracking

### NSPrivacyTrackingDomains: []
- Empty array - no tracking domains used
- No third-party analytics or advertising SDKs

### NSPrivacyCollectedDataTypes: []
- Empty array - no user data collected
- All data stored locally only

### NSPrivacyAccessedAPITypes:
Required declarations for APIs used by Flutter:

#### 1. NSPrivacyAccessedAPICategoryFileTimestamp
- **Reason Code**: C617.1
- **Purpose**: Flutter needs to access file timestamps for app functionality
- **Usage**: Local file system operations only

#### 2. NSPrivacyAccessedAPICategoryUserDefaults  
- **Reason Code**: CA92.1
- **Purpose**: Flutter uses UserDefaults for system-level app preferences
- **Usage**: Local preferences storage only

## What This Means:
- ✅ Declares app doesn't collect or track user data
- ✅ Explains necessary system API usage by Flutter
- ✅ Required for iOS 17+ App Store submissions
- ✅ Helps streamline App Store review process

## For App Store Connect:
- Reference this when answering privacy questions
- Shows proactive privacy compliance
- Demonstrates transparency about data practices