# 01 Welcome / Auth

Screens covered: app welcome, login options sheet, email login form.

---

## welcome
**Screenshot:** `screenshots/01_welcome.png`
**Reached by:** Fresh app launch (signed-out state) or after Sign Out from Settings.

### Visible elements
| Role             | Label / Text       | mobile-mcp coords        | Existing key | Proposed ValueKey               |
|------------------|--------------------|--------------------------|--------------|---------------------------------|
| Heading          | "Mealvana"         | (154, 363, 120x34)       | none         | `welcome.title`                 |
| Subtitle         | "Endurance"        | (128, 409, 172x22)       | none         | `welcome.subtitle`              |
| Body             | "Get personalized…"| (16, 479, 398x63)        | none         | `welcome.description`           |
| Button (primary) | "Get Started"      | (153, 750, 123x56)       | none         | `welcome.get_started_button`    |
| Button (text)    | "Log In"           | (170, 822, 88x56)        | none         | `welcome.log_in_button`         |

### Notes
- "Get Started" routes into onboarding `Connect Your Training`.
- "Log In" routes to login-options sheet.
- The orange accessibility button and blue testing-tools button at bottom right are dev-overlay artifacts (Flutter `Show Accessibility Issues` / Dev Tools), not part of the production UI.

---

## login_options
**Screenshot:** `screenshots/02_login_options.png`
**Reached by:** Tap **Log In** from welcome.

### Visible elements
| Role             | Label / Text            | mobile-mcp coords        | Existing key | Proposed ValueKey               |
|------------------|-------------------------|--------------------------|--------------|---------------------------------|
| Heading          | "Log In"                | (16, 139, 398x36)        | none         | `login_options.title`           |
| Body             | "Welcome back"          | (16, 187, 398x21)        | none         | `login_options.subtitle`        |
| Button           | "Continue with Apple"   | (16, 240, 398x56)        | none         | `login_options.apple_button`    |
| Button           | "Continue with Google"  | (16, 312, 398x56)        | none         | `login_options.google_button`   |
| Button (primary) | "Log in with Email"     | (16, 384, 398x56)        | none         | `login_options.email_button`    |
| Button (back)    | (top-left arrow)        | ~(38, 95)                | none         | `login_options.back_button`     |

### Notes
- "Continue without signing in" link is on the **Create Account** screen at end of onboarding, NOT on this login screen.

---

## login_email
**Screenshot:** `screenshots/03_login_email.png` (empty), `screenshots/04_login_filled.png` (with credentials)
**Reached by:** Tap **Log in with Email** from login options.

### Visible elements
| Role             | Label / Text       | mobile-mcp coords        | Existing key | Proposed ValueKey               |
|------------------|--------------------|--------------------------|--------------|---------------------------------|
| Heading          | "Log In"           | (16, 139, 398x36)        | none         | `login.title`                   |
| Body             | "Welcome back"     | (16, 187, 398x21)        | none         | `login.subtitle`                |
| Field            | "Email Address"    | (16, 248, 398x54)        | none         | `login.email_field`             |
| Field (secure)   | "Password"         | (16, 322, 398x54)        | none         | `login.password_field`          |
| Button (icon)    | Show/hide pwd eye  | (366, 325, 48x48)        | none         | `login.password_visibility_button` |
| Link             | "Forgot Password?" | (298, 392, 115x21)       | none         | `login.forgot_password_button`  |
| Button (primary) | "Log In"           | (16, 453, 398x56)        | none         | `login.log_in_button`           |
| Button (text)    | "Back"             | (16, 525, 398x56)        | none         | `login.back_button`             |

### Notes / observations
- **BLOCKER:** During this audit the "Log In" button at logical (215, 481) did NOT respond to taps via mobile-mcp (`mcp__mobile-mcp__mobile_click_on_screen_at_coordinates`) — the orange "Back" button immediately below DID respond. Tried multiple positions/y-offsets/double-tap; the button never advanced past the email form. This is likely a Flutter `GestureDetector` hit-test issue where the button's parent intercepts the synthetic tap; Patrol's `nativeTap` may need to land directly on the inner `InkWell`/`MaterialButton`. **Action for instrumentation PR**: ensure this button has a unique key (`login.log_in_button`) and that the tappable area is the outermost interactive widget (not a wrapped `Padding`/`SizedBox`).
- The keyboard's "Done" key didn't submit either — same hit-test problem.
- Password field shows 4 dots when "test" is correctly entered. The eye toggle reveals "test" in plain text confirming credential value.
- Email field accepts `test@test.com` with autocorrect off.
