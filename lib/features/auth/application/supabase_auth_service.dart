import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser, AuthException;
import '../../../services/supabase_service.dart';
import '../domain/auth_user.dart';
import '../domain/auth_exception.dart';

/// Supabase authentication service
class SupabaseAuthService {
  final SupabaseService _supabaseService;

  SupabaseAuthService(this._supabaseService);

  /// Get current authenticated user
  AuthUser? get currentUser {
    final user = _supabaseService.currentUser;
    if (user == null) return null;
    
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
      isEmailConfirmed: user.emailConfirmedAt != null,
      createdAt: user.createdAt,
      metadata: user.userMetadata,
    );
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _supabaseService.isAuthenticated;

  /// Get current session
  Session? get currentSession => _supabaseService.currentSession;

  /// Sign up with email and password
  Future<AuthUser> signUp({
    required String email,
    required String password,
    String? displayName,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final userData = <String, dynamic>{
        if (displayName != null) 'display_name': displayName,
        ...?additionalData,
      };

      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        data: userData.isNotEmpty ? userData : null,
      );

      if (response.user == null) {
        throw AuthException('Failed to create user account');
      }

      return AuthUser(
        id: response.user!.id,
        email: response.user!.email ?? email,
        displayName: displayName,
        isEmailConfirmed: response.user!.emailConfirmedAt != null,
        createdAt: response.user!.createdAt,
        metadata: response.user!.userMetadata,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Sign up failed: ${e.toString()}');
    }
  }

  /// Sign in with email and password
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw AuthException('Failed to sign in');
      }

      return AuthUser(
        id: response.user!.id,
        email: response.user!.email ?? email,
        displayName: response.user!.userMetadata?['display_name'] as String?,
        avatarUrl: response.user!.userMetadata?['avatar_url'] as String?,
        isEmailConfirmed: response.user!.emailConfirmedAt != null,
        createdAt: response.user!.createdAt,
        metadata: response.user!.userMetadata,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Sign in failed: ${e.toString()}');
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _supabaseService.signOut();
    } catch (e) {
      throw AuthException('Sign out failed: ${e.toString()}');
    }
  }

  /// Send password reset email
  Future<void> resetPassword({required String email}) async {
    try {
      await _supabaseService.resetPassword(email: email);
    } catch (e) {
      throw AuthException('Password reset failed: ${e.toString()}');
    }
  }

  /// Update user profile
  Future<AuthUser> updateProfile({
    String? displayName,
    String? avatarUrl,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final updateData = <String, dynamic>{
        if (displayName != null) 'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        ...?additionalData,
      };

      if (updateData.isEmpty) {
        throw AuthException('No data provided for update');
      }

      final response = await _supabaseService.updateUser(data: updateData);

      if (response.user == null) {
        throw AuthException('Failed to update user profile');
      }

      return AuthUser(
        id: response.user!.id,
        email: response.user!.email ?? '',
        displayName: response.user!.userMetadata?['display_name'] as String?,
        avatarUrl: response.user!.userMetadata?['avatar_url'] as String?,
        isEmailConfirmed: response.user!.emailConfirmedAt != null,
        createdAt: response.user!.createdAt,
        metadata: response.user!.userMetadata,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Profile update failed: ${e.toString()}');
    }
  }

  /// Update user email
  Future<void> updateEmail({required String newEmail}) async {
    try {
      await _supabaseService.updateUser(email: newEmail);
    } catch (e) {
      throw AuthException('Email update failed: ${e.toString()}');
    }
  }

  /// Update user password
  Future<void> updatePassword({required String newPassword}) async {
    try {
      await _supabaseService.updateUser(password: newPassword);
    } catch (e) {
      throw AuthException('Password update failed: ${e.toString()}');
    }
  }

  /// Listen to authentication state changes
  Stream<AuthUser?> get authStateChanges {
    return _supabaseService.authStateChanges.map((authState) {
      final user = authState.session?.user;
      if (user == null) return null;

      return AuthUser(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['display_name'] as String?,
        avatarUrl: user.userMetadata?['avatar_url'] as String?,
        isEmailConfirmed: user.emailConfirmedAt != null,
        createdAt: user.createdAt,
        metadata: user.userMetadata,
      );
    });
  }
}

/// Provider for Supabase auth service
final supabaseAuthServiceProvider = Provider<SupabaseAuthService>((ref) {
  return SupabaseAuthService(SupabaseService.instance);
});

/// Provider for current auth user
final currentUserProvider = StreamProvider<AuthUser?>((ref) {
  final authService = ref.watch(supabaseAuthServiceProvider);
  return authService.authStateChanges;
});

/// Provider for authentication state
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authAsync = ref.watch(currentUserProvider);
  return authAsync.when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, __) => false,
  );
});