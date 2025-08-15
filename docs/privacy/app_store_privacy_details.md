# Mealvana Run - App Store Privacy Details

**For App Store Connect Configuration**  
**Privacy Policy URL**: https://www.mealvana.io/privacy-policy

## Data Collection Summary
**Mealvana Run does NOT collect, transmit, or share any user data.**

### Data Types: NONE COLLECTED
- ❌ Contact Info (email, name, phone)
- ❌ Health & Fitness Data  
- ❌ Financial Info
- ❌ Location Data
- ❌ User Content
- ❌ Browsing History
- ❌ Search History
- ❌ Identifiers
- ❌ Usage Data
- ❌ Diagnostics
- ❌ Other Data

### Data Storage
- ✅ **Local Storage Only**: All user data stored locally using Hive database
- ✅ **No Network Requests**: App functions completely offline
- ✅ **No Analytics**: No tracking, analytics, or crash reporting
- ✅ **No Third-Party SDKs**: No data collection SDKs included

### Specific App Store Connect Answers

#### **Data Collection Questions:**
1. **"Does this app collect data from users?"** → **NO**
2. **"Do you or your third-party partners collect data from this app?"** → **NO**
3. **"Is data collected from this app used for tracking purposes?"** → **NO**
4. **"Do you or your third-party partners use data from this app for advertising or marketing purposes?"** → **NO**

#### **Age Rating:**
- **4+** (Appropriate for all ages)
- **No Objectionable Content**
- **Educational/Reference content about nutrition**

#### **App Privacy Labels (All should be "NO"):**
- Contact Info: NO
- Health & Fitness: NO (even though it's nutrition-related, we don't collect personal health data)
- Financial Info: NO
- Location: NO
- User Content: NO
- Browsing History: NO
- Search History: NO
- Identifiers: NO
- Usage Data: NO
- Diagnostics: NO
- Other Data: NO

#### **Third-Party Code:**
- **Flutter Framework**: No data collection
- **Hive Database**: Local storage only
- **Riverpod**: State management only
- **Google Fonts**: Fonts bundled with app
- **Shorebird**: Code push (no user data transmitted)

## Key Privacy Features

### ✅ What We Do:
- Store user preferences locally (food likes/dislikes)
- Store user profile locally (height, weight, running habits)
- Generate nutrition plans using local algorithms
- All data remains on user's device

### ❌ What We DON'T Do:
- Send any data to servers
- Track user behavior
- Collect personal information
- Share data with third parties
- Use analytics or crash reporting
- Access device identifiers
- Access location services
- Access health data from HealthKit
- Store data in cloud

## Technical Implementation

### Local Storage Details:
- **Technology**: Hive (offline NoSQL database)
- **Data Types Stored Locally**:
  - User profile (age, gender, height, weight, running habits)
  - Food preferences (like/dislike for 12 food items)
  - Generated nutrition plans
- **Storage Location**: App sandbox only
- **Data Persistence**: Remains on device, deleted when app is deleted

### Network Usage:
- **Shorebird Code Push**: Only checks for app updates (no user data sent)
- **No other network activity**

## App Store Connect Configuration

### Required URLs:
- **Privacy Policy**: https://www.mealvana.io/privacy-policy
- **Support URL**: https://www.mealvana.io/privacy-policy (can use same URL)

### Marketing Text Suggestions:
```
Personalized nutrition planning for endurance athletes. Generate evidence-based 
fueling plans for your long runs based on your preferences and run details. 
All data stored locally on your device for complete privacy.
```

### Keywords:
```
nutrition, running, endurance, marathon, fueling, sports nutrition, 
carbohydrates, electrolytes, hydration, training, fitness
```

### App Description:
```
Mealvana Run helps endurance athletes create personalized nutrition fueling 
plans for long run days. Input your run distance and pace to get evidence-based 
recommendations for pre-run meals and during-run fueling.

Features:
• Personalized nutrition calculations based on your body composition
• Food preference customization
• Evidence-based formulas for optimal performance
• Completely offline - your data never leaves your device
• Clean, intuitive interface designed for athletes

Perfect for marathon training, ultra running, and any endurance activity 
requiring proper fueling strategy.
```

---

**Last Updated**: 2024-08-15  
**App Version**: 1.0.0+1  
**Bundle ID**: com.milkman.mealvanaendurance