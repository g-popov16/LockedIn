import 'dart:io'; // Required for File
import 'package:flutter/cupertino.dart'; // Required for CupertinoSliverRefreshControl
import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart'; // No longer needed for ScrollDirection
import 'package:image_picker/image_picker.dart'; // Required for Story Creation
import 'package:cached_network_image/cached_network_image.dart'; // For Story Avatars & Post Images

// --- Local Imports (Adjust paths as necessary) ---
import 'sql.dart'; // Your database class
import 'package:lockedin/services/firebase_service.dart'; // Your Firebase service class (static methods)
import 'widgets/post_widget.dart';
import 'screens/create_post_page.dart';
import 'screens/messages_page.dart';
import 'screens/user_profile_page.dart';
import 'screens/jobs_page.dart';
import 'screens/comments_dialog.dart';
import 'screens/story_page_view.dart'; // Import the story view page
// --- Internationalization ---
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// --- Theme Colors (Consider moving to a central theme file) ---
const Color _backgroundColor = Color(0xFF121212);
const Color _cardBackgroundColor = Color(0xFF1F1F1F);
const Color _accentColor = Color(0xFFE85D5D);
const Color _primaryTextColor = Colors.white;
const Color _secondaryTextColor = Colors.white70;
const Color _placeholderColor = Colors.grey;
const Color _iconColor = Colors.white70;
const Color _bottomNavBarColor = Color(0xFF1F1F1F);
// ---

class HomePage extends StatefulWidget {
  final String userEmail;

  const HomePage({super.key, required this.userEmail});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --- State Variables ---
  final PostgresDB db = PostgresDB();
  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> storySummaries = [];
  bool isLoading = true;
  int _currentIndex = 0;
  String? userRole;
  int? currentUserId;

  // No ScrollController or _showStories needed for SliverAppBar approach

  // --- Lifecycle Methods ---
  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    // No controller or listener to dispose
    super.dispose();
  }

  // --- Data Fetching Methods ---

  Future<void> _initData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    await _fetchCurrentUserId();
    if (!mounted) return;

    if (currentUserId != null) {
      // Fetch remaining data concurrently
      await Future.wait([
        _fetchUserRole(),
        _fetchPosts(),
        _fetchStorySummaries(),
      ]);
    } else {
      print("Error: Could not fetch current user ID. Cannot load feed data.");
      // Error state will be handled in build method
    }

    // Ensure loading state is turned off if still mounted
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchUserRole() async {
    if (currentUserId == null) return;
    try {
      final user = await db.getUserById(currentUserId!);
      if (!mounted) return;
      if (user != null) {
        setState(() {
          userRole = user['roles'] as String?;
        });
      }
    } catch (e) {
      print("Error fetching user role: $e");
      // Optionally handle error in UI
    }
  }

  Future<void> _fetchCurrentUserId() async {
    try {
      final id = await db.getCurrentUserId();
      if (!mounted) return;
      setState(() {
        currentUserId = id;
      });
    } catch (e) {
      print("Error fetching current user ID: $e");
      if (mounted) {
        setState(() { currentUserId = null; }); // Ensure ID is null on error
      }
    }
  }

  Future<void> _fetchPosts() async {
    if (currentUserId == null) {
      if (mounted) setState(() => posts = []);
      return;
    }
    try {
      final fetchedPosts = await db.getPostsPaginated(
        limit: 20, offset: 0, currentUserId: currentUserId!,
      );
      if (!mounted) return;
      setState(() { posts = fetchedPosts; });
    } catch (e, stack) {
      print("Error fetching posts: $e\n$stack");
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        if (l10n != null) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(content: Text(l10n.errorLoadingPosts), backgroundColor: Colors.redAccent)
          );
        }
        setState(() => posts = []); // Clear posts on error
      }
    }
  }

  Future<void> _fetchStorySummaries() async {
    try {
      final summaries = await db.getRecentStoriesSummary();
      if (!mounted) return;
      setState(() { storySummaries = summaries; });
    } catch (e) {
      print("Error fetching story summaries in HomePage: $e");
      if (mounted) { setState(() => storySummaries = []); } // Clear stories on error
    }
  }
  // --- End Data Fetching ---


  // --- UI Building Methods ---
  @override
  Widget build(BuildContext context) {
    // Get localization safely
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      // Fallback if localization isn't ready
      return const Scaffold(backgroundColor: _backgroundColor, body: Center(child: CircularProgressIndicator()));
    }

    Widget body;
    if (isLoading) {
      body = const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_accentColor)));
    } else if (currentUserId == null) {
      // Critical error display
      body = Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              l10n.errorUnableToRetrieveUserInfo,
              style: const TextStyle(color: _secondaryTextColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          )
      );
    } else {
      // User logged in, build page structure
      final List<Widget> pages = [
        _buildHomeFeed(l10n), // Tab 0: The main feed with CustomScrollView
        // Other tabs can use simpler structures if they don't need collapsing headers
        JobsPage(userRole: userRole ?? ""),
        const MessagesPage(),
        UserProfilePage(userId: currentUserId!, isCurrentUser: true),
      ];
      body = IndexedStack( // Preserve state of inactive tabs
        index: _currentIndex,
        children: pages,
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      // No standard AppBar here, it's handled by SliverAppBar in _buildHomeFeed
      body: body,
      // Floating Action Button (shown only on home tab)
      floatingActionButton: (_currentIndex == 0 && currentUserId != null)
          ? FloatingActionButton(
        onPressed: () async {
          if (currentUserId == null) return;
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePostPage(userId: currentUserId!),
            ),
          );
          if (mounted && result == true) {
            _fetchPosts(); // Refresh posts after creating one
          }
        },
        tooltip: l10n.createPostTitle,
        backgroundColor: _accentColor,
        foregroundColor: _primaryTextColor,
        child: const Icon(Icons.add),
      )
          : null,
      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: _bottomNavBarColor,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() { _currentIndex = index; });
        },
        selectedItemColor: _accentColor,
        unselectedItemColor: _iconColor,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: l10n.navHome),
          BottomNavigationBarItem(icon: const Icon(Icons.work), label: l10n.navJobs),
          BottomNavigationBarItem(icon: const Icon(Icons.message), label: l10n.navMessages),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: l10n.navProfile),
        ],
      ),
    );
  }

  // Builds the content for the first tab (Home Feed) using CustomScrollView
  Widget _buildHomeFeed(AppLocalizations l10n) {
    return CustomScrollView(
      slivers: <Widget>[
        // --- Refresh Control ---
        CupertinoSliverRefreshControl(
          refreshTriggerPullDistance: 100.0, // How far to pull down
          refreshIndicatorExtent: 60.0,    // Height of the indicator area
          onRefresh: () async {
            // Refresh data on pull
            await Future.wait([ _fetchPosts(), _fetchStorySummaries() ]);
          },
        ),

        // --- Collapsing App Bar ---
        SliverAppBar(
          title: Text("Locked In", style: TextStyle(color: _primaryTextColor, fontWeight: FontWeight.bold)),
          backgroundColor: _backgroundColor, // Match scaffold background
          elevation: 0,   // No shadow
          pinned: false,  // Disappears completely when scrolled down
          floating: true, // Appears as soon as user scrolls up
          snap: true,     // Snaps fully into or out of view (doesn't stop partway)
          actions: [
            // Add Story Button
            if (currentUserId != null) // Only show if logged in
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: _primaryTextColor),
                tooltip: l10n.addStoryTooltip, // Use localization
                onPressed: _handleAddStory,
              ),
          ],
        ),

        // --- Story Summaries Row ---
        // Wrap the story container in SliverToBoxAdapter so it's part of the scroll view
        SliverToBoxAdapter(
          child: _buildStorySummariesListContainer(),
        ),

        // --- Optional Divider Below Stories ---
        if (storySummaries.isNotEmpty) // Only show if stories are present
          const SliverToBoxAdapter(
            child: Divider(height: 1, thickness: 1, color: _cardBackgroundColor),
          ),

        // --- Posts List ---
        // This method returns the appropriate sliver (SliverList or empty state)
        _buildPostsList(l10n),
      ],
    );
  }

  // Builds the Container holding the horizontal story list
  Widget _buildStorySummariesListContainer() {
    if (storySummaries.isEmpty) {
      // Return a minimal non-zero height box if you want the divider below it
      // to always appear in the same place, or SizedBox.shrink() otherwise.
      return const SizedBox(height: 1.0);
    }

    return Container(
      height: 105.0, // Define the fixed height for the story row
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      color: _backgroundColor, // Or a slightly different color if desired
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 12.0), // Padding at the start
        itemCount: storySummaries.length,
        itemBuilder: (context, index) {
          final summary = storySummaries[index];
          final storyUserId = summary['user_id'] as int? ?? 0;
          final profilePicUrl = summary['profile_pic_url'] as String?;
          final username = summary['username'] as String? ?? 'User';

          // Skip rendering if user ID is invalid
          if (storyUserId == 0) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(right: 12.0), // Spacing between avatars
            child: InkWell(
              onTap: () {
                // Navigate to Story View Page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StoryViewPage(
                      userId: storyUserId,
                      // Optionally pass username/pic to avoid re-fetch in StoryViewPage
                      // username: username,
                      // profilePicUrl: profilePicUrl,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(35), // For tap ripple effect
              child: Column(
                mainAxisSize: MainAxisSize.min, // Use minimum vertical space
                children: [
                  // Avatar with potential border (e.g., accent color)
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: _accentColor, // Story indicator border
                    child: CircleAvatar(
                      radius: 30, // Inner avatar radius
                      backgroundColor: _placeholderColor.withOpacity(0.3), // Placeholder bg
                      backgroundImage: (profilePicUrl != null && profilePicUrl.isNotEmpty)
                          ? CachedNetworkImageProvider(profilePicUrl)
                          : null,
                      // Show default icon if no profile picture
                      child: (profilePicUrl == null || profilePicUrl.isEmpty)
                          ? const Icon(Icons.person, size: 30, color: _secondaryTextColor)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 5), // Space below avatar
                  // Username Text
                  SizedBox(
                    width: 64, // Limit width to prevent overflow
                    child: Text(
                      username,
                      style: const TextStyle(fontSize: 11, color: _secondaryTextColor),
                      textAlign: TextAlign.center,
                      maxLines: 1, // Ensure single line
                      overflow: TextOverflow.ellipsis, // Handle long names
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Builds the sliver list of posts OR the empty state sliver
  Widget _buildPostsList(AppLocalizations l10n) {
    // Handle empty posts state after loading
    if (posts.isEmpty) {
      return SliverFillRemaining( // Fills available space in scroll view
        hasScrollBody: false, // Content doesn't scroll itself
        child: Center(
            child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  l10n.noPostsAvailable,
                  style: const TextStyle(color: _secondaryTextColor, fontSize: 16),
                  textAlign: TextAlign.center,
                )
            )
        ),
      );
    }

    // Display posts in a SliverList
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
          final post = posts[index];
          // currentUserId is non-null if we reach here
          final userIdForCallbacks = currentUserId!;

          // Return the PostWidget with padding
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: PostWidget(
              key: ValueKey(post['id']),
              postId: post['id'],
              content: post['content'],
              userId: post['user_id'],
              imageUrl: post['image_url'],
              profileImageUrl: post['profile_image_url'],
              username: post['username'],
              likes: post['likes_count'],
              createdAt: post['created_at'],
              isLiked: post['is_liked'],
              onLikePressed: () async {
                // --- Like/Unlike Logic ---
                try {
                  final newCount = await db.toggleLikePost(post['id'], userIdForCallbacks);
                  if (!mounted) return;
                  setState(() {
                    final postIndex = posts.indexWhere((p) => p['id'] == post['id']);
                    if (postIndex != -1) {
                      posts[postIndex]['likes_count'] = newCount;
                      posts[postIndex]['is_liked'] = !posts[postIndex]['is_liked'];
                    }
                  });
                } catch (e) {
                  print("Error toggling like: $e");
                  if(mounted) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        SnackBar(content: Text(l10n.errorLikingPost), backgroundColor: Colors.redAccent)
                    );
                  }
                }
              },
              onCommentPressed: () {
                // --- Show Comments Dialog ---
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  barrierColor: Colors.black.withOpacity(0.6),
                  builder: (BuildContext context) {
                    return CommentsDialog(
                      postId: post['id'],
                      onCommentAdded: () { /* ... */ },
                    );
                  },
                );
              },
              onNicknameTap: () {
                // --- Navigate to User Profile ---
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfilePage(
                      userId: post['user_id'],
                      isCurrentUser: post['user_id'] == userIdForCallbacks,
                    ),
                  ),
                );
              },
            ),
          );
        },
        childCount: posts.length, // Number of posts
      ),
    );
  }

  // --- Action Handlers ---

  // Handles the "Add Story" button press
  Future<void> _handleAddStory() async {
    final l10n = AppLocalizations.of(context)!;
    if (currentUserId == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && mounted) {
      File imageFile = File(image.path);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.uploadingStory)));

      // Upload using static method from FirebaseService
      String? downloadUrl = await FirebaseService.uploadStoryMedia(imageFile, currentUserId.toString());

      scaffoldMessenger.hideCurrentSnackBar();

      if (mounted && downloadUrl != null) {
        bool success = await db.createStory(userId: currentUserId!, contentUrl: downloadUrl);
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(success ? l10n.storyAddedSuccess : l10n.storyAddedError),
              backgroundColor: success ? Colors.green : Colors.redAccent,
            ),
          );
          if (success) {
            _fetchStorySummaries(); // Refresh stories list visually
          }
        }
      } else if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.uploadFailedError), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

} // End of _HomePageState class