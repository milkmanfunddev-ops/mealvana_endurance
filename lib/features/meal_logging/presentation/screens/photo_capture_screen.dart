import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../ai_credits/domain/insufficient_credits_exception.dart';
import '../../../ai_credits/presentation/insufficient_credits_paywall.dart';
import '../../application/meal_ai_service.dart';

/// Screen for selecting or capturing a meal photo.
///
/// Route: `/meal-log/photo`
/// Extras: `{ 'logDate': String }`
class PhotoCaptureScreen extends ConsumerStatefulWidget {
  const PhotoCaptureScreen({super.key});

  @override
  ConsumerState<PhotoCaptureScreen> createState() =>
      _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends ConsumerState<PhotoCaptureScreen> {
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

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
    } catch (_) {
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Could not access the camera or gallery.');
      }
      return;
    }

    if (file == null) return;
    if (!mounted) return;

    setState(() => _isAnalyzing = true);

    try {
      final service = ref.read(mealAiServiceProvider);
      MealPhotoAnalysis analysis;

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        // A dotless filename would make split().last return the whole name,
        // so only trust the extension when a dot is actually present.
        final parts = file.name.split('.');
        final ext = (parts.length > 1 ? parts.last : 'jpg').toLowerCase();
        analysis = await service.analyzePhotoBytes(bytes, extension: ext);
      } else {
        analysis = await service.analyzePhoto(File(file.path));
      }

      if (!mounted) return;
      context.push(
        '/meal-log/review',
        extra: {
          'result': analysis.result,
          'source': 'photo',
          'logDate': _logDate,
          'photoPath': analysis.storagePath,
        },
      );
    } on InsufficientCreditsException catch (e) {
      maybeShowInsufficientCreditsPaywall(e);
    } on MealAiException catch (e) {
      if (!mounted) return;
      switch (e.kind) {
        case MealAiFailureKind.notFood:
          MealvanaSnackbar.showWarning(context, e.userMessage);
          break;
        case MealAiFailureKind.offline:
          MealvanaSnackbar.showError(context, e.userMessage);
          break;
        case MealAiFailureKind.serverError:
          MealvanaSnackbar.showError(context, e.userMessage);
          break;
      }
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
        title: const Text('Photo'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: AppSpacing.screenPaddingHorizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Take or choose a photo of your meal.',
                  style: AppTextStyles.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Jade AI will identify the food and estimate macros.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.cream.withValues(alpha: 0.55)
                        : AppColors.blackberry.withValues(alpha: 0.55),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),

                // Camera option (mobile only)
                if (!kIsWeb) ...[
                  _OptionCard(
                    icon: Icons.camera_alt_outlined,
                    title: 'Take a Photo',
                    subtitle: 'Use your camera',
                    onTap: () => _pickAndAnalyze(ImageSource.camera),
                    disabled: _isAnalyzing,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Gallery option
                _OptionCard(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from Library',
                  subtitle: 'Select an existing photo',
                  onTap: () => _pickAndAnalyze(ImageSource.gallery),
                  disabled: _isAnalyzing,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
          // Loading overlay
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
                      'Analyzing your meal...',
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: Colors.white),
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

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.disabled = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 36,
                color: isDark ? AppColors.electrolyte : AppColors.electrolyteDark,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
