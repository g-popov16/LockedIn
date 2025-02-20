import 'package:flutter/material.dart';
import '../sql.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentsDialog extends StatefulWidget {
  final int postId;
  final VoidCallback? onCommentAdded; // Callback to notify parent about comment addition

  const CommentsDialog({super.key, required this.postId, this.onCommentAdded});

  @override
  _CommentsDialogState createState() => _CommentsDialogState();
}

class _CommentsDialogState extends State<CommentsDialog> {
  final PostgresDB db = PostgresDB();
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> comments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      final fetchedComments = await db.getComments(widget.postId);
      setState(() {
        comments = fetchedComments;
      });
    } catch (e) {
      print("Error fetching comments: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load comments.")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _addComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    try {
      final currentUserId = await db.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception("User ID not found");
      }

      await db.addComment(postId: widget.postId, userId: currentUserId, content: commentText);
      _commentController.clear();

      // Refresh the comments and notify parent
      await _fetchComments();
      widget.onCommentAdded?.call();
    } catch (e) {
      print("Error adding comment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add comment.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.6,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor, // Themed background color
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  "Comments",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              isLoading
                  ? const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : comments.isEmpty
                      ? Expanded(
                          child: Center(
                            child: Text(
                              "No comments yet. Be the first to comment!",
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      : Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              final DateTime createdTime = DateTime.parse(comment['created_at']);
                              final String timeAgo = timeago.format(createdTime);

                              return ListTile(
                                title: Text(
                                  comment['content'],
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                subtitle: Text(
                                  "by ${comment['username']} • $timeAgo",
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              );
                            },
                          ),
                        ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: Theme.of(context).textTheme.bodyLarge, // Themed input text
                        decoration: InputDecoration(
                          hintText: "Write a comment...",
                          hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Theme.of(context).primaryColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 15),
                        ),
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                      onPressed: _addComment,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
