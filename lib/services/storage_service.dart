import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class StorageService {
  final _supabase = Supabase.instance.client;
  static const int MAX_FILE_SIZE = 1024 * 1024; // 1MB

  Future<Map<String, String>?> uploadCasePhoto(XFile image, String caseId) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final path = '$caseId/$fileName';

      Uint8List bytes = await image.readAsBytes();
      
      // Optimize and compress image if needed
      bytes = await _optimizeImage(bytes);

      await _supabase.storage.from('case_photos').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

      return {
        'full': path,
        'medium': path,
        'thumbnail': path,
      };
    } catch (e) {
      debugPrint('Error uploading case photo: $e');
      return null;
    }
  }

  Future<Uint8List> _optimizeImage(Uint8List originalBytes) async {
    if (originalBytes.length <= MAX_FILE_SIZE) {
      return originalBytes;
    }

    // Decode the image
    img.Image? image = img.decodeImage(originalBytes);
    if (image == null) return originalBytes;

    // 1. Initial Resize - if very large, shrink to a reasonable maximum
    // This often already brings it below the limit
    if (image.width > 2000 || image.height > 2000) {
      image = img.copyResize(
        image, 
        width: image.width > image.height ? 1600 : null,
        height: image.height >= image.width ? 1600 : null,
        interpolation: img.Interpolation.linear,
      );
    }

    int quality = 85;
    Uint8List compressedBytes = Uint8List.fromList(img.encodeJpg(image, quality: quality));

    // 2. Loop to reduce quality/size until it fits under the limit
    while (compressedBytes.length > MAX_FILE_SIZE && quality > 20) {
      quality -= 10;
      compressedBytes = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }

    // 3. If still too large, shrink dimensions further
    if (compressedBytes.length > MAX_FILE_SIZE) {
      image = img.copyResize(
        image, 
        width: image.width > image.height ? 1000 : null,
        height: image.height >= image.width ? 1000 : null,
      );
      compressedBytes = Uint8List.fromList(img.encodeJpg(image, quality: 60));
    }

    debugPrint('Image optimized: from ${originalBytes.length} to ${compressedBytes.length} bytes (Quality: $quality)');
    return compressedBytes;
  }
}
