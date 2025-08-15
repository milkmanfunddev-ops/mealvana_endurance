import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase service for database operations and authentication
class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();
  SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;
  
  /// Initialize Supabase with your project URL and anon key
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  /// Get current user
  User? get currentUser => client.auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Get current session
  Session? get currentSession => client.auth.currentSession;

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Reset password
  Future<void> resetPassword({required String email}) async {
    await client.auth.resetPasswordForEmail(email);
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  /// Update user data
  Future<UserResponse> updateUser({
    String? email,
    String? password,
    Map<String, dynamic>? data,
  }) async {
    return await client.auth.updateUser(
      UserAttributes(
        email: email,
        password: password,
        data: data,
      ),
    );
  }

  /// Database operations
  
  /// Get data from a table
  SupabaseQueryBuilder from(String table) {
    return client.from(table);
  }

  /// Insert data into a table
  Future<List<Map<String, dynamic>>> insert({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    final response = await client.from(table).insert(data).select();
    return response;
  }

  /// Update data in a table
  Future<List<Map<String, dynamic>>> update({
    required String table,
    required Map<String, dynamic> data,
    required String column,
    required dynamic value,
  }) async {
    final response = await client
        .from(table)
        .update(data)
        .eq(column, value)
        .select();
    return response;
  }

  /// Delete data from a table
  Future<void> delete({
    required String table,
    required String column,
    required dynamic value,
  }) async {
    await client.from(table).delete().eq(column, value);
  }

  /// Upload file to storage
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required List<int> fileBytes,
    String? contentType,
  }) async {
    await client.storage.from(bucket).uploadBinary(
      path,
      Uint8List.fromList(fileBytes),
      fileOptions: FileOptions(
        contentType: contentType,
      ),
    );
    
    // Return public URL
    return client.storage.from(bucket).getPublicUrl(path);
  }

  /// Get public URL for a file
  String getPublicUrl({
    required String bucket,
    required String path,
  }) {
    return client.storage.from(bucket).getPublicUrl(path);
  }
}