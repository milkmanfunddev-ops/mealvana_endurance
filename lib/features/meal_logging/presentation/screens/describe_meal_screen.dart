import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../application/meal_ai_service.dart';

/// Natural-language meal description screen.
///
/// Route: `/meal-log/describe`
/// Extras: `{ 'logDate': String }`
class DescribeMealScreen extends ConsumerStatefulWidget {
  const DescribeMealScreen({super.key});

  @override
  ConsumerState<DescribeMealScreen> createState() =>
      _DescribeMealScreenState();
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
      final extra =
          GoRouterState.of(context).extra as Map<String, dynamic>?;
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isAnalyzing = true);

    try {
      final service = ref.read(mealAiServiceProvider);
      final result = await service.describeMeal(
        _descriptionCtrl.text.trim(),
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
    } on MealAiException catch (e) {
      if (!mounted) return;
      MealvanaSnackbar.showError(context, e.userMessage);
    } catch (_) {
      if (mounted) {
        MealvanaSnackbar.showError(
            context, 'Something went wrong. Please try again.');
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
                  Text(
                    'Describe what you ate and Jade will estimate the macros.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.cream.withValues(alpha: 0.65)
                          : AppColors.blackberry.withValues(alpha: 0.65),
                    ),
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
                    validator: (v) =>
                        (v == null || v.trim().length < 5)
                            ? 'Please describe your meal'
                            : null,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  KylePrimaryButton(
                    text: 'Analyze',
                    isLoading: _isAnalyzing,
                    onPressed: _isAnalyzing ? null : _analyze,
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
                      style:
                          AppTextStyles.bodyLarge.copyWith(color: Colors.white),
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
