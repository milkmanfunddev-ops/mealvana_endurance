import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/providers/user_id_provider.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../shared/widgets/content_area.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../coach_mode/application/coach_service.dart';
import '../../../coach_mode/data/coach_repository.dart';
import '../../../coach_mode/domain/pairing_code_connection_result.dart';

/// Athlete-facing screen to generate pairing codes and manage coach connection.
class CoachConnectionScreen extends ConsumerStatefulWidget {
  const CoachConnectionScreen({super.key});

  @override
  ConsumerState<CoachConnectionScreen> createState() =>
      _CoachConnectionScreenState();
}

class _CoachConnectionScreenState extends ConsumerState<CoachConnectionScreen> {
  bool _isLoading = true;
  bool _isConnecting = false;
  String? _coachName;
  String? _coachUserId;
  final _codeController = TextEditingController();
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    try {
      final userId = await ref.read(userIdProvider.future);
      final repo = ref.read(coachRepositoryProvider);

      // Check for active coach connection
      final coach = await repo.getMyCoach(userId);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _coachUserId = coach?.coachUserId;
        _coachName = coach?.coachName;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _connectViaCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _codeError = 'Code must be 6 characters');
      return;
    }

    setState(() {
      _isConnecting = true;
      _codeError = null;
    });

    try {
      final result = await ref
          .read(coachServiceProvider)
          .connectViaCoachCodeAsAthlete(code: code);

      if (!mounted) return;

      if (result.isSuccess) {
        MealvanaSnackbar.showSuccess(context, 'Connected to coach!');
        _codeController.clear();
        // Reload to show connected state
        setState(() => _isLoading = true);
        await _loadState();
      } else {
        setState(() {
          _isConnecting = false;
          _codeError = _buildFailureMessage(result.failureReason);
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _codeError = 'Connection failed. Please try again.';
      });
    }
  }

  String _buildFailureMessage(PairingCodeConnectFailureReason? reason) {
    switch (reason) {
      case PairingCodeConnectFailureReason.noUserProfile:
        return 'Could not determine your account. Please sign out and sign back in.';
      case PairingCodeConnectFailureReason.invalidCodeFormat:
        return 'Code must be 6 letters or numbers.';
      case PairingCodeConnectFailureReason.codeNotFound:
        return 'This pairing code was not found.';
      case PairingCodeConnectFailureReason.codeAlreadyUsed:
        return 'This pairing code has already been used.';
      case PairingCodeConnectFailureReason.codeExpired:
        return 'This pairing code has expired. Ask your coach for a new one.';
      case PairingCodeConnectFailureReason.selfConnectionNotAllowed:
        return 'You cannot connect to your own pairing code.';
      case PairingCodeConnectFailureReason.relationshipAlreadyExists:
        return 'You are already connected to this coach.';
      case PairingCodeConnectFailureReason.notApprovedCoach:
        return 'This code is not from an approved coach.';
      case PairingCodeConnectFailureReason.unknown:
      case null:
        return 'Unable to connect right now. Please try again.';
    }
  }

  Future<void> _disconnectCoach() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Coach?'),
        content: Text(
          'This will remove ${_coachName ?? 'your coach'} as your coach. '
          'They will no longer be able to view your activities or create plans for you.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => ctx.pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dragonfruit),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final userId = await ref.read(userIdProvider.future);
      final repo = ref.read(coachRepositoryProvider);
      final success = await repo.disconnectFromCoach(
        athleteUserId: userId,
        coachUserId: _coachUserId!,
      );

      if (!mounted) return;
      if (success) {
        setState(() {
          _coachUserId = null;
          _coachName = null;
        });
        MealvanaSnackbar.showSuccess(context, 'Disconnected from coach');
      } else {
        MealvanaSnackbar.showError(context, 'Failed to disconnect');
      }
    } catch (_) {
      if (!mounted) return;
      MealvanaSnackbar.showError(context, 'Failed to disconnect');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const CustomAppBarBackButton(),
        title: Text(
          'Coach Connection',
          style: TextStyle(
            color: isDark ? AppColors.cream : AppColors.blackberry,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ContentArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_coachUserId != null) _buildConnectedSection(isDark),
                    if (_coachUserId == null) _buildNotConnectedSection(isDark),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildConnectedSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.electrolyte.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.electrolyte.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.electrolyte, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected to Coach',
                      style: TextStyle(
                        color: isDark ? AppColors.cream : AppColors.blackberry,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _coachName ?? 'Your coach',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textDarkSecondary
                            : AppColors.textLightSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Coach chat button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/coach-chat'),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Message Coach'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(
                color: isDark ? AppColors.blackberryLight : AppColors.blackberry,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Disconnect button
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _disconnectCoach,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.dragonfruit,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Disconnect from Coach'),
          ),
        ),
      ],
    );
  }

  Widget _buildNotConnectedSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Explanation
        Text(
          'Connect with Your Coach',
          style: TextStyle(
            color: isDark ? AppColors.cream : AppColors.blackberry,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the pairing code your coach gave you. '
          'Once connected, your coach can view your activities and create nutrition plans for you.',
          style: TextStyle(
            color: isDark
                ? AppColors.textDarkSecondary
                : AppColors.textLightSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),

        // Code entry
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.blackberryDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.blackberryLight
                  : AppColors.blackberry.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Enter Coach Code',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textDarkSecondary
                      : AppColors.textLightSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: TextStyle(
                  color: isDark ? AppColors.cream : AppColors.blackberry,
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  letterSpacing: 6,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: 'ABC123',
                  counterText: '',
                  hintStyle: TextStyle(
                    color: (isDark
                            ? AppColors.textDarkSecondary
                            : AppColors.textLightSecondary)
                        .withValues(alpha: 0.5),
                    letterSpacing: 6,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.blackberry
                      : AppColors.blackberry.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.blackberryLight
                          : AppColors.blackberry.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.blackberryLight
                          : AppColors.blackberry.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.electrolyte,
                    ),
                  ),
                ),
                onSubmitted: (_) => _connectViaCode(),
              ),
              if (_codeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _codeError!,
                    style: const TextStyle(
                      color: AppColors.dragonfruit,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isConnecting ? null : _connectViaCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.electrolyte,
                    foregroundColor: AppColors.blackberry,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isConnecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Connect',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
