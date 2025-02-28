import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostWidget extends StatefulWidget {
  final int postId;
  final String content;
  final int userId;
  final String username;
  final int likes;
  final String createdAt;
  final VoidCallback? onCommentPressed;
  final VoidCallback? onNicknameTap;
  final String? profileImageUrl;
  final String? imageUrl; // ✅ Image URL for post
  final bool isLiked;
  final VoidCallback? onLikePressed;

  const PostWidget({
    super.key,
    required this.postId,
    required this.content,
    required this.userId,
    required this.username,
    this.likes = 0,
    required this.createdAt,
    this.onCommentPressed,
    this.onNicknameTap,
    this.profileImageUrl,
    this.imageUrl,
    this.isLiked = false,
    this.onLikePressed,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  late bool isLikedState;
  @override
  void initState() {
    super.initState();
    isLikedState = widget.isLiked;
  }

  @override
  Widget build(BuildContext context) {
    final DateTime createdTime = DateTime.parse(widget.createdAt);
    final String timeAgo = timeago.format(createdTime);
    final int totalLikes = (widget.likes ?? 0) + (isLikedState ? 1 : 0);
    debugPrint("🖼️ PostWidget Debug - Post ID: ${widget.postId}, Image URL: ${widget.imageUrl ?? 'No Image'}");


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
            const SizedBox(height: 8),

            // Load Image Separately Using FutureBuilder
            // Load Image Separately Using FutureBuilder
            if (widget.imageUrl?.isNotEmpty ?? false)
              Container(
                height: 250, // ✅ Set a fixed height for all images
                width: double.infinity, // ✅ Make it take full width
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[800], // ✅ Background color for consistency
                ),
                clipBehavior: Clip.hardEdge, // ✅ Ensure rounded corners apply
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl!,
                  fit: BoxFit.cover, // ✅ Ensures the image scales correctly
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => Icon(
                    Icons.broken_image,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
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
                    Text('$totalLikes Likes'),
                  ],
                ),
                GestureDetector(
                  onTap: widget.onCommentPressed,
                  child: Row(
                    children: [
                      const Icon(Icons.comment, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        ' Comments',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.white),
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

  Future<String> _loadImage(String imageUrl) async {
    return imageUrl;
  }
}
