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
  String? userRole; // User role fetched from the database
  int? currentUserId; // Store the current user ID for profile

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _fetchCurrentUserId();
    _fetchPosts();
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
      print("Error fetching user role: $e");
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
      print("Error fetching current user ID: $e");
    }
  }

  Future<void> _fetchPosts() async {
    if (_currentIndex != 0) return; // Only fetch posts for the Home tab
    setState(() {
      isLoading = true;
    });

    try {
      final fetchedPosts = await db.getPostsPaginated(limit: 10, offset: 0);
      setState(() {
        posts = fetchedPosts.map((post) {
          return {
            ...post,
            "created_at": post["created_at"].toString(),
          };
        }).toList();
      });
    } catch (e) {
      print("Error fetching posts: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildHomeContent() {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : posts.isEmpty
            ? const Center(child: Text("No posts available."))
            : ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return PostWidget(
                    postId: post['id'],
                    content: post['content'],
                    userId: post['user_id'],
                    username: post['username'],
                    likes: post['likes_count'],
                    createdAt: post['created_at'],
                    commentsCount: post['comments_count'],
                    onLikePressed: () async {
                      try {
                        await db.likePost(post['id']);
                        setState(() {
                          post['likes_count'] += 1;
                        });
                      } catch (e) {
                        print("Error liking post: $e");
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Failed to like post")),
                        );
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
    if (currentUserId == null) {
      return const Center(child: CircularProgressIndicator());
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
                        content:
                            Text("Error: Unable to retrieve user information")),
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
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              if (_currentIndex == 0) {
                _fetchPosts(); // Fetch posts when switching to Home tab
              }
            });
          },
          selectedItemColor: const Color(0xFFE74C3C), // Selected item color
          unselectedItemColor: Colors.white70, // Unselected item color
          backgroundColor: const Color(0xFF2C3E50), // Background color
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
