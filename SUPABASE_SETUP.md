# 🗄️ Supabase Database Setup for Mealvana Endurance

## Quick Setup Guide

### 1. Create Supabase Project
1. Go to [supabase.com](https://supabase.com)
2. Create new project
3. Copy your **Project URL** and **anon public key**

### 2. Create Feedback Table

Run this SQL in your Supabase SQL Editor:

```sql
-- Create feedback table
CREATE TABLE feedback (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  satisfaction_level INTEGER NOT NULL CHECK (satisfaction_level >= 1 AND satisfaction_level <= 3),
  satisfaction_emoji TEXT NOT NULL,
  satisfaction_label TEXT NOT NULL,
  app_feedback TEXT,
  suggestions TEXT,
  plan_name TEXT,
  user_name TEXT,
  timestamp TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for performance
CREATE INDEX idx_feedback_created_at ON feedback(created_at DESC);
CREATE INDEX idx_feedback_satisfaction ON feedback(satisfaction_level);

-- Enable Row Level Security (RLS)
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

-- Create policy to allow inserts (submissions)
CREATE POLICY "Allow feedback submissions" ON feedback 
FOR INSERT WITH CHECK (true);

-- Create policy to allow reading feedback (for admin/analytics)
CREATE POLICY "Allow feedback reading" ON feedback 
FOR SELECT USING (true);
```

### 3. Configure Your App

Add to your `main.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL_HERE',
    anonKey: 'YOUR_SUPABASE_ANON_KEY_HERE',
  );
  
  runApp(MyApp());
}
```

### 4. Update Feedback Provider

Replace your current feedback submission with Supabase:

```dart
import '../application/supabase_feedback_service.dart';

class FeedbackSubmissionNotifier extends StateNotifier<AsyncValue<bool>> {
  final SupabaseFeedbackService _feedbackService = SupabaseFeedbackService();
  
  Future<bool> submitFeedback(FeedbackResponse feedback) async {
    state = const AsyncValue.loading();
    
    try {
      final success = await _feedbackService.submitFeedback(feedback);
      state = AsyncValue.data(success);
      return success;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }
}
```

## Database Schema

### feedback table
| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key (auto-generated) |
| `satisfaction_level` | INTEGER | 1=😞, 2=🤗, 3=😊 |
| `satisfaction_emoji` | TEXT | Emoji representation |
| `satisfaction_label` | TEXT | Full text label |
| `app_feedback` | TEXT | Radio button selection |
| `suggestions` | TEXT | User suggestions (optional) |
| `plan_name` | TEXT | Auto-filled plan name |
| `user_name` | TEXT | User name if available |
| `timestamp` | TIMESTAMPTZ | App submission time |
| `created_at` | TIMESTAMPTZ | Database insert time |

## Benefits vs Google Forms

✅ **Reliable**: No more HTTP 400 errors  
✅ **Real-time**: Instant submissions  
✅ **Analytics**: Built-in queries and stats  
✅ **Scalable**: Handles high volume  
✅ **Secure**: Row-level security  
✅ **API**: Easy data access for dashboards  

## Testing

```dart
// Test the connection
final service = SupabaseFeedbackService();
final success = await service.testConnection();
print('Supabase test: ${success ? 'SUCCESS' : 'FAILED'}');
```

## Analytics Queries

### View all feedback:
```sql
SELECT * FROM feedback ORDER BY created_at DESC;
```

### Satisfaction distribution:
```sql
SELECT 
  satisfaction_level,
  satisfaction_emoji,
  COUNT(*) as count
FROM feedback 
GROUP BY satisfaction_level, satisfaction_emoji
ORDER BY satisfaction_level;
```

### App feedback summary:
```sql
SELECT 
  app_feedback,
  COUNT(*) as count
FROM feedback 
WHERE app_feedback IS NOT NULL
GROUP BY app_feedback
ORDER BY count DESC;
```

### Recent suggestions:
```sql
SELECT 
  suggestions,
  plan_name,
  created_at
FROM feedback 
WHERE suggestions IS NOT NULL AND suggestions != ''
ORDER BY created_at DESC
LIMIT 10;
```

This setup will be much more reliable than Google Forms and give you better analytics capabilities!