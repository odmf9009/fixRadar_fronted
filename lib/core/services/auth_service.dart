import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'socket_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final ApiService _api = ApiService();
  final SocketService _socket = SocketService();

  Stream<User?> get userStream => _auth.authStateChanges();
  String? get currentUserUid => _auth.currentUser?.uid;

  Future<UserModel?> signInWithGoogle({String? referralCode}) async {
    await _googleSignIn.signOut();
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    if (userCredential.user == null) return null;

    return _syncWithBackend(
      name: userCredential.user!.displayName ?? 'Usuario',
      profileImageUrl: userCredential.user!.photoURL ?? '',
      userType: 'client',
      referralCode: referralCode,
    );
  }

  Future<UserModel?> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    return _syncWithBackend();
  }

  Future<UserModel?> signUpWithEmail(
    String email,
    String password,
    String name, {
    String? referralCode,
    String userType = 'client',
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    if (cred.user == null) return null;

    return _syncWithBackend(
      name: name,
      userType: userType,
      referralCode: referralCode,
    );
  }

  Future<UserModel?> _syncWithBackend({
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
      return null;
    }
  }

  Future<void> signOut() async {
    _socket.disconnect();
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Future<void> updateFcmToken(String token) async {
    try {
      await _api.put('/auth/fcm-token', data: {'token': token});
    } catch (_) {}
  }
}
