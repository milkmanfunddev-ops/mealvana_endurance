/// Domain model for workout notes
/// Represents a single workout note entry with optional rating
class WorkoutNote {
  const WorkoutNote({
    required this.id,
    required this.userId,
    this.activityId,
    required this.noteText,
    this.rating,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Unique identifier for the note
  final String id;

  /// User ID (UUID-based identifier)
  final String userId;

  /// Optional reference to activity ID
  final String? activityId;
  
  /// The text content of the note
  final String noteText;
  
  /// Optional rating (1-5 scale)
  final int? rating;
  
  /// When the note was created
  final DateTime createdAt;
  
  /// When the note was last updated
  final DateTime updatedAt;

  /// Creates a copy of this workout note with the given fields replaced
  WorkoutNote copyWith({
    String? id,
    String? userId,
    String? activityId,
    String? noteText,
    int? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkoutNote(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      activityId: activityId ?? this.activityId,
      noteText: noteText ?? this.noteText,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkoutNote &&
        other.id == id &&
        other.userId == userId &&
        other.activityId == activityId &&
        other.noteText == noteText &&
        other.rating == rating &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      activityId,
      noteText,
      rating,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'WorkoutNote(id: $id, userId: $userId, activityId: $activityId, noteText: $noteText, rating: $rating, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}