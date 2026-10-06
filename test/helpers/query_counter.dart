// Counts the statements a real Drift database runs, for N+1 regression tests
// (Sentry's "N+1 Query" performance issues, ticket 24).
//
//   final counter = QueryCounter();
//   final db = AppDatabase.forTesting(
//     NativeDatabase.memory().interceptWith(counter),
//   );
//   counter.reset();                    // after seeding
//   ...                                 // the code under test
//   expect(counter.selectsOn('activities'), 3);
//
// A `batch` reaches the executor as ONE `runBatched` call (one transaction,
// one round-trip, one Sentry span), which is what a batched write should be.
import 'package:drift/drift.dart';

class QueryCounter extends QueryInterceptor {
  final List<String> selects = [];
  final List<String> customs = [];
  final List<String> inserts = [];
  final List<String> updates = [];
  final List<String> deletes = [];
  final List<BatchedStatements> batches = [];

  void reset() {
    selects.clear();
    customs.clear();
    inserts.clear();
    updates.clear();
    deletes.clear();
    batches.clear();
  }

  /// SELECTs whose FROM names [table] (quoted or not).
  int selectsOn(String table) => selects.where((s) => _from(s, table)).length;

  /// Custom statements (`customStatement`) that mention [needle].
  int customsMatching(String needle) =>
      customs.where((s) => s.contains(needle)).length;

  static bool _from(String sql, String table) =>
      RegExp('FROM\\s+"?$table"?\\b', caseSensitive: false).hasMatch(sql);

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selects.add(statement);
    return super.runSelect(executor, statement, args);
  }

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    customs.add(statement);
    return super.runCustom(executor, statement, args);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    inserts.add(statement);
    return super.runInsert(executor, statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    updates.add(statement);
    return super.runUpdate(executor, statement, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    deletes.add(statement);
    return super.runDelete(executor, statement, args);
  }

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) {
    batches.add(statements);
    return super.runBatched(executor, statements);
  }
}
