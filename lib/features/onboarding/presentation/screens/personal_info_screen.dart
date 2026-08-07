import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/services/app_external_deps.dart';
import '../../../auth/domain/user_preferences.dart';
import '../providers/onboarding_controller.dart';
import '../theme/onboarding_design_tokens.dart';
import '../widgets/onboarding_step_scaffold.dart';

/// Personal Info Screen - Step 5 of Onboarding — HTML-spec pixel port.
///
/// Names/email are optional (grouped under the "PERSONAL INFORMATION ·
/// optional" card); gender gates Continue (the spec's dimmed-CTA state).
/// Birth year is an inline wheel that always carries a value (spec default
/// 1994), written to the draft on mount and on scroll. Every change is
/// mirrored into the controller draft immediately, so Continue is pure
/// navigation.
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
  late final FixedExtentScrollController _yearController;

  /// Spec wheel: default-centered year when the athlete hasn't chosen one.
  static const int _defaultYear = 1994;
  static const int _minYear = 1930;
  static const int _maxYear = 2012;

  Gender? _gender;
  late int _birthYear;

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
    _birthYear = draft.birthYear ?? _defaultYear;
    _yearController = FixedExtentScrollController(
      initialItem: _birthYear - _minYear,
    );
    // The wheel always shows a year, so the draft carries it from first
    // render (spec behavior: only gender gates Continue).
    if (draft.birthYear == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.updatePersonalInfo(birthYear: _birthYear);
      });
    }

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
    _yearController.dispose();
    super.dispose();
  }

  bool get _canContinue => _gender != null;

  void _selectGender(Gender gender) {
    setState(() => _gender = gender);
    _controller.updatePersonalInfo(gender: gender);
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
      // Spec card: radius 20, cream-5% fill, 1px cream-12% border,
      // padding 15/16/17.
      decoration: BoxDecoration(
        color: OnbTokens.creamA(0.05),
        borderRadius: BorderRadius.circular(OnbTokens.rLarge),
        border: Border.all(color: OnbTokens.creamA(0.12)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Spec label row: Apercu 16/500 ls 2.08 uppercase cream, with the
          // '· optional' aside at 12px cream-45%.
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'PERSONAL INFORMATION',
                  style: TextStyle(
                    fontFamily: OnbTokens.fontBody,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.08,
                    color: OnbTokens.cream,
                  ),
                ),
                TextSpan(
                  text: '  · optional',
                  style: TextStyle(
                    fontFamily: OnbTokens.fontBody,
                    fontSize: 12,
                    color: OnbTokens.creamA(0.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _darkTextField(
                  fieldKey: const ValueKey('personal_info.first_name_field'),
                  controller: _firstNameController,
                  hint: 'First name',
                  icon: Icons.person_outline,
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
            icon: Icons.mail_outline,
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
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool autocorrect = true,
    Iterable<String>? autofillHints,
  }) {
    // Spec input: radius 14, cream-4% fill, 1px cream-30% border,
    // padding 11/12, Apercu 15 cream text, dim leading glyph.
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      autofillHints: autofillHints,
      onChanged: onChanged,
      cursorColor: OnbTokens.orange,
      style: const TextStyle(
        fontFamily: OnbTokens.fontBody,
        fontSize: 15,
        color: OnbTokens.cream,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: OnbTokens.fontBody,
          fontSize: 15,
          color: OnbTokens.creamA(0.35),
        ),
        prefixIcon: icon != null
            ? Icon(icon, size: 16, color: OnbTokens.creamA(0.45))
            : null,
        prefixIconConstraints: icon != null
            ? const BoxConstraints(minWidth: 34, minHeight: 16)
            : null,
        isDense: true,
        filled: true,
        fillColor: OnbTokens.creamA(0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OnbTokens.rTile),
          borderSide: BorderSide(color: OnbTokens.creamA(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OnbTokens.rTile),
          borderSide: const BorderSide(color: OnbTokens.orange),
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Spec: 'Gender' Apercu 15/700 cream (sentence case).
        const Text(
          'Gender',
          style: TextStyle(
            fontFamily: OnbTokens.fontBody,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: OnbTokens.cream,
          ),
        ),
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
            const SizedBox(width: 11),
            Expanded(
              child: _GenderCard(
                cardKey: const ValueKey('personal_info.gender_female'),
                gender: Gender.female,
                icon: FontAwesomeIcons.venus.data,
                isSelected: _gender == Gender.female,
                onTap: _selectGender,
              ),
            ),
            const SizedBox(width: 11),
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
        // Spec: 'Birth year' Apercu 13/500 cream.
        const Text(
          'Birth year',
          style: TextStyle(
            fontFamily: OnbTokens.fontBody,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: OnbTokens.cream,
          ),
        ),
        const SizedBox(height: 4),
        // Spec inline wheel: center year Sansita 27/700 cream between two
        // 1px orange-40% hairlines; neighbors Apercu 21 cream-40%. The wheel
        // always has a value, so no tap-to-open sheet exists any more.
        SizedBox(
          key: const ValueKey('personal_info.birth_year_button'),
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ListWheelScrollView.useDelegate(
                controller: _yearController,
                itemExtent: 44,
                physics: const FixedExtentScrollPhysics(),
                diameterRatio: 8,
                onSelectedItemChanged: (index) {
                  setState(() => _birthYear = _minYear + index);
                  _controller.updatePersonalInfo(birthYear: _birthYear);
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: _maxYear - _minYear + 1,
                  builder: (context, index) {
                    final year = _minYear + index;
                    final selected = year == _birthYear;
                    return Center(
                      child: Text(
                        '$year',
                        style: selected
                            ? const TextStyle(
                                fontFamily: OnbTokens.fontDisplay,
                                fontSize: 27,
                                fontWeight: FontWeight.w700,
                                color: OnbTokens.cream,
                              )
                            : TextStyle(
                                fontFamily: OnbTokens.fontBody,
                                fontSize: 21,
                                color: OnbTokens.creamA(0.4),
                              ),
                      ),
                    );
                  },
                ),
              ),
              // Hairlines framing the selected row (spec: 1px orange-40%,
              // inset from the edges).
              IgnorePointer(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 22),
                      color: OnbTokens.orange40,
                    ),
                    const SizedBox(height: 43),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 22),
                      color: OnbTokens.orange40,
                    ),
                  ],
                ),
              ),
            ],
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
    // Spec card: radius 14, transparent fill, 1px cream-55% border,
    // padding 12/6, h76.5; label Apercu 11/700 ls .66 cream-50%. Selected
    // fills cream with plum content (per the rendered prototype).
    final foreground = isSelected ? OnbTokens.bg : OnbTokens.creamA(0.5);

    return GestureDetector(
      key: cardKey,
      onTap: () => onTap(gender),
      child: Container(
        height: 76.5,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? OnbTokens.cream : Colors.transparent,
          border: Border.all(color: OnbTokens.creamA(0.55)),
          borderRadius: BorderRadius.circular(OnbTokens.rTile),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: foreground),
            const SizedBox(height: 7),
            Text(
              // Gender.other renders "Non-binary" per its displayName.
              gender.displayName.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontFamily: OnbTokens.fontBody,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.66,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
