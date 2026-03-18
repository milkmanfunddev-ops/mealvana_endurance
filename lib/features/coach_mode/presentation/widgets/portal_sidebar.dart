import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../application/coach_service.dart';
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
              error: (error, _) =>
                  _buildErrorView(context, error.toString(), ref),
              data: (state) =>
                  _buildAthletesList(context, ref, state, portalState),
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
      child: const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Coach Portal',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.cream,
          ),
        ),
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
          const Icon(
            Icons.error_outline,
            color: AppColors.dragonfruit,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textDarkSecondary,
              fontSize: 12,
            ),
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
            ],
          ),
        ),

        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.electrolyte,
                side: const BorderSide(color: AppColors.blackberryLight),
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => _showAthleteCodeDialog(context, ref),
              icon: const Icon(Icons.key, size: 16),
              label: const Text('Add Athlete'),
            ),
          ),
        ),

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
          ...state.activeAthletes.map(
            (athlete) => _AthleteListItem(
              relationship: athlete,
              isSelected: portalState.selectedRelationshipId == athlete.id,
              onTap: () {
                ref
                    .read(coachPortalControllerProvider.notifier)
                    .selectAthlete(athlete.id);
              },
              onRemove: () => _confirmRemoveAthlete(context, ref, athlete),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmRemoveAthlete(
    BuildContext context,
    WidgetRef ref,
    CoachAthleteRelationship athlete,
  ) async {
    final name =
        athlete.athleteDisplayName ??
        'Athlete ${athlete.athleteUserId.substring(0, 8)}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.blackberry,
        title: const Text(
          'Remove Athlete',
          style: TextStyle(color: AppColors.cream),
        ),
        content: Text(
          'Are you sure you want to remove $name? '
          'You will no longer have access to their data.',
          style: const TextStyle(color: AppColors.textDarkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(coachDashboardControllerProvider.notifier)
          .archiveAthlete(athlete.id);
      if (context.mounted) {
        MealvanaSnackbar.showSuccess(context, '$name removed');
      }
    }
  }

  Future<void> _showAthleteCodeDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _AthleteCodeDialog(
        onInviteSuccess: () {
          ref.read(coachDashboardControllerProvider.notifier).refresh();
        },
      ),
    );
  }
}

class _AthleteCodeDialog extends ConsumerStatefulWidget {
  final VoidCallback onInviteSuccess;

  const _AthleteCodeDialog({required this.onInviteSuccess});

  @override
  ConsumerState<_AthleteCodeDialog> createState() => _AthleteCodeDialogState();
}

class _AthleteCodeDialogState extends ConsumerState<_AthleteCodeDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isConnectingViaCode = false;
  String? _codeError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _connectViaCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _codeError = 'Code must be 6 characters');
      return;
    }

    setState(() {
      _isConnectingViaCode = true;
      _codeError = null;
    });

    try {
      final relationship = await ref
          .read(coachServiceProvider)
          .connectViaPairingCode(code: code);

      if (!mounted) return;

      if (relationship != null) {
        MealvanaSnackbar.showSuccess(context, 'Athlete connected!');
        widget.onInviteSuccess();
        Navigator.of(context).pop();
      } else {
        setState(() {
          _isConnectingViaCode = false;
          _codeError =
              'Unable to connect this code. Check that it is active and your coach account is approved.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isConnectingViaCode = false;
        _codeError = 'Connection failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.blackberry,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      title: Row(
        children: [
          const Expanded(
            child: Text(
              'Add Athlete',
              style: TextStyle(
                color: AppColors.cream,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textDarkSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Pairing Code Entry ──
            const Text(
              'Enter athlete pairing code',
              style: TextStyle(
                color: AppColors.textDarkSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 18,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ABC123',
                      counterText: '',
                      hintStyle: TextStyle(
                        color: AppColors.textDarkSecondary.withValues(
                          alpha: 0.5,
                        ),
                        letterSpacing: 4,
                      ),
                      filled: true,
                      fillColor: AppColors.blackberryDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.blackberryLight,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.blackberryLight,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.electrolyte,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _connectViaCode(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isConnectingViaCode ? null : _connectViaCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.electrolyte,
                      foregroundColor: AppColors.blackberry,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isConnectingViaCode
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Connect'),
                  ),
                ),
              ],
            ),
            if (_codeError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _codeError!,
                  style: const TextStyle(
                    color: AppColors.dragonfruit,
                    fontSize: 11,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Ask your athlete to generate this code from Settings > Coach Connection.',
              style: TextStyle(
                color: AppColors.textDarkSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
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
                  color: isSelected
                      ? AppColors.cream
                      : AppColors.textDarkSecondary,
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
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
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
  final VoidCallback onRemove;

  const _AthleteListItem({
    required this.relationship,
    required this.isSelected,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        relationship.athleteDisplayName ??
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
                backgroundColor: isSelected
                    ? AppColors.electrolyte
                    : AppColors.inputBackground,
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
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
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
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  tooltip: 'Remove athlete',
                  icon: Icon(
                    Icons.close,
                    color: isSelected
                        ? AppColors.textDarkSecondary
                        : AppColors.textDarkSecondary.withOpacity(0.5),
                  ),
                  onPressed: onRemove,
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
