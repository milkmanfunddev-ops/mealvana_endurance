import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../domain/coach_athlete_relationship.dart';
import '../providers/coach_dashboard_controller.dart';
import '../providers/coach_portal_controller.dart';

/// Left sidebar for the coach portal with nav + athlete list
class PortalSidebar extends ConsumerWidget {
  const PortalSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(coachDashboardControllerProvider);
    final portalState = ref.watch(coachPortalControllerProvider);

    return Container(
      width: 280,
      color: AppColors.blackberry,
      child: Column(
        children: [
          // Header
          _buildHeader(context),

          // Navigation items
          _buildNavSection(context, ref, portalState),

          const Divider(color: AppColors.blackberryLight, height: 1),

          // Athletes list (only shown when athletes section is active)
          Expanded(
            child: dashboardAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.electrolyte),
              ),
              error: (error, _) => _buildErrorView(context, error.toString(), ref),
              data: (state) => _buildAthletesList(context, ref, state, portalState),
            ),
          ),

          // Back to App button at bottom of sidebar
          const Divider(color: AppColors.blackberryLight, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textDarkSecondary,
              ),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to App', style: TextStyle(fontSize: 13)),
              onPressed: () => context.go('/main'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: const Row(
        children: [
          Icon(
            Icons.sports,
            color: AppColors.electrolyte,
            size: 28,
          ),
          SizedBox(width: 12),
          Text(
            'Coach Portal',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.cream,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavSection(
    BuildContext context,
    WidgetRef ref,
    CoachPortalState portalState,
  ) {
    return Column(
      children: [
        _NavItem(
          icon: Icons.people,
          label: 'Athletes',
          isSelected: portalState.activeSection == PortalSection.athletes,
          onTap: () {
            ref
                .read(coachPortalControllerProvider.notifier)
                .setSection(PortalSection.athletes);
          },
        ),
        _NavItem(
          icon: Icons.bar_chart,
          label: 'Reports',
          isSelected: portalState.activeSection == PortalSection.reports,
          onTap: () {
            ref
                .read(coachPortalControllerProvider.notifier)
                .setSection(PortalSection.reports);
          },
        ),
        _NavItem(
          icon: Icons.chat_bubble_outline,
          label: 'Messages',
          isSelected: portalState.activeSection == PortalSection.messages,
          onTap: () {
            ref
                .read(coachPortalControllerProvider.notifier)
                .setSection(PortalSection.messages);
          },
        ),
      ],
    );
  }

  Widget _buildErrorView(BuildContext context, String error, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.dragonfruit, size: 32),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.electrolyte),
            onPressed: () {
              ref.read(coachDashboardControllerProvider.notifier).refresh();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAthletesList(
    BuildContext context,
    WidgetRef ref,
    CoachDashboardState state,
    CoachPortalState portalState,
  ) {
    if (!state.isCoach) {
      return const Center(
        child: Text(
          'Not registered as a coach',
          style: TextStyle(color: AppColors.textDarkSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Stats summary
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _StatBadge(
                label: 'Athletes',
                count: state.athleteCount,
                color: AppColors.electrolyte,
              ),
              const SizedBox(width: 8),
              if (state.hasPendingRequests)
                _StatBadge(
                  label: 'Pending',
                  count: state.pendingRequests.length,
                  color: AppColors.orange,
                ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Active athletes
        if (state.activeAthletes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No athletes yet',
              style: TextStyle(
                color: AppColors.textDarkSecondary,
                fontSize: 13,
              ),
            ),
          )
        else
          ...state.activeAthletes.map((athlete) => _AthleteListItem(
                relationship: athlete,
                isSelected:
                    portalState.selectedRelationshipId == athlete.id,
                onTap: () {
                  ref
                      .read(coachPortalControllerProvider.notifier)
                      .selectAthlete(athlete.id);
                },
              )),

        // Pending requests section
        if (state.hasPendingRequests) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'PENDING (${state.pendingRequests.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textDarkSecondary.withOpacity(0.6),
                letterSpacing: 1,
              ),
            ),
          ),
          ...state.pendingRequests.map((request) => _PendingRequestItem(
                relationship: request,
                onAccept: () {
                  ref
                      .read(coachDashboardControllerProvider.notifier)
                      .acceptRequest(request.id);
                },
                onDecline: () {
                  ref
                      .read(coachDashboardControllerProvider.notifier)
                      .declineRequest(request.id);
                },
              )),
        ],
      ],
    );
  }
}

/// Navigation item in the sidebar
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.blackberryLight : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.blackberryLight.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.electrolyte : AppColors.inactive,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppColors.cream : AppColors.textDarkSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact stat badge for sidebar
class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact athlete list item for sidebar
class _AthleteListItem extends StatelessWidget {
  final CoachAthleteRelationship relationship;
  final bool isSelected;
  final VoidCallback onTap;

  const _AthleteListItem({
    required this.relationship,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = relationship.athleteDisplayName ??
        'Athlete ${relationship.athleteUserId.substring(0, 8)}';

    return Material(
      color: isSelected ? AppColors.blackberryLight : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.blackberryLight.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    isSelected ? AppColors.electrolyte : AppColors.inputBackground,
                child: Text(
                  _getInitials(name),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.blackberryDark
                        : AppColors.textDarkSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? AppColors.cream
                            : AppColors.textDarkSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.electrolyte.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}

/// Pending request item for sidebar
class _PendingRequestItem extends StatelessWidget {
  final CoachAthleteRelationship relationship;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _PendingRequestItem({
    required this.relationship,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final isFromCoach = relationship.requestedBy == 'coach';
    final name = relationship.athleteDisplayName ??
        'Athlete ${relationship.athleteUserId.substring(0, 8)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.blackberryLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.orange.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.orange.withOpacity(0.2),
                  child: Icon(
                    isFromCoach ? Icons.arrow_forward : Icons.arrow_back,
                    size: 14,
                    color: AppColors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.cream,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (!isFromCoach) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 28,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textDarkSecondary,
                        side: const BorderSide(color: AppColors.textDarkSecondary),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      onPressed: onDecline,
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 28,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.electrolyte,
                        foregroundColor: AppColors.blackberryDark,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      onPressed: onAccept,
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Waiting for response',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textDarkSecondary.withOpacity(0.6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
