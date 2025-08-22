import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/services/sentry_service.dart';
import '../providers/onboarding_controller.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../nutrition_plan/data/food_repository.dart';
import '../../../nutrition_plan/domain/food_item.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/food_preference_widget.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';

/// Food preferences screen - final step of onboarding
/// Users select their food preferences using radio options
class FoodPreferencesScreen extends ConsumerStatefulWidget {
  const FoodPreferencesScreen({super.key});

  @override
  ConsumerState<FoodPreferencesScreen> createState() => _FoodPreferencesScreenState();
}

class _FoodPreferencesScreenState extends ConsumerState<FoodPreferencesScreen> {
  final Map<String, FoodPreference> _selectedPreferences = {};
  List<FoodItem> _foods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    try {
      final foodRepository = ref.read(foodRepositoryProvider);
      final foods = await foodRepository.getAllFoods();
      setState(() {
        _foods = foods;
        _isLoading = false;
        // Initialize all foods as dislike by default
        for (final food in foods) {
          _selectedPreferences[food.name] = FoodPreference.dislike;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading foods: $e');
    }
  }

  Future<void> _completeOnboarding() async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final success = await controller.saveFoodPreferences(_selectedPreferences);
    if (success && mounted) {
      context.go('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncState = ref.watch(onboardingControllerProvider);
    final content = ref.read(contentServiceProvider);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.baseCream,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final title = content.getValue(ContentKeys.foodPreferencesTitle, defaultValue: 'Food Preferences');
    final likeLabel = content.getValue(ContentKeys.foodPreferencesOptionLike, defaultValue: 'Love');
    final willingLabel = content.getValue(ContentKeys.foodPreferencesOptionWillingToTry, defaultValue: 'Willing to Try');
    final dislikeLabel = content.getValue(ContentKeys.foodPreferencesOptionDislike, defaultValue: 'Avoid');
    final completeLabel = content.getValue(ContentKeys.foodPreferencesCompleteButton, defaultValue: 'Complete Setup');

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        foregroundColor: AppTheme.baseWhite,
        leading: const CustomAppBarBackButton(),
        title: Text(title),
        centerTitle: true,
        iconTheme: IconThemeData(
          color: AppTheme.baseWhite,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              itemCount: _foods.length,
              separatorBuilder: (context, index) => SizedBox(height: 8.h),
              itemBuilder: (context, index) {
                final food = _foods[index];
                final selected = _selectedPreferences[food.name] ?? FoodPreference.dislike;
                return FoodPreferenceChipItem(
                  food: food,
                  selected: selected,
                  likeLabel: likeLabel,
                  willingLabel: willingLabel,
                  dislikeLabel: dislikeLabel,
                  onChanged: (value) {
                    setState(() {
                      _selectedPreferences[food.name] = value;
                    });
                  },
                );
              },
            ),
          ),

          Padding(
            padding: EdgeInsets.all(16.w),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: asyncState.isLoading ? null : _completeOnboarding,
                child: asyncState.isLoading
                    ? const CircularProgressIndicator()
                    : Text(completeLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}