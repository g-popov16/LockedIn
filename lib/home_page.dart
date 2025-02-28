import 'package:flutter/material.dart';
import 'sql.dart';
import 'widgets/post_widget.dart';
import 'screens/create_post_page.dart';
import 'screens/messages_page.dart';
import 'screens/user_profile_page.dart';
import 'screens/jobs_page.dart';
import 'screens/comments_dialog.dart';

class HomePage extends StatefulWidget {
  final String userEmail;

  const HomePage({super.key, required this.userEmail});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PostgresDB db = PostgresDB();
  List<Map<String, dynamic>> posts = [];
  bool isLoading = true;
  int _currentIndex = 0; // To track the selected tab
  String? userRole;      // User role fetched from the database
  int? currentUserId;    // Store the current user ID for profile

  @override
  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    // 1. Fetch user role
    await _fetchUserRole();

    // 2. Fetch currentUserId
    await _fetchCurrentUserId();

    // 3. Now that we (hopefully) have currentUserId, call _fetchPosts
    if (currentUserId != null) {
      await _fetchPosts();
    }
  }


  Future<void> _fetchUserRole() async {
    setState(() {
      isLoading = true;
    });

    try {
      final user = await db.getUserByEmail(widget.userEmail);
      if (user != null) {
        setState(() {
          userRole = user['roles'];
        });
      }
    } catch (e) {
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchCurrentUserId() async {
    try {
      final id = await db.getCurrentUserId();
      setState(() {
        currentUserId = id;
      });
    } catch (e) {
    }
  }

  Future<void> _fetchPosts() async {

    if (currentUserId == null) {
      return;
    }

    setState(() => isLoading = true);

    try {

      final fetchedPosts = await db.getPostsPaginated(
        limit: 10,
        offset: 0,
        currentUserId: currentUserId!,
      );


      fetchedPosts.forEach((post) {
      });

      setState(() {
        posts = fetchedPosts.map((post) {
          return {
            ...post,
            "created_at": post["created_at"].toString(),
            "image_url": post["image_url"]?.isNotEmpty == true ? post["image_url"] : null,
          };
        }).toList();
      });


    } catch (e, stack) {
    } finally {
      setState(() => isLoading = false);
    }
  }


  Widget _buildHomeContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty) {
      return const Center(child: Text("No posts available."));
    }

    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        // IMPORTANT: Return the PostWidget, not just call it
        return PostWidget(

          postId: post['id'] ?? 0,
          content: post['content'] ?? "[No content]",
          userId: post['user_id'] ?? 0,
          imageUrl: post['image_url'],
          username: post['username'] ?? "Unknown",
          likes: post['likes_count'] ?? 0,  // ✅ Use direct value from DB
          createdAt: post['created_at'] ?? DateTime.now().toIso8601String(),
          isLiked: post['is_liked'] ?? false,
          onLikePressed: () async {
            try {
              final newCount = await db.toggleLikePost(
                post['id'],
                currentUserId!,
              );

              setState(() {
                post['likes_count'] = newCount;  // ✅ Only use the DB response
                post['is_liked'] = !post['is_liked'];  // Toggle the like state
              });
            } catch (e) {
            }
          },

        onCommentPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (BuildContext context) {
                return CommentsDialog(
                  postId: post['id'],
                  onCommentAdded: () {
                    setState(() {
                      post['comments_count'] += 1;
                    });
                  },
                );
              },
            );
          },
          onNicknameTap: () {
            // If the clicked user is the current user, navigate to their profile page
            if (post['user_id'] == currentUserId) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfilePage(
                    userId: currentUserId!,
                    isCurrentUser: true,
                  ),
                ),
              );
            } else {
              // Navigate to the profile of the clicked user
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfilePage(
                    userId: post['user_id'],
                    isCurrentUser: false,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // If we literally have no user ID loaded, show a spinner or do a fallback
    if (currentUserId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E1E1E),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> pages = [
      _buildHomeContent(),
      JobsPage(userRole: userRole ?? ""),
      const MessagesPage(),
      UserProfilePage(userId: currentUserId!, isCurrentUser: true),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Neutral light grey background
      body: pages[_currentIndex],
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
        onPressed: () async {
          if (currentUserId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Error: Unable to retrieve user information"),
              ),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePostPage(userId: currentUserId!),
            ),
          ).then((_) => _fetchPosts());
        },
        child: const Icon(Icons.add),
      )
          : null,
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: const Color(0xFF2C3E50), // Lux-themed background color
          primaryColor: const Color(0xFFE74C3C), // Selected item color
          textTheme: Theme.of(context).textTheme.copyWith(
            bodySmall: const TextStyle(color: Colors.white),
          ),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed, // Ensures full width coloring
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              if (_currentIndex == 0) {
                _fetchPosts(); // Re-fetch posts when switching to Home
              }
            });
          },
          selectedItemColor: const Color(0xFFE74C3C),
          unselectedItemColor: Colors.white70,
          backgroundColor: const Color(0xFF2C3E50), // Ensure full coverage
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.work),
              label: "Jobs",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.message),
              label: "Messages",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}
