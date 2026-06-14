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

  /// Alias for deleteFile — used by some screens
  Future<void> deleteImageByUrl(String url) => deleteFile(url);

  /// Uploads an image with both full and thumbnail sizes.
  /// Returns a map with 'full' and 'thumb' keys.
  Future<Map<String, String>> uploadOptimizedImage(File file, String folder) async {
    try {
      final fileName = _uuid.v4();

      // Full size
      final fullCompressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: 80,
        minWidth: 1024,
        minHeight: 1024,
      );
      final fullRef = _storage.ref('$folder/$fileName.jpg');
      await fullRef.putData(fullCompressed!);
      final fullUrl = await fullRef.getDownloadURL();

      // Thumbnail
      final thumbCompressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: 60,
        minWidth: 256,
        minHeight: 256,
      );
      final thumbRef = _storage.ref('$folder/${fileName}_thumb.jpg');
      await thumbRef.putData(thumbCompressed!);
      final thumbUrl = await thumbRef.getDownloadURL();

      return {'full': fullUrl, 'thumb': thumbUrl};
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  /// Uploads an image for a service request/object — returns URL or empty string
  Future<String> uploadObjectImage(File file) async {
    final url = await uploadServiceImage(file, 'objects');
    return url ?? '';
  }

  /// Uploads a profile image — alias
  Future<String?> uploadProfileImageFromFile(File file, String userId) =>
      uploadProfileImage(file, userId);
}
