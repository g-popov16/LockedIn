import 'package:flutter/material.dart';
import '../sql.dart';

class CreatePostPage extends StatefulWidget {
  final int userId;

  const CreatePostPage({super.key, required this.userId});

  @override
  _CreatePostPageState createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final PostgresDB db = PostgresDB();
  final TextEditingController _postController = TextEditingController();

  Future<void> _submitPost() async {
    final content = _postController.text.trim();
    if (content.isEmpty) return;

    await db.createPost(userId: widget.userId, content: content);
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
