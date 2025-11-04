class ShareResult {
  const ShareResult({
    required this.success,
    this.message,
    this.error,
  });

  final bool success;
  final String? message;
  final String? error;

  factory ShareResult.success({String? message}) {
    return ShareResult(
      success: true,
      message: message,
    );
  }

  factory ShareResult.failure({required String error}) {
    return ShareResult(
      success: false,
      error: error,
    );
  }
}
