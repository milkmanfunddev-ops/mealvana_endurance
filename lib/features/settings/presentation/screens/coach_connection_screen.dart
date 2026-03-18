import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/providers/user_id_provider.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../coach_mode/data/coach_repository.dart';

/// Athlete-facing screen to generate pairing codes and manage coach connection.
class CoachConnectionScreen extends ConsumerStatefulWidget {
  const CoachConnectionScreen({super.key});

  @override
  ConsumerState<CoachConnectionScreen> createState() =>
      _CoachConnectionScreenState();
}

class _CoachConnectionScreenState extends ConsumerState<CoachConnectionScreen> {
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _activeCode;
  DateTime? _codeExpiresAt;
  String? _coachName;
  String? _coachUserId;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    try {
      final userId = await ref.read(userIdProvider.future);
      final repo = ref.read(coachRepositoryProvider);

      // Check for active coach connection
      final coach = await repo.getMyCoach(userId);

      // Check for active pairing code
      final code = await repo.getActivePairingCode(userId);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _coachUserId = coach?.coachUserId;
        _coachName = coach?.coachName;
        _activeCode = code?.code;
        _codeExpiresAt = code?.expiresAt;
      });

      if (_codeExpiresAt != null) {
        _startCountdown();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (_codeExpiresAt != null &&
          _codeExpiresAt!.isBefore(DateTime.now().toUtc())) {
        setState(() {
          _activeCode = null;
          _codeExpiresAt = null;
        });
        _countdownTimer?.cancel();
      } else {
        setState(() {}); // Refresh remaining time display
      }
    });
  }

  Future<void> _generateCode() async {
    setState(() => _isGenerating = true);

    try {
      final userId = await ref.read(userIdProvider.future);
      final repo = ref.read(coachRepositoryProvider);
      final code = await repo.generatePairingCode(userId);

      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _activeCode = code;
        _codeExpiresAt = DateTime.now().toUtc().add(const Duration(hours: 24));
      });
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      MealvanaSnackbar.showError(context, 'Failed to generate code');
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

  String _formatRemainingTime() {
    if (_codeExpiresAt == null) return '';
    final remaining = _codeExpiresAt!.difference(DateTime.now().toUtc());
    if (remaining.isNegative) return 'Expired';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) return 'Expires in ${hours}h ${minutes}m';
    return 'Expires in ${minutes}m';
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
      body: _isLoading
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
          'Generate a pairing code and share it with your coach. '
          'Once connected, your coach can view your activities and create nutrition plans for you.',
          style: TextStyle(
            color: isDark
                ? AppColors.textDarkSecondary
                : AppColors.textLightSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),

        // Active code or generate button
        if (_activeCode != null) _buildActiveCodeCard(isDark),
        if (_activeCode == null) _buildGenerateButton(isDark),
      ],
    );
  }

  Widget _buildActiveCodeCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.blackberryDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.blackberryLight : AppColors.blackberry.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Your Pairing Code',
            style: TextStyle(
              color: isDark
                  ? AppColors.textDarkSecondary
                  : AppColors.textLightSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),

          // Code display with copy
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _activeCode!));
              MealvanaSnackbar.showSuccess(context, 'Code copied!');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.electrolyte),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _activeCode!,
                    style: TextStyle(
                      color: isDark ? AppColors.cream : AppColors.blackberry,
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                      letterSpacing: 6,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.copy,
                    color: AppColors.electrolyte,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Expiry info
          Text(
            _formatRemainingTime(),
            style: TextStyle(
              color: isDark
                  ? AppColors.textDarkSecondary
                  : AppColors.textLightSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share this code with your coach',
            style: TextStyle(
              color: isDark
                  ? AppColors.textDarkSecondary
                  : AppColors.textLightSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),

          // Generate new code
          TextButton(
            onPressed: _isGenerating ? null : _generateCode,
            child: Text(_isGenerating ? 'Generating...' : 'Generate New Code'),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isGenerating ? null : _generateCode,
        icon: _isGenerating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.vpn_key_outlined),
        label: Text(_isGenerating ? 'Generating...' : 'Generate Pairing Code'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electrolyte,
          foregroundColor: AppColors.blackberry,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
