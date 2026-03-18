import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/inputs/kyle_switch.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../application/coach_service.dart';
import '../providers/athlete_detail_controller.dart';

/// Editable profile form for coach to update athlete's profile
class PortalAthleteProfileForm extends ConsumerStatefulWidget {
  final String relationshipId;
  final UserProfile? profile;
  final String athleteUserId;

  const PortalAthleteProfileForm({
    super.key,
    required this.relationshipId,
    required this.profile,
    required this.athleteUserId,
  });

  @override
  ConsumerState<PortalAthleteProfileForm> createState() =>
      _PortalAthleteProfileFormState();
}

class _PortalAthleteProfileFormState
    extends ConsumerState<PortalAthleteProfileForm> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _weightController;
  late TextEditingController _heightFeetController;
  late TextEditingController _heightInchesController;

  DateTime? _birthday;
  String _gender = 'male';
  String _gutTraining = 'moderate';
  bool _runsWithWaterBottle = false;
  bool? _giSensitivity;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _firstNameController = TextEditingController(text: p?.firstName ?? '');
    _lastNameController = TextEditingController(text: p?.lastName ?? '');
    _weightController = TextEditingController(
      text: p != null ? p.weightPounds.toStringAsFixed(1) : '',
    );
    _heightFeetController = TextEditingController(
      text: p != null ? '${p.heightFeet}' : '',
    );
    _heightInchesController = TextEditingController(
      text: p != null ? '${p.heightInches}' : '',
    );
    _birthday = p?.birthday;
    _gender = p?.gender.name ?? 'male';
    _gutTraining = p?.gutTraining.name ?? 'moderate';
    _runsWithWaterBottle = p?.runsWithWaterBottle ?? false;
    _giSensitivity = p?.giSensitivity;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _weightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final weight = double.tryParse(_weightController.text);
      final heightFeet = int.tryParse(_heightFeetController.text);
      final heightInches = int.tryParse(_heightInchesController.text);

      await ref
          .read(coachServiceProvider)
          .updateAthleteProfile(
            athleteUserId: widget.athleteUserId,
            firstName: _firstNameController.text.trim().isNotEmpty
                ? _firstNameController.text.trim()
                : null,
            lastName: _lastNameController.text.trim().isNotEmpty
                ? _lastNameController.text.trim()
                : null,
            birthday: _birthday,
            weightPounds: weight,
            heightFeet: heightFeet,
            heightInches: heightInches,
            runsWithWaterBottle: _runsWithWaterBottle,
            gutTraining: _gutTraining,
            gender: _gender,
            giSensitivity: _giSensitivity,
          );

      if (mounted) {
        MealvanaSnackbar.showSuccess(context, 'Profile updated successfully');
        // Refresh athlete detail data
        ref
            .read(
              athleteDetailControllerProvider(widget.relationshipId).notifier,
            )
            .refresh();
      }
    } catch (e) {
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Failed to save: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Personal Information
        _buildSectionCard('Personal Information', Icons.person, [
          _buildTextField('First Name', _firstNameController),
          _buildTextField('Last Name', _lastNameController),
          _buildGenderDropdown(),
          _buildBirthdayPicker(),
          _buildTextField(
            'Height (ft)',
            _heightFeetController,
            keyboardType: TextInputType.number,
          ),
          _buildTextField(
            'Height (in)',
            _heightInchesController,
            keyboardType: TextInputType.number,
          ),
          _buildTextField(
            'Weight (lbs)',
            _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ]),
        const SizedBox(height: 16),

        // Training Preferences
        _buildSectionCard('Training Preferences', Icons.fitness_center, [
          _buildSwitchRow('Runs with Water Bottle', _runsWithWaterBottle, (
            val,
          ) {
            setState(() => _runsWithWaterBottle = val);
          }),
          _buildGutTrainingDropdown(),
          _buildGiSensitivityDropdown(),
        ]),
        const SizedBox(height: 24),

        // Save button
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.electrolyte,
                foregroundColor: AppColors.blackberryDark,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.blackberryDark,
                      ),
                    )
                  : const Text(
                      'Save Profile',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blackberry,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blackberryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.electrolyte, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cream,
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.blackberryLight, height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textDarkSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(color: AppColors.cream, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                filled: true,
                fillColor: AppColors.blackberryDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.blackberryLight,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.blackberryLight,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.electrolyte),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return _buildDropdownRow('Gender', _gender, [
      'male',
      'female',
      'other',
    ], (val) => setState(() => _gender = val!));
  }

  Widget _buildGutTrainingDropdown() {
    return _buildDropdownRow('Gut Training', _gutTraining, [
      'low',
      'moderate',
      'high',
    ], (val) => setState(() => _gutTraining = val!));
  }

  Widget _buildGiSensitivityDropdown() {
    final value = _giSensitivity == null
        ? 'unknown'
        : _giSensitivity!
        ? 'yes'
        : 'no';

    return _buildDropdownRow(
      'GI Sensitivity',
      value,
      ['unknown', 'yes', 'no'],
      (val) {
        setState(() {
          if (val == 'unknown') {
            _giSensitivity = null;
          } else {
            _giSensitivity = val == 'yes';
          }
        });
      },
    );
  }

  Widget _buildDropdownRow(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textDarkSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.blackberryDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.blackberryLight),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  isExpanded: true,
                  dropdownColor: AppColors.blackberry,
                  style: const TextStyle(color: AppColors.cream, fontSize: 13),
                  items: options
                      .map(
                        (o) => DropdownMenuItem(
                          value: o,
                          child: Text(o[0].toUpperCase() + o.substring(1)),
                        ),
                      )
                      .toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.blackberryDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.blackberryLight),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDarkSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            KyleSwitch(
              value: value,
              activeTrackColor: AppColors.electrolyte,
              inactiveTrackColor: AppColors.blackberryLight,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBirthdayPicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 140,
            child: Text(
              'Birthday',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textDarkSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _birthday ?? DateTime(1990, 1, 1),
                  firstDate: DateTime(1930),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: AppColors.electrolyte,
                          surface: AppColors.blackberry,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() => _birthday = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blackberryDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.blackberryLight),
                ),
                child: Text(
                  _birthday != null
                      ? '${_birthday!.month}/${_birthday!.day}/${_birthday!.year}'
                      : 'Tap to set',
                  style: TextStyle(
                    color: _birthday != null
                        ? AppColors.cream
                        : AppColors.textDarkSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
