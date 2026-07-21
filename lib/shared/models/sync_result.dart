/// Result of a repository sync operation
class SyncResult {
  final SyncStatus status;
  final int count;
  final String? errorMessage;
  final Object? error;
  final StackTrace? stackTrace;

  const SyncResult._({
    required this.status,
    this.count = 0,
    this.errorMessage,
    this.error,
    this.stackTrace,
  });

  /// Successful sync with the number of records synced
  factory SyncResult.success({required int count}) {
    return SyncResult._(status: SyncStatus.success, count: count);
  }

  /// Sync failed with error information
  factory SyncResult.failure({
    required Object error,
    StackTrace? stackTrace,
    String? message,
  }) {
    return SyncResult._(
      status: SyncStatus.failure,
      error: error,
      stackTrace: stackTrace,
      errorMessage: message ?? error.toString(),
    );
  }

  /// No records to sync (repository already up to date)
  factory SyncResult.nothingToSync() {
    return const SyncResult._(status: SyncStatus.nothingToSync, count: 0);
  }

  bool get isSuccess => status == SyncStatus.success;
  bool get isFailure => status == SyncStatus.failure;
  bool get isNothingToSync => status == SyncStatus.nothingToSync;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SyncResult &&
        other.status == status &&
        other.count == count &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return Object.hash(status, count, errorMessage);
  }

  @override
  String toString() {
    switch (status) {
      case SyncStatus.success:
        return 'SyncResult.success(count: $count)';
      case SyncStatus.failure:
        return 'SyncResult.failure(error: $errorMessage)';
      case SyncStatus.nothingToSync:
        return 'SyncResult.nothingToSync()';
    }
  }
}

/// Status of a sync operation
enum SyncStatus { success, failure, nothingToSync }
