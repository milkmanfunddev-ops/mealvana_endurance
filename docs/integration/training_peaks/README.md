# TrainingPeaks Partner API Integration

## Overview

The **TrainingPeaks Partner API** enables Mealvana to integrate with TrainingPeaks, the leading training platform for endurance athletes and coaches. This integration allows us to synchronize nutrition data, fetch upcoming races/events, and provide seamless workout analysis for our users.

**Official Documentation**: [TrainingPeaks Partner API GitHub Wiki](https://github.com/TrainingPeaks/PartnersAPI/wiki)

### Why Mealvana is Integrating

Mealvana's integration with TrainingPeaks provides:

1. **Event Synchronization**: Automatically fetch upcoming races and events from TrainingPeaks to provide timely nutrition planning
2. **Nutrition Data Sync**: Push daily macro targets and nutrition plans back to TrainingPeaks for unified athlete tracking
3. **Training Analysis**: Access workout history to better personalize nutrition recommendations based on training load
4. **Athlete Profile Data**: Retrieve weight, preferences, and premium status for enhanced personalization
5. **Unified Experience**: Provide athletes with a seamless connection between their training and nutrition plans

### Key Capabilities

With the granted scopes, Mealvana can:
- **Read athlete profiles** (weight, preferences, zones, premium status)
- **Fetch upcoming events/races** for nutrition planning
- **Push daily nutrition data** (macros, calories) to TrainingPeaks
- **Access workout data** for training analysis (optional future feature)
- **Sync weight and HRV metrics** (optional future feature)

---

## Mealvana API Credentials

**IMPORTANT**: These credentials were provided via email on November 25, 2025.

### Credentials

| Field | Value |
|-------|-------|
| **Client ID** | `mealvana` |
| **Client Secret** | **STORED IN .env FILES ONLY** (never in documentation or version control) |
| **Available Date** | December 1, 2025 |
| **Initial Environment** | Sandbox only |

### Granted Scopes

Mealvana has been granted the following OAuth scopes:

```
athlete:profile
events:read
events:write
file:write
metrics:read
metrics:write
nutrition:write
nutrition:read
webhook:write-subscriptions
webhook:read-subscriptions
workouts:read
workouts:details
workouts:wod
workouts:plan
```

**Note**: The `client_secret` must be stored securely in environment variables (`.env` files) and NEVER committed to version control or included in documentation.

---

## Environment URLs

TrainingPeaks provides separate sandbox and production environments for development and deployment.

### Complete Environment Configuration

| Environment | OAuth URL | API Base URL | App URL |
|-------------|-----------|--------------|---------|
| **Sandbox** | `https://oauth.sandbox.trainingpeaks.com` | `https://api.sandbox.trainingpeaks.com` | `https://app.sandbox.trainingpeaks.com` |
| **Production** | `https://oauth.trainingpeaks.com` | `https://api.trainingpeaks.com` | `https://app.trainingpeaks.com` |

### Specific Endpoints

#### Sandbox Environment
- **Authorization**: `https://oauth.sandbox.trainingpeaks.com/OAuth/Authorize`
- **Token Exchange**: `https://oauth.sandbox.trainingpeaks.com/oauth/token`
- **Deauthorization**: `https://oauth.sandbox.trainingpeaks.com/oauth/deauthorize`
- **API Base**: `https://api.sandbox.trainingpeaks.com`
- **Test Account Signup**: `https://home.sandbox.trainingpeaks.com/signup?partner=mealvana`

#### Production Environment
- **Authorization**: `https://oauth.trainingpeaks.com/OAuth/Authorize`
- **Token Exchange**: `https://oauth.trainingpeaks.com/oauth/token`
- **Deauthorization**: `https://oauth.trainingpeaks.com/oauth/deauthorize`
- **API Base**: `https://api.trainingpeaks.com`

---

## Important Notes from TrainingPeaks

### Development Requirements

1. **Credentials Available**: December 1, 2025
2. **Initial Environment**: Sandbox only - production access requires successful validation
3. **Sandbox Database Refresh**: Every Saturday at 6:00 PM MST
   - Sandbox receives a copy of production data
   - Test data uploaded during the week will be lost on Monday
   - Plan testing around this schedule
4. **Access Token Expiration**: Tokens expire after 1 hour
   - MUST implement token refresh flow
   - Test refresh flow thoroughly before production
5. **Production Access**: Once working in sandbox, TrainingPeaks will add credentials to production
6. **Support**: For issues, fill out the [support request form](https://sportsbrands.atlassian.net/servicedesk/customer/portal/2)

### Critical Development Rules

- **Always use sandbox URLs during development** - Do not test against production
- **Test token refresh flow** - Access tokens expire in 1 hour (600 seconds)
- **Plan for weekend data resets** - Sandbox data refreshes every Saturday at 6:00 PM MST
- **Implement proper error handling** - Handle 401 (expired tokens), 403 (premium restrictions), and rate limits
- **Use proper User-Agent header** - Identify your application in all API requests

---

## Quick Start for Development

### Step 1: Wait for Credentials (December 1, 2025)

Credentials will be available on December 1, 2025. In the meantime:
- Review the [comprehensive API guide](./TRAININGPEAKS_API_COMPREHENSIVE_GUIDE.md)
- Plan the integration architecture
- Design the OAuth flow UI
- Set up Drift database tables for token storage

### Step 2: Create Test Account in Sandbox

Once credentials are available:

```
https://home.sandbox.trainingpeaks.com/signup?partner=mealvana
```

**Options**:
- **Athlete Account**: For testing athlete-side features
- **Coach Account**: `https://home.sandbox.trainingpeaks.com/coach/signup?partner=mealvana`

**Login**: `https://home.sandbox.trainingpeaks.com/login`

### Step 3: Implement OAuth Flow

Implement the three-legged OAuth 2.0 flow:

1. **Redirect to Authorization**:
   ```
   https://oauth.sandbox.trainingpeaks.com/OAuth/Authorize?response_type=code&client_id=mealvana&scope=athlete:profile%20events:read%20nutrition:write&redirect_uri=YOUR_REDIRECT_URI
   ```

2. **Handle Authorization Code Callback**:
   - Receive `code` parameter in redirect
   - Authorization code expires in 60 minutes

3. **Exchange Code for Tokens**:
   ```http
   POST https://oauth.sandbox.trainingpeaks.com/oauth/token
   Content-Type: application/x-www-form-urlencoded

   client_id=mealvana&client_secret=YOUR_SECRET&code=AUTH_CODE&redirect_uri=YOUR_REDIRECT_URI&grant_type=authorization_code
   ```

4. **Store Tokens Securely**:
   - `access_token`: Short-lived (1 hour)
   - `refresh_token`: Long-lived, use to get new access tokens
   - Store in encrypted Drift database

5. **Implement Token Refresh**:
   ```http
   POST https://oauth.sandbox.trainingpeaks.com/oauth/token
   Content-Type: application/x-www-form-urlencoded

   client_id=mealvana&client_secret=YOUR_SECRET&grant_type=refresh_token&refresh_token=REFRESH_TOKEN
   ```

### Step 4: Test API Calls

Start with basic endpoints:

```typescript
// Get athlete profile
GET https://api.sandbox.trainingpeaks.com/v1/athlete/profile
Authorization: Bearer ACCESS_TOKEN
User-Agent: Mealvana Endurance v1.0

// Get next event
GET https://api.sandbox.trainingpeaks.com/v2/events/next
Authorization: Bearer ACCESS_TOKEN
User-Agent: Mealvana Endurance v1.0

// Push nutrition data
POST https://api.sandbox.trainingpeaks.com/v1/athletes/{athleteId}/nutrition
Authorization: Bearer ACCESS_TOKEN
Content-Type: application/json
User-Agent: Mealvana Endurance v1.0

{
  "NutritionDate": "2025-12-01T00:00:00",
  "Calories": 2500.0,
  "Carbohydrates": 320.0,
  "Fat": 70.0,
  "Protein": 120.0
}
```

### Step 5: Complete Pre-Production Validation

Before requesting production credentials, complete TrainingPeaks' validation checklist:

- [ ] Verify OAuth flow works correctly
- [ ] Test token refresh mechanism
- [ ] Confirm proper User-Agent header implementation
- [ ] Test all anticipated API endpoints
- [ ] Verify nutrition data displays correctly in TrainingPeaks UI
- [ ] Test with both premium and basic athletes
- [ ] Handle 403 errors for basic athlete restrictions
- [ ] Implement proper error handling and logging
- [ ] Create user-facing documentation

### Step 6: Request Production Access

Once sandbox testing is complete:
1. Submit validation results to TrainingPeaks
2. Provide user interaction flow diagrams
3. Follow TrainingPeaks branding guidelines ([media kit](https://www.trainingpeaks.com/media))
4. Request production credentials via support portal

---

## Mealvana Integration Use Cases

Based on the granted scopes, Mealvana can implement the following features:

### Core Features (MVP)

#### 1. Event Synchronization (`events:read`)
- Fetch upcoming races and events from athlete's TrainingPeaks calendar
- Auto-populate event details in Mealvana (date, type, distance)
- Trigger nutrition plan generation based on upcoming events
- Display event countdown and preparation timeline

#### 2. Nutrition Data Push (`nutrition:write`, `nutrition:read`)
- Push daily macro targets to TrainingPeaks
- Sync nutrition plan adherence data
- Update nutrition cards in TrainingPeaks calendar
- Track historical nutrition trends

#### 3. Athlete Profile Sync (`athlete:profile`)
- Retrieve athlete weight for accurate nutrition calculations
- Access preferred units (metric vs. imperial)
- Detect premium status for feature access
- Sync training zones for workout analysis

### Optional Features (Future)

#### 4. Workout Analysis (`workouts:read`)
- Analyze training load and patterns
- Adjust nutrition recommendations based on training volume
- Identify peak training periods requiring increased nutrition

#### 5. Metrics Synchronization (`metrics:write`, `metrics:read`)
- Push weight updates to TrainingPeaks
- Sync HRV data (if available)
- Track recovery metrics

#### 6. Planned Workouts (`workouts:plan`)
- Create nutrition-specific events on TrainingPeaks calendar
- Mark carb-loading days
- Add nutrition reminders as calendar items

#### 7. Webhooks (`webhook:write-subscriptions`, `webhook:read-subscriptions`)
- Real-time notifications when workouts are created/updated
- Auto-adjust nutrition plans when events change
- Push notifications for workout changes

---

## Additional Documentation

### In This Directory

- **[Comprehensive API Guide](./TRAININGPEAKS_API_COMPREHENSIVE_GUIDE.md)** - Complete technical reference with all endpoints, data models, error handling, and integration examples

### Official TrainingPeaks Resources

- **API Documentation**: [GitHub Wiki](https://github.com/TrainingPeaks/PartnersAPI/wiki)
- **Support Portal**: [Help Center](https://sportsbrands.atlassian.net/servicedesk/customer/portal/2)
- **Media Kit**: [Branding Guidelines](https://www.trainingpeaks.com/media)
- **Help Center**: [TrainingPeaks API Help](https://help.trainingpeaks.com/hc/en-us/articles/234441128-TrainingPeaks-API)

### Related Mealvana Documentation

- [App Architecture](/Users/leemartin/development/mealvana_endurance/docs/architecture/README.md)
- [Database Schema](/Users/leemartin/development/mealvana_endurance/database_schemas/v1/README.md)
- [Feature-Oriented Architecture](/Users/leemartin/development/mealvana_endurance/docs/technical/foa-architecture.md)

---

## Development Checklist

### Phase 1: OAuth Implementation
- [ ] Add TrainingPeaks OAuth configuration to `.env` files
- [ ] Create Drift database tables for token storage
- [ ] Implement OAuth authorization flow
- [ ] Implement token exchange and storage
- [ ] Implement token refresh mechanism
- [ ] Build UI for TrainingPeaks connection
- [ ] Add deauthorization/disconnect functionality

### Phase 2: Core API Integration
- [ ] Implement athlete profile fetching
- [ ] Implement event fetching (`events:read`)
- [ ] Implement nutrition data push (`nutrition:write`)
- [ ] Add error handling for all API calls
- [ ] Implement rate limiting and retry logic
- [ ] Add caching for frequently accessed data

### Phase 3: Testing
- [ ] Create test accounts in sandbox
- [ ] Test with premium athletes
- [ ] Test with basic athletes (verify 403 handling)
- [ ] Test token refresh flow
- [ ] Test error scenarios (network failures, API errors)
- [ ] Verify data displays correctly in TrainingPeaks UI
- [ ] Performance testing (API response times)

### Phase 4: Production Preparation
- [ ] Complete TrainingPeaks pre-production validation
- [ ] Create user documentation
- [ ] Implement analytics tracking for integration usage
- [ ] Add monitoring and alerting for API errors
- [ ] Request production credentials
- [ ] Deploy to production

### Phase 5: Future Enhancements
- [ ] Implement workout analysis features
- [ ] Add metrics synchronization
- [ ] Set up webhook subscriptions
- [ ] Implement two-way nutrition data sync
- [ ] Add coach integration features

---

## Security Considerations

### Token Storage
- Store `access_token` and `refresh_token` in encrypted Drift database
- Never log tokens in plain text
- Implement secure token rotation
- Clear tokens on user logout or account deletion

### API Security
- Always use HTTPS for all API calls
- Validate SSL certificates
- Implement request signing if required
- Rate limit internal API calls to prevent abuse

### User Privacy
- Only request necessary scopes
- Allow users to disconnect TrainingPeaks integration
- Clear all TrainingPeaks data on disconnect
- Comply with GDPR and data privacy regulations

---

## Support and Resources

### TrainingPeaks Support
- **Support Request Form**: [Submit a ticket](https://sportsbrands.atlassian.net/servicedesk/customer/portal/2)
- **Email**: Check support portal for contact information

### Mealvana Internal
- **Integration Owner**: TBD
- **Architecture Questions**: See [CLAUDE.md](/Users/leemartin/development/mealvana_endurance/CLAUDE.md)
- **Development Questions**: Use `/docs-manager` or `/code-researcher` agents

---

## Changelog

### 2025-11-26
- Initial documentation created
- Added credentials information (awaiting December 1, 2025 activation)
- Documented environment URLs and OAuth flow
- Created development checklist

---

*For detailed API endpoint documentation, data models, error handling, and code examples, see the [Comprehensive API Guide](./TRAININGPEAKS_API_COMPREHENSIVE_GUIDE.md).*
