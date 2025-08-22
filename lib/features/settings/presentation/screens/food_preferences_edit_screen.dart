import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../auth/application/auth_service.dart';
import '../../../nutrition_plan/data/food_repository.dart';
import '../../../nutrition_plan/domain/food_item.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/food_preference_widget.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';

/// Food preferences editing screen for settings
/// Allows users to update their food preferences after onboarding
class FoodPreferencesEditScreen extends ConsumerStatefulWidget {
  const FoodPreferencesEditScreen({super.key});

  @override
  ConsumerState<FoodPreferencesEditScreen> createState() => _FoodPreferencesEditScreenState();
}

class _FoodPreferencesEditScreenState extends ConsumerState<FoodPreferencesEditScreen> {
  final Map<String, FoodPreference> _selectedPreferences = {};
  List<FoodItem> _foods = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    try {
      final foodRepository = ref.read(foodRepositoryProvider);
      final authService = ref.read(authServiceProvider);
      
      // Load all foods
      final foods = await foodRepository.getAllFoods();
      
      // Load existing preferences
      final currentUser = await authService.getCurrentUser();
      if (currentUser != null) {
        final existingPreferences = await authService.getFoodPreferences(currentUser.id);
        
        setState(() {
          _foods = foods;
          _isLoading = false;
          
          // Set existing preferences or default to dislike
          for (final food in foods) {
            _selectedPreferences[food.name] = existingPreferences?[food.name] ?? FoodPreference.dislike;
          }
        });
      } else {
        throw Exception('No user found');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading foods: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading food preferences: $e'),
            backgroundColor: AppTheme.highlight600,
          ),
        );
      }
    }
  }

  Future<void> _savePreferences() async {
    if (_isSaving) return;
    
    setState(() {
      _isSaving = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final currentUser = await authService.getCurrentUser();
      
      if (currentUser != null) {
        await authService.saveFoodPreferences(currentUser.id, _selectedPreferences);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Food preferences saved!'),
              backgroundColor: AppTheme.primary600,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Navigate back to settings
          context.pop();
        }
      } else {
        throw Exception('No user found');
      }
    } catch (e) {
      debugPrint('Error saving preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: AppTheme.highlight600,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.baseCream,
        appBar: AppBar(
          backgroundColor: AppTheme.baseCream,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: CustomAppBarBackButton(
            onPressed: () => context.pop(),
          ),
          title: const Text('Food Preferences'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final title = content.getValue(ContentKeys.foodPreferencesTitle, defaultValue: 'Food Preferences');
    final likeLabel = content.getValue(ContentKeys.foodPreferencesOptionLike, defaultValue: 'Love');
    final willingLabel = content.getValue(ContentKeys.foodPreferencesOptionWillingToTry, defaultValue: 'Willing to Try');
    final dislikeLabel = content.getValue(ContentKeys.foodPreferencesOptionDislike, defaultValue: 'Avoid');

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: CustomAppBarBackButton(
          onPressed: () => context.pop(),
        ),
        title: Text(
          title,
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
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
                final preference = _selectedPreferences[food.name] ?? FoodPreference.dislike;
                
                return FoodPreferenceChipItem(
                  food: food,
                  selected: preference,
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
          
          // Save button
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppTheme.baseWhite,
              border: Border(
                top: BorderSide(
                  color: AppTheme.baseGrey.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: PrimaryButton(
              text: _isSaving ? 'Saving...' : 'Save Changes',
              onPressed: _isSaving ? null : _savePreferences,
              width: double.infinity,
            ),
          ),
        ],
      ),
    );
  }
}