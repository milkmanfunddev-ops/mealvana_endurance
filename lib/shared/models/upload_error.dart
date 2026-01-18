/// Model representing an error that occurred during upload attempt.
class UploadError {
  /// Repository key where the error occurred (e.g., "activities")
  final String repository;

  /// Error message
  final String error;

  /// Timestamp when the error occurred
  final DateTime timestamp;

  /// Number of retry attempts made
  final int retryAttempts;

  UploadError({
    required this.repository,
    required this.error,
    required this.timestamp,
    this.retryAttempts = 0,
  });

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'repository': repository,
      'error': error,
      'timestamp': timestamp.toIso8601String(),
      'retry_attempts': retryAttempts,
    };
  }

  /// Create from JSON
  factory UploadError.fromJson(Map<String, dynamic> json) {
    return UploadError(
      repository: json['repository'] as String,
      error: json['error'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      retryAttempts: json['retry_attempts'] as int? ?? 0,
    );
  }
}
