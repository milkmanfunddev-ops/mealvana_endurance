/// Thrown when the athlete tries to undo (mark undone, or skip) a workout a
/// training platform reported completed (`completion_type = 'provider'`).
/// Such a completion is final for the athlete, like a Garmin-verified one
/// (Lee, 2026-09-25; final-surge-completion.PROPOSED.md rule 1): undoing it
/// would only flip back on the next sync.
class ProviderCompletionIsFinal implements Exception {
  const ProviderCompletionIsFinal(this.activityId);

  final String activityId;

  @override
  String toString() =>
      'ProviderCompletionIsFinal: activity $activityId was completed by a '
      'training platform and cannot be undone';
}
