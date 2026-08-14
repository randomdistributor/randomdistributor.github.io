import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

/// Picks an image (camera or gallery), uploads it to a Supabase Storage bucket,
/// and returns the public URL. image_picker resizes/compresses on device via
/// maxWidth + imageQuality so uploads stay small.
class ImageService {
  static final _picker = ImagePicker();

  static Future<String?> pickAndUpload({
    required String bucket,
    required String folder,
    required ImageSource source,
  }) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 78,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final path = '$folder/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return supabase.storage.from(bucket).getPublicUrl(path);
  }
}
