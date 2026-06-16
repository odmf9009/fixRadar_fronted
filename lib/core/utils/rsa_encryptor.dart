import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/asymmetric/api.dart';
import '../services/api_service.dart';

class RsaEncryptor {
  static String? _cachedPublicKey;

  static Future<String> _getPublicKey() async {
    if (_cachedPublicKey != null) return _cachedPublicKey!;
    final response = await ApiService().get('/auth/public-key');
    _cachedPublicKey = response.data['publicKey'] as String;
    return _cachedPublicKey!;
  }

  static Future<String> encryptPassword(String password) async {
    final pem = await _getPublicKey();
    final publicKey = enc.RSAKeyParser().parse(pem) as RSAPublicKey;
    final encrypter = enc.Encrypter(enc.RSA(publicKey: publicKey));
    return encrypter.encrypt(password).base64;
  }
}
