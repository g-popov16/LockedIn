import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart';

class FirebaseService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<String?> uploadPostImage(File imageFile) async {
    try {
      String fileName = basename(imageFile.path);
      Reference ref = _storage.ref().child('post_images/$fileName');

      // ✅ Explicitly set metadata (Avoids NullPointerException)
      SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg', // Adjust based on file type
      );

      await ref.putFile(imageFile, metadata); // ✅ Pass metadata
      return await ref.getDownloadURL(); // 🔹 Get Firebase URL
    } catch (e) {
      print("❌ Error uploading image: $e");
      return null;
    }
  }
}
