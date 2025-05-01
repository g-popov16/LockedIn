import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../sql.dart';
import '../services/firebase_service.dart'; // Assuming this handles Firebase upload
// 1. Import AppLocalizations
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CreatePostPage extends StatefulWidget {
  final int userId;

  const CreatePostPage({super.key, required this.userId});

  @override
  _CreatePostPageState createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final PostgresDB db = PostgresDB();
  final TextEditingController _postController = TextEditingController();
  File? _selectedImage;
  bool _isSubmitting = false; // Prevent double submissions

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }


  Future<void> _pickImage() async {
    // Prevent picking image while submitting
    if (_isSubmitting) return;
    try {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      // Check if mounted after await
      if (!mounted || pickedFile == null) return;

      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    } catch (e) {
      print("Error picking image: $e");
      // Optionally show a SnackBar error
      // if (mounted) ScaffoldMessenger.of(context).showSnackBar(...)
    }
  }

  Future<void> _submitPost() async {
    // Get l10n for potential errors
    final l10n = AppLocalizations.of(context)!; // Safe here as it's user action driven
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final content = _postController.text.trim();
    // Require content OR an image
    if (content.isEmpty && _selectedImage == null) {
      // TODO: Add a specific key/message for this validation if needed
      scaffoldMessenger.showSnackBar(SnackBar(content: Text("Post cannot be empty."))); // Example placeholder
      return;
    }

    // Prevent double submission
    if (_isSubmitting) return;
    if (mounted) {
      setState(() => _isSubmitting = true);
    }

    String? imageUrl;
    bool success = false;

    try {
      if (_selectedImage != null) {
        // Upload image to Firebase
        imageUrl = await FirebaseService.uploadPostImage(_selectedImage!);
        // Check if mounted after await
        if (!mounted) return;
        // Optional: Check if imageUrl is null and handle upload failure
        if (imageUrl == null) {
          throw Exception("Image upload failed.");
        }
      }

      // Create post in DB
      await db.createPost(
        userId: widget.userId,
        content: content, // Pass content even if empty, if image exists
        imageUrl: imageUrl,
      );
      success = true; // Mark as successful

    } catch (e) {
      print("Error submitting post: $e");
      // Check mounted before showing SnackBar
      if (mounted) {
        // Use a generic error or add a specific key
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.signUpGeneralError))); // Re-use generic error?
      }
    } finally {
      // Re-enable button only if mounted
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }

    // Pop only on success and if still mounted
    if (success && mounted) {
      // Pop with a value (e.g., true) to indicate success to the previous page if needed
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2. Get AppLocalizations instance
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context); // Get theme

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Use theme background
      appBar: AppBar(
        // 3. Use localized title
        title: Text(l10n.createPostTitle),
        backgroundColor: theme.appBarTheme.backgroundColor,
        titleTextStyle: theme.appBarTheme.titleTextStyle,
        iconTheme: theme.appBarTheme.iconTheme,
        actions: [
          // Show Post button in AppBar for common UI pattern
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitPost, // Disable while submitting
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey, // Indicate disabled state
              ),
              // 3. Use localized button text
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(l10n.createPostSubmitButton),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        // Use SingleChildScrollView to prevent overflow if keyboard appears
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch buttons
            children: [
              TextField(
                controller: _postController,
                style: theme.textTheme.bodyLarge, // Use theme style
                decoration: InputDecoration(
                  // 3. Use localized hint text
                  hintText: l10n.createPostHint,
                  border: const OutlineInputBorder(), // Use default border or style as needed
                  hintStyle: theme.inputDecorationTheme.hintStyle, // Use theme hint style
                ),
                maxLines: 8, // Allow more lines for post content
                minLines: 5,
                keyboardType: TextInputType.multiline, // Allow multiline input
              ),
              const SizedBox(height: 16),

              // Image Preview and Selection
              if (_selectedImage != null)
                Stack( // Use Stack to add a remove button
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect( // Clip image to rounded corners
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.file(
                        _selectedImage!,
                        height: 200, // Adjust height as needed
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Remove button
                    IconButton(
                      icon: const CircleAvatar( // Circular background for visibility
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                      onPressed: _isSubmitting ? null : () => setState(() => _selectedImage = null),
                      tooltip: 'Remove image', // TODO: Localize tooltip if needed
                    ),
                  ],
                )
              else // Show button to pick image if none selected
                OutlinedButton.icon( // Use OutlinedButton for better visibility
                  icon: const Icon(Icons.image_outlined),
                  // 3. Use localized button text
                  label: Text(l10n.createPostPickImageButton),
                  onPressed: _isSubmitting ? null : _pickImage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.textTheme.bodyLarge?.color, // Use theme text color
                    side: BorderSide(color: theme.dividerColor), // Use theme divider color
                  ),
                ),

              // Removed redundant Text("No image selected")
              // Removed redundant Post ElevatedButton (moved to AppBar actions)
            ],
          ),
        ),
      ),
    );
  }
}