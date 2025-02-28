import 'package:flutter/material.dart';
import 'package:lockedin/main.dart';
import 'package:lockedin/screens/team_page.dart';
import '../sql.dart';
import '../widgets/post_widget.dart';
import '../widgets/job_widget.dart';

class UserProfilePage extends StatefulWidget {
  final int userId;
  final bool isCurrentUser;


  const UserProfilePage({
    super.key,
    required this.userId,
    this.isCurrentUser = false,
  });

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final PostgresDB db = PostgresDB();
  String? username;
  String? role;
  String? bio;
  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> jobs = [];
  List<Map<String, dynamic>> connectionRequests = [];
  bool isLoading = true;
  bool showPosts = true;
  bool showJobs = true;
  bool showRequests = false;
  bool hasTeam = false;

  String? profileImageUrl; // ✅ Store Firebase URL properly

  String connectionStatus =
      "not_connected"; // Can be "not_connected", "pending", or "connected"

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    if (widget.isCurrentUser) {
      _fetchConnectionRequests();
    }
    _fetchPostsAndJobs();
  }

  String formatRole(String? role) {
    switch (role) {
      case "ROLE_USER":
        return "User";
      case "ROLE_ADMIN":
        return "Admin";
      case "ROLE_SPONSOR":
        return "Sponsor";
      case "ROLE_TEAM":
        return "Team";
      default:
        print("❌ Unknown Role received: $role"); // Debugging
        return "Unknown Role";
    }
  }


  Future<void> _fetchUserData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 1️⃣ Fetch user details
      final user = await db.getUserById(widget.userId);

      if (user == null) {
        throw Exception("User not found in database.");
      }

      print("🔍 Full user data from DB: $user"); // Debugging

      // 2️⃣ Extract Role (Fix: Ensure it's accessed correctly)
      final String? fetchedRole = user["roles"] ?? user["role"]; // Ensure correct key
      final String? fetchedProfileUrl = user["profile_pic_url"];

      print("🔍 Role from DB: $fetchedRole"); // Debugging

      bool teamExists = await db.isUserInTeam(widget.userId);
      bool isTeamCreator = await db.isUserTeamCreator(widget.userId);

      // 3️⃣ Ensure valid role and profile picture URL
      setState(() {
        username = user["username"] ?? "Unknown User";
        role = formatRole(fetchedRole ?? "Unknown"); // ✅ Ensure role is passed correctly
        bio = user["bio"] ?? "No bio available.";
        profileImageUrl = (fetchedProfileUrl != null && fetchedProfileUrl.isNotEmpty)
            ? fetchedProfileUrl
            : "https://via.placeholder.com/150"; // Default Placeholder\
        hasTeam = teamExists || isTeamCreator;
        isLoading = false;
      });

      print("✅ Processed Role: $role"); // Debugging
    } catch (e) {
      print("❌ Error fetching user data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchConnectionRequests() async {
    try {
      final requests = await db.getConnectionRequests(widget.userId);
      setState(() {
        connectionRequests = requests;
        showRequests = requests.isNotEmpty;
      });
    } catch (e) {
      print("Error fetching connection requests: $e");
    }
  }

  Future<void> _sendConnectionRequest() async {
    try {
      final int? currentUserId = await db.getCurrentUserId();
      print(
          "Current User ID: $currentUserId, Target User ID: ${widget.userId}"); // Debugging Line

      if (currentUserId == null || currentUserId == widget.userId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("You cannot send a request to yourself!")),
        );
        return;
      }

      await db.sendConnectionRequest(
        currentUserId: currentUserId,
        connectionId: widget.userId,
      );

      setState(() {
        connectionStatus = "pending";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection request sent!")),
      );
    } catch (e) {
      print("Error sending connection request: $e");
    }
  }

  Future<void> _cancelConnectionRequest() async {
    try {
      final int? currentUserId = await db.getCurrentUserId();
      if (currentUserId == null) return;

      await db.cancelConnectionRequest(
          currentUserId: currentUserId, connectionId: widget.userId);

      setState(() {
        connectionStatus = "not_connected";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection request canceled.")),
      );
    } catch (e) {
      print("Error canceling connection request: $e");
    }
  }

  Future<void> _removeConnection() async {
    try {
      final int? currentUserId = await db.getCurrentUserId();
      if (currentUserId == null) return;

      await db.removeConnection(
          currentUserId: currentUserId, connectionId: widget.userId);

      setState(() {
        connectionStatus = "not_connected";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection removed.")),
      );
    } catch (e) {
      print("Error removing connection: $e");
    }
  }

  Widget _buildConnectionButton() {
    switch (connectionStatus) {
      case "connected":
        return ElevatedButton(
          onPressed: _removeConnection,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
          ),
          child: const Text("Remove Connection"),
        );
      case "pending":
        return ElevatedButton(
          onPressed: _cancelConnectionRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text("Cancel Request"),
        );
      case "not_connected":
      default:
        return ElevatedButton(
          onPressed: _sendConnectionRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C3E50),
            foregroundColor: Colors.white,
          ),
          child: const Text("Connect"),
        );
    }
  }

  Widget _buildCollapsibleSection({
    required String title,
    required bool isVisible,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              Icon(
                isVisible ? Icons.expand_less : Icons.expand_more,
                color: Colors.blueAccent,
              ),
            ],
          ),
        ),
        const Divider(thickness: 1, color: Colors.white30),
        if (isVisible) child,
      ],
    );
  }

  Future<void> _handleRequest(int connectionId, bool accept) async {
    try {
      if (accept) {
        await db.acceptConnectionRequest(connectionId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connection request accepted!")),
        );
      } else {
        await db.declineConnectionRequest(connectionId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connection request declined.")),
        );
      }
      await _fetchConnectionRequests();
    } catch (e) {
      print("Error handling connection request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to process the request.")),
      );
    }
  }

  Future<void> _viewApplicants(int jobId) async {
    try {
      final applicants = await db.getApplicantsForJob(jobId);
      if (applicants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No applicants for this job.")),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          print("🐞 userProfileImage is null? ${profileImageUrl == null}");
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Applicants",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                ...applicants.map((applicant) {
                  return ListTile(
                    title: Text(applicant["username"]),
                    subtitle: Text(applicant["email"]),
                    trailing: ElevatedButton(
                      onPressed: () {
                        print("Viewing resume: ${applicant['resume_link']}");
                      },
                      child: const Text("View Resume"),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print("Error viewing applicants: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load applicants.")),
      );
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    print("🐞 Checking role before rendering UI: $role");

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Dark background
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: const Color(0xFF343a40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    if (widget.isCurrentUser)
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: ElevatedButton.icon(
                            onPressed: _logOut,
                            icon: const Icon(
                              Icons.logout,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: const Text(
                              "Log Out",
                              style: TextStyle(fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      backgroundImage: (profileImageUrl != null &&
                          profileImageUrl!.isNotEmpty)
                          ? NetworkImage(profileImageUrl!)
                          : null,
                      child: (profileImageUrl == null ||
                          profileImageUrl!.isEmpty)
                          ? Text(
                        username != null
                            ? username![0].toUpperCase()
                            : "?",
                        style: const TextStyle(
                            fontSize: 40,
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold),
                      )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      username ?? "Unknown User",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (role != null)
                      Text(
                        "Role: $role",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (!widget.isCurrentUser) _buildConnectionButton(),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  if (widget.isCurrentUser)
              _buildCollapsibleSection(
              title: "Connection Requests",
              isVisible: showRequests,
              onToggle: () => setState(() {
                showRequests = !showRequests;
              }),
              child: connectionRequests.isEmpty
                  ? const Text(
                "No connection requests.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white54,
                ),
              )
                  : Column(
                children: connectionRequests.map((request) {
                  return ListTile(
                    title: Text(
                      request["username"],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    subtitle: const Text(
                      "Wants to connect",
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check,
                              color: Colors.green),
                          onPressed: () => _handleRequest(
                              request["id"], true),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.red),
                          onPressed: () => _handleRequest(
                              request["id"], false),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),



                  if (role != null && (role == "Team" || role == "User") && hasTeam)
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            print("🔍 Navigating to Team Page - Role: $role");
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TeamPage(
                                  userId: widget.userId,
                                  userRole: role!,
                                ),
                              ),
                            );
                          },
                          child: const Text("View Team"),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),

                  // ✅ Collapsible Section for Posts
                  _buildCollapsibleSection(
                    title: "Posts",
                    isVisible: showPosts,
                    onToggle: () => setState(() {
                      showPosts = !showPosts;
                    }),
                    child: posts.isEmpty
                        ? const Text(
                      "No posts to display.",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white54,
                      ),
                    )
                        : Column(
                      children: posts.map((post) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8.0),
                          child: PostWidget(
                            postId: post["id"],
                            content: post["content"],
                            userId: post["user_id"],
                            username: post["username"],
                            likes: post["likes_count"] ?? 0,
                            createdAt: post["created_at"],

                            isLiked: post["is_liked"] ?? false,   // <--- provide this!
                          )

                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ✅ Collapsible Section for Jobs
                  _buildCollapsibleSection(
                    title: "Jobs",
                    isVisible: showJobs,
                    onToggle: () => setState(() {
                      showJobs = !showJobs;
                    }),
                    child: jobs.isEmpty
                        ? const Text(
                      "No jobs to display.",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white54,
                      ),
                    )
                        : Column(
                      children: jobs.map((job) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8.0),
                          child: JobWidget(
                            jobId: job["id"],
                            title: job["title"],
                            company: job["company"],
                            description: job["description"],
                            createdAt: job["created_at"],
                            postedBy: job["user_id"],
                            currentUserId: widget.userId,
                            onJobUpdated: () {},
                            onApply: widget.isCurrentUser
                                ? () {}
                                : () {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "You cannot apply to your own job!"),
                                ),
                              );
                            },
                            onViewApplicants: widget.isCurrentUser
                                ? () => _viewApplicants(job["id"])
                                : () {},
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }




  Future<void> _logOut() async {
    try {
      await db.signOut(); // Call the new signOut method

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
        (route) => false,
      );

      print("✅ User logged out successfully!");
    } catch (e) {
      print("❌ Error logging out: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to log out.")),
      );
    }
  }

  Future<void> _fetchPostsAndJobs() async {
    try {
      final data = await db.getUserPostsAndJobs(widget.userId);
      setState(() {
        posts = data["posts"];
        jobs = data["jobs"];
      });
    } catch (e) {
      print("Error fetching posts and jobs: $e");
    }
  }

}
