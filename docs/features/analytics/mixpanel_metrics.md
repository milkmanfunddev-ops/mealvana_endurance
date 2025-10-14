# Mixpanel metrics

# North-star + core KPIs

- #. of weekly active users (WAU)
- #. of weekly new users
- **Activation:** % new users who save a plan in first 24h and **time-to-first-plan**.
- Successful fueling plans per weekly active user
- **Retention:** D1/D7/D28 action retention using plan_saved
- **Conversion (early proxy):** % plan_saved → reminder_set → plan_opened_from_reminder. (Add subscription events later.)

# Hypothesis Testing

- H0: Users would like to have better control of the macro levels.
    - Percentage of unique users who have edited macros
- H0: Users would like to view information of how the macros are calculated.
    - Percentage of unique users who have clicked the info button
- H0: Users would like to fine-tune the plans.
    - Percentage of unique users who have deleted items
    - Percentage of unique users who have swapped items
    - Percentage of unique users who have added items
- H0: Reminder will increase user retention.
    - Weekly retention of users who have set reminders
    - Percentage of reminders being clicked