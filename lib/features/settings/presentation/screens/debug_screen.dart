import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/report/report.dart';
import '../../../../shared/services/sync/data_sync_service.dart';
import '../../../../shared/database/database_provider.dart';
import '../../../auth/data/user_repository.dart';
import '../../application/report_pipeline_probe.dart';

/// Debug console, opened from Settings → Developer / Tester → Debug console
/// (the tester section shows after seven taps on the version text, or on an
/// internal device).
/// Shows logs, provides manual sync, and carries the Sentry pipeline probes
/// (one button per report class) that a device run uses to prove reporting
/// end to end against the dev project.
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  bool _isSyncing = false;
  String? _syncResult;
  ReportLogLevel? _filterLevel;
  final _scrollController = ScrollController();
  bool _probeBusy = false;
  String? _probeResult;

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

    // Before the first await: a catch after unmount cannot touch `ref`.
    final report = ref.read(reportProvider);
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
      final dirtyActivities = await (database.select(
        database.activitiesTable,
      )..where((tbl) => tbl.needsUpload.equals(true))).get();

      final dirtyEvents = await (database.select(
        database.eventsTable,
      )..where((tbl) => tbl.needsUpload.equals(true))).get();

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
      report.fault(
        e,
        stackTrace: stackTrace,
        area: 'sync',
        message: 'Manual sync from the debug screen failed',
      );
      if (!mounted) return;
      setState(() {
        _syncResult = '❌ Sync error: $e';
        _isSyncing = false;
      });
    }
  }

  void _clearLogs() {
    ReportLog().clear();
    setState(() {});
  }

  /// Runs one probe and shows what it did. The probe reports through
  /// `Report`, so a failure inside it is already on its way to Sentry; the
  /// screen only has to stay usable.
  Future<void> _runProbe(
    String label,
    Future<String> Function(ReportPipelineProbe probe) run,
  ) async {
    setState(() {
      _probeBusy = true;
      _probeResult = null;
    });
    final probe = ref.read(reportPipelineProbeProvider);
    final outcome = await run(probe);
    if (!mounted) return;
    setState(() {
      _probeBusy = false;
      _probeResult = '$label: $outcome';
    });
  }

  String _describeEdge(EdgeProbeOutcome outcome) => switch (outcome.kind) {
    EdgeProbeKind.refused =>
      'answered ${outcome.status}. One event is due in Sentry under '
          'environment edge-dev.',
    EdgeProbeKind.accepted =>
      'answered 2xx, so the function captured nothing. No edge event is due.',
    EdgeProbeKind.unreachable =>
      'never reached the function. A Degraded was reported from here '
          'instead; see the log below.',
  };

  /// An unhandled throw, outside any `Report` call, so the SDK's own Flutter
  /// error integration captures it marked `handled: false`. Thrown from the
  /// next frame so the tap handler itself completes.
  void _crashUnhandled() {
    setState(() => _probeResult = 'Crash: thrown on the next frame.');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      throw const ReportProbeFault('Debug screen: deliberate unhandled crash');
    });
  }

  void _copyLogsToClipboard() {
    final logs = ReportLog().getLogs();
    final logText = logs
        .map(
          (log) =>
              '${log.timeString} ${log.levelEmoji} [${log.context ?? 'GENERAL'}] ${log.message}',
        )
        .join('\n');

    Clipboard.setData(ClipboardData(text: logText));

    MealvanaSnackbar.showSuccess(
      context,
      'Logs copied to clipboard',
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filterLevel != null
        ? ReportLog().getLogsByLevel(_filterLevel!)
        : ReportLog().getLogs();

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
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Sync section
          SliverToBoxAdapter(
            child: Container(
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
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
          ),

          SliverToBoxAdapter(child: _buildPipelineSection()),

          // Filter section
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              color: AppTheme.baseWhite,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', null),
                    SizedBox(width: 8.w),
                    _buildFilterChip('🔍 Debug', ReportLogLevel.debug),
                    SizedBox(width: 8.w),
                    _buildFilterChip('💡 Info', ReportLogLevel.info),
                    SizedBox(width: 8.w),
                    _buildFilterChip('⚠️ Warning', ReportLogLevel.warning),
                    SizedBox(width: 8.w),
                    _buildFilterChip('❌ Error', ReportLogLevel.error),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Divider(
              height: 1,
              color: AppTheme.baseGrey.withValues(alpha: 0.3),
            ),
          ),

          // Logs section
          if (logs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Text(
                    'No logs yet.\nUse the app to generate logs.',
                    textAlign: TextAlign.center,
                    style: AppTheme.noteStyle.copyWith(
                      color: AppTheme.baseGrey,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.all(8.w),
              sliver: SliverList.separated(
                itemCount: logs.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: AppTheme.baseGrey.withValues(alpha: 0.2),
                ),
                itemBuilder: (context, index) => _buildLogEntry(logs[index]),
              ),
            ),
        ],
      ),
    );
  }

  /// Collapsed by default so the log view keeps its height; expand it to
  /// fire the probes.
  Widget _buildPipelineSection() {
    return Material(
      color: AppTheme.baseWhite,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const Key('probe_section'),
          tilePadding: EdgeInsets.symmetric(horizontal: 16.w),
          childrenPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
          title: Text(
            'Sentry pipeline',
            style: AppTheme.textStyle.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            'One report of each class, to the dev project.',
            style: AppTheme.noteStyle.copyWith(
              fontSize: 12.sp,
              color: AppTheme.baseGrey,
            ),
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8.w,
              runSpacing: 4.h,
              children: [
                _probeButton(
                  key: const Key('probe_fault'),
                  label: 'Throw a Fault',
                  onPressed: () => _runProbe('Fault', (p) async {
                    await p.fault();
                    return 'sent as a Sentry error.';
                  }),
                ),
                _probeButton(
                  key: const Key('probe_degraded'),
                  label: 'Raise a Degraded',
                  onPressed: () => _runProbe('Degraded', (p) async {
                    await p.degraded();
                    return 'sent as a Sentry warning.';
                  }),
                ),
                _probeButton(
                  key: const Key('probe_note_then_fault'),
                  label: 'Note, then throw',
                  onPressed: () => _runProbe('Note then Fault', (p) async {
                    await p.noteThenFault();
                    return 'one error; its breadcrumbs carry the note.';
                  }),
                ),
                _probeButton(
                  key: const Key('probe_edge'),
                  label: 'Edge: bad payload',
                  onPressed: () => _runProbe('Edge', (p) async {
                    final outcome = await p.edgeBadPayload();
                    return _describeEdge(outcome);
                  }),
                ),
                _probeButton(
                  key: const Key('probe_crash'),
                  label: 'Crash (unhandled)',
                  onPressed: _crashUnhandled,
                ),
              ],
            ),
            if (_probeResult != null) ...[
              SizedBox(height: 8.h),
              Text(
                _probeResult!,
                key: const Key('probe_result'),
                style: AppTheme.noteStyle.copyWith(
                  fontSize: 12.sp,
                  color: AppTheme.baseBlack,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _probeButton({
    required Key key,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      key: key,
      onPressed: _probeBusy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primary600,
        side: BorderSide(color: AppTheme.primary600),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      ),
      child: Text(label, style: AppTheme.noteStyle.copyWith(fontSize: 12.sp)),
    );
  }

  Widget _buildFilterChip(String label, ReportLogLevel? level) {
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

  Widget _buildLogEntry(ReportLogEntry log) {
    Color backgroundColor;
    switch (log.level) {
      case ReportLogLevel.error:
      case ReportLogLevel.fatal:
        backgroundColor = Colors.red.shade50;
        break;
      case ReportLogLevel.warning:
        backgroundColor = Colors.orange.shade50;
        break;
      case ReportLogLevel.info:
        backgroundColor = Colors.blue.shade50;
        break;
      case ReportLogLevel.debug:
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
              Text(log.levelEmoji, style: TextStyle(fontSize: 16.sp)),
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
