import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../providers/voice_memo_controller.dart';
import '../../domain/workout_note.dart';
import '../../../../../../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Screen for users to view and add workout notes about their nutrition plan
/// Displays a list of notes with timestamps and supports speech-to-text input
class VoiceMemoScreen extends ConsumerStatefulWidget {
  const VoiceMemoScreen({super.key, required this.activityId, this.rating});

  final String activityId;
  final int? rating;

  @override
  ConsumerState<VoiceMemoScreen> createState() => _VoiceMemoScreenState();
}

class _VoiceMemoScreenState extends ConsumerState<VoiceMemoScreen> {
  late TextEditingController _textController;
  late FocusNode _textFieldFocusNode;
  bool _hasChanges = false;
  bool _showNewNoteEntry = false; // Don't show by default when used in tabs
  List<WorkoutNote> _notes = [];
  bool _isLoadingNotes = false;
  late final String _activityId;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textFieldFocusNode = FocusNode();
    _activityId = widget.activityId;

    // Show new note entry by default if coming from plan rating
    _showNewNoteEntry = widget.rating != null;

    _textController.addListener(() {
      if (!_hasChanges && _textController.text.isNotEmpty) {
        setState(() {
          _hasChanges = true;
        });
      }
    });

    // Load notes when screen initializes
    _loadNotes();
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        title: Text(
          'Workout Notes',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.primary900,
            fontSize: 20.sp,
          ),
        ),
        // leading: IconButton(
        //   icon: Icon(
        //     Icons.arrow_back,
        //     color: AppTheme.primary900,
        //   ),
        //   onPressed: () => _handleBackPress(),
        // ),
        // actions: [
        //   // User avatar placeholder (from design)
        //   Container(
        //     margin: EdgeInsets.only(right: 16.w),
        //     width: 32.w,
        //     height: 32.h,
        //     decoration: BoxDecoration(
        //       color: AppTheme.primary600,
        //       shape: BoxShape.circle,
        //     ),
        //     child: Center(
        //       child: Text(
        //         'E',
        //         style: TextStyle(
        //           color: AppTheme.baseWhite,
        //           fontSize: 16.sp,
        //           fontWeight: FontWeight.bold,
        //         ),
        //       ),
        //     ),
        //   ),
        // ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
          child: Column(
            children: [
              // New note entry section (shown when _showNewNoteEntry is true)
              if (_showNewNoteEntry) ...[
                _buildNewNoteEntry(),
                SizedBox(height: 24.h),
              ],

              // Notes list section
              Expanded(child: _buildNotesList()),
            ],
          ),
        ),
      ),
      // Floating action button to add new note
      floatingActionButton: _showNewNoteEntry
          ? null
          : FloatingActionButton(
              heroTag:
                  "workout-notes-fab", // Unique hero tag to avoid conflicts
              onPressed: _showNewNoteInput,
              backgroundColor: AppTheme.primary900,
              child: Icon(Icons.add, color: AppTheme.baseWhite),
            ),
    );
  }

  /// Show the new note input interface
  void _showNewNoteInput() {
    setState(() {
      _showNewNoteEntry = true;
      _textController.clear();
      _hasChanges = false;
    });

    // Focus the text field after a brief delay to ensure the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_textFieldFocusNode);
    });
  }

  /// Build the new note entry widget
  Widget _buildNewNoteEntry() {
    final controllerState = ref.watch(voiceMemoControllerProvider);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppTheme.primary50, // Light blue background from AppTheme
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.primary100, width: 1),
      ),
      child: Column(
        children: [
          // Text input area
          TextField(
            controller: _textController,
            focusNode: _textFieldFocusNode,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Add notes about your workout nutrition...',
              hintStyle: AppTheme.textStyle.copyWith(
                color: AppTheme.baseGrey,
                fontSize: 16.sp,
              ),
              border: InputBorder.none,
            ),
            style: AppTheme.textStyle.copyWith(
              fontSize: 16.sp,
              color: AppTheme.primary900,
              height: 1.5,
            ),
          ),

          SizedBox(height: 16.h),

          // Controls row with microphone and save button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Speech recognition button and status
              Row(
                children: [
                  GestureDetector(
                    onTap: _toggleSpeechRecognition,
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: controllerState.maybeWhen(
                          data: (state) => state.isListening
                              ? AppTheme.warningColor
                              : AppTheme.primary900,
                          orElse: () => AppTheme.primary900,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        controllerState.maybeWhen(
                          data: (state) =>
                              state.isListening ? Icons.stop : Icons.mic,
                          orElse: () => Icons.mic,
                        ),
                        color: AppTheme.baseWhite,
                        size: 20.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Speech recognition status
                  controllerState.when(
                    loading: () => Text(
                      'Listening...',
                      style: AppTheme.textStyle.copyWith(
                        color: AppTheme.primary600,
                        fontSize: 12.sp,
                      ),
                    ),
                    error: (error, _) => Text(
                      'Voice unavailable',
                      style: AppTheme.textStyle.copyWith(
                        color: AppTheme.warningColor,
                        fontSize: 12.sp,
                      ),
                    ),
                    data: (state) => Text(
                      state.isListening ? 'Listening...' : '',
                      style: AppTheme.textStyle.copyWith(
                        color: AppTheme.primary600,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),

              // Save and Cancel buttons
              Row(
                children: [
                  SecondaryButton(
                    text: 'Cancel',
                    onPressed: _cancelNewNote,
                    width: 80.w,
                    height: 36.h,
                    fontSize: 14.sp,
                  ),
                  SizedBox(width: 8.w),
                  PrimaryButton(
                    text: controllerState.maybeWhen(
                      data: (state) => state.isSaving ? 'Saving...' : 'Save',
                      orElse: () => 'Save',
                    ),
                    onPressed: controllerState.maybeWhen(
                      data: (state) =>
                          state.isSaving ? null : _handleSaveNewNote,
                      orElse: () => _handleSaveNewNote,
                    ),
                    isLoading: controllerState.maybeWhen(
                      data: (state) => state.isSaving,
                      orElse: () => false,
                    ),
                    width: 80.w,
                    height: 36.h,
                    fontSize: 14.sp,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build the notes list widget
  Widget _buildNotesList() {
    if (_isLoadingNotes) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primary600),
      );
    }

    if (_notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 48.sp,
              color: AppTheme.baseGrey,
            ),
            SizedBox(height: 16.h),
            Text(
              'No workout notes yet',
              style: AppTheme.textStyle.copyWith(
                color: AppTheme.baseGrey,
                fontSize: 16.sp,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Add your first note using the + button',
              style: AppTheme.textStyle.copyWith(
                color: AppTheme.baseGrey,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _notes.length,
      separatorBuilder: (context, index) => SizedBox(height: 16.h),
      itemBuilder: (context, index) {
        final note = _notes[index];
        return _buildNoteItem(note);
      },
    );
  }

  /// Build an individual note item
  Widget _buildNoteItem(WorkoutNote note) {
    final timeAgo = _formatTimeAgo(note.createdAt);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.baseWhite,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppTheme.baseGrey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Note text
          Text(
            note.noteText,
            style: AppTheme.textStyle.copyWith(
              fontSize: 16.sp,
              color: AppTheme.primary900,
              height: 1.4,
            ),
          ),

          SizedBox(height: 12.h),

          // Timestamp and edit options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timeAgo,
                style: AppTheme.textStyle.copyWith(
                  fontSize: 12.sp,
                  color: AppTheme.baseGrey,
                ),
              ),

              // Edit button
              GestureDetector(
                onTap: () => _editNote(note),
                child: Icon(
                  Icons.edit_outlined,
                  size: 18.sp,
                  color: AppTheme.baseGrey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Format timestamp to "time ago" string
  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Cancel adding new note
  void _cancelNewNote() {
    if (_hasChanges && _textController.text.trim().isNotEmpty) {
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard Note'),
          content: const Text('Are you sure you want to discard this note?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep Editing'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ).then((shouldDiscard) {
        if (shouldDiscard == true) {
          setState(() {
            _showNewNoteEntry = false;
            _textController.clear();
            _hasChanges = false;
          });
        }
      });
    } else {
      setState(() {
        _showNewNoteEntry = false;
        _textController.clear();
        _hasChanges = false;
      });
    }
  }

  /// Handle saving a new note
  Future<void> _handleSaveNewNote() async {
    final notes = _textController.text.trim();
    if (notes.isEmpty) {
      MealvanaSnackbar.showWarning(
        context,
        'Please enter some notes before saving',
      );
      return;
    }

    try {
      final controller = ref.read(voiceMemoControllerProvider.notifier);
      await controller.saveNotes(_activityId, notes);

      if (mounted) {
        // Hide the new note entry and clear the form
        setState(() {
          _showNewNoteEntry = false;
          _textController.clear();
          _hasChanges = false;
        });

        // Refresh the notes list after saving
        await _loadNotes();

        // Show success message
        MealvanaSnackbar.showInfo(context, 'Note saved successfully!');
      }
    } catch (error) {
      if (mounted) {
        MealvanaSnackbar.showWarning(context, 'Failed to save note: $error');
      }
    }
  }

  /// Edit an existing note
  void _editNote(WorkoutNote note) {
    // TODO: Implement edit functionality
    MealvanaSnackbar.showInfo(context, 'Edit functionality coming soon');
  }

  /// Load notes from the controller
  Future<void> _loadNotes() async {
    setState(() {
      _isLoadingNotes = true;
    });

    try {
      final controller = ref.read(voiceMemoControllerProvider.notifier);
      final notes = await controller.getNotes();
      setState(() {
        _notes = notes;
        _isLoadingNotes = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingNotes = false;
      });
      if (mounted) {
        MealvanaSnackbar.showWarning(context, 'Failed to load notes: $e');
      }
    }
  }

  void _toggleSpeechRecognition() {
    final controller = ref.read(voiceMemoControllerProvider.notifier);
    final state = ref.read(voiceMemoControllerProvider);

    state.whenData((data) {
      if (data.isListening) {
        controller.stopListening();
      } else {
        controller.startListening((text) {
          // Append recognized text to the text field
          final currentText = _textController.text;
          final newText = currentText.isEmpty ? text : '$currentText $text';
          _textController.text = newText;
          _textController.selection = TextSelection.collapsed(
            offset: newText.length,
          );

          if (!_hasChanges) {
            setState(() {
              _hasChanges = true;
            });
          }
        });
      }
    });
  }
}
