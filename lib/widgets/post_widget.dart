import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// --- Re-Define Colors Here or Import from a Shared File ---
const Color _backgroundColor = Color(0xFF121212);
const Color _cardBackgroundColor = Color(0xFF1F1F1F); // Updated Card Color
const Color _accentColor = Color(0xFFE85D5D);
const Color _primaryTextColor = Colors.white;
const Color _secondaryTextColor = Colors.white70;
const Color _placeholderColor = Colors.grey;
const Color _iconColor = Colors.white70;
const double _cardBorderRadius = 12.0; // Slightly increased radius
// ---

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
  final String? imageUrl;
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
  void didUpdateWidget(covariant PostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked != oldWidget.isLiked) {
      setState(() {
        isLikedState = widget.isLiked;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final DateTime createdTime = DateTime.parse(widget.createdAt);
    final String timeAgo = timeago.format(createdTime);
    // Logic for likes count remains the same

    return Card(
      color: _cardBackgroundColor, // Use defined card background color
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardBorderRadius), // Use defined radius
      ),
      elevation: 0.0, // Flatter look like SignUp page elements
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile image and username
            Row(
              children: [
                // Profile Image styling
                Padding(
                  padding: const EdgeInsets.only(right: 12.0), // Slightly more padding
                  child: CircleAvatar(
                    radius: 22, // Slightly larger
                    backgroundColor: _placeholderColor.withOpacity(0.3), // Placeholder bg
                    backgroundImage: (widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty)
                        ? CachedNetworkImageProvider(widget.profileImageUrl!) // Use CachedNetworkImageProvider
                        : null,
                    child: (widget.profileImageUrl == null || widget.profileImageUrl!.isEmpty)
                        ? const Icon(Icons.person, color: _secondaryTextColor, size: 24,) // Default icon styling
                        : null,
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: widget.onNicknameTap,
                    child: Text(
                      widget.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _primaryTextColor, // Use defined primary text color
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12), // Increased spacing

            // Post content
            Text(
              widget.content,
              style: const TextStyle(fontSize: 14, color: _secondaryTextColor), // Use defined secondary text color
            ),
            const SizedBox(height: 12), // Increased spacing

            // Post Image
            if (widget.imageUrl?.isNotEmpty ?? false)
              Container(
                // height: 250, // Height can be intrinsic or fixed
                constraints: const BoxConstraints(
                  maxHeight: 400, // Max height for image
                ),
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_cardBorderRadius - 4), // Slightly smaller radius than card
                  color: _backgroundColor, // Use main background for image placeholder area
                ),
                clipBehavior: Clip.antiAlias, // Use antiAlias for smoother edges
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container( // More subtle placeholder
                    color: _placeholderColor.withOpacity(0.1),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(_placeholderColor),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container( // More subtle error
                    color: _placeholderColor.withOpacity(0.1),
                    child: const Icon(
                      Icons.broken_image,
                      size: 40,
                      color: _placeholderColor,
                    ),
                  ),
                ),
              ),
            if (widget.imageUrl?.isNotEmpty ?? false)
              const SizedBox(height: 16), // Increased spacing after image

            // Like, comment, and timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Likes Section
                Row(
                  children: [
                    // Like Button - make tap target slightly larger
                    InkWell(
                      onTap: () {
                        setState(() { isLikedState = !isLikedState; });
                        widget.onLikePressed?.call();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0), // Padding around icon
                        child: Icon(
                          isLikedState ? Icons.favorite : Icons.favorite_border,
                          color: isLikedState ? _accentColor : _iconColor, // Use defined colors
                          size: 22, // Slightly larger icon
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Likes Count Text
                    Text(
                      l10n.postLikesCount(widget.likes),
                      style: const TextStyle(fontSize: 13, color: _primaryTextColor), // Use primary color
                    ),
                  ],
                ),
                // Comment Button
                InkWell(
                  onTap: widget.onCommentPressed,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Row(
                      children: [
                        Icon(Icons.comment_outlined, size: 20, color: _iconColor), // Use defined icon color
                        const SizedBox(width: 6),
                        Text(
                          l10n.postViewComments.trim(),
                          style: const TextStyle(fontSize: 13, color: _primaryTextColor), // Use primary color
                        ),
                      ],
                    ),
                  ),
                ),
                // Timestamp
                Text(
                  timeAgo,
                  style: const TextStyle(fontSize: 12, color: _secondaryTextColor), // Use secondary color
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}