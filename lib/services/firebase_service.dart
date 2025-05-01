import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p; // Use 'as p' to avoid naming conflicts
class FirebaseService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<String?> uploadPostImage(File imageFile) async {
    try {
      String fileName = p.basename(imageFile.path);
      Reference ref = _storage.ref().child('post_images/$fileName');

      // Explicitly set metadata (Avoids NullPointerException)
      SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg', // Adjust based on file type
      );

      await ref.putFile(imageFile, metadata); //  Pass metadata
      return await ref.getDownloadURL(); // 🔹 Get Firebase URL
    } catch (e) {
      return null;
    }
  }

  static Future<String?> uploadStoryMedia(File file, String userId) async {
    try {
      String fileExtension = p.extension(file.path); // Get file extension
      // Create a unique file name including timestamp and user ID
      String fileName = '${DateTime.now().millisecondsSinceEpoch}-$userId$fileExtension';

      // Store stories in a separate folder, organized by user ID
      Reference ref = _storage.ref().child('stories').child(userId).child(fileName);

      // --- Determine Content Type (Similar to post image) ---
      String contentType = 'image/jpeg'; // Default or determine based on extension
      if (fileExtension.toLowerCase() == '.png') {
        contentType = 'image/png';
      } else if (fileExtension.toLowerCase() == '.gif') {
        contentType = 'image/gif';
      } else if (fileExtension.toLowerCase() == '.mp4'){ // Example for video
        contentType = 'video/mp4';
      } // Add other supported types (webp, etc.)

      SettableMetadata metadata = SettableMetadata(
        contentType: contentType,
      );

      UploadTask uploadTask = ref.putFile(file, metadata);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading story media: $e"); // Log the error
      return null;
    }
  }
}
