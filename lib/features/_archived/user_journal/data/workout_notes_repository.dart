import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_service.dart';
import '../../calendar/application/calendar_service.dart';
import '../../activities/application/activities_service.dart';
import '../../activities/domain/activity.dart' as calendar_activity;
import '../domain/workout_note.dart';

part 'workout_notes_repository.g.dart';

class WorkoutNotesRepository {
  WorkoutNotesRepository({
    required CalendarService calendarService,
    required ActivitiesService activitiesService,
    required AuthService authService,
  }) : _calendarService = calendarService,
       _activitiesService = activitiesService,
       _authService = authService;

  final CalendarService _calendarService;
  final ActivitiesService _activitiesService;
  final AuthService _authService;

  Future<String> _requireUserId() async {
    final user = await _authService.getCurrentUser();
    if (user == null) {
      throw Exception('No user session found');
    }
    return user.id;
  }

  Future<List<WorkoutNote>> getAllNotes() async {
    final userId = await _requireUserId();
    final activities = await _calendarService.getAllActivities(userId);
    final notes = activities
        .where(_activityHasNotes)
        .map(_mapActivityToNote)
        .toList();

    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  Future<WorkoutNote?> getNoteById(String noteId) async {
    final userId = await _requireUserId();
    final activity = await _calendarService.getActivityById(userId, noteId);
    if (activity == null || !_activityHasNotes(activity)) {
      return null;
    }
    return _mapActivityToNote(activity);
  }

  Future<List<WorkoutNote>> getNotesForActivity(String activityId) async {
    final note = await getNoteById(activityId);
    if (note == null) return [];
    return [note];
  }

  Future<WorkoutNote> saveNote({
    required String activityId,
    required String noteText,
    int? rating,
  }) async {
    final user = await _authService.getCurrentUser();
    if (user == null) throw Exception('No user session found');
    final userId = user.id;
    final deviceId = user.id;

    // Get current activity
    final activity = await _calendarService.getActivityById(userId, activityId);
    if (activity == null) {
      throw Exception('Activity not found');
    }

    // Update activity with completion notes
    final updatedActivity = activity.copyWith(completionNotes: noteText);

    await _activitiesService.updateActivity(
      deviceId: deviceId,
      activity: updatedActivity,
    );

    await _maybeUpdateRating(activityId: activityId, rating: rating);

    final reloadedActivity = await _calendarService.getActivityById(
      userId,
      activityId,
    );
    if (reloadedActivity == null) {
      throw Exception('Failed to reload activity after saving note');
    }
    return _mapActivityToNote(reloadedActivity);
  }

  Future<WorkoutNote?> updateNote({
    required String noteId,
    String? noteText,
    int? rating,
  }) async {
    final user = await _authService.getCurrentUser();
    if (user == null) throw Exception('No user session found');
    final userId = user.id;
    final deviceId = user.id;

    final activity = await _calendarService.getActivityById(userId, noteId);
    if (activity == null) {
      return null;
    }

    if (noteText != null) {
      // Update activity with new completion notes
      final updatedActivity = activity.copyWith(completionNotes: noteText);

      await _activitiesService.updateActivity(
        deviceId: deviceId,
        activity: updatedActivity,
      );
    }

    await _maybeUpdateRating(
      activityId: noteId,
      rating: rating,
      fallbackCompletedAt: activity.completedAt,
    );

    final updated = await _calendarService.getActivityById(userId, noteId);
    return updated == null ? null : _mapActivityToNote(updated);
  }

  Future<bool> deleteNote(String noteId) async {
    final user = await _authService.getCurrentUser();
    if (user == null) throw Exception('No user session found');
    final userId = user.id;
    final deviceId = user.id;

    final activity = await _calendarService.getActivityById(userId, noteId);
    if (activity == null) return false;

    // Update activity to remove completion notes
    final updatedActivity = activity.copyWith(completionNotes: null);

    await _activitiesService.updateActivity(
      deviceId: deviceId,
      activity: updatedActivity,
    );

    final reloadedActivity = await _calendarService.getActivityById(
      userId,
      noteId,
    );
    return reloadedActivity?.completionNotes == null;
  }

  Future<int> getNotesCount() async {
    final notes = await getAllNotes();
    return notes.length;
  }

  Future<List<WorkoutNote>> searchNotes(String searchTerm) async {
    final lower = searchTerm.toLowerCase();
    final notes = await getAllNotes();
    return notes
        .where((note) => note.noteText.toLowerCase().contains(lower))
        .toList();
  }

  bool _activityHasNotes(calendar_activity.Activity activity) {
    final hasText = (activity.completionNotes?.trim().isNotEmpty ?? false);
    final hasRating = activity.completionRating != null;
    return hasText || hasRating;
  }

  WorkoutNote _mapActivityToNote(calendar_activity.Activity activity) {
    final created = activity.completedAt ?? DateTime.now();
    final updated = activity.updatedAt;

    return WorkoutNote(
      id: activity.id,
      userId: activity.userId,
      activityId: activity.id,
      noteText: activity.completionNotes ?? '',
      rating: activity.completionRating,
      createdAt: created,
      updatedAt: updated,
    );
  }

  Future<void> _maybeUpdateRating({
    required String activityId,
    int? rating,
    DateTime? fallbackCompletedAt,
  }) async {
    if (rating == null) return;

    final user = await _authService.getCurrentUser();
    if (user == null) throw Exception('No user session found');
    final userId = user.id;
    final deviceId = user.id;

    final activity = await _calendarService.getActivityById(userId, activityId);
    if (activity == null) return;

    // Update activity with completion rating
    final updatedActivity = activity.copyWith(
      status: calendar_activity.ActivityStatus.completed,
      completedAt:
          fallbackCompletedAt ?? activity.completedAt ?? DateTime.now(),
      completionRating: rating,
    );

    await _activitiesService.updateActivity(
      deviceId: deviceId,
      activity: updatedActivity,
    );
  }
}

@riverpod
Future<WorkoutNotesRepository> workoutNotesRepository(Ref ref) async {
  final calendarService = ref.read(calendarServiceProvider);
  final activitiesService = ref.read(activitiesServiceProvider);
  final authService = ref.read(authServiceProvider);
  return WorkoutNotesRepository(
    calendarService: calendarService,
    activitiesService: activitiesService,
    authService: authService,
  );
}
