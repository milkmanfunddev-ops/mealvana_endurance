import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';

/// Text input field with send button for the chat screen
/// Uses AppColors for consistent theming
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
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: AppColors.blackberry,
        border: Border(
          top: BorderSide(
            color: AppColors.blackberryLight,
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
                style: const TextStyle(color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    color: AppColors.textDarkSecondary.withOpacity(0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.inputBackground,
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
