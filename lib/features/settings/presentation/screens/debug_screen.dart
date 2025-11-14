import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/services/debug_log_storage.dart';
import '../../../../shared/services/sync/data_sync_service.dart';
import '../../../../shared/database/database_provider.dart';
import '../../../auth/data/user_repository.dart';

/// Secret debug screen accessible via triple-tap on Profile in Settings
/// Shows logs and provides manual sync functionality
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  bool _isSyncing = false;
  String? _syncResult;
  LogLevel? _filterLevel;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _performSync() async {
    setState(() {
      _isSyncing = true;
      _syncResult = null;
    });

    try {
      // Get current user and database
      final database = ref.read(appDatabaseProvider);
      final userRepo = await ref.read(userRepositoryProvider.future);
      final userProfile = await userRepo.getCurrentUser();

      if (userProfile == null) {
        setState(() {
          _syncResult = '❌ No user profile found';
          _isSyncing = false;
        });
        return;
      }

      // Perform sync using user ID (which is the device_id for our device-first architecture)
      final syncService = ref.read(dataSyncServiceProvider);
      final success = await syncService.syncAllData(userProfile.id);

      // Check dirty records after sync
      final dirtyActivities = await (database.select(database.activitiesTable)
            ..where((tbl) => tbl.needsUpload.equals(true)))
          .get();

      final dirtyEvents = await (database.select(database.eventsTable)
            ..where((tbl) => tbl.needsUpload.equals(true)))
          .get();

      // NOTE: Activity completions table removed - data now in activities table

      setState(() {
        _syncResult = success
            ? '✅ Sync successful!\n\n'
                'Dirty records remaining:\n'
                '• Activities (incl. completion data): ${dirtyActivities.length}\n'
                '• Events: ${dirtyEvents.length}'
            : '❌ Sync failed - check logs';
        _isSyncing = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Debug sync error: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _syncResult = '❌ Sync error: $e';
        _isSyncing = false;
      });
    }
  }

  void _clearLogs() {
    DebugLogStorage().clear();
    setState(() {});
  }

  void _copyLogsToClipboard() {
    final logs = DebugLogStorage().getLogs();
    final logText = logs
        .map((log) =>
            '${log.timeString} ${log.levelEmoji} [${log.context ?? 'GENERAL'}] ${log.message}')
        .join('\n');

    Clipboard.setData(ClipboardData(text: logText));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Logs copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filterLevel != null
        ? DebugLogStorage().getLogsByLevel(_filterLevel!)
        : DebugLogStorage().getLogs();

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        title: Text(
          '🐛 Debug Console',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyLogsToClipboard,
            tooltip: 'Copy logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Sync section
          Container(
            padding: EdgeInsets.all(16.w),
            color: AppTheme.baseWhite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Manual Sync',
                  style: AppTheme.textStyle.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12.h),
                ElevatedButton(
                  onPressed: _isSyncing ? null : _performSync,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary600,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  child: _isSyncing
                      ? SizedBox(
                          height: 20.h,
                          width: 20.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          '🔄 Force Sync Now',
                          style: AppTheme.textStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                if (_syncResult != null) ...[
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: _syncResult!.startsWith('✅')
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: _syncResult!.startsWith('✅')
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    child: Text(
                      _syncResult!,
                      style: AppTheme.noteStyle.copyWith(
                        fontSize: 12.sp,
                        color: AppTheme.baseBlack,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Filter section
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            color: AppTheme.baseWhite,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', null),
                  SizedBox(width: 8.w),
                  _buildFilterChip('🔍 Debug', LogLevel.debug),
                  SizedBox(width: 8.w),
                  _buildFilterChip('💡 Info', LogLevel.info),
                  SizedBox(width: 8.w),
                  _buildFilterChip('⚠️ Warning', LogLevel.warning),
                  SizedBox(width: 8.w),
                  _buildFilterChip('❌ Error', LogLevel.error),
                ],
              ),
            ),
          ),

          Divider(height: 1, color: AppTheme.baseGrey.withValues(alpha: 0.3)),

          // Logs section
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      'No logs yet.\nUse the app to generate logs.',
                      textAlign: TextAlign.center,
                      style: AppTheme.noteStyle.copyWith(
                        color: AppTheme.baseGrey,
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: EdgeInsets.all(8.w),
                    itemCount: logs.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: AppTheme.baseGrey.withValues(alpha: 0.2),
                    ),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return _buildLogEntry(log);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, LogLevel? level) {
    final isSelected = _filterLevel == level;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterLevel = selected ? level : null;
        });
      },
      backgroundColor: AppTheme.baseWhite,
      selectedColor: AppTheme.primary600.withValues(alpha: 0.2),
      labelStyle: AppTheme.noteStyle.copyWith(
        fontSize: 12.sp,
        color: isSelected ? AppTheme.primary600 : AppTheme.baseGrey,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primary600 : AppTheme.baseGrey,
      ),
    );
  }

  Widget _buildLogEntry(DebugLogEntry log) {
    Color backgroundColor;
    switch (log.level) {
      case LogLevel.error:
      case LogLevel.fatal:
        backgroundColor = Colors.red.shade50;
        break;
      case LogLevel.warning:
        backgroundColor = Colors.orange.shade50;
        break;
      case LogLevel.info:
        backgroundColor = Colors.blue.shade50;
        break;
      case LogLevel.debug:
        backgroundColor = Colors.grey.shade50;
        break;
    }

    return Container(
      padding: EdgeInsets.all(12.w),
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text(
                log.levelEmoji,
                style: TextStyle(fontSize: 16.sp),
              ),
              SizedBox(width: 8.w),
              Text(
                log.timeString,
                style: AppTheme.noteStyle.copyWith(
                  fontSize: 11.sp,
                  color: AppTheme.baseGrey,
                  fontFamily: 'monospace',
                ),
              ),
              if (log.context != null) ...[
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primary600.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    log.context!,
                    style: AppTheme.noteStyle.copyWith(
                      fontSize: 10.sp,
                      color: AppTheme.primary600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 6.h),
          // Message
          Text(
            log.message,
            style: AppTheme.textStyle.copyWith(
              fontSize: 13.sp,
              color: AppTheme.baseBlack,
            ),
          ),
          // Data
          if (log.data != null && log.data!.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                log.data.toString(),
                style: AppTheme.noteStyle.copyWith(
                  fontSize: 11.sp,
                  color: AppTheme.baseGrey,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
          // Error
          if (log.error != null) ...[
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                'Error: ${log.error.toString()}',
                style: AppTheme.noteStyle.copyWith(
                  fontSize: 11.sp,
                  color: Colors.red.shade900,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
