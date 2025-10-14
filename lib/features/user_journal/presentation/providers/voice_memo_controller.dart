import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../data/workout_notes_repository.dart';
import '../../domain/workout_note.dart';
import '../../../auth/data/user_repository.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

part 'voice_memo_controller.g.dart';

/// Controller state for voice memo
class VoiceMemoState {
  const VoiceMemoState({
    this.isListening = false,
    this.isSaving = false,
    this.hasPermission = false,
    this.isInitialized = false,
    this.error,
  });

  final bool isListening;
  final bool isSaving;
  final bool hasPermission;
  final bool isInitialized;
  final String? error;

  VoiceMemoState copyWith({
    bool? isListening,
    bool? isSaving,
    bool? hasPermission,
    bool? isInitialized,
    String? error,
  }) {
    return VoiceMemoState(
      isListening: isListening ?? this.isListening,
      isSaving: isSaving ?? this.isSaving,
      hasPermission: hasPermission ?? this.hasPermission,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error ?? this.error,
    );
  }
}

/// Controller for voice memo functionality
/// Handles speech-to-text and note saving using proper repository
@riverpod
class VoiceMemoController extends _$VoiceMemoController {
  late stt.SpeechToText _speech;
  Future<WorkoutNotesRepository> get _notesRepository => ref.read(workoutNotesRepositoryProvider.future);
  
  /// Cache for notes list
  List<WorkoutNote> _cachedNotes = [];

  @override
  FutureOr<VoiceMemoState> build() async {
    _speech = stt.SpeechToText();
    
    // Initialize speech recognition
    try {
      final available = await _speech.initialize(
        onError: (error) {
          if (kDebugMode) {
            DebugLogger.debug('Speech recognition error: $error');
          }
          state = AsyncData(state.value?.copyWith(
            error: error.errorMsg,
            isListening: false,
          ) ?? VoiceMemoState(error: error.errorMsg));
        },
        onStatus: (status) {
          if (kDebugMode) {
            DebugLogger.debug('Speech recognition status: $status');
          }
          final isListening = status == stt.SpeechToText.listeningStatus;
          state = AsyncData(state.value?.copyWith(
            isListening: isListening,
          ) ?? VoiceMemoState(isListening: isListening));
        },
      );

      if (!available) {
        return const VoiceMemoState(
          error: 'Speech recognition not available on this device',
          isInitialized: false,
        );
      }

      // Check permissions
      final hasPermission = await _speech.hasPermission;
      
      return VoiceMemoState(
        hasPermission: hasPermission,
        isInitialized: true,
      );
    } catch (error) {
      if (kDebugMode) {
        DebugLogger.error('Failed to initialize speech recognition: $error');
      }
      return VoiceMemoState(
        error: 'Failed to initialize speech recognition: $error',
        isInitialized: false,
      );
    }
  }

  /// Start listening for speech input
  Future<void> startListening(Function(String) onResult) async {
    final currentState = state.value;
    if (currentState == null || !currentState.isInitialized || currentState.isListening) {
      return;
    }

    try {
      // Request permission if not already granted
      if (!currentState.hasPermission) {
        final hasPermission = await _speech.hasPermission;
        if (!hasPermission) {
          state = AsyncData(currentState.copyWith(
            error: 'Microphone permission required for voice input',
          ));
          return;
        }
        state = AsyncData(currentState.copyWith(hasPermission: true));
      }

      await _speech.listen(
        onResult: (result) {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30), // Max 30 seconds
        pauseFor: const Duration(seconds: 3),   // Stop after 3 seconds of silence
        partialResults: false, // Only final results
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );

      state = AsyncData(currentState.copyWith(
        isListening: true,
        error: null,
      ));
    } catch (error) {
      if (kDebugMode) {
        DebugLogger.error('Failed to start listening: $error');
      }
      state = AsyncData(currentState.copyWith(
        error: 'Failed to start speech recognition: $error',
        isListening: false,
      ));
    }
  }

  /// Stop listening for speech input
  Future<void> stopListening() async {
    final currentState = state.value;
    if (currentState == null || !currentState.isListening) {
      return;
    }

    try {
      await _speech.stop();
      state = AsyncData(currentState.copyWith(isListening: false));
    } catch (error) {
      if (kDebugMode) {
        DebugLogger.error('Failed to stop listening: $error');
      }
      state = AsyncData(currentState.copyWith(
        error: 'Failed to stop speech recognition: $error',
        isListening: false,
      ));
    }
  }

  /// Save notes using the proper workout notes repository
  Future<void> saveNotes(String? planId, String notes) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isSaving: true));

    try {
      // Get current user ID
      final userRepository = await ref.read(userRepositoryProvider.future);
      final currentUser = await userRepository.getCurrentUser();
      final userId = currentUser?.id ?? 'current-user';
      
      // Save the note using the workout notes repository
      final repository = await _notesRepository;
      final savedNote = await repository.saveNote(
        userId: userId,
        planId: planId,
        noteText: notes,
      );
      
      // Add to cached notes and refresh the list
      _cachedNotes = [savedNote, ..._cachedNotes];
      
      state = AsyncData(currentState.copyWith(
        isSaving: false,
        error: null,
      ));
    } catch (error) {
      if (kDebugMode) {
        DebugLogger.error('Failed to save notes: $error');
      }
      state = AsyncData(currentState.copyWith(
        isSaving: false,
        error: 'Failed to save notes: $error',
      ));
      rethrow;
    }
  }
  
  /// Get all workout notes for the current user
  Future<List<WorkoutNote>> getNotes() async {
    try {
      // Get current user ID
      final userRepository = await ref.read(userRepositoryProvider.future);
      final currentUser = await userRepository.getCurrentUser();
      final userId = currentUser?.id ?? 'current-user';
      
      // Get notes from repository
      final repository = await _notesRepository;
      final notes = await repository.getAllNotesForUser(userId);
      _cachedNotes = notes;
      return notes;
    } catch (error) {
      if (kDebugMode) {
        DebugLogger.error('Failed to load notes: $error');
      }
      return [];
    }
  }
  
  /// Get cached notes (for immediate UI updates)
  List<WorkoutNote> getCachedNotes() {
    return _cachedNotes;
  }
}
