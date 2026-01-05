import 'dart:convert';
import 'dart:math';

/// Represents an invite code that athletes generate for coaches to connect
class AthleteInviteCode {
  const AthleteInviteCode({
    required this.userId,
    required this.deviceId,
    required this.displayName,
    required this.createdAt,
    required this.expiresAt,
  });

  final String userId;
  final String deviceId;
  final String displayName;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isExpired;

  /// Generate a short code from the invite data
  /// Format: 6-character alphanumeric code (encoded reference)
  String toShortCode() {
    // Create a simple encoding of the invite data
    final data = {
      'u': userId,
      'd': deviceId,
      'n': displayName,
      'e': expiresAt.millisecondsSinceEpoch,
    };
    final json = jsonEncode(data);
    final bytes = utf8.encode(json);
    final base64Str = base64Url.encode(bytes);
    return base64Str;
  }

  /// Parse a short code back to invite data
  static AthleteInviteCode? fromShortCode(String code) {
    try {
      final bytes = base64Url.decode(code);
      final json = utf8.decode(bytes);
      final data = jsonDecode(json) as Map<String, dynamic>;

      return AthleteInviteCode(
        userId: data['u'] as String,
        deviceId: data['d'] as String,
        displayName: data['n'] as String,
        createdAt: DateTime.now(), // We don't store creation time in code
        expiresAt:
            DateTime.fromMillisecondsSinceEpoch(data['e'] as int),
      );
    } catch (e) {
      return null;
    }
  }

  /// Generate a human-readable code (6 characters)
  /// This is used alongside the full code for easier sharing
  static String generateReadableCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
