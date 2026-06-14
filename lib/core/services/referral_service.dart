// Migrated: stubbed — no backend referral endpoint yet
import 'dart:async';
import 'dart:math';

class ReferralService {
  // Reward constants
  static const int rewardRegistration = 100;
  static const int rewardFirstService = 150;
  static const int rewardFirstJobCompleted = 200;

  /// Generates a unique referral code for a user
  String generateReferralCode(String username) {
    final random = Random();
    final suffix = random.nextInt(9000) + 1000; // 4 digits
    final prefix = username.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final cleanPrefix = prefix.length > 6 ? prefix.substring(0, 6) : prefix;
    return 'FIX-$cleanPrefix-$suffix';
  }

  /// Validates a referral code — stubbed (always returns null)
  Future<String?> validateReferralCode(String code) async {
    return null;
  }

  /// Links a new user to their referrer — stubbed (no-op)
  Future<void> processReferral(String newUserId, String referrerId) async {
    // No backend endpoint yet — no-op
  }

  /// Called when a user posts their first service request — stubbed (no-op)
  Future<void> trackFirstService(String userId) async {
    // No backend endpoint yet — no-op
  }

  /// Called when a user completes their first service job — stubbed (no-op)
  Future<void> trackFirstJobCompletion(String userId) async {
    // No backend endpoint yet — no-op
  }

  /// Returns referral history — stubbed (empty stream)
  Stream<List<Map<String, dynamic>>> getReferralHistory(String userId) {
    final controller = StreamController<List<Map<String, dynamic>>>();
    controller.add([]);
    return controller.stream;
  }
}
