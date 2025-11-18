import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../providers/settings_controller.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import 'debug_screen.dart';

/// Settings Screen - Kyle's Design System + Database Integration RESTORED
/// Main settings screen with full controller integration for data persistence
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Triple-tap debug feature
  int _tapCount = 0;
  DateTime? _lastTapTime;

  void _handleProfileTap() {
    final now = DateTime.now();

    // Reset counter if more than 2 seconds since last tap
    if (_lastTapTime != null && now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _tapCount = 0;
    }

    _tapCount++;
    _lastTapTime = now;

    debugPrint('🐛 Settings tap detected! Tap count: $_tapCount');

    if (_tapCount == 3) {
      _tapCount = 0; // Reset counter
      debugPrint('🎉 Triple tap detected! Opening debug screen...');

      // Navigate to debug screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const DebugScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: settingsAsync.when(
        data: (state) => _buildContent(context, state),
        loading: () => _buildLoadingState(context),
        error: (error, stack) => _buildErrorState(context, error),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Text(
        'Settings',
        style: AppTextStyles.sectionTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.electrolyte,
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            FontAwesomeIcons.circleExclamation,
            color: AppColors.dragonfruit,
            size: 64,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Error loading settings',
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.dragonfruit,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error.toString(),
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, dynamic state) {
    return SingleChildScrollView(
      padding: AppSpacing.screenPaddingHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),

          // Account section (new for Phase 2)
          _buildAccountSection(context, state),

          const SizedBox(height: AppSpacing.lg),

          // Theme toggle section
          _buildThemeSection(context),

          const SizedBox(height: AppSpacing.lg),

          // Profile section (with triple-tap gesture)
          GestureDetector(
            onTap: _handleProfileTap,
            behavior: HitTestBehavior.opaque,
            child: _buildProfileSection(context, state),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Preferences section
          _buildPreferencesSection(context, state),

          const SizedBox(height: AppSpacing.lg),

          // Quick links section
          _buildQuickLinksSection(context),

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context, dynamic state) {
    final isAnonymous = state.isAnonymous ?? true;
    final authProvider = state.authProvider ?? 'anonymous';
    final email = state.email;

    // Format provider name for display
    String providerName = authProvider;
    switch (authProvider) {
      case 'apple':
        providerName = 'Apple';
        break;
      case 'google':
        providerName = 'Google';
        break;
      case 'email':
        providerName = 'Email';
        break;
      default:
        providerName = 'Anonymous';
    }

    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.accountSectionTitle ?? 'Account',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          if (isAnonymous) ...[
            // Anonymous user - show "Create Account" CTA
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.userLarge,
                  size: AppIconSizes.md,
                  color: AppColors.orange.withOpacity(0.7),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.accountStatusAnonymous ?? 'Not signed in',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Create an account to sync your data across devices',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Create Account button
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                text: state.createAccountButton ?? 'Create Account',
                onPressed: () {
                  final analytics = ref.read(appExternalDepsProvider);
                  analytics.analytics.track('settings_create_account_tapped');
                  context.push('/auth/post-onboarding');
                },
              ),
            ),
          ] else ...[
            // Authenticated user - show provider and sign out
            Row(
              children: [
                Icon(
                  authProvider == 'apple' ? FontAwesomeIcons.apple :
                  authProvider == 'google' ? FontAwesomeIcons.google :
                  FontAwesomeIcons.envelope,
                  size: AppIconSizes.md,
                  color: AppColors.electrolyte,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Signed in with $providerName',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (email != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          email,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Sign Out button
            SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                text: state.signOutButton ?? 'Sign Out',
                onPressed: () async {
                  await ref.read(settingsControllerProvider.notifier).signOut();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    final themeModeAsync = ref.watch(kyleThemeModeProvider);

    return themeModeAsync.when(
      data: (themeMode) => BaseCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: AppTextStyles.subtitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Theme mode selector
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.palette,
                  size: AppIconSizes.md,
                  color: AppColors.electrolyte,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme Mode',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      KyleSegmentedControl<ThemeMode>(
                        segments: ThemeMode.values,
                        selected: themeMode,
                        onChanged: (mode) => ref.read(kyleThemeModeProvider.notifier).setThemeMode(mode),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      loading: () => const BaseCard(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.electrolyte),
        ),
      ),
      error: (error, stack) => BaseCard(
        child: Text(
          'Error loading theme settings',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.dragonfruit,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, dynamic state) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                state.profileSectionTitle,
                style: AppTextStyles.subtitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '(Tap 3x for debug)',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Gender selector
          _buildGenderSelector(context, state),

          const SizedBox(height: AppSpacing.md),

          // Birthday selector
          _buildBirthdaySelector(context, state),

          const SizedBox(height: AppSpacing.md),

          // Height selector
          _buildHeightSelector(context, state),

          const SizedBox(height: AppSpacing.md),

          // Weight selector
          _buildWeightSelector(context, state),

          const SizedBox(height: AppSpacing.md),

          // Water bottle toggle
          _buildWaterBottleToggle(context, state),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection(BuildContext context, dynamic state) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.preferenceSectionTitle,
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Distance unit
          _buildDistanceUnitSelector(context, state),

          const SizedBox(height: AppSpacing.md),

          // Pace unit
          _buildPaceUnitSelector(context, state),

          const SizedBox(height: AppSpacing.md),

          // Gut training level
          _buildGutTrainingSelector(context, state),
        ],
      ),
    );
  }

  Widget _buildQuickLinksSection(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Links',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Food preferences
          _buildQuickLink(
            context: context,
            icon: FontAwesomeIcons.utensils,
            title: 'Food Preferences',
            subtitle: 'Manage your food likes & dislikes',
            onTap: () {
              final analytics = ref.read(appExternalDepsProvider);
              analytics.analytics.track('settings_food_preferences_tapped');
              context.push('/settings/food-preferences');
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          // Help & Feedback
          _buildQuickLink(
            context: context,
            icon: FontAwesomeIcons.circleQuestion,
            title: 'Help & Feedback',
            subtitle: 'Get help and send feedback',
            onTap: () {
              final analytics = ref.read(appExternalDepsProvider);
              analytics.analytics.track('settings_help_tapped');
              context.push('/help');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelector(BuildContext context, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.genderLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        KyleSegmentedControl<Gender>(
          segments: [Gender.male, Gender.female],
          selected: state.gender ?? Gender.male,
          onChanged: (gender) => ref.read(settingsControllerProvider.notifier).updateGender(gender),
        ),
      ],
    );
  }

  Widget _buildBirthdaySelector(BuildContext context, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.birthdayLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        InkWell(
          onTap: () async {
            final selectedDate = await showDatePicker(
              context: context,
              initialDate: state.birthday ?? DateTime.now().subtract(const Duration(days: 365 * 30)),
              firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
              lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
            );
            if (selectedDate != null) {
              ref.read(settingsControllerProvider.notifier).updateBirthday(selectedDate);
            }
          },
          borderRadius: AppRadius.inputRadius,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              ),
              borderRadius: AppRadius.inputRadius,
            ),
            child: Row(
              children: [
                Icon(
                  FontAwesomeIcons.calendar,
                  size: AppIconSizes.controlIcon,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    state.birthday != null
                        ? '${state.birthday!.month}/${state.birthday!.day}/${state.birthday!.year}'
                        : 'Select your birthday',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: state.birthday != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeightSelector(BuildContext context, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.heightLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        Row(
          children: [
            // Feet dropdown
            Expanded(
              child: _buildDropdown<int>(
                context: context,
                value: state.heightFeet,
                hint: 'Feet',
                items: List.generate(6, (index) => index + 3),
                itemBuilder: (feet) => '$feet ft',
                onChanged: (feet) {
                  if (feet != null) {
                    ref.read(settingsControllerProvider.notifier).updateHeight(feet, state.heightInches ?? 0);
                  }
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Inches dropdown
            Expanded(
              child: _buildDropdown<int>(
                context: context,
                value: state.heightInches,
                hint: 'Inches',
                items: List.generate(12, (index) => index),
                itemBuilder: (inches) => '$inches in',
                onChanged: (inches) {
                  if (inches != null) {
                    ref.read(settingsControllerProvider.notifier).updateHeight(state.heightFeet ?? 5, inches);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeightSelector(BuildContext context, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.weightLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        TextFormField(
          initialValue: state.weightPounds?.toString() ?? '',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Enter weight',
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            suffixText: 'lbs',
            suffixStyle: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            border: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: const BorderSide(
                color: AppColors.orange,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
          ),
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onChanged: (value) {
            final weight = double.tryParse(value);
            if (weight != null && weight > 0) {
              ref.read(settingsControllerProvider.notifier).updateWeight(weight);
            }
          },
        ),
      ],
    );
  }

  Widget _buildWaterBottleToggle(BuildContext context, dynamic state) {
    return InkWell(
      onTap: () => ref.read(settingsControllerProvider.notifier).updateWaterBottle(!state.runsWithWaterBottle),
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: state.runsWithWaterBottle
              ? AppColors.blackberry.withOpacity(0.1)
              : Colors.transparent,
          border: Border.all(
            color: state.runsWithWaterBottle
                ? AppColors.blackberry
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            width: state.runsWithWaterBottle ? 2 : 1,
          ),
          borderRadius: AppRadius.cardRadius,
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: state.runsWithWaterBottle
                    ? AppColors.blackberry
                    : Colors.transparent,
                border: Border.all(
                  color: state.runsWithWaterBottle
                      ? AppColors.blackberry
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: state.runsWithWaterBottle
                  ? const Icon(
                      FontAwesomeIcons.check,
                      size: 14,
                      color: AppColors.cream,
                    )
                  : null,
            ),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'I run with a water bottle',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'This helps us estimate your hydration needs',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceUnitSelector(BuildContext context, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.distanceUnitLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        KyleSegmentedControl<DistanceUnit>(
          segments: DistanceUnit.values,
          selected: state.preferredDistanceUnit ?? DistanceUnit.miles,
          onChanged: (unit) => ref.read(settingsControllerProvider.notifier).updateDistanceUnit(unit),
        ),
      ],
    );
  }

  Widget _buildPaceUnitSelector(BuildContext context, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.paceUnitLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        KyleSegmentedControl<PaceUnit>(
          segments: PaceUnit.values,
          selected: state.preferredPaceUnit ?? PaceUnit.minPerMile,
          onChanged: (unit) => ref.read(settingsControllerProvider.notifier).updatePaceUnit(unit),
        ),
      ],
    );
  }

  Widget _buildGutTrainingSelector(BuildContext context, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.gutTrainingLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        KyleGutTrainingSegmentedControl(
          selected: state.gutTrainingLevel ?? GutTraining.moderate,
          onChanged: (level) => ref.read(settingsControllerProvider.notifier).updateGutTraining(level),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required BuildContext context,
    required T? value,
    required String hint,
    required List<T> items,
    required String Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
        ),
        borderRadius: AppRadius.inputRadius,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          isExpanded: true,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemBuilder(item),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          dropdownColor: Theme.of(context).colorScheme.surface,
        ),
      ),
    );
  }

  Widget _buildQuickLink({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppIconSizes.controlIcon,
                color: AppColors.electrolyte,
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              FontAwesomeIcons.chevronRight,
              size: AppIconSizes.controlIcon,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
