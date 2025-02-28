import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadProfilePicture(File imageFile, String userId) async {
    try {
      final ref = _storage.ref().child('profile_pictures/$userId.jpg');

      // Set metadata safely
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploaded_by': userId},
      );

      UploadTask uploadTask = ref.putFile(imageFile, metadata);
      TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("❌ Error uploading file: $e");
      return null;
    }
  }
}
