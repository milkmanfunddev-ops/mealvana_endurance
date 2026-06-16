import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../widgets/manual_log_form.dart';

/// Manual meal entry screen.
///
/// Route: `/meal-log/manual`
/// Extras: `{ 'logDate': String }`
///
/// Thin Scaffold wrapper around the shared [ManualLogForm]; the same form is
/// embedded inline as the "Manual" tab of the log sheet.
class ManualLogScreen extends ConsumerStatefulWidget {
  const ManualLogScreen({super.key});

  @override
  ConsumerState<ManualLogScreen> createState() => _ManualLogScreenState();
}

class _ManualLogScreenState extends ConsumerState<ManualLogScreen> {
  String? _logDate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_logDate == null) {
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      _logDate = extra?['logDate'] as String? ?? _todayDateString();
    }
  }

  static String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        title: const Text('Log a Meal'),
        elevation: 0,
      ),
      body: ManualLogForm(
        logDate: _logDate ?? _todayDateString(),
        onLogged: () {
          MealvanaSnackbar.showSuccess(context, 'Meal logged!');
          context.pop();
        },
        onLogError: () => MealvanaSnackbar.showError(
          context,
          'Failed to log meal. Please try again.',
        ),
      ),
    );
  }
}
