# 14 Other

Screens that don't fit other categories: Learn (educational content), Help & Feedback, Rate Your Experience, Report a Bug.

---

## learn
**Screenshot:** `screenshots/01_learn.png`, `screenshots/02_learn_scrolled.png`
**Reached by:** Bottom nav → 4th icon (graduation cap).

### Visible elements
| Role             | Label / Text                       | mobile-mcp coords  | Proposed ValueKey                       |
|------------------|------------------------------------|--------------------|-----------------------------------------|
| Heading          | "Learn"                            | (20, 60, 100x30)   | `learn.title`                           |
| Button (icon)    | Settings gear (top-right)          | ~(405, 75)         | `learn.settings_button`                 |
| Section heading  | "▶ Mealvana 101"                   | (20, 110, 200x26)  | `learn.mealvana_101_section`            |
| Body             | "Free nutrition lessons for endurance athletes" | (20, 145, 400x18) | `learn.mealvana_101_subtitle` |
| Card (h-scroll)  | "MEALVANA 101 - 1.1 / Intro lesson" + thumb + duration "1:37" | (16, 180, ~190x230) | `learn.lesson_card_<index>` |
| Card             | "MEALVANA 101 - 1.2 / Lesson 1.2"  | (210, 180, ~190x230) | `learn.lesson_card_<index>`           |
| Section heading  | "👑 Pro Videos"                    | (20, 430, 200x26)  | `learn.pro_videos_section`              |
| Card             | "PREMIUM VIDEO LIBRARY" / Coming Soon / "Notify Me" | (16, 465, 398x250) | `learn.pro_videos_card` |
| Button           | "Notify Me" (Pro Videos)           | inside card        | `learn.pro_videos_notify_button`        |
| Section heading  | "📖 Courses"                       | scroll             | `learn.courses_section`                 |
| Card             | "STRUCTURED LEARNING PATHS" / Coming Soon | scroll       | `learn.courses_card`                    |
| Button           | "Notify Me" (Courses)              | inside card        | `learn.courses_notify_button`           |

---

## lesson_video
**Screenshot:** `screenshots/03_lesson_video.png`
**Reached by:** Learn → tap a Mealvana 101 video card.

### Visible elements
| Role             | Label / Text          | Proposed ValueKey                  |
|------------------|-----------------------|------------------------------------|
| Button (back)    | Arrow (top-left)      | `lesson.back_button`               |
| Heading          | "MEALVANA 101 - 1.1"  | `lesson.title`                     |
| Button (icon)    | Fullscreen (top-left, below back) | `lesson.fullscreen_button` |
| Button (icon)    | Mute (top-right)      | `lesson.mute_button`               |
| Video player     | (Flutter video_player) | `lesson.video_player`             |
| Button (overlay) | Play/Pause            | `lesson.play_button`               |
| Scrubber         | Bottom progress bar   | `lesson.progress_bar`              |
| Label            | "00:00" / "-01:36"    | `lesson.elapsed_label` / `lesson.remaining_label` |

---

## help_feedback
**Screenshot:** `screenshots/04_help_feedback.png`
**Reached by:** Settings → tap **Help & Feedback**.

### Visible elements
| Role             | Label / Text                          | mobile-mcp coords  | Proposed ValueKey                        |
|------------------|---------------------------------------|--------------------|------------------------------------------|
| Button (back)    | Arrow circle                          | (4, 63)            | `help.back_button`                       |
| Heading          | "Help & Feedback"                     | center             | `help.title`                             |
| Section heading  | "FEEDBACK"                            | (32, 198, 220x18)  | `help.feedback_section`                  |
| Row              | "Rate Your Experience / How likely are you to recommend us?" | (32, 240, 366x90) | `help.rate_row` |
| Row              | "Report a Bug / Help us fix issues you encounter" | (32, 340, 366x90) | `help.report_bug_row` |
| Section heading  | "CONTACT US"                          | (32, 460, 220x18)  | `help.contact_section`                   |
| Row (info)       | "Email Support / support@mealvana.com"| (32, 500, 366x80)  | `help.email_row`                         |
| Row (info)       | "Website / endurance.mealvana.io"     | (32, 590, 366x80)  | `help.website_row`                       |

### Notes
- Email and Website rows likely open `mailto:` / external browser when tapped (not exercised).

---

## rate_experience (Sentry feedback widget)
**Screenshot:** `screenshots/05_rate_experience.png`
**Reached by:** Help & Feedback → tap **Rate Your Experience**.

### Visible elements
This is a **Sentry user feedback widget** rendered as an overlay panel sliding up from the bottom. The app remains visible underneath behind a "Return to app" handle.

| Role             | Label / Text                          | mobile-mcp coords  | Proposed ValueKey                        |
|------------------|---------------------------------------|--------------------|------------------------------------------|
| Status pill      | "Step 1 of 2"                         | top-left           | `feedback.step_indicator`                |
| Button (close)   | "Close" (top-right)                   | top-right          | `feedback.close_button`                  |
| Heading          | "How likely are you to recommend us?" | top                | `feedback.nps_title`                     |
| Body             | "0 = Not likely, 10 = Most likely"    |                    | `feedback.nps_body`                      |
| Radio buttons    | 0..10 squares                          | grid              | `feedback.nps_score_<n>`                 |
| Handle           | "Return to app" (drag handle)         | center             | `feedback.return_to_app_handle`          |

### Step 2 of 2
**Reached by:** Selecting a score on step 1.

| Role             | Label / Text                          | Proposed ValueKey                       |
|------------------|---------------------------------------|-----------------------------------------|
| Heading          | "How likely are you to recommend us to your friends and family?" | `feedback.nps_step2_title` |
| Field (multiline)| Free-form feedback text (optional)    | `feedback.nps_step2_text_field`         |
| Button (outline) | "Back"                                | `feedback.nps_step2_back_button`        |
| Button (primary) | "Submit"                              | `feedback.nps_step2_submit_button`      |

### Notes
- This is a Sentry overlay (not a Flutter route); the close X-button and "Return to app" both dismiss without persisting selection. **Tapping outside the panel does NOT dismiss it** — must use Return to app or Close.
- During audit the X-button at top-right was hard to hit reliably; "Return to app" handle is more accessible.

---

## report_bug (Sentry feedback widget)
**Screenshot:** `screenshots/06_report_bug.png`
**Reached by:** Help & Feedback → tap **Report a Bug**.

### Visible elements
| Role             | Label / Text                          | Proposed ValueKey                       |
|------------------|---------------------------------------|-----------------------------------------|
| Status pill      | "Step 1 of 4"                         | `bug_report.step_indicator`             |
| Label            | "Compose message"                     | `bug_report.compose_label`              |
| Button (text)    | "Discard feedback" (top-right)        | `bug_report.discard_button`             |
| Heading          | "Send us your feedback"               | `bug_report.title`                      |
| Body             | "Add a short description of what you encountered" | `bug_report.subtitle`     |
| Field (multiline)| Placeholder "There's an unknown error when I try to change my avatar..." | `bug_report.message_field` |
| Button (text)    | "Close"                               | `bug_report.close_button`               |
| Button (primary) | "Next →"                              | `bug_report.next_button`                |

### Notes
- 4-step flow (compose → screenshots/attachments → email → confirm). Only step 1 captured.
- Same Sentry overlay scaffold as Rate Your Experience.
