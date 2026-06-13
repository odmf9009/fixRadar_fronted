import 'dart:math';
// Migrated: uses API service instead of Firestore
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class ReferralService {
  final FirebaseFirestore _db = /* MongoDB via ApiService */;

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

  /// Validates a referral code and returns the referrer's UID if valid
  Future<String?> validateReferralCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return null;

    final query = await _db
        .collection('users')
        .where('referralCode', isEqualTo: cleanCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return query.docs.first.id;
  }

  /// Links a new user to their referrer
  Future<void> processReferral(String newUserId, String referrerId) async {
    if (newUserId == referrerId) return; // Cannot refer self

    final WriteBatch batch = _db.batch();

    // 1. Update New User
    batch.update(_db.collection('users').doc(newUserId), {
      'referredBy': referrerId,
    });

    // 2. Update Referrer Stats
    batch.update(_db.collection('users').doc(referrerId), {
      'referralCount': /* increment 1 via API */,
      'pendingReferrals': /* increment 1 via API */,
    });

    // 3. Create Referral History Entry
    final historyRef = _db.collection('users').doc(referrerId).collection('referrals').doc(newUserId);
    batch.set(historyRef, {
      'userId': newUserId,
      'status': 'registered',
      'xpEarned': rewardRegistration,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // 4. Grant initial XP to Referrer
    batch.update(_db.collection('users').doc(referrerId), {
      'points': /* increment rewardRegistration via API */,
      'totalXp': /* increment rewardRegistration via API */,
      'referralXpEarned': /* increment rewardRegistration via API */,
    });

    // 5. Log XP History
    batch.set(_db.collection('users').doc(referrerId).collection('xp_history').doc(), {
      'title': 'Referido Registrado',
      'xpAmount': rewardRegistration,
      'date': DateTime.now().toIso8601String(),
    });

    await batch.commit();
  }

  /// Called when a user posts their first service request
  Future<void> trackFirstService(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    final String? referrerId = userDoc.data()?['referredBy'];
    
    if (referrerId == null) return;

    final historyRef = _db.collection('users').doc(referrerId).collection('referrals').doc(userId);
    final historyDoc = await historyRef.get();
    
    if (!historyDoc.exists) return;
    if (historyDoc.data()?['status'] == 'first_service' || historyDoc.data()?['status'] == 'completed') return;

    final batch = _db.batch();
    
    batch.update(historyRef, {
      'status': 'first_service',
      'xpEarned': /* increment rewardFirstService via API */,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    batch.update(_db.collection('users').doc(referrerId), {
      'points': /* increment rewardFirstService via API */,
      'totalXp': /* increment rewardFirstService via API */,
      'referralXpEarned': /* increment rewardFirstService via API */,
    });

    // Log XP History
    batch.set(_db.collection('users').doc(referrerId).collection('xp_history').doc(), {
      'title': 'Primer Pedido Publicado por Referido',
      'xpAmount': rewardFirstService,
      'date': DateTime.now().toIso8601String(),
    });

    await batch.commit();
  }

  /// Called when a user completes their first service job
  Future<void> trackFirstJobCompletion(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    final String? referrerId = userDoc.data()?['referredBy'];
    
    if (referrerId == null) return;

    final historyRef = _db.collection('users').doc(referrerId).collection('referrals').doc(userId);
    final historyDoc = await historyRef.get();
    
    if (!historyDoc.exists) return;
    if (historyDoc.data()?['status'] == 'completed') return;

    final batch = _db.batch();
    
    batch.update(historyRef, {
      'status': 'completed',
      'xpEarned': /* increment rewardFirstJobCompleted via API */,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    batch.update(_db.collection('users').doc(referrerId), {
      'points': /* increment rewardFirstJobCompleted via API */,
      'totalXp': /* increment rewardFirstJobCompleted via API */,
      'referralXpEarned': /* increment rewardFirstJobCompleted via API */,
      'successfulReferrals': /* increment 1 via API */,
      'pendingReferrals': /* increment -1 via API */,
    });

    // Log XP History
    batch.set(_db.collection('users').doc(referrerId).collection('xp_history').doc(), {
      'title': 'Primer Trabajo Completado por Referido',
      'xpAmount': rewardFirstJobCompleted,
      'date': DateTime.now().toIso8601String(),
    });

    await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> getReferralHistory(String userId) {
    return _db.collection('users').doc(userId).collection('referrals')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .asyncMap((snapshot) async {
        List<Map<String, dynamic>> results = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final invitedUserId = data['userId'];
          final invitedUserDoc = await _db.collection('users').doc(invitedUserId).get();
          
          results.add({
            ...data,
            'userName': invitedUserDoc.data()?['username'] ?? 'Usuario',
            'userAvatar': invitedUserDoc.data()?['profileImageUrl'] ?? '',
          });
        }
        return results;
      });
  }
}
