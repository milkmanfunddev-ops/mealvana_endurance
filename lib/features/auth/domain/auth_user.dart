/// Custom auth user model to avoid using deprecated Supabase AuthUser
class AuthUser {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final bool isEmailConfirmed;
  final String? createdAt;
  final Map<String, dynamic>? metadata;

  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.isEmailConfirmed = false,
    this.createdAt,
    this.metadata,
  });

  /// Copy with method for updates
  AuthUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    bool? isEmailConfirmed,
    String? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isEmailConfirmed: isEmailConfirmed ?? this.isEmailConfirmed,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ email.hashCode;

  @override
  String toString() {
    return 'AuthUser{id: $id, email: $email, displayName: $displayName}';
  }
}
