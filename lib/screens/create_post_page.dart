import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../sql.dart';
import '../services/firebase_service.dart'; // New file for Firebase

class CreatePostPage extends StatefulWidget {
  final int userId;

  const CreatePostPage({super.key, required this.userId});

  @override
  _CreatePostPageState createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final PostgresDB db = PostgresDB();
  final TextEditingController _postController = TextEditingController();
  File? _selectedImage; // Store the selected image

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitPost() async {
    final content = _postController.text.trim();
    if (content.isEmpty) return;

    String? imageUrl;

    if (_selectedImage != null) {
      // 🔹 Upload image to Firebase
      imageUrl = await FirebaseService.uploadPostImage(_selectedImage!);
    }

    await db.createPost(
      userId: widget.userId,
      content: content,
      imageUrl: imageUrl, // Save the image URL
    );

    Navigator.pop(context); // Close the page after posting
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Post")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _postController,
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 10),
            _selectedImage != null
                ? Image.file(_selectedImage!,
                    height: 150) // Show selected image
                : const Text("No image selected"),
            TextButton.icon(
              icon: const Icon(Icons.image),
              label: const Text("Pick Image"),
              onPressed: _pickImage,
            ),
            ElevatedButton(
              onPressed: _submitPost,
              child: const Text("Post"),
            ),
          ],
        ),
      ),
    );
  }
}
