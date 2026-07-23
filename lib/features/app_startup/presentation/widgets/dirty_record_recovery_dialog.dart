import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/models/dirty_record_backup.dart';

/// User's choice when prompted about dirty record backup
enum RecoveryChoice {
  /// Upload the backed up records to Supabase
  upload,

  /// Discard the backed up records
  discard,
}

/// Dialog shown when dirty record backup is found on app startup.
///
/// This dialog prompts the user to either upload the previously failed
/// records or discard them. It displays backup metadata including:
/// - When the backup was created
/// - How many records are in the backup
/// - Which repositories have dirty records
class DirtyRecordRecoveryDialog extends StatelessWidget {
  const DirtyRecordRecoveryDialog({super.key, required this.backup});

  final DirtyRecordBackup backup;

  /// Show the recovery dialog and return the user's choice
  static Future<RecoveryChoice?> show(
    BuildContext context,
    DirtyRecordBackup backup,
  ) {
    return showDialog<RecoveryChoice>(
      context: context,
      barrierDismissible: false, // User must make a choice
      builder: (context) => DirtyRecordRecoveryDialog(backup: backup),
    );
  }

  String _formatBackupTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat.jm().format(timestamp)}';
    } else {
      return DateFormat('MMM d, y \'at\' h:mm a').format(timestamp);
    }
  }

  String _formatRepositoryNames(List<String> repositories) {
    // Convert repository keys to user-friendly names
    final friendlyNames = repositories.map((key) {
      switch (key) {
        case 'activities':
          return 'Activities';
        case 'events':
          return 'Events';
        case 'carb_loading_plans':
          return 'Carb Loading Plans';
        case 'carb_loading_days':
          return 'Carb Loading Days';
        case 'food_preferences':
          return 'Food Preferences';
        case 'user_foods':
          return 'Custom Foods';
        default:
          return key;
      }
    }).toList();

    if (friendlyNames.length == 1) {
      return friendlyNames.first;
    } else if (friendlyNames.length == 2) {
      return '${friendlyNames[0]} and ${friendlyNames[1]}';
    } else {
      final last = friendlyNames.removeLast();
      return '${friendlyNames.join(', ')}, and $last';
    }
  }

  @override
  Widget build(BuildContext context) {
    final repositoriesWithData = backup.dirtyRecords.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.key)
        .toList();

    return Dialog(
      backgroundColor: AppTheme.baseCream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                width: 80.w,
                height: 80.h,
                decoration: BoxDecoration(
                  color: AppTheme.highlight600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(40.r),
                ),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 40.w,
                  color: AppTheme.highlight600,
                ),
              ),

              SizedBox(height: 20.h),

              // Title
              Text(
                'Unsaved Data Found',
                style: AppTheme.titleStyle.copyWith(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary900,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 12.h),

              // Description
              Text(
                'We found ${backup.totalRecordCount} unsaved ${backup.totalRecordCount == 1 ? 'record' : 'records'} from your last session.',
                style: AppTheme.textStyle.copyWith(
                  fontSize: 15.sp,
                  color: AppTheme.baseGrey,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 20.h),

              // Backup details card
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppTheme.primary50,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppTheme.primary100, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      Icons.access_time,
                      'Backup created',
                      _formatBackupTime(backup.backupCreatedAt),
                    ),
                    SizedBox(height: 12.h),
                    _buildDetailRow(
                      Icons.storage,
                      'Records',
                      '${backup.totalRecordCount} (${_formatRepositoryNames(repositoriesWithData)})',
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // Upload button (primary action)
              PrimaryButton(
                text: 'Upload Now',
                onPressed: () =>
                    Navigator.of(context).pop(RecoveryChoice.upload),
                width: double.infinity,
                height: 48.h,
              ),

              SizedBox(height: 12.h),

              // Discard button (secondary/destructive action)
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(RecoveryChoice.discard),
                style: TextButton.styleFrom(
                  minimumSize: Size(double.infinity, 48.h),
                ),
                child: Text(
                  'Discard',
                  style: AppTheme.textStyle.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.highlight600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20.w, color: AppTheme.primary600),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.noteStyle.copyWith(
                  fontSize: 12.sp,
                  color: AppTheme.baseGrey,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: AppTheme.textStyle.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
