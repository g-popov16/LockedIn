import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads an image to Firebase Storage and returns the download URL
  Future<String?> uploadProfilePicture(File imageFile, String userId) async {
    try {
      // Create a reference with a unique filename: profile_pictures/userId_timestamp.jpg
      final storageRef = _storage
          .ref()
          .child('profile_pictures')
          .child('${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Start the upload task
      final uploadTask = storageRef.putFile(imageFile);

      // Wait for completion
      final snapshot = await uploadTask.whenComplete(() => null);

      // Get the download URL
      final downloadURL = await snapshot.ref.getDownloadURL();

      return downloadURL; // ✅ Return the image URL
    } catch (e, stacktrace) {
      print("❌ Firebase Upload Error: $e");
      print(stacktrace);
      return null;
    }
  }
}
