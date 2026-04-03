/// Consistency contract for write operations.
///
/// - [offlineFirst]: accept local write first and sync remote asynchronously.
/// - [remoteAckRequired]: require server acknowledgment before treating write
///   as complete in the calling flow.
enum WriteConsistency { offlineFirst, remoteAckRequired }

extension WriteConsistencyValue on WriteConsistency {
  String get value {
    switch (this) {
      case WriteConsistency.offlineFirst:
        return 'offline_first';
      case WriteConsistency.remoteAckRequired:
        return 'remote_ack_required';
    }
  }
}

/// Helper for selecting default consistency mode based on actor/owner IDs.
class WriteConsistencyResolver {
  const WriteConsistencyResolver._();

  static WriteConsistency forActorAndOwner({
    required String actorUserId,
    required String ownerUserId,
  }) {
    final actor = actorUserId.trim().toLowerCase();
    final owner = ownerUserId.trim().toLowerCase();
    if (actor.isNotEmpty && owner.isNotEmpty && actor != owner) {
      return WriteConsistency.remoteAckRequired;
    }
    return WriteConsistency.offlineFirst;
  }
}
