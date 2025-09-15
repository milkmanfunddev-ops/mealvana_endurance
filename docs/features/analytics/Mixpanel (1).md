Mixpanel Instrumentation Guide — Mealvana Endurance

Purpose: enable an LLM coding tool (and human devs) to generate correct, consistent Mixpanel tracking code for the Mealvana Endurance app and to support the North-Star metric: Successful fueling plans per weekly active user (WAU).

⸻

1) Overview

Platforms: iOS (Swift), Android (Kotlin), React Native/Expo (JS/TS)
Analytics vendor: Mixpanel
Event naming: snake_case, action-oriented (e.g., plan_saved)
Property naming: snake_case with explicit units (_g, _ml, _mg, _pct, _mi, _min)
Time format: ISO-8601 strings with timezone (e.g., 2025-09-06T06:00:00-05:00)
IDs: plan_id is a UUID v4 generated at plan_flow_started and persisted on all downstream events for that plan

The detailed schema for events & properties lives in our tracking plan (CSV). If you don’t have it locally, request the latest copy.

⸻

2) North-Star Metric Definition

Successful fueling plan = a plan that meets this sequence within a time window:
	1.	plan_saved
	2.	reminder_fired
	3.	plan_opened_from_reminder (tap-through)

Hold plan_id constant across the steps.

Default time windows
	•	Step 1 → 2: ≤ 48h
	•	Step 2 → 3: ≤ 8h

North-Star: Successful fueling plans per WAU (weekly). See §9 for how to build this in Mixpanel.

⸻

3) Global SDK Setup

iOS (Swift)

// AppDelegate.swift
import Mixpanel

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Mixpanel.initialize(token: "<MIXPANEL_PROJECT_TOKEN>", trackAutomaticEvents: true)
    Analytics.shared.bootstrap()
    return true
}

Android (Kotlin)

// MyApplication.kt
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val mp = MixpanelAPI.getInstance(this, "<MIXPANEL_PROJECT_TOKEN>")
        Analytics.bootstrap(mp)
    }
}

React Native (JS/TS)

import Mixpanel from '@mixpanel/react-native';

await Mixpanel.init('<MIXPANEL_PROJECT_TOKEN>', true); // opt-in auto events as you like
Analytics.bootstrap();


⸻

4) Analytics Wrapper (required)

Create a strongly-typed wrapper so events are consistent and easy to test. The LLM tool should generate one per platform.

Responsibilities
	•	identify(distinctId) once after auth/onboarding
	•	setSuperProperties(props) for persistent context (gender, age, app_version, device, experiment_variant, etc.)
	•	track(event, properties) with runtime validation (required props, numeric types, units)
	•	withPlan(planId) helper to attach plan_id automatically
	•	timeEvent() / trackWithDuration() helpers where needed

Common super-properties (set on app open or profile save)
	•	app_version, os_version, device_model, locale
	•	gender, age, height_cm, weight_kg, run_with_bottle
	•	signup_source
	•	experiment_variant (when flags are active)

⸻

5) Event Catalog (what to instrument)

The full property schema is in the tracking plan CSV. Below is the minimum viable set for the North-Star, then recommended events.

5.1 Minimum viable (North-Star capable)
	1.	plan_flow_started
When: user begins creating a plan (first edit or CTA on “Adjust Your Macros”).
Required props:
plan_id (uuid), screen, activity_type, distance_mi, duration_min or pace_sec_per_mile, time_before_run_min, gut_training_level, sweat_rate_level, temperature_c, humidity_pct, experiment_variant?
	2.	plan_saved
When: user taps Save on Plan.
Required props:
plan_id, totals & coverage: carbs_total_g, sodium_total_mg, fluids_total_ml,
carbs_coverage_pct, sodium_coverage_pct, fluids_coverage_pct,
items_pre_count, items_during_count, items_post_count,
seconds_to_save (time since plan_flow_started)
	3.	reminder_set (optional but recommended)
When: user schedules a reminder.
Required props: plan_id, remind_at_iso
	4.	reminder_fired
When: local push notification is delivered.
Required props: plan_id
	5.	plan_opened_from_reminder
When: user taps the notification and lands on the plan.
Required props: plan_id, screen

With just these five events you can compute the North-Star.

5.2 Recommended usage/quality events
	•	targets_viewed, edit_all_macros_opened, macros_changed(macro, old_value, new_value)
	•	Item CRUD: item_added, item_removed, item_quantity_changed
	•	guidelines_opened(topic) for education engagement
	•	feedback_prompt_shown, feedback_submitted(plan_match_rating, app_intent)
	•	plan_exported(channel, format)
	•	error_shown(error_code, message, screen)
	•	(optional) plan_generated, plan_viewed

⸻

6) Where to fire events (screen → event map)
	•	Adjust Your Macros: plan_flow_started (first edit/CTA), targets_viewed, edit_all_macros_opened, macros_changed
	•	Plan (generated): plan_generated (success), plan_viewed (screen load), item CRUD events, plan_saved (CTA)
	•	Guidelines bottom sheet: guidelines_opened(topic)
	•	Feedback sheet: feedback_prompt_shown → feedback_submitted
	•	Reminders: reminder_set (schedule) → reminder_fired (notification delivered) → plan_opened_from_reminder (deep-link open)

⸻

7) Code templates (per platform)

7.1 iOS (Swift)

// Analytics.swift
import Mixpanel

final class Analytics {
    static let shared = Analytics()
    private init() {}

    func bootstrap() {
        let mp = Mixpanel.mainInstance()
        mp.registerSuperProperties([
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev",
            "os_version": UIDevice.current.systemVersion,
            "device_model": UIDevice.current.model
        ])
    }

    func identify(_ id: String) {
        Mixpanel.mainInstance().identify(distinctId: id)
    }

    func setSuper(_ props: Properties) {
        Mixpanel.mainInstance().registerSuperProperties(props)
    }

    func track(_ event: String, _ props: Properties = [:]) {
        Mixpanel.mainInstance().track(event: event, properties: props)
    }
}

// Example usage
func savePlan(plan: Plan, totals: Totals) {
    Analytics.shared.track("plan_saved", [
        "plan_id": plan.id.uuidString,
        "carbs_total_g": totals.carbs,
        "sodium_total_mg": totals.sodium,
        "fluids_total_ml": totals.fluids,
        "carbs_coverage_pct": totals.carbsCoverage,
        "sodium_coverage_pct": totals.sodiumCoverage,
        "fluids_coverage_pct": totals.fluidsCoverage,
        "items_pre_count": plan.pre.count,
        "items_during_count": plan.during.count,
        "items_post_count": plan.post.count,
        "seconds_to_save": plan.secondsFromStart
    ])
}

7.2 Android (Kotlin)

// Analytics.kt
object Analytics {
    private lateinit var mp: MixpanelAPI

    fun bootstrap(instance: MixpanelAPI) {
        mp = instance
        mp.registerSuperProperties(JSONObject(mapOf(
            "app_version" to BuildConfig.VERSION_NAME,
            "os_version" to Build.VERSION.RELEASE
        )))
    }

    fun identify(id: String) = mp.identify(id)

    fun setSuper(props: Map<String, Any>) =
        mp.registerSuperProperties(JSONObject(props))

    fun track(event: String, props: Map<String, Any?> = emptyMap()) =
        mp.track(event, JSONObject(props))
}

// Example
fun onReminderFired(planId: UUID) {
    Analytics.track("reminder_fired", mapOf("plan_id" to planId.toString()))
}

7.3 React Native (JS/TS)

// analytics.ts
import Mixpanel from '@mixpanel/react-native';

export const Analytics = {
  async bootstrap() {
    const appVersion = '1.0.0';
    Mixpanel.registerSuperProperties({
      app_version: appVersion,
      locale: Intl.DateTimeFormat().resolvedOptions().locale,
    });
  },
  identify(id: string) {
    Mixpanel.identify(id);
  },
  track(event: string, props: Record<string, any> = {}) {
    Mixpanel.track(event, props);
  },
};

// Example
Analytics.track('plan_opened_from_reminder', { plan_id: planId });


⸻

8) QA & Validation Checklist
	•	Live View: open Mixpanel → Live View → run the flow → confirm events appear with correct properties & types
	•	Lexicon: Data Management → Lexicon → confirm events are listed and add human-readable descriptions
	•	plan_id threading: search a plan_id and verify it spans start→save→reminder→open
	•	Units: grams/milligrams/milliliters/percents are numeric, not strings (no % sign)
	•	Test matrix: iOS/Android; cold vs warm start; reminders foreground/background; airplane mode (retry logic)
	•	Internal testers cohort: mark and exclude from dashboards and alerts

⸻

9) Mixpanel Board (North-Star)
	1.	Funnel: plan_saved → reminder_fired → plan_opened_from_reminder
	•	Hold property constant: plan_id
	•	Windows: 48h then 8h
	•	Save as Successful Plan (3-step)
	2.	Metric: Save the funnel’s Total Conversions (Weekly) as Successful Plans.
	3.	WAU Metric: Active Users (Weekly) — either Any Event or filtered to plan_saved.
	4.	Derived Metric: Successful Plans per WAU = Successful Plans / WAU.
Add goal line & alerts.
	5.	Breakdowns: by experiment_variant, sweat_rate_level, gut_training_level, temperature_c, humidity_pct.

⸻

10) Data Governance & Privacy
	•	Do not send PII (addresses, full names).
	•	Age = computed from birthday; send only the derived age number.
	•	Send location only if permissioned and coarse (city/state).
	•	Filter/flag internal testers.
	•	Version-gate new properties (keep backward compatibility).

⸻

11) LLM Coding Tool — Task List

When the task is “add Mixpanel tracking,” the tool should:
	1.	Create/Update an Analytics wrapper with identify, setSuperProperties, track, withPlan(planId).
	2.	Insert minimum viable calls (§5.1) at the exact screen touchpoints (§6).
	3.	Generate UUID v4 for plan_id at plan_flow_started; propagate it.
	4.	Emit numeric metrics with unit-suffixed property names (_g, _ml, _mg, _pct, _mi, _min).
	5.	Hook reminders properly: fire reminder_fired on delivery; plan_opened_from_reminder on deep-link open.
	6.	Register super-properties from Settings/Profile and environment.
	7.	Provide basic unit tests or a debug flag to log emitted events locally.
	8.	Produce a PR checklist referencing §8 and paste a Live View screenshot after manual run.

⸻

12) Glossary
	•	Plan coverage %: total provided / target * 100 (e.g., carbs_coverage_pct).
	•	WAU: weekly active users (unique).
	•	North-Star: the single guiding metric the team optimizes.

⸻

End of README.