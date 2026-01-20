/// Custom exceptions for brick workout operations.
///
/// These exceptions provide specific error types for better error handling
/// and user-friendly error messages.
library;

/// Base exception for brick operations
class BrickException implements Exception {
  const BrickException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'BrickException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Thrown when brick validation fails (e.g., not enough sports, same day requirement)
class BrickValidationException extends BrickException {
  const BrickValidationException(super.message, {super.code});

  /// Factory constructors for common validation errors
  factory BrickValidationException.minimumSports() {
    return const BrickValidationException(
      'Cannot create brick: need at least 2 different sports',
      code: 'MINIMUM_SPORTS',
    );
  }

  factory BrickValidationException.maximumActivities() {
    return const BrickValidationException(
      'Cannot create brick: maximum 3 activities allowed',
      code: 'MAXIMUM_ACTIVITIES',
    );
  }

  factory BrickValidationException.sameDayRequired() {
    return const BrickValidationException(
      'Cannot create brick: all activities must be on the same day',
      code: 'SAME_DAY_REQUIRED',
    );
  }

  factory BrickValidationException.duplicateSports() {
    return const BrickValidationException(
      'Cannot create brick: all activities must be different sports',
      code: 'DUPLICATE_SPORTS',
    );
  }

  factory BrickValidationException.invalidSegmentOrder() {
    return const BrickValidationException(
      'Cannot create brick: segment order does not match selected activities',
      code: 'INVALID_SEGMENT_ORDER',
    );
  }
}

/// Thrown when brick creation fails due to database or network errors
class BrickCreationException extends BrickException {
  const BrickCreationException(super.message, {super.code, this.originalError});

  final Object? originalError;

  factory BrickCreationException.databaseError(Object error) {
    return BrickCreationException(
      'Failed to save brick workout to database',
      code: 'DATABASE_ERROR',
      originalError: error,
    );
  }

  factory BrickCreationException.networkError(Object error) {
    return BrickCreationException(
      'Network error while creating brick workout',
      code: 'NETWORK_ERROR',
      originalError: error,
    );
  }

  factory BrickCreationException.unknown(Object error) {
    return BrickCreationException(
      'An unexpected error occurred while creating brick workout',
      code: 'UNKNOWN_ERROR',
      originalError: error,
    );
  }
}

/// Thrown when ungrouping a brick fails
class BrickUngroupException extends BrickException {
  const BrickUngroupException(super.message, {super.code, this.originalError});

  final Object? originalError;

  factory BrickUngroupException.brickNotFound(String brickId) {
    return BrickUngroupException(
      'Brick workout not found (ID: $brickId)',
      code: 'BRICK_NOT_FOUND',
    );
  }

  factory BrickUngroupException.databaseError(Object error) {
    return BrickUngroupException(
      'Failed to ungroup brick workout',
      code: 'DATABASE_ERROR',
      originalError: error,
    );
  }

  factory BrickUngroupException.networkError(Object error) {
    return BrickUngroupException(
      'Network error while ungrouping brick workout',
      code: 'NETWORK_ERROR',
      originalError: error,
    );
  }
}

/// Thrown when macro generation for brick fails
class BrickMacroGenerationException extends BrickException {
  const BrickMacroGenerationException(super.message, {super.code, this.originalError, this.statusCode});

  final Object? originalError;
  final int? statusCode;

  factory BrickMacroGenerationException.edgeFunctionError(String message, {int? statusCode}) {
    return BrickMacroGenerationException(
      'Edge function error: $message',
      code: 'EDGE_FUNCTION_ERROR',
      statusCode: statusCode,
    );
  }

  factory BrickMacroGenerationException.networkError(Object error) {
    return BrickMacroGenerationException(
      'Network error while generating brick macros. Please check your connection and try again.',
      code: 'NETWORK_ERROR',
      originalError: error,
    );
  }

  factory BrickMacroGenerationException.parsingError(Object error) {
    return BrickMacroGenerationException(
      'Failed to parse macro targets from server response',
      code: 'PARSING_ERROR',
      originalError: error,
    );
  }

  factory BrickMacroGenerationException.invalidSegments() {
    return const BrickMacroGenerationException(
      'Invalid segment data: cannot generate macros',
      code: 'INVALID_SEGMENTS',
    );
  }
}
