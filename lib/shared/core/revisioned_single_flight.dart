/// Collapses concurrent work for the same key while preserving changes that
/// arrive during the work.
///
/// Calling [markChanged] before [run] simply advances the baseline. Calling it
/// while [operation] is running causes one follow-up pass after [beforeRerun]
/// clears any stale result produced by the first pass.
class RevisionedSingleFlight<T> {
  final Map<Object, Future<T>> _inFlight = {};
  final Map<Object, int> _revisions = {};

  void markChanged(Object key) {
    _revisions[key] = (_revisions[key] ?? 0) + 1;
  }

  Future<T> run(
    Object key, {
    required Future<T> Function() operation,
    Future<void> Function()? beforeRerun,
    void Function()? onJoin,
    void Function()? onPassStarted,
    void Function()? onPassFinished,
    void Function()? onRerun,
  }) {
    final existing = _inFlight[key];
    if (existing != null) {
      onJoin?.call();
      return existing;
    }

    late final Future<T> future;
    future =
        _runUntilStable(
          key,
          operation: operation,
          beforeRerun: beforeRerun,
          onPassStarted: onPassStarted,
          onPassFinished: onPassFinished,
          onRerun: onRerun,
        ).whenComplete(() {
          if (identical(_inFlight[key], future)) {
            _inFlight.remove(key);
          }
        });
    _inFlight[key] = future;
    return future;
  }

  Future<T> _runUntilStable(
    Object key, {
    required Future<T> Function() operation,
    required Future<void> Function()? beforeRerun,
    required void Function()? onPassStarted,
    required void Function()? onPassFinished,
    required void Function()? onRerun,
  }) async {
    while (true) {
      final revisionAtStart = _revisions[key] ?? 0;
      onPassStarted?.call();
      late final T result;
      try {
        result = await operation();
      } finally {
        onPassFinished?.call();
      }

      if ((_revisions[key] ?? 0) == revisionAtStart) {
        return result;
      }

      await beforeRerun?.call();
      onRerun?.call();
    }
  }
}
