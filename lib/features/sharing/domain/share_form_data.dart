class ShareFormData {
  const ShareFormData({
    required this.recipientEmail,
    this.senderName,
    this.subject,
    this.comments,
  });

  final String recipientEmail;
  final String? senderName;
  final String? subject;
  final String? comments;

  ShareFormData copyWith({
    String? recipientEmail,
    String? senderName,
    String? subject,
    String? comments,
  }) {
    return ShareFormData(
      recipientEmail: recipientEmail ?? this.recipientEmail,
      senderName: senderName ?? this.senderName,
      subject: subject ?? this.subject,
      comments: comments ?? this.comments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recipientEmail': recipientEmail,
      if (senderName != null) 'senderName': senderName,
      if (subject != null) 'subject': subject,
      if (comments != null) 'comments': comments,
    };
  }

  factory ShareFormData.fromJson(Map<String, dynamic> json) {
    return ShareFormData(
      recipientEmail: json['recipientEmail'] as String,
      senderName: json['senderName'] as String?,
      subject: json['subject'] as String?,
      comments: json['comments'] as String?,
    );
  }
}
