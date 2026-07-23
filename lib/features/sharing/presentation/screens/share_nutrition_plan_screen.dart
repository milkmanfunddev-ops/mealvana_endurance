import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../content/application/content_service.dart';
import '../../../nutrition_plan/domain/nutrition_plan.dart';
import '../providers/share_form_controller.dart';

class ShareNutritionPlanScreen extends ConsumerStatefulWidget {
  const ShareNutritionPlanScreen({super.key, required this.nutritionPlan});

  final NutritionPlan nutritionPlan;

  @override
  ConsumerState<ShareNutritionPlanScreen> createState() =>
      _ShareNutritionPlanScreenState();
}

class _ShareNutritionPlanScreenState
    extends ConsumerState<ShareNutritionPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientEmailController = TextEditingController();
  final _senderNameController = TextEditingController();
  final _subjectController = TextEditingController();
  final _commentsController = TextEditingController();

  @override
  void dispose() {
    _recipientEmailController.dispose();
    _senderNameController.dispose();
    _subjectController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final controller = ref.read(
      shareFormControllerProvider(widget.nutritionPlan).notifier,
    );

    final result = await controller.sendPlan(widget.nutritionPlan);

    if (!mounted) return;

    if (result.success) {
      final content = ref.read(contentServiceProvider);
      final successMessage = content.getValue(
        'sharing.success_message',
        defaultValue: 'Nutrition plan sent successfully!',
      );

      MealvanaSnackbar.showSuccess(context, successMessage);

      context.pop();
    } else {
      final content = ref.read(contentServiceProvider);
      final errorMessage = content.getValue(
        'sharing.error_message',
        defaultValue: 'Failed to send nutrition plan. Please try again.',
      );

      MealvanaSnackbar.showError(context, result.error ?? errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentServiceProvider);
    final controllerState = ref.watch(
      shareFormControllerProvider(widget.nutritionPlan),
    );

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: CustomAppBarBackButton(onPressed: () => context.pop()),
        title: Text(
          content.getValue(
            'sharing.screen_title',
            defaultValue: 'Share Nutrition Plan',
          ),
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 18.sp,
          ),
        ),
      ),
      body: controllerState.when(
        data: (state) {
          if (_senderNameController.text.isEmpty &&
              state.senderName.isNotEmpty) {
            _senderNameController.text = state.senderName;
          }
          if (_subjectController.text.isEmpty && state.subject.isNotEmpty) {
            _subjectController.text = state.subject;
          }
          if (_commentsController.text.isEmpty && state.comments.isNotEmpty) {
            _commentsController.text = state.comments;
          }

          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.getValue(
                        'sharing.recipient_email_label',
                        defaultValue: 'Recipient Email',
                      ),
                      style: AppTheme.textStyle.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary900,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: _recipientEmailController,
                      keyboardType: TextInputType.emailAddress,
                      style: AppTheme.textStyle.copyWith(
                        fontSize: 16.sp,
                        color: AppTheme.primary900,
                      ),
                      decoration: InputDecoration(
                        hintText: content.getValue(
                          'sharing.recipient_email_hint',
                          defaultValue: 'coach@example.com',
                        ),
                        hintStyle: AppTheme.textStyle.copyWith(
                          fontSize: 16.sp,
                          color: AppTheme.baseGrey,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppTheme.baseGrey.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppTheme.baseGrey.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppTheme.primary600,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 16.h,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return content.getValue(
                            'sharing.recipient_email_required',
                            defaultValue: 'Email address is required',
                          );
                        }
                        final controller = ref.read(
                          shareFormControllerProvider(
                            widget.nutritionPlan,
                          ).notifier,
                        );
                        if (!controller.isValidEmail(value)) {
                          return content.getValue(
                            'sharing.recipient_email_invalid',
                            defaultValue: 'Please enter a valid email address',
                          );
                        }
                        return null;
                      },
                      onChanged: (value) {
                        ref
                            .read(
                              shareFormControllerProvider(
                                widget.nutritionPlan,
                              ).notifier,
                            )
                            .updateRecipientEmail(value);
                      },
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      content.getValue(
                        'sharing.sender_name_label',
                        defaultValue: 'Your Name',
                      ),
                      style: AppTheme.textStyle.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary900,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: _senderNameController,
                      style: AppTheme.textStyle.copyWith(
                        fontSize: 16.sp,
                        color: AppTheme.primary900,
                      ),
                      decoration: InputDecoration(
                        hintText: content.getValue(
                          'sharing.sender_name_hint',
                          defaultValue: 'Optional',
                        ),
                        hintStyle: AppTheme.textStyle.copyWith(
                          fontSize: 16.sp,
                          color: AppTheme.baseGrey,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppTheme.baseGrey.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppTheme.baseGrey.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppTheme.primary600,
                            width: 2,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 16.h,
                        ),
                      ),
                      onChanged: (value) {
                        ref
                            .read(
                              shareFormControllerProvider(
                                widget.nutritionPlan,
                              ).notifier,
                            )
                            .updateSenderName(value);
                      },
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      content.getValue(
                        'sharing.subject_label',
                        defaultValue: 'Subject',
                      ),
                      style: AppTheme.textStyle.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary900,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: _subjectController,
                      style: AppTheme.textStyle.copyWith(
                        fontSize: 16.sp,
                        color: AppTheme.primary900,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppTheme.baseGrey.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppTheme.baseGrey.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppTheme.primary600,
                            width: 2,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 16.h,
                        ),
                      ),
                      onChanged: (value) {
                        ref
                            .read(
                              shareFormControllerProvider(
                                widget.nutritionPlan,
                              ).notifier,
                            )
                            .updateSubject(value);
                      },
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      content.getValue(
                        'sharing.comments_label',
                        defaultValue: 'Additional Comments',
                      ),
                      style: AppTheme.textStyle.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary900,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: _commentsController,
                      maxLines: 4,
                      style: AppTheme.textStyle.copyWith(
                        fontSize: 16.sp,
                        color: AppTheme.primary900,
                      ),
                      decoration: InputDecoration(
                        hintText: content.getValue(
                          'sharing.comments_hint',
                          defaultValue:
                              'Optional message to include with your plan',
                        ),
                        hintStyle: AppTheme.textStyle.copyWith(
                          fontSize: 16.sp,
                          color: AppTheme.baseGrey,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppTheme.baseGrey.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppTheme.baseGrey.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppTheme.primary600,
                            width: 2,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 16.h,
                        ),
                      ),
                      onChanged: (value) {
                        ref
                            .read(
                              shareFormControllerProvider(
                                widget.nutritionPlan,
                              ).notifier,
                            )
                            .updateComments(value);
                      },
                    ),
                    SizedBox(height: 32.h),
                    Center(
                      child: PrimaryButton(
                        text: state.isSending
                            ? content.getValue(
                                'sharing.sending_button',
                                defaultValue: 'Sending...',
                              )
                            : content.getValue(
                                'sharing.send_button',
                                defaultValue: 'Send',
                              ),
                        onPressed: state.isSending ? null : _handleSend,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
