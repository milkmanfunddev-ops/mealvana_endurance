# Sentry Testing

This directory contains tests for the Sentry error tracking integration in Mealvana Endurance.

## Test Files

### `sentry_service_test.dart`
Unit tests for the SentryService class. These tests verify:
- Service instantiation
- Method availability  
- Function signatures
- Error handling (no crashes)

**Run with:**
```bash
flutter test test/sentry/sentry_service_test.dart
```

### `sentry_integration_test.dart`
Integration test that actually sends test data to Sentry. This test:
- Initializes Sentry with real configuration
- Sends test messages, errors, and breadcrumbs
- Verifies end-to-end functionality
- Creates performance transactions

**⚠️ Note:** This test sends real data to the Sentry project. Use only for development verification.

**Run with:**
```bash
flutter test test/sentry/sentry_integration_test.dart
```

### `quick_sentry_test.dart` ⭐ **RECOMMENDED**
Quick test that sends essential error types to Sentry for verification:
- Critical errors with stack traces
- Edge Function errors with timing
- Database errors with context
- Success messages with tags

**✅ Fast execution (~2 seconds)**
**✅ Minimal data transmission**
**✅ Production-like error scenarios**

**Run with:**
```bash
flutter test test/sentry/quick_sentry_test.dart
```

### `error_categories_test.dart`
Comprehensive test of all error categories and severity levels:
- All error types (Critical, Edge Function, Database, Network)
- User context tracking and lifecycle events
- Performance transactions with spans
- Different severity levels (Info, Warning, Error)
- Business logic and validation errors

**Run with:**
```bash
flutter test test/sentry/error_categories_test.dart
```

### `sentry_live_test.dart`
Full comprehensive test suite (may timeout in CI):
- Complete user lifecycle simulation
- Error filtering and deduplication testing
- Release tracking integration
- All Sentry features in one test

**Run with:**
```bash
flutter test test/sentry/sentry_live_test.dart --timeout=60s
```

## Verification Steps

After running any live test, check your Sentry dashboard:

### 1. **Access Dashboard:**
   - Go to https://sentry.io/organizations/mealvana/projects/
   - Look for events with environment tags like `quick_test`, `error_categories_test`, or `test_live`

### 2. **Expected Events from Quick Test:**
   - 🚨 Critical Error: "TEST CRITICAL ERROR - Sentry verification test"
   - ⏱️ Edge Function Error: 504 timeout with 3000ms response time
   - 💾 Database Error: Connection failure on users table
   - ✅ Success Message: Test completion confirmation

### 3. **Expected Events from Error Categories Test:**
   - 🚨 StateError: App crash during nutrition calculation
   - ⏱️ Edge Function Timeout: 8000ms response time
   - 💾 Database Constraint: UNIQUE constraint violation
   - 🌐 Network Error: No internet connection
   - 📊 Performance Transaction: User onboarding flow
   - ❌ Validation Error: Invalid distance input
   - 📈 Metrics: Plan creation duration
   - ℹ️ Different severity levels

### 4. **Verify Sentry Features:**
   - ✅ Error grouping by type and component
   - ✅ Stack trace symbolication and source maps
   - ✅ Breadcrumb timeline showing user actions
   - ✅ User context correlation with device ID
   - ✅ Performance monitoring and spans
   - ✅ Tag-based filtering and search
   - ✅ Release tracking (if enabled)
   - ✅ Environment separation

## Development Usage

To test Sentry integration during development:

1. **Run the app in debug mode:**
   ```bash
   flutter run --debug
   ```

2. **Trigger test errors:**
   - Use the integration test
   - Add temporary error throws in your code
   - Test network failures, database errors, etc.

3. **Monitor Sentry Dashboard:**
   - Watch for real-time events
   - Verify proper context and tagging
   - Check performance monitoring data

## Configuration Notes

- **DSN:** Uses the production DSN for testing
- **Environment:** Set to 'test' for integration tests
- **Sample Rate:** 100% for testing (vs 10% in production)
- **Debug Mode:** Enabled for detailed logging
- **Privacy:** No PII is sent (device ID only)

## Next Steps

After successful testing:
1. Deploy app with Sentry enabled
2. Monitor production error rates
3. Set up alerts for critical errors
4. Tune sampling rates based on usage
5. Configure performance monitoring thresholds