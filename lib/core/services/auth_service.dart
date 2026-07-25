import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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
    // serverClientId = Web OAuth client (type 3) del proyecto Firebase.
    // En Android NO se usa clientId; se necesita serverClientId para obtener el idToken.
    serverClientId: '528608210144-cajos5fejrd64hjfscv8kq6k9qmo2baa.apps.googleusercontent.com',
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

      return _syncFirebaseUserWithBackend(
        name: userCred.user!.displayName ?? 'Usuario',
        profileImageUrl: userCred.user!.photoURL ?? '',
        referralCode: referralCode,
      );
    } on DioException {
      // Error del backend al sincronizar → propagar para que la UI muestre el mensaje.
      rethrow;
    } catch (e) {
      print('Error en signInWithGoogle: $e');
      rethrow;
    }
  }

  // ─── Sign in with Apple (Firebase) ──────────────────────────────────────────
  // Requerido por la guía 4.8 de Apple: como la app ofrece otro login de
  // terceros (Google), debe ofrecer también "Sign in with Apple" en iOS.

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();

  Future<UserModel?> signInWithApple({String? referralCode}) async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      final userCred = await _auth.signInWithCredential(oauthCredential);
      if (userCred.user == null) return null;

      // El nombre completo solo llega la PRIMERA vez que el usuario autoriza
      // la app (Apple no lo reenvía en sesiones siguientes), así que hay que
      // guardarlo en el perfil de Firebase en ese momento.
      final givenName = appleCredential.givenName;
      final familyName = appleCredential.familyName;
      String? displayName = userCred.user!.displayName;
      if ((givenName != null && givenName.isNotEmpty) || (familyName != null && familyName.isNotEmpty)) {
        displayName = [givenName, familyName].where((s) => s != null && s.isNotEmpty).join(' ');
        await userCred.user!.updateDisplayName(displayName);
      }

      return _syncFirebaseUserWithBackend(
        name: displayName ?? 'Usuario',
        profileImageUrl: userCred.user!.photoURL ?? '',
        referralCode: referralCode,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      // El usuario canceló el diálogo nativo de Apple.
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    } on DioException {
      rethrow;
    } catch (e) {
      print('Error en signInWithApple: $e');
      rethrow;
    }
  }

  Future<UserModel?> _syncFirebaseUserWithBackend({
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
      await _uploadFcmToken();
      return user;
    } catch (e) {
      print('Error en _syncFirebaseUserWithBackend: $e');
      if (e is DioException) {
        print('Dio error: ${e.type} | ${e.message} | ${e.response}');
      }
      // Propagar para que la UI muestre siempre un mensaje al usuario.
      rethrow;
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
      await _signInToFirebaseIfPossible(response.data['firebaseToken'] as String?);
      await _socket.connect();
      await _uploadFcmToken();
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
      await _signInToFirebaseIfPossible(response.data['firebaseToken'] as String?);
      await _socket.connect();
      await _uploadFcmToken();
      return user;
    } catch (e) {
      print('Error en signInWithEmailBackend: $e');
      rethrow;
    }
  }

  // ─── Firebase session for email users ────────────────────────────────────────

  /// Inicia sesión en Firebase Auth con un custom token para que los usuarios
  /// de email/contraseña tengan `request.auth` válido en Storage/Firestore.
  /// No es fatal: si falla, el usuario sigue autenticado vía JWT del backend.
  Future<void> _signInToFirebaseIfPossible(String? customToken) async {
    if (customToken == null || customToken.isEmpty) return;
    if (_auth.currentUser != null) return;
    try {
      await _auth.signInWithCustomToken(customToken);
    } catch (e) {
      print('Error signInWithCustomToken: $e');
    }
  }

  /// Garantiza que el usuario de email (con JWT del backend) también tenga
  /// sesión de Firebase. Se llama en el arranque para migrar a quienes
  /// iniciaron sesión con el build anterior, sin obligarles a re-login.
  Future<void> ensureFirebaseSession() async {
    if (_auth.currentUser != null) return;
    try {
      final response = await _api.get('/auth/firebase-token');
      await _signInToFirebaseIfPossible(response.data['firebaseToken'] as String?);
    } catch (e) {
      print('Error ensureFirebaseSession: $e');
    }
  }

  // ─── Session management ──────────────────────────────────────────────────────

  Future<void> signOut() async {
    _socket.reset();
    await _auth.signOut();
    await _googleSignIn.signOut();
    await _clearBackendToken();
    await _clearBackendUserId();
  }

  /// Called on splash for Firebase-auth users (Google o Apple).
  /// Sincronización silenciosa: no propaga errores (el splash no debe mostrar
  /// snackbars ni romperse). El login interactivo sí los propaga.
  Future<UserModel?> syncCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    try {
      return await _syncFirebaseUserWithBackend(
        name: firebaseUser.displayName,
        profileImageUrl: firebaseUser.photoURL,
      );
    } catch (e) {
      print('Error en syncCurrentUser (splash): $e');
      return null;
    }
  }

  /// Called on splash for backend-email users.
  Future<UserModel?> syncCurrentUserFromBackend() async {
    try {
      // Asegura sesión de Firebase (migra usuarios de email del build anterior).
      await ensureFirebaseSession();
      final response = await _api.get('/users/me');
      final data = response.data;
      final user = UserModel.fromJson(data['user'] ?? data);
      await _saveBackendUserId(user.id); // populate sync cache for build() methods
      await _socket.connect();
      await _uploadFcmToken();
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

  // Uploads the device's FCM token to the backend.
  // Must be called AFTER authentication so the JWT is available.
  Future<void> _uploadFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await updateFcmToken(token);
    } catch (_) {}
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
