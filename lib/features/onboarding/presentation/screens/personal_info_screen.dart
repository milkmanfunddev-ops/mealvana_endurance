import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/birth_year_picker.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../auth/domain/user_preferences.dart';
import '../providers/onboarding_controller.dart';
import '../widgets/onboarding_step_scaffold.dart';

/// Personal Info Screen - Step 5 of Onboarding (2026-08 redesign)
///
/// Names/email are optional (grouped under the "PERSONAL INFORMATION ·
/// optional" card); gender + birth year gate Continue — they're the inputs
/// the RMR formula needs. Every change is mirrored into the controller draft
/// immediately, so Continue is pure navigation.
///
/// NOTE: unlike the old user_profile_screen, email is NOT auto-filled from
/// Supabase auth here — saveAllOnboardingData resolves the auth email at
/// save time when the draft has none.
class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({
    super.key,
    this.onContinue,
    this.onBack,
    this.stepIndex,
  });

  /// Callback to advance to next page (optional for PageView mode)
  final VoidCallback? onContinue;

  /// Callback to go back to previous page (optional for PageView mode)
  final VoidCallback? onBack;

  /// Position in the onboarding flow, stamped onto `screen_viewed` so the
  /// drop-off funnel can order the steps. Null outside onboarding.
  final int? stepIndex;

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;

  Gender? _gender;
  int? _birthYear;

  OnboardingController get _controller =>
      ref.read(onboardingControllerProvider.notifier);

  @override
  void initState() {
    super.initState();

    // Seeded from the draft so revisiting the step restores prior answers.
    final draft = _controller.draft;
    _firstNameController = TextEditingController(text: draft.firstName ?? '');
    _lastNameController = TextEditingController(text: draft.lastName ?? '');
    _emailController = TextEditingController(text: draft.email ?? '');
    _gender = draft.gender;
    _birthYear = draft.birthYear;

    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'screen_viewed',
          properties: {
            'screen_name': 'Personal Info Onboarding',
            if (widget.stepIndex != null) 'step_index': widget.stepIndex,
          },
        );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool get _canContinue => _gender != null && _birthYear != null;

  void _selectGender(Gender gender) {
    setState(() => _gender = gender);
    _controller.updatePersonalInfo(gender: gender);
  }

  Future<void> _selectBirthYear() async {
    FocusScope.of(context).unfocus();
    // Reuses the shared bottom-sheet wheel (same widget the old
    // user_profile_screen used). Known Android Patrol quirk carried over:
    // the Cupertino wheel doesn't respond to Patrol scroll gestures on
    // Android, so integration tests tap Done with the pre-selected year
    // rather than scrolling. Sheet keys remain 'profile.birth_year_*'.
    final year = await showBirthYearPicker(
      context: context,
      initialYear: _birthYear,
    );
    if (year != null) {
      setState(() => _birthYear = year);
      _controller.updatePersonalInfo(birthYear: year);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: 'Tell us about yourself',
      subtitle: 'Age and gender help us determine the best fueling strategy.',
      titleKey: const ValueKey('personal_info.title'),
      stepIndex: widget.stepIndex,
      canContinue: _canContinue,
      onContinue: () {
        FocusScope.of(context).unfocus();
        widget.onContinue?.call();
      },
      onBack: widget.onBack,
      continueButtonKey: const ValueKey('personal_info.continue_button'),
      backButtonKey: const ValueKey('personal_info.back_button'),
      children: [
        _buildOptionalInfoCard(),
        const SizedBox(height: 20),
        _buildGenderSelector(),
        const SizedBox(height: 20),
        _buildBirthYearSelector(),
      ],
    );
  }

  Widget _buildOptionalInfoCard() {
    return Container(
      decoration: onboardingCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PERSONAL INFORMATION · optional',
            style: kOnboardingSectionLabelStyle,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _darkTextField(
                  fieldKey: const ValueKey('personal_info.first_name_field'),
                  controller: _firstNameController,
                  hint: 'First name',
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) =>
                      _controller.updatePersonalInfo(firstName: value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _darkTextField(
                  fieldKey: const ValueKey('personal_info.last_name_field'),
                  controller: _lastNameController,
                  hint: 'Last name',
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) =>
                      _controller.updatePersonalInfo(lastName: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _darkTextField(
            fieldKey: const ValueKey('personal_info.email_field'),
            controller: _emailController,
            hint: 'Email address',
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            onChanged: (value) => _controller.updatePersonalInfo(email: value),
          ),
        ],
      ),
    );
  }

  Widget _darkTextField({
    required Key fieldKey,
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool autocorrect = true,
    Iterable<String>? autofillHints,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      autofillHints: autofillHints,
      onChanged: onChanged,
      cursorColor: AppColors.orange,
      style: const TextStyle(
        fontFamily: 'Apercu',
        fontSize: 15,
        color: AppColors.textDark,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'Apercu',
          fontSize: 15,
          color: AppColors.textDark.withValues(alpha: 0.4),
        ),
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.orange, width: 2),
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('GENDER', style: kOnboardingSectionLabelStyle),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _GenderCard(
                cardKey: const ValueKey('personal_info.gender_male'),
                gender: Gender.male,
                icon: FontAwesomeIcons.mars.data,
                isSelected: _gender == Gender.male,
                onTap: _selectGender,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GenderCard(
                cardKey: const ValueKey('personal_info.gender_female'),
                gender: Gender.female,
                icon: FontAwesomeIcons.venus.data,
                isSelected: _gender == Gender.female,
                onTap: _selectGender,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GenderCard(
                cardKey: const ValueKey('personal_info.gender_non_binary'),
                gender: Gender.other,
                icon: FontAwesomeIcons.genderless.data,
                isSelected: _gender == Gender.other,
                onTap: _selectGender,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBirthYearSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('BIRTH YEAR', style: kOnboardingSectionLabelStyle),
        const SizedBox(height: 8),
        InkWell(
          key: const ValueKey('personal_info.birth_year_button'),
          onTap: _selectBirthYear,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.calendar,
                  size: 16,
                  color: AppColors.textDark.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _birthYear != null
                        ? '$_birthYear'
                        : 'Select your birth year',
                    style: TextStyle(
                      fontFamily: 'Apercu',
                      fontSize: 15,
                      color: _birthYear != null
                          ? AppColors.textDark
                          : AppColors.textDark.withValues(alpha: 0.4),
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
}

/// One of the three tappable gender cards (dark-scaffold styling adapted
/// from the old user_profile_screen radio options).
class _GenderCard extends StatelessWidget {
  const _GenderCard({
    required this.cardKey,
    required this.gender,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final Key cardKey;
  final Gender gender;
  final IconData icon;
  final bool isSelected;
  final ValueChanged<Gender> onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected
        ? AppColors.blackberry
        : AppColors.cream.withValues(alpha: 0.6);

    return GestureDetector(
      key: cardKey,
      onTap: () => onTap(gender),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cream : Colors.transparent,
          border: Border.all(color: AppColors.cream, width: 2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: foreground),
            const SizedBox(height: 6),
            Text(
              // Gender.other renders "Non-binary" per its displayName.
              gender.displayName.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Apercu',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
