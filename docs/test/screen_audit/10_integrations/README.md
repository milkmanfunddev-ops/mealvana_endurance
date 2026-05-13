# 10 Integrations

Training-platform integrations (Final Surge, TrainingPeaks, Garmin Connect).

---

## connected_apps
**Screenshot:** `screenshots/01_connected_apps.png`
**Reached by:** Settings → tap **Connected Apps**.

### Visible elements
| Role             | Label / Text                          | mobile-mcp coords  | Proposed ValueKey                          |
|------------------|---------------------------------------|--------------------|--------------------------------------------|
| Button (back)    | Arrow circle                          | (4, 63)            | `connected_apps.back_button`               |
| Heading          | "Connected Apps"                      | center             | `connected_apps.title`                     |
| Body             | "Connect your training platforms…"    | (16, 110, 398x42)  | `connected_apps.description`               |
| Card             | Final Surge "Connect" button          | (16, 175, 398x65)  | `connected_apps.finalsurge_connect_button` |
| Card             | TrainingPeaks "Connect" button        | (16, 250, 398x65)  | `connected_apps.trainingpeaks_connect_button` |
| Card             | Garmin (icon only) "Connect" button   | (16, 325, 398x65)  | `connected_apps.garmin_connect_button`     |
| Card             | TriDot "Notify Me" / Coming soon      | (16, 400, 398x65)  | `connected_apps.tridot_notify_button`      |
| Card             | Runna "Notify Me" / Coming soon       | (16, 480, 398x65)  | `connected_apps.runna_notify_button`       |
| Card             | VDOT "Notify Me" / Coming soon        | (16, 560, 398x65)  | `connected_apps.vdot_notify_button`        |
| Card             | Strava "Notify Me" / Coming soon      | (16, 640, 398x65)  | `connected_apps.strava_notify_button`      |

### Notes
- Same scaffold as the onboarding **Connect Your Training** screen but with no Continue/Skip buttons at the bottom (this is the in-app settings view).
- Tapping Connect on a real provider would open an OAuth flow (Final Surge: web view; Garmin: OAuth PKCE — see MEMORY.md notes). Not exercised during audit because we'd need real credentials.
- Once connected, the Connect button presumably changes to "Disconnect" or shows last-sync info; this state is documented in MEMORY (Garmin Refresh button + reset-push escape hatch).
