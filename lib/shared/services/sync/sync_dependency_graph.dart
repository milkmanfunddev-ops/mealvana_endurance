/// Canonical dependency graph for repository-level sync ordering.
///
/// Keep this map as the single source of truth for repository dependencies.
class SyncDependencyGraph {
  const SyncDependencyGraph._();

  static const Map<String, List<String>> dependenciesByRepository = {
    'users': [],
    'foods': [],
    'carb_loading_foods': [],
    'activities': ['users'],
    // events.activity_id has an FK to activities.id, so a dirty event can only
    // be uploaded once its activity exists remotely.
    'events': ['users', 'activities'],
    'feedback': ['users'],
    'food_preferences': ['users', 'template_foods'],
    'user_foods': ['users'],
    'integrations': ['users'],
    'coaches': ['users'],
    'coach_athlete_relationships': ['coaches', 'users'],
    'carb_loading_plans': ['users', 'events'],
    'carb_loading_days': ['carb_loading_plans'],
    'carb_loading_day_meals': ['carb_loading_days', 'carb_loading_foods'],
    'coach_messages': ['coach_athlete_relationships'],
    'template_foods': [],
    'templates': ['template_foods'],
    'during_workout_templates': ['template_foods'],
    'post_workout_templates': ['template_foods'],
    'pre_workout_templates': ['template_foods'],
    'personal_templates': ['users'],
    'formula_pins': ['users'],
    'onboarding_surveys': ['users'],
    'personal_formulas': ['users'],
    'meal_logs': ['users'],
    'saved_meals': ['users'],
  };

  static List<String> dependenciesFor(String repositoryKey) {
    return dependenciesByRepository[repositoryKey] ?? const [];
  }

  static Iterable<String> get repositoryKeys => dependenciesByRepository.keys;

  /// Groups [keys] into dependency levels: every key in level N depends only on
  /// keys in levels < N. Callers upload/sync one level at a time (in parallel
  /// within a level) so a child row is never written before its parent exists.
  ///
  /// Keys outside [keys] are ignored when computing depth, so callers can order
  /// any subset of the graph. Dependencies not present in the graph are treated
  /// as depth 0. A cycle (which the schema does not have) would leave keys
  /// unplaced; those are appended as a final level rather than dropped.
  static List<List<String>> topologicalLevels(Iterable<String> keys) {
    final remaining = keys.toSet();
    final depths = <String, int>{};

    // Iterate to a fixed point. The graph is a shallow DAG, so this converges in
    // a handful of passes.
    var progressed = true;
    while (progressed && depths.length < remaining.length) {
      progressed = false;
      for (final key in remaining) {
        if (depths.containsKey(key)) continue;

        final deps = dependenciesFor(
          key,
        ).where(remaining.contains).toList(growable: false);

        if (deps.every(depths.containsKey)) {
          depths[key] = deps.isEmpty
              ? 0
              : deps.map((d) => depths[d]!).reduce((a, b) => a > b ? a : b) + 1;
          progressed = true;
        }
      }
    }

    final maxDepth = depths.values.isEmpty
        ? -1
        : depths.values.reduce((a, b) => a > b ? a : b);

    final levels = <List<String>>[
      for (var depth = 0; depth <= maxDepth; depth++)
        [
          for (final key in remaining)
            if (depths[key] == depth) key,
        ],
    ];

    // Anything left unplaced would be part of a cycle. Upload it last rather
    // than silently dropping the records.
    final unplaced = [
      for (final key in remaining)
        if (!depths.containsKey(key)) key,
    ];
    if (unplaced.isNotEmpty) levels.add(unplaced);

    return levels;
  }
}
