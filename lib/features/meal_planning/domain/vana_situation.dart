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
  main('/main'),

  /// The personal-formula editor, editing a saved formula.
  formulaEditor('/settings/food-preferences/formula-library/personal/:id'),

  /// The same editor, building one from scratch.
  formulaEditorNew(
    '/settings/food-preferences/formula-library/personal/create',
  );

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
    this.draft,
  });

  /// A screen from the table, with whatever it has in view.
  VanaSituation.screen(
    VanaScreen screen, {
    this.entityId,
    DateTime? date,
    this.slot,
  }) : route = screen.route,
       draft = null,
       date = date == null ? null : _iso(date);

  /// The formula editor, with the draft as it is on screen — unsaved edits
  /// included (mp-274). The only screen that sends more than ids, and the
  /// server refuses a draft from anywhere else.
  VanaSituation.formulaEditor({
    required this.draft,
    String? formulaId,
  }) : route =
           (formulaId == null
                   ? VanaScreen.formulaEditorNew
                   : VanaScreen.formulaEditor)
               .route,
       entityId = formulaId,
       date = null,
       slot = null;

  /// Any other screen: the route, and nothing else. Still worth sending — being
  /// in settings changes what a question means.
  const VanaSituation.route(this.route)
    : entityId = null,
      date = null,
      slot = null,
      draft = null;

  /// What the main tab shell says for the tab on screen. The Fuel Timeline is
  /// the shell's own screen, so it sends the day. Every other tab is sent as
  /// its route (`/food`, `/events`, `/learn`, `/coach`): all tabs share the
  /// `/main` route, so without this a tab with no scope of its own would leave
  /// the previous tab speaking for it. A tab that reports for itself reports
  /// after the shell and wins.
  static VanaSituation shellTab(String tabId, DateTime today) =>
      tabId == 'timeline'
      ? VanaSituation.screen(VanaScreen.main, date: today)
      : VanaSituation.route('/$tabId');

  /// The matched route pattern, e.g. `/plan`, `/food/meals/:id`.
  final String route;

  /// The primary entity in view, when the route has one.
  final String? entityId;

  /// The day the screen is showing, `YYYY-MM-DD`.
  final String? date;

  /// Meal-log screens only: which slot is being logged.
  final String? slot;

  /// The formula editor only: the draft on screen.
  final VanaFormulaDraft? draft;

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'route': route,
    if (entityId != null && entityId!.isNotEmpty) 'entityId': entityId,
    if (date != null && date!.isNotEmpty) 'date': date,
    if (slot != null && slot!.isNotEmpty) 'slot': slot,
    if (draft != null) 'draft': draft!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is VanaSituation &&
      other.route == route &&
      other.entityId == entityId &&
      other.date == date &&
      other.slot == slot &&
      other.draft == draft;

  @override
  int get hashCode => Object.hash(route, entityId, date, slot, draft);

  @override
  String toString() => 'VanaSituation(${toJson()})';
}

/// One component of a formula draft: which food, and how much of it.
///
/// Ids, like everything else the client sends — the server resolves the name
/// from the catalog and the athlete's own foods. During formulas carry no
/// quantity at all; the solver derives the amounts.
@immutable
class VanaFormulaDraftComponent {
  const VanaFormulaDraftComponent({required this.id, this.qty});

  /// `template_foods.id` or `user_foods.id`.
  final String id;

  /// Servings multiplier, or null when the formula has none.
  final double? qty;

  Map<String, dynamic> toJson() => {'id': id, if (qty != null) 'qty': qty};

  @override
  bool operator ==(Object other) =>
      other is VanaFormulaDraftComponent && other.id == id && other.qty == qty;

  @override
  int get hashCode => Object.hash(id, qty);
}

/// The formula editor's draft, as it is on screen (mp-274).
///
/// Structured fields, never a dump of the editor's state: the phase and its
/// sub-phase, the durations and activities it targets, the component ids with
/// their quantities, and the name the athlete typed, capped at
/// [nameCap]. This is the one named exception to mp-043, for one screen; the
/// server validates the same shape and refuses a draft from any other route.
@immutable
class VanaFormulaDraft {
  const VanaFormulaDraft({
    required this.components,
    this.name,
    this.phase,
    this.subPhase,
    this.durations,
    this.activities,
  });

  /// The athlete typed the name, so it is the only free text that travels.
  static const nameCap = 40;

  final List<VanaFormulaDraftComponent> components;
  final String? name;

  /// `before` | `during` | `after`.
  final String? phase;

  /// Before formulas only: `full_meal` | `snack` | `top_up`.
  final String? subPhase;
  final List<String>? durations;
  final List<String>? activities;

  Map<String, dynamic> toJson() {
    final trimmed = name?.trim();
    return {
      if (trimmed != null && trimmed.isNotEmpty)
        'name': trimmed.length > nameCap
            ? trimmed.substring(0, nameCap)
            : trimmed,
      if (phase != null) 'phase': phase,
      if (subPhase != null) 'subPhase': subPhase,
      if (durations != null && durations!.isNotEmpty) 'durations': durations,
      if (activities != null && activities!.isNotEmpty)
        'activities': activities,
      'components': components.map((c) => c.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is VanaFormulaDraft &&
      other.name == name &&
      other.phase == phase &&
      other.subPhase == subPhase &&
      listEquals(other.durations, durations) &&
      listEquals(other.activities, activities) &&
      listEquals(other.components, components);

  @override
  int get hashCode => Object.hash(
    name,
    phase,
    subPhase,
    Object.hashAll(durations ?? const []),
    Object.hashAll(activities ?? const []),
    Object.hashAll(components),
  );
}
