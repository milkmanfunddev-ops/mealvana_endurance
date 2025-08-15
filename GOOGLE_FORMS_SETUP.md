# Google Forms Setup for Feedback Collection

This guide will help you set up a Google Form to collect user feedback from your Flutter app and integrate it properly with your feedback system.

## Step 1: Create a New Google Form

1. Go to [Google Forms](https://forms.google.com)
2. Click the **+ (Plus)** button to create a new form
3. Give your form a title: **"Mealvana Endurance Feedback"**
4. Add a description: **"Help us improve your nutrition planning experience"**

## Step 2: Configure Form Questions

Add the following questions in this exact order to match your app's feedback structure:

### Question 1: Plan Satisfaction (Required)
- **Question Type**: Multiple choice
- **Question**: "What do you think about this plan?"
- **Options**:
  - Much more than what I think I should use
  - Pretty close to what I think I should use  
  - Much less than what I think I should use
- **Required**: Yes
- **Note**: This corresponds to the emoji slider section in your app

### Question 2: App Feedback (Required)
- **Question Type**: Multiple choice
- **Question**: "What do you think about this tiny app?"
- **Options**:
  - I like it! Remind me to use it
  - It has potential but I need it to...
  - I don't think I'll use it
- **Required**: Yes
- **Note**: This corresponds to the radio button section in your app

### Question 3: Suggestions (Optional)
- **Question Type**: Paragraph text
- **Question**: "Any suggestions for improvement?"
- **Description**: "This field will auto-populate when you select 'It has potential but I need it to...' in the previous question"
- **Required**: No
- **Note**: This appears conditionally when "It has potential..." is selected

### Question 4: Plan Name (Hidden)
- **Question Type**: Short answer text
- **Question**: "Plan Name"
- **Required**: No
- **Note**: This will be auto-filled by your app

### Question 5: Timestamp (Hidden)
- **Question Type**: Short answer text  
- **Question**: "Submission Time"
- **Required**: No
- **Note**: This will be auto-filled by your app

## Form Structure Mapping

Your feedback drawer has this structure:
1. **"Like our plan?"** (Main title in yellow background)
2. **"Leave us feedback so we know how we're doing"** (Subtitle)
3. **"What do you think about this plan?"** → Maps to Question 1 above
4. **Emoji slider with satisfaction levels** → Maps to Question 1 options
5. **"What do you think about this tiny app?"** → Maps to Question 2 above
6. **Radio buttons with app feedback options** → Maps to Question 2 options
7. **Conditional suggestions text field** → Maps to Question 3 above

## Step 3: Configure Form Settings

1. Click the **Settings** gear icon at the top right
2. Under **General**:
   - ✅ Check "Collect email addresses" if you want to track users
   - ✅ Check "Limit to 1 response" to prevent spam
   - ✅ Check "Edit after submit" to allow users to modify responses
3. Under **Presentation**:
   - ✅ Check "Show progress bar"
   - ✅ Check "Shuffle question order" (Optional)
4. Under **Defaults**:
   - Set confirmation message: "Thank you for your feedback! We'll use it to improve your nutrition planning experience."

## Step 4: Get the Form URL

1. Click the **Send** button at the top right
2. Click the **Link** tab (chain icon)
3. **Copy the form URL** - this is what you'll use in your app
4. **Important**: Make sure the URL ends with `/viewform` for direct access

Example URL format:
```
https://docs.google.com/forms/d/e/[FORM_ID]/viewform
```

## Step 5: Set Up Pre-filled URLs (Advanced)

To automatically populate form fields from your app:

1. Click the **three dots menu** (⋮) in the top right of your form
2. Select **"Get pre-filled link"**
3. Fill in dummy data for each field you want to pre-populate
4. Click **"Get link"**
5. Copy the generated URL - it will look like:

```
https://docs.google.com/forms/d/e/[FORM_ID]/viewform?usp=pp_url&entry.123456789=PLAN_SATISFACTION&entry.987654321=APP_FEEDBACK&entry.456789123=SUGGESTIONS&entry.789123456=PLAN_NAME&entry.321654987=TIMESTAMP
```

## Step 6: Extract Entry IDs

From the pre-filled URL, extract the entry IDs:
- `entry.123456789` = Plan Satisfaction field
- `entry.987654321` = App Feedback field  
- `entry.456789123` = Suggestions field
- `entry.789123456` = Plan Name field
- `entry.321654987` = Timestamp field

## Step 7: Update Your Flutter App

Update your `FeedbackService` with the form URL and entry IDs:

```dart
class FeedbackService {
  static const String _formUrl = 'https://docs.google.com/forms/d/e/YOUR_FORM_ID/formResponse';
  
  // Replace these with your actual entry IDs from Step 6
  static const String _planSatisfactionEntry = 'entry.123456789';
  static const String _appFeedbackEntry = 'entry.987654321';
  static const String _suggestionsEntry = 'entry.456789123';
  static const String _planNameEntry = 'entry.789123456';
  static const String _timestampEntry = 'entry.321654987';
  
  // Your existing submission logic...
}
```

## Step 8: Test the Integration

1. Run your Flutter app
2. Submit test feedback through the app
3. Check your Google Form responses to ensure data is being captured correctly
4. Verify all fields are mapping correctly

## Step 9: View and Analyze Responses

1. Go back to your Google Form
2. Click the **Responses** tab
3. You can view individual responses or link to Google Sheets for analysis
4. To create a spreadsheet: Click the **Google Sheets** icon in the Responses tab

## Form URL Structure for Submissions

Use this URL structure for programmatic submissions:
```
https://docs.google.com/forms/d/e/[FORM_ID]/formResponse?entry.[ID1]=[VALUE1]&entry.[ID2]=[VALUE2]&submit=Submit
```

Replace `[FORM_ID]` with your actual form ID and `[ID1]`, `[ID2]`, etc. with your actual entry IDs.

## Integration with Analytics

Consider tracking form submission events in your analytics:
```dart
// Track successful form submission
AnalyticsService.instance.trackFeedbackSubmitted(
  feedbackType: 'google_form',
  rating: satisfactionLevel.value,
  hasComments: suggestions?.isNotEmpty ?? false,
);
```

This setup will ensure reliable feedback collection and provide valuable insights for improving your nutrition planning app.