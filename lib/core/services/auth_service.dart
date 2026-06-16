import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../utils/rsa_encryptor.dart';
import 'api_service.dart';
import 'socket_service.dart';

const _kBackendTokenKey = 'backend_jwt';
const _kBackendUserIdKey = 'backend_user_id';

class AuthService {
  // Static cache so build() methods can read the uid synchronously for both auth providers.
  // Set on login/register and on splash sync; cleared on sign-out.
  static String _cachedBackendUserId = '';

  /// Returns the current user ID synchronously.
  /// Prefer Firebase UID when available (Google sign-in); falls back to cached backend UUID.
  static String get currentUidSync =>
      FirebaseAuth.instance.currentUser?.uid ?? _cachedBackendUserId;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '528608210144-cajos5fejrd64hjfscv8kq6k9qmo2baa.apps.googleusercontent.com',
  );
  final ApiService _api = ApiService();
  final SocketService _socket = SocketService();

  Stream<User?> get userStream => _auth.authStateChanges();
  String? get currentUserUid => _auth.currentUser?.uid;

  // ─── Google Sign-In (Firebase) ──────────────────────────────────────────────

  Future<UserModel?> signInWithGoogle({String? referralCode}) async {
    try {
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      if (userCred.user == null) return null;

      return _syncGoogleWithBackend(
        name: userCred.user!.displayName ?? 'Usuario',
        profileImageUrl: userCred.user!.photoURL ?? '',
        referralCode: referralCode,
      );
    } catch (e) {
      print('Error en signInWithGoogle: $e');
      return null;
    }
  }

  Future<UserModel?> _syncGoogleWithBackend({
    String? name,
    String? profileImageUrl,
    String? userType,
    String? referralCode,
  }) async {
    try {
      final response = await _api.post('/auth/sync', data: {
        if (name != null) 'name': name,
        if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
        if (userType != null) 'userType': userType,
        if (referralCode != null) 'referralCode': referralCode,
      });
      final user = UserModel.fromJson(response.data['user']);
      await _socket.connect();
      return user;
    } catch (e) {
      print('Error en _syncGoogleWithBackend: $e');
      if (e is DioException) {
        print('Dio error: ${e.type} | ${e.message} | ${e.response}');
      }
      return null;
    }
  }

  // ─── Email Auth (Backend-managed) ───────────────────────────────────────────

  /// Sends a 6-digit verification code to [email].
  Future<void> sendVerificationCode(String email) async {
    await _api.post('/auth/send-verification', data: {'email': email});
  }

  /// Registers a new user. Password is RSA-encrypted before sending.
  Future<UserModel?> signUpWithEmailBackend(
    String email,
    String password,
    String name,
    String verificationCode, {
    String? referralCode,
  }) async {
    try {
      final encryptedPassword = await RsaEncryptor.encryptPassword(password);
      final response = await _api.post('/auth/register', data: {
        'email': email,
        'encryptedPassword': encryptedPassword,
        'name': name,
        'verificationCode': verificationCode,
        if (referralCode != null && referralCode.isNotEmpty)
          'referralCode': referralCode,
      });
      final token = response.data['token'] as String;
      await _saveBackendToken(token);
      final user = UserModel.fromJson(response.data['user']);
      await _saveBackendUserId(user.id);
      await _socket.connect();
      return user;
    } catch (e) {
      print('Error en signUpWithEmailBackend: $e');
      rethrow;
    }
  }

  /// Logs in with email. Password is RSA-encrypted before sending.
  Future<UserModel?> signInWithEmailBackend(String email, String password) async {
    try {
      final encryptedPassword = await RsaEncryptor.encryptPassword(password);
      final response = await _api.post('/auth/login', data: {
        'email': email,
        'encryptedPassword': encryptedPassword,
      });
      final token = response.data['token'] as String;
      await _saveBackendToken(token);
      final user = UserModel.fromJson(response.data['user']);
      await _saveBackendUserId(user.id);
      await _socket.connect();
      return user;
    } catch (e) {
      print('Error en signInWithEmailBackend: $e');
      rethrow;
    }
  }

  // ─── Session management ──────────────────────────────────────────────────────

  Future<void> signOut() async {
    _socket.disconnect();
    await _auth.signOut();
    await _googleSignIn.signOut();
    await _clearBackendToken();
    await _clearBackendUserId();
  }

  /// Called on splash for Google-auth users.
  Future<UserModel?> syncCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return _syncGoogleWithBackend(
      name: firebaseUser.displayName,
      profileImageUrl: firebaseUser.photoURL,
    );
  }

  /// Called on splash for backend-email users.
  Future<UserModel?> syncCurrentUserFromBackend() async {
    try {
      final response = await _api.get('/users/me');
      final data = response.data;
      final user = UserModel.fromJson(data['user'] ?? data);
      await _saveBackendUserId(user.id); // populate sync cache for build() methods
      await _socket.connect();
      return user;
    } catch (e) {
      await _clearBackendToken();
      return null;
    }
  }

  Future<String?> getBackendToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kBackendTokenKey);
  }

  Future<void> updateFcmToken(String token) async {
    try {
      await _api.put('/auth/fcm-token', data: {'token': token});
    } catch (_) {}
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Future<String?> getBackendUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kBackendUserIdKey);
  }

  Future<String> getCurrentUserId() async {
    final firebaseUid = _auth.currentUser?.uid;
    if (firebaseUid != null && firebaseUid.isNotEmpty) return firebaseUid;
    return await getBackendUserId() ?? '';
  }

  Future<void> _saveBackendToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBackendTokenKey, token);
  }

  Future<void> _clearBackendToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBackendTokenKey);
  }

  Future<void> _saveBackendUserId(String userId) async {
    AuthService._cachedBackendUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBackendUserIdKey, userId);
  }

  Future<void> _clearBackendUserId() async {
    AuthService._cachedBackendUserId = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBackendUserIdKey);
  }
}
