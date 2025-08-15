# 📋 ACCURATE Google Forms Setup for Mealvana Endurance Feedback

Based on the actual feedback drawer implementation and data structures.

## What Your App Actually Collects

Looking at the feedback drawer and `FeedbackResponse` class, here's what your app actually submits:

1. **Plan Satisfaction** (`satisfactionLevel`) - from emoji slider with 3 options
2. **App Feedback** (`appFeedback`) - from radio buttons with 3 options  
3. **Suggestions** (`suggestions`) - conditional text field
4. **Plan Name** (`planName`) - auto-filled
5. **User Name** (`userName`) - if available
6. **Timestamp** (`timestamp`) - auto-filled

## Step 1: Create Your Google Form

1. Go to [Google Forms](https://forms.google.com)
2. Click **+ Blank** to create a new form
3. **Title**: "Mealvana Endurance - Feedback"
4. **Description**: "Help us improve your nutrition planning experience"

## Step 2: Add Form Fields (EXACT Match)

### Field 1: Plan Satisfaction ⭐
- **Question Type**: Multiple choice
- **Question**: "What do you think about this plan?"
- **Options** (EXACT text from your `SatisfactionLevel` enum):
  ```
  Much more than what I think I should use
  Pretty close to what I think I should use
  Much less than what I think I should use
  ```
- **Required**: Yes
- **Maps to**: `satisfactionLevel.label`

### Field 2: App Feedback 📱
- **Question Type**: Multiple choice
- **Question**: "What do you think about this tiny app?"
- **Options** (EXACT text from your `AppFeedbackOption` enum):
  ```
  I like it! Remind me to use it
  It has potential but I need it to...
  Not interested
  ```
- **Required**: No (user may not select anything)
- **Maps to**: `appFeedback.label`

### Field 3: Suggestions 💭
- **Question Type**: Paragraph text
- **Question**: "Suggestions for improvement"
- **Required**: No
- **Maps to**: `suggestions` (only filled when "It has potential..." is selected)

### Field 4: Plan Name 📋
- **Question Type**: Short answer
- **Question**: "Plan Name"
- **Required**: No
- **Maps to**: `planName`

### Field 5: User Name 👤
- **Question Type**: Short answer
- **Question**: "User Name"
- **Required**: No
- **Maps to**: `userName`

### Field 6: Timestamp ⏰
- **Question Type**: Short answer
- **Question**: "Submission Time"
- **Required**: No
- **Maps to**: `timestamp` (ISO8601 format)

## Step 3: Get Entry IDs

1. **Send your form** and get the URL
2. **Change** `/viewform` to `/formResponse` 
3. **View page source** and search for `entry.`
4. **Find 6 entry IDs** like `entry.123456789`

Example:
```
entry.XXXXXXXXX  // Plan Satisfaction
entry.YYYYYYYYY  // App Feedback  
entry.ZZZZZZZZZ  // Suggestions
entry.AAAAAAAAA  // Plan Name
entry.BBBBBBBBB  // User Name
entry.CCCCCCCCC  // Timestamp
```

## Step 4: Your App's Data Mapping

From `FeedbackResponse.toFormData()`:

```dart
{
  'satisfaction': satisfactionLevel.value,        // 1, 2, or 3
  'satisfaction_emoji': satisfactionLevel.emoji,  // 😞, 🤗, or 😊
  'satisfaction_label': satisfactionLevel.label,  // Full text label
  'app_feedback': appFeedback?.label ?? '',       // Radio button selection
  'suggestions': suggestions ?? '',               // Text field
  'plan_name': planName ?? '',                    // Auto-filled
  'user_name': userName ?? '',                    // If available
  'timestamp': timestamp?.toIso8601String()       // ISO format
}
```

## Step 5: Update Your FeedbackService

```dart
class FeedbackService {
  static const String _formUrl = 'https://docs.google.com/forms/d/e/YOUR_FORM_ID/formResponse';
  
  // Replace with your actual entry IDs
  static const String _satisfactionEntry = 'entry.123456789';
  static const String _appFeedbackEntry = 'entry.987654321';
  static const String _suggestionsEntry = 'entry.555666777';
  static const String _planNameEntry = 'entry.111222333';
  static const String _userNameEntry = 'entry.444555666';
  static const String _timestampEntry = 'entry.777888999';
  
  Future<bool> submitToGoogleForm(FeedbackResponse feedback) async {
    final formData = feedback.toFormData();
    
    final uri = Uri.parse(_formUrl).replace(queryParameters: {
      _satisfactionEntry: formData['satisfaction_label'],
      _appFeedbackEntry: formData['app_feedback'],
      _suggestionsEntry: formData['suggestions'],
      _planNameEntry: formData['plan_name'],
      _userNameEntry: formData['user_name'],
      _timestampEntry: formData['timestamp'],
    });
    
    // Submit to Google Forms...
  }
}
```

## Key Differences from Previous Setup

❌ **Previous errors**:
- Missing "Not interested" option in app feedback
- Wrong field requirements (app feedback should be optional)
- Missing user name field
- Incorrect data structure assumptions

✅ **Correct setup**:
- Matches exact enum values from your code
- Includes all 6 actual data fields
- Proper optional/required settings
- Maps to actual `FeedbackResponse.toFormData()` output

## Form Submission Flow in Your App

1. User opens feedback drawer ("Like our plan?")
2. User interacts with emoji slider → sets `satisfactionLevel`
3. User selects radio button → sets `appFeedback`
4. If "It has potential..." selected → shows suggestions text field
5. User fills suggestions → sets `suggestions`
6. User clicks Submit → creates `FeedbackResponse` with all data
7. App calls `toFormData()` → converts to map
8. Submit to Google Forms with entry IDs

This setup will correctly capture all the data your feedback drawer actually collects!