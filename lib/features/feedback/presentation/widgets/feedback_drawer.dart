import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/feedback_data.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/custom_close_button.dart';
import 'emoji_slider.dart';
import 'app_feedback_options.dart';

/// Feedback drawer matching Alex's design with yellow background
class FeedbackDrawer extends StatefulWidget {
  const FeedbackDrawer({
    super.key,
    required this.onSubmitFeedback,
    this.planName,
    this.isVisible = false,
    this.onClose,
  });

  final Function(FeedbackResponse) onSubmitFeedback;
  final String? planName;
  final bool isVisible;
  final VoidCallback? onClose;

  @override
  State<FeedbackDrawer> createState() => _FeedbackDrawerState();
}

class _FeedbackDrawerState extends State<FeedbackDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  
  SatisfactionLevel _selectedLevel = SatisfactionLevel.justRight;
  AppFeedbackOption? _selectedAppFeedback;
  final TextEditingController _suggestionsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    
    if (widget.isVisible) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(FeedbackDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _suggestionsController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    if (_isSubmitting) return;
    
    setState(() {
      _isSubmitting = true;
    });

    final feedback = FeedbackResponse(
      satisfactionLevel: _selectedLevel,
      appFeedback: _selectedAppFeedback,
      suggestions: _suggestionsController.text.isNotEmpty ? _suggestionsController.text : null,
      planName: widget.planName,
      timestamp: DateTime.now(),
    );

    try {
      await widget.onSubmitFeedback(feedback);
      _handleClose();
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _handleClose() {
    widget.onClose?.call();
    _controller.reverse().then((_) {
      if (mounted) {
        setState(() {
          _selectedLevel = SatisfactionLevel.justRight;
          _selectedAppFeedback = null;
          _suggestionsController.clear();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Backdrop
            if (_slideAnimation.value > 0)
              GestureDetector(
                onTap: _handleClose,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5 * _slideAnimation.value),
                ),
              ),
            
            // Drawer
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Transform.translate(
                offset: Offset(0, (1 - _slideAnimation.value) * 600.h),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  decoration: BoxDecoration(
                    color: AppTheme.warning500, // Yellow background
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24.r),
                      topRight: Radius.circular(24.r),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with title and close button (at very top)
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Like our plan?',
                              style: AppTheme.titleStyle.copyWith(
                                color: AppTheme.highlight490, // Darker color
                                fontSize: 28.sp,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Sansita',
                              ),
                            ),
                            CustomCloseButton(onTap: _handleClose),
                          ],
                        ),
                      ),
                      
                      // Main content with SafeArea and padding - Scrollable
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.w), // Minimal top padding
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Leave us feedback so we know how we\'re doing',
                                style: AppTheme.textStyle.copyWith(
                                  color: AppTheme.baseBlack,
                                  fontSize: 14.sp,
                                ),
                              ),
                              
                              SizedBox(height: 24.h),
                              
                              // Question
                              Text(
                                'What do you think about this plan?',
                                style: AppTheme.textStyle.copyWith(
                                  color: AppTheme.primary900,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              
                              SizedBox(height: 12.h),
                              
                              // Emoji Slider
                              EmojiSlider(
                                selectedLevel: _selectedLevel,
                                onChanged: (SatisfactionLevel level) {
                                  setState(() {
                                    _selectedLevel = level;
                                  });
                                },
                              ),
                              
                              SizedBox(height: 16.h),
                              
                              // App feedback question
                              Text(
                                'What do you think about this tiny app?',
                                style: AppTheme.textStyle.copyWith(
                                  color: AppTheme.primary900,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              
                              SizedBox(height: 8.h),
                              
                              // App feedback options component
                              AppFeedbackOptions(
                                selectedOption: _selectedAppFeedback,
                                onOptionChanged: (AppFeedbackOption option) {
                                  setState(() {
                                    _selectedAppFeedback = option;
                                  });
                                },
                                suggestionsController: _suggestionsController,
                              ),
                              
                              SizedBox(height: 20.h),
                              
                              // Submit button
                              Center(
                                child: PrimaryButton(
                                  text: 'Submit',
                                  onPressed: _handleSubmit,
                                  isLoading: _isSubmitting,
                                  width: 160.w,
                                ),
                              ),
                              
                              SizedBox(height: 20.h), // Bottom padding for scroll
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
} 