import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';

/// Text input field with send button for the chat screen
/// Uses AppColors for consistent theming, adapts to light/dark mode
class ChatInputField extends StatelessWidget {
  const ChatInputField({
    super.key,
    required this.controller,
    required this.isSending,
    required this.onSend,
    this.hintText = 'Type a message...',
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.blackberry : AppColors.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.blackberryLight : AppColors.borderLightSecondary,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text input field
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                enabled: !isSending,
                style: TextStyle(
                  color: isDark ? AppColors.textDark : AppColors.textLight,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    color: isDark
                        ? AppColors.textDarkSecondary.withOpacity(0.5)
                        : AppColors.textLightSecondary.withOpacity(0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.inputBackground
                      : AppColors.surfaceLightSecondary,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) {
                  if (controller.text.trim().isNotEmpty) {
                    onSend();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),

            // Send button
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: isSending
                  ? null
                  : () {
                      if (controller.text.trim().isNotEmpty) {
                        onSend();
                      }
                    },
              icon: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
