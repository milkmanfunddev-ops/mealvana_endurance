import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_dependency_graph.dart';

/// Position of [key] in a flattened level list, for order assertions.
int _levelOf(List<List<String>> levels, String key) =>
    levels.indexWhere((level) => level.contains(key));

void main() {
  group('SyncDependencyGraph dependencies', () {
    test('events depends on activities (events.activity_id FK)', () {
      // Regression: Sentry MEALVANA-ENDURANCE-DEV-5K. Uploading a dirty event
      // before its activity violates events_activity_id_fkey (Postgres 23503).
      expect(SyncDependencyGraph.dependenciesFor('events'), contains('activities'));
    });

    test('every declared dependency is itself a known repository', () {
      for (final entry in SyncDependencyGraph.dependenciesByRepository.entries) {
        for (final dep in entry.value) {
          expect(
            SyncDependencyGraph.dependenciesByRepository.containsKey(dep),
            isTrue,
            reason: '${entry.key} depends on unknown repository "$dep"',
          );
        }
      }
    });
  });

  group('SyncDependencyGraph.topologicalLevels', () {
    test('places a repository after every repository it depends on', () {
      final levels = SyncDependencyGraph.topologicalLevels(
        SyncDependencyGraph.repositoryKeys,
      );

      for (final entry in SyncDependencyGraph.dependenciesByRepository.entries) {
        final repoLevel = _levelOf(levels, entry.key);
        for (final dep in entry.value) {
          expect(
            _levelOf(levels, dep),
            lessThan(repoLevel),
            reason: '${entry.key} must be uploaded after its dependency "$dep"',
          );
        }
      }
    });

    test('orders users before activities before events', () {
      final levels = SyncDependencyGraph.topologicalLevels([
        'events',
        'activities',
        'users',
      ]);

      expect(_levelOf(levels, 'users'), lessThan(_levelOf(levels, 'activities')));
      expect(
        _levelOf(levels, 'activities'),
        lessThan(_levelOf(levels, 'events')),
      );
    });

    test('returns every key exactly once', () {
      const keys = <String>[
        'users',
        'activities',
        'events',
        'carb_loading_plans',
        'feedback',
        'food_preferences',
        'user_foods',
        'meal_logs',
        'saved_meals',
      ];

      final flattened = SyncDependencyGraph.topologicalLevels(
        keys,
      ).expand((level) => level).toList();

      expect(flattened, hasLength(keys.length));
      expect(flattened.toSet(), keys.toSet());
    });

    test('ignores dependencies outside the requested subset', () {
      // 'events' depends on users + activities, but callers may order a subset.
      // The absent dependencies must not strand 'events' in a trailing level.
      final levels = SyncDependencyGraph.topologicalLevels(['events']);

      expect(levels, [
        ['events'],
      ]);
    });

    test('groups independent repositories into the same level', () {
      final levels = SyncDependencyGraph.topologicalLevels([
        'users',
        'activities',
        'feedback',
      ]);

      // activities and feedback both depend only on users, so they can upload
      // concurrently once users lands.
      expect(levels.first, ['users']);
      expect(levels[1], containsAll(['activities', 'feedback']));
    });

    test('handles an empty key set', () {
      expect(SyncDependencyGraph.topologicalLevels(const []), isEmpty);
    });
  });
}
