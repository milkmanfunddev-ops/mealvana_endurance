import 'dart:async';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/workout_note.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';

part 'workout_notes_repository.g.dart';

/// Repository for managing workout notes in local database
/// Follows FOA pattern with local-only storage
class WorkoutNotesRepository {
  WorkoutNotesRepository(this._database);

  final AppDatabase _database;

  /// Get all workout notes for a user, ordered by creation date (newest first)
  Future<List<WorkoutNote>> getAllNotesForUser(String userId) async {
    final notes = await (_database.select(_database.workoutNotesTable)
          ..where((tbl) => tbl.userId.equals(userId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .get();

    return notes.map(_mapFromDrift).toList();
  }

  /// Get a specific workout note by ID
  Future<WorkoutNote?> getNoteById(String noteId) async {
    final note = await (_database.select(_database.workoutNotesTable)
          ..where((tbl) => tbl.id.equals(noteId)))
        .getSingleOrNull();

    return note != null ? _mapFromDrift(note) : null;
  }

  /// Get workout notes for a specific nutrition plan
  Future<List<WorkoutNote>> getNotesForPlan(String planId) async {
    final notes = await (_database.select(_database.workoutNotesTable)
          ..where((tbl) => tbl.planId.equals(planId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .get();

    return notes.map(_mapFromDrift).toList();
  }

  /// Save a new workout note
  Future<WorkoutNote> saveNote({
    required String userId,
    String? planId,
    required String noteText,
    int? rating,
  }) async {
    final now = DateTime.now();
    final noteId = const Uuid().v4();

    final companion = WorkoutNotesTableCompanion(
      id: Value(noteId),
      userId: Value(userId),
      planId: Value(planId),
      noteText: Value(noteText),
      rating: Value(rating),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await _database.into(_database.workoutNotesTable).insert(companion);

    return WorkoutNote(
      id: noteId,
      userId: userId,
      planId: planId,
      noteText: noteText,
      rating: rating,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Update an existing workout note
  Future<WorkoutNote?> updateNote({
    required String noteId,
    String? noteText,
    int? rating,
  }) async {
    final now = DateTime.now();
    
    // First get the current note to preserve other fields
    final currentNote = await getNoteById(noteId);
    if (currentNote == null) return null;

    final companion = WorkoutNotesTableCompanion(
      noteText: noteText != null ? Value(noteText) : Value.absent(),
      rating: rating != null ? Value(rating) : Value.absent(),
      updatedAt: Value(now),
    );

    final updatedRows = await (_database.update(_database.workoutNotesTable)
          ..where((tbl) => tbl.id.equals(noteId)))
        .write(companion);

    if (updatedRows == 0) return null;

    return currentNote.copyWith(
      noteText: noteText ?? currentNote.noteText,
      rating: rating ?? currentNote.rating,
      updatedAt: now,
    );
  }

  /// Delete a workout note
  Future<bool> deleteNote(String noteId) async {
    final deletedRows = await (_database.delete(_database.workoutNotesTable)
          ..where((tbl) => tbl.id.equals(noteId)))
        .go();

    return deletedRows > 0;
  }

  /// Get count of notes for a user
  Future<int> getNotesCountForUser(String userId) async {
    final count = await (_database.selectOnly(_database.workoutNotesTable)
          ..addColumns([_database.workoutNotesTable.id.count()])
          ..where(_database.workoutNotesTable.userId.equals(userId)))
        .getSingle();

    return count.read(_database.workoutNotesTable.id.count()) ?? 0;
  }

  /// Search notes by text content
  Future<List<WorkoutNote>> searchNotes(String userId, String searchTerm) async {
    final notes = await (_database.select(_database.workoutNotesTable)
          ..where((tbl) => 
              tbl.userId.equals(userId) & 
              tbl.noteText.like('%$searchTerm%'))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .get();

    return notes.map(_mapFromDrift).toList();
  }

  /// Map from Drift database entry to domain model
  WorkoutNote _mapFromDrift(WorkoutNoteEntry entry) {
    return WorkoutNote(
      id: entry.id,
      userId: entry.userId,
      planId: entry.planId,
      noteText: entry.noteText,
      rating: entry.rating,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }
}

/// Provider for the workout notes repository
@riverpod
Future<WorkoutNotesRepository> workoutNotesRepository(Ref ref) async {
  final database = await ref.watch(databaseProvider.future);
  return WorkoutNotesRepository(database);
}