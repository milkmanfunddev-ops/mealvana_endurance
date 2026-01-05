import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/athlete_invite_code.dart';
import '../providers/invite_athlete_controller.dart';

/// Screen for coaches to invite athletes by entering their invite code
class InviteAthleteScreen extends ConsumerStatefulWidget {
  const InviteAthleteScreen({super.key});

  @override
  ConsumerState<InviteAthleteScreen> createState() =>
      _InviteAthleteScreenState();
}

class _InviteAthleteScreenState extends ConsumerState<InviteAthleteScreen> {
  final _codeController = TextEditingController();
  AthleteInviteCode? _parsedCode;
  String? _errorMessage;
  bool _isValidating = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _validateCode(String code) {
    setState(() {
      _errorMessage = null;
      _parsedCode = null;
    });

    if (code.isEmpty) return;

    // Try to parse the code
    final parsed = AthleteInviteCode.fromShortCode(code.trim());
    if (parsed == null) {
      setState(() {
        _errorMessage = 'Invalid invite code format';
      });
      return;
    }

    if (parsed.isExpired) {
      setState(() {
        _errorMessage = 'This invite code has expired';
      });
      return;
    }

    setState(() {
      _parsedCode = parsed;
    });
  }

  Future<void> _sendInvite() async {
    if (_parsedCode == null) return;

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      final success = await ref
          .read(inviteAthleteControllerProvider.notifier)
          .inviteAthlete(
            athleteUserId: _parsedCode!.userId,
            athleteDeviceId: _parsedCode!.deviceId,
          );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation sent to ${_parsedCode!.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      } else {
        setState(() {
          _errorMessage = 'Failed to send invitation. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _codeController.text = data!.text!.trim();
      _validateCode(data.text!.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Athlete'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'How to invite an athlete',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                      context,
                      '1',
                      'Ask your athlete to open their Mealvana app',
                    ),
                    _buildInstructionStep(
                      context,
                      '2',
                      'Have them go to Settings > Coach Connection',
                    ),
                    _buildInstructionStep(
                      context,
                      '3',
                      'They tap "Generate Invite Code" and share it with you',
                    ),
                    _buildInstructionStep(
                      context,
                      '4',
                      'Enter or paste that code below',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Code input section
            Text(
              'Enter Athlete\'s Invite Code',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                hintText: 'Paste invite code here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste),
                  onPressed: _pasteFromClipboard,
                  tooltip: 'Paste from clipboard',
                ),
                errorText: _errorMessage,
              ),
              maxLines: 3,
              onChanged: _validateCode,
            ),

            const SizedBox(height: 24),

            // Parsed athlete info (if valid code)
            if (_parsedCode != null) ...[
              Card(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Valid Invite Code',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              _parsedCode!.displayName.isNotEmpty
                                  ? _parsedCode!.displayName[0].toUpperCase()
                                  : 'A',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _parsedCode!.displayName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Expires: ${_formatExpiry(_parsedCode!.expiresAt)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Send invite button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _parsedCode != null && !_isValidating ? _sendInvite : null,
                icon: _isValidating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(_isValidating ? 'Sending...' : 'Send Invitation'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(
    BuildContext context,
    String number,
    String text,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatExpiry(DateTime expiry) {
    final now = DateTime.now();
    final diff = expiry.difference(now);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours';
    } else {
      return '${diff.inDays} days';
    }
  }
}
