import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/language_service.dart';

/// Selector reutilizable para elegir si una foto se toma con la cámara o se
/// escoge de la galería. Se usa al publicar un problema (cliente) y al
/// finalizar un trabajo (técnico). En ambos casos se permite hasta 3 fotos.
class PhotoSourcePicker {
  static final ImagePicker _picker = ImagePicker();

  /// Hoja inferior para elegir cámara o galería. Devuelve `null` si se cancela.
  static Future<ImageSource?> chooseSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                tr('photo_source_title'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFFFF8A00)),
              title: Text(tr('take_photo')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFFFF8A00)),
              title: Text(tr('choose_gallery')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Pide fotos respetando el máximo restante. Cámara = 1 foto; galería = varias
  /// (se recorta a [remaining]). Devuelve la lista elegida (vacía si se cancela).
  static Future<List<File>> pick(BuildContext context, {required int remaining}) async {
    if (remaining <= 0) return [];
    final source = await chooseSource(context);
    if (source == null) return [];

    final List<File> files = [];
    if (source == ImageSource.gallery) {
      final picked = await _picker.pickMultiImage(imageQuality: 70);
      for (final x in picked.take(remaining)) {
        files.add(File(x.path));
      }
    } else {
      final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
      if (picked != null) files.add(File(picked.path));
    }
    return files;
  }
}
