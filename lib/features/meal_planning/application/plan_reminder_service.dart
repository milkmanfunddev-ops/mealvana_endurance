import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/notification_service.dart';
import '../../../shared/services/prefs_provider.dart';
import '../../content/application/content_service.dart';
import '../../content/domain/content_keys.dart';
import '../domain/cooking_session.dart';
import '../domain/meal_plan.dart';

part 'plan_reminder_service.g.dart';

@riverpod
PlanReminderService planReminderService(Ref ref) => PlanReminderService(
  content: ref.watch(contentServiceProvider),
  prefs: ref.watch(sharedPreferencesProvider),
);

/// Why a reminder was or was not scheduled.
enum PlanReminderOutcome {
  scheduled,

  /// Notifications are off for the app (or unsupported — web).
  noPermission,

  /// The slot is already in the past.
  pastDue,
}

/// The result of one scheduling call: the outcome and, when scheduled, the
/// local time it fires.
class PlanReminderResult {
  const PlanReminderResult(this.outcome, [this.when]);

  final PlanReminderOutcome outcome;
  final DateTime? when;

  bool get scheduled => outcome == PlanReminderOutcome.scheduled;
}

/// Local reminders around a confirmed meal plan (plan Phases 3.5 and 4):
///
/// * the **check-in** — 18:00 the evening before the week's cook day, and
/// * the **debrief** — 18:00 on the Sunday that closes the week.
///
/// Both go through [NotificationService.scheduleReminder] (a no-op on web)
/// under fixed ids, so re-scheduling for the same plan replaces rather than
/// stacks, and a past-due slot is skipped rather than fired immediately.
///
/// **Which day is cook day.** `MealPlan.weekStart` is a **Sunday** (the
/// server's `weekStartFor`, ported in `domain/week_start.dart`; the
/// `MealPlan` doc comment saying Monday is wrong — see
/// `docs/implement_mealplanning/05-flutter-feature.md` "Deviations"). The
/// `cook-sun` session therefore falls on `weekStart` itself, the check-in is
/// the Saturday before it (`weekStart - 1`), and the debrief is the next
/// Sunday (`weekStart + 7`) — the evening the following week's cook would
/// start, which is when "how did last week go?" is worth asking.
///
/// The opt-in toggle ("Check-in and debrief reminders") is a **device
/// preference** in shared_preferences, not a server setting: notifications
/// are per-device, and Vana's server-side settings are things she can flip
/// in conversation.
class PlanReminderService {
  PlanReminderService({
    required ContentService content,
    required SharedPreferences prefs,
  }) : _content = content,
       _prefs = prefs;

  final ContentService _content;
  final SharedPreferences _prefs;

  /// Notification slot ids — distinct from the activity reminders'
  /// legacy slots (1 and 2).
  static const checkinNotificationId = 4101;
  static const debriefNotificationId = 4102;

  /// shared_preferences key for the settings toggle.
  static const remindersPrefKey = 'meal_planning.reminders_enabled';

  /// 18:00 local — both reminders fire at the same evening slot.
  static const reminderHour = 18;

  /// The settings toggle (default OFF).
  bool get remindersEnabled => _prefs.getBool(remindersPrefKey) ?? false;

  /// Flip the toggle. Turning it on with a confirmed [plan] schedules both
  /// reminders for it; turning it off cancels whatever is pending.
  Future<void> setRemindersEnabled(bool enabled, {MealPlan? plan}) async {
    await _prefs.setBool(remindersPrefKey, enabled);
    if (!enabled) {
      await cancelAll();
      return;
    }
    if (plan != null && plan.isConfirmed) await scheduleForPlan(plan);
  }

  /// Both reminders for a confirmed plan; called on confirm when the toggle
  /// is on, and again when the toggle is turned on.
  Future<void> scheduleForPlan(MealPlan plan) async {
    await scheduleCheckin(plan);
    await scheduleDebrief(plan);
  }

  /// The "night before cook day" reminder (also the ConfirmedCard chip).
  Future<PlanReminderResult> scheduleCheckin(MealPlan plan, {DateTime? now}) {
    final when = checkinTimeFor(plan, now: now);
    return _schedule(
      id: checkinNotificationId,
      when: when,
      title: _content.getValue(ContentKeys.mpNotifCheckinTitle),
      body: ContentKeys.format(
        _content.getValue(ContentKeys.mpNotifCheckinBody),
        {'n': plan.meals.length},
      ),
    );
  }

  /// The end-of-week debrief reminder.
  Future<PlanReminderResult> scheduleDebrief(MealPlan plan, {DateTime? now}) {
    final when = debriefTimeFor(plan, now: now);
    return _schedule(
      id: debriefNotificationId,
      when: when,
      title: _content.getValue(ContentKeys.mpNotifDebriefTitle),
      body: ContentKeys.format(
        _content.getValue(ContentKeys.mpNotifDebriefBody),
        {'n': plan.meals.length},
      ),
    );
  }

  Future<void> cancelAll() async {
    await NotificationService.cancelReminder(checkinNotificationId);
    await NotificationService.cancelReminder(debriefNotificationId);
  }

  Future<PlanReminderResult> _schedule({
    required int id,
    required DateTime? when,
    required String title,
    required String body,
  }) async {
    if (when == null) {
      return const PlanReminderResult(PlanReminderOutcome.pastDue);
    }
    if (!await NotificationService.areNotificationsEnabled()) {
      return const PlanReminderResult(PlanReminderOutcome.noPermission);
    }
    await NotificationService.scheduleReminder(
      id: id,
      scheduledDate: when,
      recurring: false,
      title: title,
      body: body,
    );
    return PlanReminderResult(PlanReminderOutcome.scheduled, when);
  }

  // ── Pure date maths (tested directly) ─────────────────────────────────

  /// The plan's cook day: the date of its `cook-sun` session, which by
  /// construction is `weekStart` (a Sunday) — the session carries no date
  /// of its own. Plans with no batch session still get the week's Sunday;
  /// the plan is built around that week either way.
  static DateTime cookDayFor(MealPlan plan) {
    final start = DateTime.parse(plan.weekStart);
    return DateTime(start.year, start.month, start.day);
  }

  /// Whether the plan has a Sunday cook session at all (the chip's copy
  /// says "cook day"; hosts may hide it when nothing is batch-cooked).
  static bool hasCookSession(MealPlan plan) =>
      plan.meals.any((m) => m.session == CookingSession.cookSun);

  /// 18:00 the evening before cook day, or `null` when that is already past.
  static DateTime? checkinTimeFor(MealPlan plan, {DateTime? now}) {
    final cook = cookDayFor(plan);
    final when = DateTime(cook.year, cook.month, cook.day - 1, reminderHour);
    return when.isAfter(now ?? DateTime.now()) ? when : null;
  }

  /// 18:00 on the Sunday that closes the week (`weekStart + 7`), or `null`
  /// when that is already past.
  static DateTime? debriefTimeFor(MealPlan plan, {DateTime? now}) {
    final start = DateTime.parse(plan.weekStart);
    final when = DateTime(start.year, start.month, start.day + 7, reminderHour);
    return when.isAfter(now ?? DateTime.now()) ? when : null;
  }
}
