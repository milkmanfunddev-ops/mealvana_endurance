/// Result of checking app version and schema version against remote configuration
sealed class VersionCheckResult {
  const VersionCheckResult();

  /// App version and schema version are both compatible
  const factory VersionCheckResult.ok() = VersionCheckOk;

  /// App version is below minimum required version
  const factory VersionCheckResult.updateRequired({
    required String currentVersion,
    required String requiredVersion,
  }) = VersionCheckUpdateRequired;

  /// Schema version mismatch requires database resync
  const factory VersionCheckResult.resyncRequired({
    required int localSchemaVersion,
    required int remoteSchemaVersion,
  }) = VersionCheckResyncRequired;

  bool get isOk => this is VersionCheckOk;
  bool get isUpdateRequired => this is VersionCheckUpdateRequired;
  bool get isResyncRequired => this is VersionCheckResyncRequired;
}

/// App and schema versions are compatible - normal startup
class VersionCheckOk extends VersionCheckResult {
  const VersionCheckOk();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is VersionCheckOk;
  }

  @override
  int get hashCode => 0;

  @override
  String toString() => 'VersionCheckResult.ok()';
}

/// App version is below minimum required version - force upgrade
class VersionCheckUpdateRequired extends VersionCheckResult {
  final String currentVersion;
  final String requiredVersion;

  const VersionCheckUpdateRequired({
    required this.currentVersion,
    required this.requiredVersion,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is VersionCheckUpdateRequired &&
        other.currentVersion == currentVersion &&
        other.requiredVersion == requiredVersion;
  }

  @override
  int get hashCode => Object.hash(currentVersion, requiredVersion);

  @override
  String toString() {
    return 'VersionCheckResult.updateRequired('
        'current: $currentVersion, required: $requiredVersion)';
  }
}

/// Schema version mismatch - database resync required
class VersionCheckResyncRequired extends VersionCheckResult {
  final int localSchemaVersion;
  final int remoteSchemaVersion;

  const VersionCheckResyncRequired({
    required this.localSchemaVersion,
    required this.remoteSchemaVersion,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is VersionCheckResyncRequired &&
        other.localSchemaVersion == localSchemaVersion &&
        other.remoteSchemaVersion == remoteSchemaVersion;
  }

  @override
  int get hashCode => Object.hash(localSchemaVersion, remoteSchemaVersion);

  @override
  String toString() {
    return 'VersionCheckResult.resyncRequired('
        'local: $localSchemaVersion, remote: $remoteSchemaVersion)';
  }
}
