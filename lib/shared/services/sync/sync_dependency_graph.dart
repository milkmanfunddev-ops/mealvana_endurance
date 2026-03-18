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
    'events': ['users'],
    'feedback': ['users'],
    'food_preferences': ['users', 'template_foods'],
    'user_foods': ['users'],
    'coaches': ['users'],
    'coach_athlete_relationships': ['coaches', 'users'],
    'carb_loading_plans': ['users', 'events'],
    'carb_loading_days': ['carb_loading_plans'],
    'carb_loading_day_meals': ['carb_loading_days', 'carb_loading_foods'],
    'coach_messages': ['coach_athlete_relationships'],
    'template_foods': [],
    'templates': ['template_foods'],
    'personal_templates': ['users'],
  };

  static List<String> dependenciesFor(String repositoryKey) {
    return dependenciesByRepository[repositoryKey] ?? const [];
  }

  static Iterable<String> get repositoryKeys => dependenciesByRepository.keys;
}
