import 'package:flutter/material.dart';
import '../sql.dart';
import 'package:timeago/timeago.dart' as timeago;
// 1. Import AppLocalizations
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CommentsDialog extends StatefulWidget {
  final int postId;
  final VoidCallback? onCommentAdded;

  const CommentsDialog({super.key, required this.postId, this.onCommentAdded});

  @override
  _CommentsDialogState createState() => _CommentsDialogState();
}

class _CommentsDialogState extends State<CommentsDialog> {
  final PostgresDB db = PostgresDB();
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> comments = [];
  bool isLoading = true;
  bool _isAddingComment = false; // Prevent double submission

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }


  Future<void> _fetchComments() async {
    // Use mounted check before setState
    if (!mounted) return;
    setState(() { isLoading = true; }); // Set loading true at the start

    try {
      final fetchedComments = await db.getComments(widget.postId);
      // Check mounted after await
      if (!mounted) return;
      setState(() {
        comments = fetchedComments;
        // isLoading = false; // Set loading false here inside setState
      });
    } catch (e) {
      print("Error fetching comments: $e");
      // Check mounted before showing SnackBar
      if (!mounted) return;
      // 2. Get l10n instance for SnackBar
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        // 3. Use localized error message
        SnackBar(content: Text(l10n.commentsLoadFailedError)),
      );
    } finally {
      // Ensure isLoading is set to false eventually, even on error
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _addComment() async {
    // Get l10n instance and ScaffoldMessenger safely
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return; // Don't add empty comments

    // Prevent double submission
    if (_isAddingComment) return;
    if (mounted) setState(() => _isAddingComment = true);


    try {
      final currentUserId = await db.getCurrentUserId();
      // Check mounted after await
      if (!mounted) return;

      if (currentUserId == null) {
        // Throwing an exception might crash, show SnackBar instead
        scaffoldMessenger.showSnackBar(
          // Use localized error message
          SnackBar(content: Text(l10n.errorUnableToRetrieveUserInfo)),
        );
        // Reset submitting state on error
        if (mounted) setState(() => _isAddingComment = false);
        return; // Exit if user ID not found
      }

      await db.addComment(postId: widget.postId, userId: currentUserId, content: commentText);
      // Check mounted after await
      if (!mounted) return;

      _commentController.clear(); // Clear input field

      // Refresh the comments list locally to show the new comment immediately
      await _fetchComments();
      // Check mounted after await
      if (!mounted) return;

      widget.onCommentAdded?.call(); // Notify parent

    } catch (e) {
      print("Error adding comment: $e");
      // Check mounted before showing SnackBar
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        // Use localized error message
        SnackBar(content: Text(l10n.commentAddFailedError)),
      );
    } finally {
      // Always re-enable button if mounted
      if (mounted) setState(() => _isAddingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2. Get AppLocalizations instance
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context); // Get theme instance

    // Wrap with GestureDetector to dismiss keyboard when tapping outside input
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard
      child: FractionallySizedBox(
        // Adjust height factor if needed, consider keyboard height
        heightFactor: 0.7, // Slightly increased height factor
        child: Container(
          // Use theme colors
          decoration: BoxDecoration(
            color: theme.cardColor, // Use cardColor for background
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          // Ensure padding accounts for keyboard inset
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom, // Adjust for keyboard
              left: 10, right: 10, top: 10
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Crucial for BottomSheet
            children: [
              // Handle draggable indicator (optional)
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  // 3. Use localized title
                  l10n.commentsTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              // Use a Divider
              Divider(color: theme.dividerColor, height: 1),
              // Content Area (List or Loading/Empty State)
              Expanded( // Make list expandable
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : comments.isEmpty
                    ? Center(
                  child: Padding( // Add padding to empty state text
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      // 3. Use localized empty state message
                      l10n.commentsNone,
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
                    : ListView.separated( // Use separated for dividers
                  // shrinkWrap: true, // Not needed inside Expanded
                  padding: const EdgeInsets.symmetric(vertical: 8.0), // Add padding around list items
                  itemCount: comments.length,
                  separatorBuilder: (context, index) => Divider(
                      color: theme.dividerColor.withOpacity(0.5),
                      height: 1
                  ),
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    // Safely parse date, provide fallback
                    DateTime createdTime;
                    try {
                      createdTime = DateTime.parse(comment['created_at'] ?? '');
                    } catch (_) {
                      createdTime = DateTime.now(); // Fallback
                    }
                    final String timeAgo = timeago.format(createdTime);
                    final String username = comment['username'] ?? l10n.unknownUser; // Use localized unknown user

                    return ListTile(
                      title: Text(
                        comment['content'] ?? '', // Handle null content
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(
                        // 3. Use localized prefix and format
                        '${l10n.commentByPrefix}$username • $timeAgo',
                        style: theme.textTheme.bodyMedium,
                      ),
                      // Optional: Add dense layout
                      dense: true,
                    );
                  },
                ),
              ),
              // Input Area
              Padding(
                // Add padding also at the bottom of the input row
                padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration(
                          // 3. Use localized hint text
                          hintText: l10n.commentInputHint,
                          hintStyle: theme.inputDecorationTheme.hintStyle,
                          filled: true,
                          // Use a slightly different fill color for input if desired
                          fillColor: theme.scaffoldBackgroundColor, // Or another theme color
                          // Customize border or use theme default
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none), // Rounded border, no outline
                          isDense: true, // Make input field slightly smaller
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15), // Adjust padding
                        ),
                        maxLines: null, // Allows multi-line based on content
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.send, // Change keyboard action
                        onSubmitted: (_) => _isAddingComment ? null : _addComment(), // Allow sending via keyboard
                      ),
                    ),
                    const SizedBox(width: 8), // Space before button
                    // Send Button with loading indicator
                    IconButton(
                      icon: _isAddingComment
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(Icons.send, color: theme.primaryColor),
                      onPressed: _isAddingComment ? null : _addComment, // Disable while adding
                      tooltip: 'Send Comment', // TODO: Localize tooltip
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