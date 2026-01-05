import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/become_coach_controller.dart';

/// Screen for users to enter a coach invite code and become a coach
class BecomeCoachScreen extends ConsumerStatefulWidget {
  const BecomeCoachScreen({super.key});

  @override
  ConsumerState<BecomeCoachScreen> createState() => _BecomeCoachScreenState();
}

class _BecomeCoachScreenState extends ConsumerState<BecomeCoachScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    if (!_formKey.currentState!.validate()) return;

    final code = _codeController.text.trim().toUpperCase();

    final result = await ref
        .read(becomeCoachControllerProvider.notifier)
        .redeemInviteCode(code);

    if (!mounted) return;

    if (result.success) {
      // Show success and navigate to coach dashboard
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Welcome! You are now a coach.'),
          backgroundColor: Colors.green,
        ),
      );
      // Navigate to coach dashboard
      context.go('/coach');
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to redeem code'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(becomeCoachControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Become a Coach'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sports,
                  size: 48,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Enter Your Invite Code',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                'If you\'ve received a coach invite code, enter it below to unlock coach features and start working with athletes.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Code input
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Invite Code',
                  hintText: 'e.g., COACH-ABC123',
                  prefixIcon: const Icon(Icons.vpn_key),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste),
                    tooltip: 'Paste from clipboard',
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _codeController.text = data!.text!.trim().toUpperCase();
                      }
                    },
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                  UpperCaseTextFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your invite code';
                  }
                  if (value.trim().length < 6) {
                    return 'Invalid code format';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submitCode(),
              ),

              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : _submitCode,
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(isLoading ? 'Verifying...' : 'Activate Coach Mode'),
                ),
              ),

              const SizedBox(height: 48),

              // Info section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'What is Coach Mode?',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      context,
                      Icons.people,
                      'Manage athletes and their nutrition plans',
                    ),
                    _buildFeatureItem(
                      context,
                      Icons.comment,
                      'Provide feedback on activities',
                    ),
                    _buildFeatureItem(
                      context,
                      Icons.visibility,
                      'View athlete progress and data',
                    ),
                    _buildFeatureItem(
                      context,
                      Icons.web,
                      'Access coach dashboard (web)',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Don't have a code?
              Text(
                'Don\'t have an invite code?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Contact us to learn about becoming a coach on Mealvana Endurance.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text input formatter to convert to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
