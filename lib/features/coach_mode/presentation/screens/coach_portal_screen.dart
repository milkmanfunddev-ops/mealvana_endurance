import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../providers/coach_dashboard_controller.dart';
import '../providers/coach_portal_controller.dart';
import '../widgets/portal_sidebar.dart';
import '../widgets/portal_athlete_detail_panel.dart';
import '../widgets/portal_reports_placeholder.dart';
import '../widgets/portal_messages_panel.dart';

/// Unified full-screen coach portal with split-panel layout
/// Left sidebar: navigation + athlete list
/// Right panel: athlete detail, reports, or messages
class CoachPortalScreen extends ConsumerWidget {
  const CoachPortalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portalState = ref.watch(coachPortalControllerProvider);
    final dashboardAsync = ref.watch(coachDashboardControllerProvider);

    // Auto-select first athlete if none selected
    dashboardAsync.whenData((state) {
      if (portalState.selectedRelationshipId == null &&
          state.activeAthletes.isNotEmpty) {
        // Schedule the state change after the current build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(coachPortalControllerProvider.notifier)
              .selectAthlete(state.activeAthletes.first.id);
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.blackberryDark,
      body: Row(
        children: [
          // Left sidebar
          const PortalSidebar(),

          // Divider
          const VerticalDivider(
            width: 1,
            color: AppColors.blackberryLight,
          ),

          // Right panel
          Expanded(
            child: Column(
              children: [
                // Top bar
                _buildTopBar(context, ref),

                // Content area
                Expanded(
                  child: _buildRightPanel(portalState),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, WidgetRef ref) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.blackberry,
      child: Row(
        children: [
          const Spacer(),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            color: AppColors.textDarkSecondary,
            tooltip: 'Refresh all data',
            onPressed: () {
              ref.read(coachDashboardControllerProvider.notifier).refresh();
            },
          ),
          const SizedBox(width: 4),
          // Logout / Back to app
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textDarkSecondary,
            ),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to App', style: TextStyle(fontSize: 13)),
            onPressed: () {
              context.go('/main');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel(CoachPortalState portalState) {
    switch (portalState.activeSection) {
      case PortalSection.athletes:
        if (portalState.selectedRelationshipId == null) {
          return _buildNoAthleteSelected();
        }
        return PortalAthleteDetailPanel(
          key: ValueKey(portalState.selectedRelationshipId),
          relationshipId: portalState.selectedRelationshipId!,
        );
      case PortalSection.reports:
        return const PortalReportsPlaceholder();
      case PortalSection.messages:
        return const PortalMessagesPanel();
    }
  }

  Widget _buildNoAthleteSelected() {
    return Container(
      color: AppColors.blackberryDark,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.inactive.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select an athlete',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.cream,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose an athlete from the sidebar to view their details.',
              style: TextStyle(
                color: AppColors.textDarkSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
