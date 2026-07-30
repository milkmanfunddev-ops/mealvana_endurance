import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../ai_credits/domain/insufficient_credits_exception.dart';
import '../../../ai_credits/presentation/insufficient_credits_paywall.dart';
import '../../../ai_credits/presentation/widgets/token_pill.dart';
import '../../application/meal_ai_service.dart';

/// Natural-language meal description screen.
///
/// Route: `/meal-log/describe`
/// Extras: `{ 'logDate': String }`
class DescribeMealScreen extends ConsumerStatefulWidget {
  const DescribeMealScreen({super.key});

  @override
  ConsumerState<DescribeMealScreen> createState() => _DescribeMealScreenState();
}

class _DescribeMealScreenState extends ConsumerState<DescribeMealScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();
  bool _isAnalyzing = false;
  String? _logDate;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      _logDate = extra?['logDate'] as String? ?? _todayDateString();
      _initialized = true;
    }
  }

  static String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final analytics = ref.read(appExternalDepsProvider).analytics;
    analytics.track('meal_ai_action_tapped', properties: {'method': 'text'});
    if (!_formKey.currentState!.validate()) {
      analytics.track(
        'meal_ai_validation_failed',
        properties: {'method': 'text'},
      );
      return;
    }

    setState(() => _isAnalyzing = true);
    analytics.track('meal_ai_started', properties: {'method': 'text'});
    final stopwatch = Stopwatch()..start();

    try {
      final service = ref.read(mealAiServiceProvider);
      final result = await service.describeMeal(_descriptionCtrl.text.trim());
      stopwatch.stop();
      analytics.track(
        'meal_ai_completed',
        properties: {
          'method': 'text',
          'latency_ms': stopwatch.elapsedMilliseconds,
          'input_tokens': result.inputTokens,
          'output_tokens': result.outputTokens,
          'total_tokens': result.totalTokens,
          if (result.model != null) 'model': result.model,
          if (result.costUsd != null) 'cost_usd': result.costUsd,
          'confidence': result.confidence.name,
          'item_count': result.items.length,
        },
      );

      if (!mounted) return;
      context.push(
        '/meal-log/review',
        extra: {
          'result': result,
          'source': 'describe',
          'logDate': _logDate,
          'photoPath': null,
        },
      );
    } on InsufficientCreditsException catch (e) {
      stopwatch.stop();
      analytics.track(
        'meal_ai_failed',
        properties: {
          'method': 'text',
          'error_type': 'insufficient_credits',
          'latency_ms': stopwatch.elapsedMilliseconds,
        },
      );
      maybeShowInsufficientCreditsPaywall(e);
    } on MealAiException catch (e) {
      stopwatch.stop();
      analytics.track(
        'meal_ai_failed',
        properties: {
          'method': 'text',
          'error_type': e.kind.name,
          'latency_ms': stopwatch.elapsedMilliseconds,
        },
      );
      if (!mounted) return;
      MealvanaSnackbar.showError(context, e.userMessage);
    } catch (_) {
      stopwatch.stop();
      analytics.track(
        'meal_ai_failed',
        properties: {
          'method': 'text',
          'error_type': 'unknown',
          'latency_ms': stopwatch.elapsedMilliseconds,
        },
      );
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        title: const Text('Describe to Jade'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: AppSpacing.screenPaddingHorizontal,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  // Prompt on the left, token balance on the right — the cost
                  // of the action sits next to the description of it.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Describe what you ate and Jade will estimate the '
                          'macros.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isDark
                                ? AppColors.cream.withValues(alpha: 0.65)
                                : AppColors.blackberry.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const TokenPill(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _descriptionCtrl,
                    maxLines: 6,
                    minLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'What did you eat?',
                      hintText:
                          'e.g. A bowl of oatmeal with blueberries and a tablespoon of honey, plus a large coffee with oat milk.',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v == null || v.trim().length < 5)
                        ? 'Please describe your meal'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // The Analyze button carries its own price: "Analyze 🍪 1".
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      KylePrimaryButton(
                        text: 'Analyze',
                        isLoading: _isAnalyzing,
                        onPressed: _isAnalyzing ? null : _analyze,
                      ),
                      if (!_isAnalyzing)
                        const IgnorePointer(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Reserve the label's width so the chip sits to
                              // its right rather than over it.
                              SizedBox(width: 76),
                              TokenCostChip(),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
          if (_isAnalyzing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Jade is thinking...',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
