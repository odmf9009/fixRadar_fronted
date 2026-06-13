import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';

class UploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  Future<String?> uploadServiceImage(File file, String requestId) async {
    try {
      final compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: 75,
        minWidth: 1024,
        minHeight: 1024,
      );
      if (compressed == null) return null;

      final fileName = '${_uuid.v4()}.jpg';
      final ref = _storage.ref('service_requests/$requestId/$fileName');
      await ref.putData(compressed);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadProfileImage(File file, String userId) async {
    try {
      final compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: 80,
        minWidth: 512,
        minHeight: 512,
      );
      if (compressed == null) return null;

      final ref = _storage.ref('profiles/$userId/avatar.jpg');
      await ref.putData(compressed);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadPortfolioImage(File file, String technicianId) async {
    try {
      final compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: 80,
        minWidth: 1024,
        minHeight: 1024,
      );
      if (compressed == null) return null;

      final fileName = '${_uuid.v4()}.jpg';
      final ref = _storage.ref('portfolio/$technicianId/$fileName');
      await ref.putData(compressed);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }
}
