import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/database/database_provider.dart';
import '../../domain/athlete_invite_code.dart';

/// Screen for athletes to generate an invite code to share with their coach
class GenerateInviteCodeScreen extends ConsumerStatefulWidget {
  const GenerateInviteCodeScreen({super.key});

  @override
  ConsumerState<GenerateInviteCodeScreen> createState() =>
      _GenerateInviteCodeScreenState();
}

class _GenerateInviteCodeScreenState
    extends ConsumerState<GenerateInviteCodeScreen> {
  AthleteInviteCode? _inviteCode;
  bool _isGenerating = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _generateCode();
  }

  Future<void> _generateCode() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      // Get current user profile
      final database = ref.read(appDatabaseProvider);
      final profile = await database.getCurrentUserProfile();

      if (profile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to generate code. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Create invite code that expires in 24 hours
      final now = DateTime.now();
      final code = AthleteInviteCode(
        userId: profile.id,
        deviceId: profile.deviceId,
        displayName: 'Athlete', // User profile doesn't have display name
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );

      setState(() {
        _inviteCode = code;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating code: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _copyToClipboard() async {
    if (_inviteCode == null) return;

    final code = _inviteCode!.toShortCode();
    await Clipboard.setData(ClipboardData(text: code));

    setState(() {
      _copied = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite code copied to clipboard'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }

    // Reset copied state after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  Future<void> _shareCode() async {
    if (_inviteCode == null) return;

    final code = _inviteCode!.toShortCode();
    final shareText =
        'Connect with me on Mealvana Endurance!\n\nPaste this code in the Coach Dashboard:\n\n$code';

    // Copy to clipboard as fallback for web
    await Clipboard.setData(ClipboardData(text: shareText));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code copied! Share it with your coach.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach Invite Code'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isGenerating
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Info card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.link,
                            size: 48,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Share with Your Coach',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Give this code to your coach so they can connect with you and view your training data.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Code display
                  if (_inviteCode != null) ...[
                    Text(
                      'Your Invite Code',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          SelectableText(
                            _inviteCode!.toShortCode(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              letterSpacing: 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '(Tap and hold to select)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Expiry warning
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Expires in 24 hours',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _copyToClipboard,
                            icon: Icon(_copied ? Icons.check : Icons.copy),
                            label: Text(_copied ? 'Copied!' : 'Copy Code'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _shareCode,
                            icon: const Icon(Icons.share),
                            label: const Text('Share'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Regenerate button
                    TextButton.icon(
                      onPressed: _generateCode,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Generate New Code'),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Security note
                  Card(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.security,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Privacy & Security',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Only share this code with coaches you trust. They will be able to view your training and nutrition data once you accept their invitation.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
