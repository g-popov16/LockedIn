import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostWidget extends StatefulWidget {
  final int postId;
  final String content;
  final int userId;
  final String username;
  final int likes;
  final String createdAt;
  final int commentsCount;
  final VoidCallback? onLikePressed;
  final VoidCallback? onCommentPressed;
  final VoidCallback? onNicknameTap;
  final String? profileImageUrl;

  const PostWidget({
    super.key,
    required this.postId,
    required this.content,
    required this.userId,
    required this.username,
    required this.likes,
    required this.createdAt,
    required this.commentsCount,
    this.onLikePressed,
    this.onCommentPressed,
    this.onNicknameTap,
    this.profileImageUrl,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  bool isLikedState = false;

  @override
  Widget build(BuildContext context) {
    final DateTime createdTime = DateTime.parse(widget.createdAt);
    final String timeAgo = timeago.format(createdTime);

    return Card(
      color: const Color(0xFF343a40), // Dark card color
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile image and username
            Row(
              children: [
                if (widget.profileImageUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(widget.profileImageUrl!),
                      radius: 20,
                    ),
                  ),
                InkWell(
                  onTap: widget.onNicknameTap,
                  child: Text(
                    widget.username,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Post content
            Text(
              widget.content,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 12),

            // Like, comment, and timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isLikedState ? Icons.favorite : Icons.favorite_border,
                        color: isLikedState ? Colors.redAccent : Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          isLikedState = !isLikedState;
                        });
                        widget.onLikePressed?.call();
                      },
                    ),
                    Text(
                      '${widget.likes + (isLikedState ? 1 : 0)} Likes',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: widget.onCommentPressed,
                  child: Row(
                    children: [
                      const Icon(Icons.comment, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.commentsCount} Comments',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Text(
                  timeAgo,
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
