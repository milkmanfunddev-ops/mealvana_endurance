/// What Vana is told about the screen the athlete is on.
///
/// Ids only. The client never sends a name, a title, or any free text — the
/// server resolves the ids into one sentence from the athlete's own rows, under
/// their RLS. See `supabase/functions/_shared/vana/situation.ts`, which holds
/// the matching screen table; the two must move together.
///
/// A Situation is never stored. It rides one message and is gone.
library;

import 'package:flutter/foundation.dart';

/// The screens that have something in view, and what that thing is.
enum VanaScreen {
  /// The meal-planning Plan tab (`/food?tab=plan`) — the week's plan, on a day.
  planTab('/food'),

  /// Meal detail.
  mealDetail('/food/meals/:id'),

  /// Cooking mode.
  cookingMode('/food/cook/:id'),

  /// Fuel log for a session.
  fuelLog('/fuel-log'),

  /// A session's fuel plan (the activity detail screen).
  activityPlan('/plan'),

  /// The same screen, reached from adjust-macros.
  currentPlan('/current-plan'),

  /// An event's checklist.
  eventChecklist('/events/:eventId/checklist'),

  /// The events list.
  events('/events'),

  /// Any meal-logging screen — a day and a slot.
  mealLog('/meal-log'),

  /// The main tab shell — a day and nothing else.
  main('/main');

  const VanaScreen(this.route);

  /// The route pattern sent to the server. Matches the server's screen table.
  final String route;
}

@immutable
class VanaSituation {
  const VanaSituation({
    required this.route,
    this.entityId,
    this.date,
    this.slot,
  });

  /// A screen from the table, with whatever it has in view.
  VanaSituation.screen(
    VanaScreen screen, {
    this.entityId,
    DateTime? date,
    this.slot,
  }) : route = screen.route,
       date = date == null ? null : _iso(date);

  /// Any other screen: the route, and nothing else. Still worth sending — being
  /// in settings changes what a question means.
  const VanaSituation.route(this.route)
    : entityId = null,
      date = null,
      slot = null;

  /// The matched route pattern, e.g. `/plan`, `/food/meals/:id`.
  final String route;

  /// The primary entity in view, when the route has one.
  final String? entityId;

  /// The day the screen is showing, `YYYY-MM-DD`.
  final String? date;

  /// Meal-log screens only: which slot is being logged.
  final String? slot;

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'route': route,
    if (entityId != null && entityId!.isNotEmpty) 'entityId': entityId,
    if (date != null && date!.isNotEmpty) 'date': date,
    if (slot != null && slot!.isNotEmpty) 'slot': slot,
  };

  @override
  bool operator ==(Object other) =>
      other is VanaSituation &&
      other.route == route &&
      other.entityId == entityId &&
      other.date == date &&
      other.slot == slot;

  @override
  int get hashCode => Object.hash(route, entityId, date, slot);

  @override
  String toString() => 'VanaSituation(${toJson()})';
}
