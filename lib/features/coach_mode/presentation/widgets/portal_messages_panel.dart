import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../domain/coach_athlete_relationship.dart';
import '../providers/coach_dashboard_controller.dart';
import '../providers/coach_portal_controller.dart';

/// Messages overview panel showing recent conversations with athletes
class PortalMessagesPanel extends ConsumerWidget {
  const PortalMessagesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(coachDashboardControllerProvider);

    return Container(
      color: AppColors.blackberryDark,
      child: dashboardAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.electrolyte),
        ),
        error: (error, _) => Center(
          child: Text(
            'Failed to load messages',
            style: const TextStyle(color: AppColors.textDarkSecondary),
          ),
        ),
        data: (state) => _buildMessagesList(context, ref, state),
      ),
    );
  }

  Widget _buildMessagesList(
    BuildContext context,
    WidgetRef ref,
    CoachDashboardState state,
  ) {
    if (state.activeAthletes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_outlined,
                size: 64,
                color: AppColors.inactive.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Conversations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cream,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connect with athletes to start messaging.',
                textAlign: TextAlign.center,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            'Conversations',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.cream,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: state.activeAthletes.length,
            itemBuilder: (context, index) {
              final athlete = state.activeAthletes[index];
              return _ConversationTile(
                relationship: athlete,
                onTap: () {
                  ref
                      .read(coachPortalControllerProvider.notifier)
                      .selectAthlete(athlete.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final CoachAthleteRelationship relationship;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.relationship,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = relationship.athleteDisplayName ??
        'Athlete ${relationship.athleteUserId.substring(0, 8)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.blackberry,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.blackberryLight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.electrolyte,
                  child: Text(
                    _getInitials(name),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blackberryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.cream,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tap to open conversation',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textDarkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: AppColors.textDarkSecondary,
                ),
              ],
            ),
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
