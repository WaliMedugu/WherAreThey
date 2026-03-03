import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class StorageService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, String>?> uploadCasePhoto(XFile image, String caseId) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final path = '$caseId/$fileName';

      final List<int> bytes = await image.readAsBytes();
      
      await _supabase.storage.from('case_photos').uploadBinary(
        path,
        Uint8List.fromList(bytes),
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

}
