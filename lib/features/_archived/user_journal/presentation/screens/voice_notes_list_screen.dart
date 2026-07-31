import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../theme/app_theme.dart';
import '../providers/voice_notes_controller.dart';
import '../../../nutrition_plan/domain/nutrition_plan.dart';

/// Screen displaying list of voice notes/journal entries
/// Shows historical notes organized by date
class VoiceNotesListScreen extends ConsumerWidget {
  const VoiceNotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesState = ref.watch(voiceNotesControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        title: Text(
          'Voice notes',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.primary900,
            fontSize: 20.sp,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              color: AppTheme.primary900,
              size: 24.sp,
            ),
            onPressed: () {
              // Show options menu
              _showOptionsMenu(context, ref);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(voiceNotesControllerProvider);
        },
        color: AppTheme.primary600,
        child: notesState.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary600),
          ),
          error: (error, stack) => _buildErrorState(error.toString()),
          data: (notes) =>
              notes.isEmpty ? _buildEmptyState() : _buildNotesList(notes, ref),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(32.w),
              decoration: BoxDecoration(
                color: AppTheme.primary50.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.note_add,
                size: 64.sp,
                color: AppTheme.primary600,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'No journal entries yet',
              style: AppTheme.titleStyle.copyWith(
                color: AppTheme.primary900,
                fontSize: 24.sp,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Complete a run and rate your nutrition plan\\nto start building your journal',
              style: AppTheme.textStyle.copyWith(
                color: AppTheme.baseGrey,
                fontSize: 16.sp,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.sp,
              color: AppTheme.warningColor,
            ),
            SizedBox(height: 24.h),
            Text(
              'Unable to load notes',
              style: AppTheme.titleStyle.copyWith(
                color: AppTheme.primary900,
                fontSize: 24.sp,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              error,
              style: AppTheme.textStyle.copyWith(
                color: AppTheme.baseGrey,
                fontSize: 16.sp,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesList(List<NutritionPlan> notes, WidgetRef ref) {
    // Group notes by date
    final groupedNotes = <String, List<NutritionPlan>>{};
    final dateFormat = DateFormat('dd MMM, yyyy');

    for (final note in notes) {
      final date = note.runDateTime ?? note.createdAt ?? DateTime.now();
      final dateKey = dateFormat.format(date);
      if (groupedNotes[dateKey] == null) {
        groupedNotes[dateKey] = [];
      }
      groupedNotes[dateKey]!.add(note);
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: groupedNotes.length,
      itemBuilder: (context, index) {
        final dateKey = groupedNotes.keys.elementAt(index);
        final dateNotes = groupedNotes[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) SizedBox(height: 32.h),

            // Date header
            Padding(
              padding: EdgeInsets.only(left: 8.w, bottom: 16.h),
              child: Text(
                dateKey,
                style: AppTheme.textStyle.copyWith(
                  color: AppTheme.primary600,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Notes for this date
            ...dateNotes.map((note) => _buildNoteItem(note, ref)),
          ],
        );
      },
    );
  }

  Widget _buildNoteItem(NutritionPlan plan, WidgetRef ref) {
    final timeFormat = DateFormat('HH:mm');
    final time = plan.runDateTime ?? plan.createdAt ?? DateTime.now();
    final rating = plan.planRating;
    final notes = plan.journalNotes ?? '';

    // Get emoji for rating
    final ratingEmoji = _getRatingEmoji(rating);

    // Preview of notes (first 2 lines)
    final notePreview = _getNotesPreview(notes);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showNoteDetails(plan, ref),
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppTheme.baseWhite,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppTheme.baseGrey.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Play button placeholder (now just shows rating emoji)
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: AppTheme.primary100,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Center(
                    child: Text(ratingEmoji, style: TextStyle(fontSize: 20.sp)),
                  ),
                ),

                SizedBox(width: 16.w),

                // Note content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Note preview
                      Text(
                        notePreview,
                        style: AppTheme.textStyle.copyWith(
                          fontSize: 16.sp,
                          color: AppTheme.primary900,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: 4.h),

                      // Time
                      Text(
                        '${timeFormat.format(time)} A.M.',
                        style: AppTheme.textStyle.copyWith(
                          fontSize: 12.sp,
                          color: AppTheme.baseGrey,
                        ),
                      ),
                    ],
                  ),
                ),

                // More options button
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: AppTheme.baseGrey,
                    size: 20.sp,
                  ),
                  onPressed: () => _showNoteOptions(plan, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRatingEmoji(int? rating) {
    switch (rating) {
      case 3:
        return '😄';
      case 2:
        return '😐';
      case 1:
        return '😬';
      default:
        return '📝';
    }
  }

  String _getNotesPreview(String notes) {
    if (notes.isEmpty) {
      return 'No notes added';
    }

    // Return first ~80 characters or until second newline
    final lines = notes.split('\\n');
    if (lines.length > 2) {
      return '${lines[0]}\\n${lines[1]}...';
    } else if (notes.length > 80) {
      return '${notes.substring(0, 77)}...';
    }
    return notes;
  }

  void _showNoteDetails(NutritionPlan plan, WidgetRef ref) {
    // For now, just show the edit dialog
    _showEditDialog(plan, ref);
  }

  void _showNoteOptions(NutritionPlan plan, WidgetRef ref) {
    // Show bottom sheet with edit/delete options
    // Implementation would go here
  }

  void _showEditDialog(NutritionPlan plan, WidgetRef ref) {
    // Show dialog to edit notes
    // Implementation would go here
  }

  void _showOptionsMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.baseWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(top: 12.h),
              decoration: BoxDecoration(
                color: AppTheme.baseGrey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            ListTile(
              leading: Icon(Icons.refresh, color: AppTheme.primary600),
              title: const Text('Refresh'),
              onTap: () {
                Navigator.pop(context);
                ref.invalidate(voiceNotesControllerProvider);
              },
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: AppTheme.primary600),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                // Show about dialog
              },
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }
}
