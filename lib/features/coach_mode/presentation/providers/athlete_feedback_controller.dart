import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/coach_service.dart';
import '../../domain/coach_feedback.dart';

part 'athlete_feedback_controller.g.dart';

/// State for the athlete feedback screen
class AthleteFeedbackState {
  final List<CoachFeedback> allFeedback;
  final Map<String, String> coachNames; // coachId -> coach name

  const AthleteFeedbackState({
    this.allFeedback = const [],
    this.coachNames = const {},
  });

  bool get isEmpty => allFeedback.isEmpty;
  bool get hasFeedback => allFeedback.isNotEmpty;
  int get feedbackCount => allFeedback.length;

  /// Get coach name by ID, with fallback
  String getCoachName(String coachId) {
    return coachNames[coachId] ?? 'Coach';
  }

  AthleteFeedbackState copyWith({
    List<CoachFeedback>? allFeedback,
    Map<String, String>? coachNames,
  }) {
    return AthleteFeedbackState(
      allFeedback: allFeedback ?? this.allFeedback,
      coachNames: coachNames ?? this.coachNames,
    );
  }
}

@riverpod
class AthleteFeedbackController extends _$AthleteFeedbackController {
  CoachService get _coachService => ref.read(coachServiceProvider);

  @override
  FutureOr<AthleteFeedbackState> build() async {
    return _loadFeedback();
  }

  Future<AthleteFeedbackState> _loadFeedback() async {
    // Get all active coach relationships for this athlete
    final coaches = await _coachService.getMyCoaches();

    if (coaches.isEmpty) {
      return const AthleteFeedbackState();
    }

    // Collect all feedback from all coaches
    final allFeedback = <CoachFeedback>[];
    final coachNames = <String, String>{};

    for (final relationship in coaches) {
      // Get feedback for this relationship
      final feedback = await _coachService.getFeedbackForRelationship(
        relationship.id,
      );

      // Only include feedback visible to athlete
      final visibleFeedback = feedback.where((f) => f.isVisibleToAthlete);
      allFeedback.addAll(visibleFeedback);

      // Store coach name (we'd need to look this up from the coaches table)
      // For now use a placeholder - in a real implementation we'd join with coaches table
      coachNames[relationship.coachId] = 'Coach ${relationship.coachId.substring(0, 8)}';
    }

    // Sort by date (newest first)
    allFeedback.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return AthleteFeedbackState(
      allFeedback: allFeedback,
      coachNames: coachNames,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
