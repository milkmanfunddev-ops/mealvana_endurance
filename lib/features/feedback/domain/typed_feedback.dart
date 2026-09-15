/// Feedback the athlete typed to Vana, as the server filed it
/// (`feedback_saved` part, `user_feedback` row) and as the device forwards it
/// to Wiredash so typed feedback and shaken reports share one inbox
/// (mp-245 clause 6, ticket 26).
///
/// [sentiment] and [about] are the wire strings (`positive|negative|neutral`,
/// `vana|app|suggestion`), not the chat feature's enums: this type sits under
/// `features/feedback` and must not depend on `features/meal_planning`.
class TypedFeedback {
  const TypedFeedback({
    required this.message,
    required this.sentiment,
    required this.about,
    this.conversationId,
  });

  /// The athlete's own words.
  final String message;
  final String sentiment;
  final String about;

  /// The Vana conversation the words came from (null only if the server
  /// never named one).
  final String? conversationId;

  @override
  String toString() =>
      'TypedFeedback(about: $about, sentiment: $sentiment, '
      'conversation: $conversationId, message: $message)';
}
