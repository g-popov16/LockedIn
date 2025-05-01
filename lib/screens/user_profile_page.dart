import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Import for consistency
import 'package:lockedin/main.dart'; // Assuming main.dart has SignInPage for logout
import 'package:lockedin/screens/team_page.dart';
import 'package:url_launcher/url_launcher.dart';
import '../sql.dart';
import '../widgets/post_widget.dart';
import '../widgets/job_widget.dart';
// 1. Import AppLocalizations (Already present)
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// Import url_launcher if needed for View Resume (Keep commented if not used)
// import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'comments_dialog.dart'; // Import timeago if needed by PostWidget/JobWidget indirectly or directly here

// --- Design Colors Imported from HomePage/PostWidget ---
const Color _backgroundColor = Color(0xFF121212); // Dark background
const Color _cardBackgroundColor = Color(0xFF1F1F1F); // Slightly lighter card background
const Color _accentColor = Color(0xFFE85D5D); // Accent color for buttons, highlights
const Color _primaryTextColor = Colors.white; // Primary text (names, titles)
const Color _secondaryTextColor = Colors.white70; // Secondary text (bio, timestamps, subtitles)
const Color _placeholderColor = Colors.grey; // For placeholders
const Color _iconColor = Colors.white70; // Default icon color
const double _cardBorderRadius = 12.0; // Consistent card border radius
// --- End Design Colors ---


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
  // --- State Variables (Original Logic - Unchanged) ---
  final PostgresDB db = PostgresDB();
  String? username;
  String? _rawDbRole; // Stores the role string from DB (e.g., "ROLE_TEAM")
  String? bio;
  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> jobs = [];
  List<Map<String, dynamic>> connectionRequests = [];
  bool isLoading = true;
  bool showPosts = true;
  bool showJobs = true;
  bool showRequests = false; // Default visibility based on original logic
  bool hasTeam = false;
  String? profileImageUrl;
  // Default connection status. It will be updated by button actions.
  // Set to "self" in initState if it's the current user's profile.
  String connectionStatus = "not_connected"; // Original default state
  int? _loggedInUserId;

  // --- Lifecycle and Data Fetching Methods (Original Logic - Unchanged) ---
  @override
  void initState() {
    super.initState();
    // Set initial connection status if it's the current user's profile
    if (widget.isCurrentUser) {
      connectionStatus = "self"; // Original logic preserved
    }
    _fetchAllData(); // Fetch all data - original call preserved
  }

  // Combined fetching function called from initState (Original Logic - Unchanged)
  Future<void> _fetchAllData() async {
    // Ensure isLoading is true at the start
    if (mounted) {
      setState(() { isLoading = true; });
    } else {
      // If not mounted at the start, don't proceed
      return;
    }

    // Fetch user data first (Original Logic - Unchanged)
    await _fetchUserData();
    if (!mounted) return; // Check after user data fetch

    // Fetch other data only if component still mounted (Original Logic - Unchanged)
    // Note: The original logic didn't have an initial checkConnectionStatus call here for non-self profiles.
    // It relied on the default "not_connected" state until an action changed it.
    if (widget.isCurrentUser) {
      await _fetchConnectionRequests();
      if (!mounted) return;
    }
    // Fetch posts and jobs regardless of connection status (as per original logic)
    await _fetchPostsAndJobs();
    if (!mounted) return;

    // Set loading to false after all fetches are complete (or have failed)
    // Original logic implicitly handled this within the methods or at the end here.
    // Let's explicitly ensure it's set false if still mounted.
    if (mounted) {
      setState(() { isLoading = false; });
    }
  }

  // Helper remains the same, takes raw DB role and l10n instance (Original Logic - Unchanged)
  String _getLocalizedRole(String? dbRole, AppLocalizations l10n) {
    switch (dbRole) {
      case "ROLE_USER": return l10n.roleUser;
      case "ROLE_ADMIN": return l10n.roleAdmin;
      case "ROLE_SPONSOR": return l10n.roleSponsor;
      case "ROLE_TEAM": return l10n.roleTeam;
      default: return l10n.roleUnknown;
    }
  }

  Future<void> _fetchUserData() async {
    // (Original Logic - Unchanged)
    try {
      final user = await db.getUserById(widget.userId);
      if (!mounted) return;

      if (user == null) {
        // Original logic didn't explicitly handle null user this way,
        // but throwing helps catch issues. Let's keep the original implicit handling
        // which might result in "Unknown User" displayed. If you prefer explicit
        // error handling, uncomment the throw or set an error state.
        // throw Exception("User not found in database.");
        if(mounted) {
          setState(() {
            username = "User Not Found"; // Or keep null/default? Reverting to closer to original:
            username = null; // Or user["username"] default ""
            //isLoading = false; // Let _fetchAllData handle this
          });
        }
        return; // Stop if user not found
      }

      final String? fetchedDbRole = user["roles"] ?? user["role"];
      final String? fetchedProfileUrl = user["profile_pic_url"];

      bool teamExists = await db.isUserInTeam(widget.userId);
      if (!mounted) return;
      bool isTeamCreator = await db.isUserTeamCreator(widget.userId);
      if (!mounted) return;

      setState(() {
        username = user["username"] ?? "Unknown User"; // Original default
        _rawDbRole = fetchedDbRole;
        bio = user["bio"];
        profileImageUrl = (fetchedProfileUrl != null && fetchedProfileUrl.isNotEmpty) ? fetchedProfileUrl : null;
        hasTeam = teamExists || isTeamCreator;
      });

    } catch (e) {
      print("Error fetching user data: $e");
      // Original logic didn't explicitly set isLoading=false here.
      // Handle error state if needed, e.g., show a message
      if(mounted) {
        setState(() {
          username = "Error Loading"; // Indicate error
        });
      }
    }
    // isLoading is handled by _fetchAllData
  }

  // Removed _checkConnectionStatus function as it wasn't in the original third file's logic.
  // The original relied on the initial state and button actions to update connectionStatus.

  Future<void> _fetchConnectionRequests() async {
    // (Original Logic - Unchanged)
    if (!widget.isCurrentUser) return;
    try {
      final requests = await db.getConnectionRequests(widget.userId);
      if (!mounted) return;
      setState(() {
        connectionRequests = requests;
        showRequests = requests.isNotEmpty; // Original logic based on results
      });
    } catch (e) {
      print("Error fetching connection requests: $e");
      if (mounted) { // Clear on error as per good practice (might differ from original implicit handling)
        setState(() { connectionRequests = []; showRequests = false; });
      }
    }
  }

  Future<void> _sendConnectionRequest() async {
    // (Original Logic - Unchanged)
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final int? currentUserId = await db.getCurrentUserId();
      if (!mounted) return;
      if (currentUserId == null || currentUserId == widget.userId) {
        // Original logic might have shown a snackbar here
        if (currentUserId == widget.userId && mounted) {
          scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.connectErrorSelf), backgroundColor: Colors.orangeAccent));
        }
        return;
      }
      await db.sendConnectionRequest(currentUserId: currentUserId, connectionId: widget.userId);
      if (!mounted) return;
      // Update status *after* successful request (Original Logic - Unchanged)
      setState(() { connectionStatus = "pending"; });
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.connectRequestSentSuccess), backgroundColor: Colors.green));
    } catch (e) {
      print("Error sending connection request: $e");
      if (mounted) { scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.connectRequestProcessError), backgroundColor: Colors.redAccent)); }
    }
  }

  Future<void> _cancelConnectionRequest() async {
    // (Original Logic - Unchanged)
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final int? currentUserId = await db.getCurrentUserId();
      if (!mounted || currentUserId == null) return;
      await db.cancelConnectionRequest(currentUserId: currentUserId, connectionId: widget.userId);
      if (!mounted) return;
      // Update status *after* successful cancellation (Original Logic - Unchanged)
      setState(() { connectionStatus = "not_connected"; });
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.connectRequestCanceledSuccess), backgroundColor: Colors.orangeAccent));
    } catch (e) {
      print("Error cancelling connection request: $e");
      if (mounted) { scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.connectRequestProcessError), backgroundColor: Colors.redAccent)); }
    }
  }

  Future<void> _removeConnection() async {
    // (Original Logic - Unchanged)
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final int? currentUserId = await db.getCurrentUserId();
      if (!mounted || currentUserId == null) return;
      await db.removeConnection(currentUserId: currentUserId, connectionId: widget.userId);
      if (!mounted) return;
      // Update status *after* successful removal (Original Logic - Unchanged)
      setState(() { connectionStatus = "not_connected"; });
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.connectionRemovedSuccess), backgroundColor: Colors.orangeAccent));
    } catch (e) {
      print("Error removing connection: $e");
      if (mounted) { scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.connectRequestProcessError), backgroundColor: Colors.redAccent)); }
    }
  }

  Future<void> _handleRequest(int connectionId, bool accept) async {
    // (Original Logic - Unchanged)
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      if (accept) {
        await db.acceptConnectionRequest(connectionId);
        // Original logic didn't need to change 'connectionStatus' here for incoming requests on self profile
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.connectRequestAcceptedSuccess), backgroundColor: Colors.green));
      } else {
        await db.declineConnectionRequest(connectionId);
        if (!mounted) return;
        // Status remains "not_connected" implicitly for the other user relative to current user
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.connectRequestDeclinedSuccess), backgroundColor: Colors.orangeAccent));
      }
      if (mounted) { await _fetchConnectionRequests(); } // Refresh list (Original Logic - Unchanged)
    } catch (e) {
      print("Error handling connection request: $e");
      if (mounted) { scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.connectRequestProcessError), backgroundColor: Colors.redAccent)); }
    }
  }

  Future<void> _viewApplicants(int jobId) async {
    // (Original Logic - Unchanged, applying theme to dialog)
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final applicants = await db.getApplicantsForJob(jobId);
      if (!mounted) return;
      if (applicants.isEmpty) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.jobApplicantsNone)));
        return;
      }
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: _cardBackgroundColor, // Apply theme color
        shape: const RoundedRectangleBorder( // Apply theme shape
          borderRadius: BorderRadius.vertical(top: Radius.circular(_cardBorderRadius)),
        ),
        builder: (BuildContext context) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.applicantsTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryTextColor)), // Apply theme text style
                Divider(color: _secondaryTextColor.withOpacity(0.5)), // Apply theme divider
                LimitedBox(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                  child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: applicants.length,
                      itemBuilder: (context, index) {
                        final applicant = applicants[index];
                        final String? resumeUrl = applicant['resume_url'] as String?;
                        return ListTile(
                          // Apply theme text styles
                          title: Text(applicant["username"] ?? l10n.roleUnknown, style: const TextStyle(color: _primaryTextColor)),
                          subtitle: Text(applicant["email"] ?? 'No email', style: const TextStyle(color: _secondaryTextColor)),
                          trailing: ElevatedButton(
                            onPressed: (resumeUrl != null && resumeUrl.isNotEmpty)
                                ? () async {
                              final Uri? uri = Uri.tryParse(resumeUrl);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(l10n.jobResumeOpenError), backgroundColor: Colors.redAccent)
                                  );
                                }
                                print('Could not launch $resumeUrl');
                              }
                            }
                                : null, // Disable button if no URL
                            // Apply theme button style
                            style: ElevatedButton.styleFrom(backgroundColor: _accentColor, foregroundColor: _primaryTextColor),
                            child: Text(l10n.viewResumeButton),
                          ),
                        );
                      }
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      // Apply theme text button style
                      child: Text(l10n.closeButton, style: const TextStyle(color: _accentColor))
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print("Error viewing applicants: $e");
      if (mounted) { scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.jobApplicantsFetchError), backgroundColor: Colors.redAccent)); }
    }
  }

  Future<void> _logOut() async {
    // (Original Logic - Unchanged)
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await db.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SignInPage()), (route) => false);
    } catch (e) {
      print("Error logging out: $e");
      if (mounted) { scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.logOutFailedError), backgroundColor: Colors.redAccent)); }
    }
  }

  Future<void> _fetchPostsAndJobs() async {
    // (Original Logic - Unchanged)
    try {
      final int? loggedInUserId = await db.getCurrentUserId();
      if (!mounted || loggedInUserId == null) {
        print("Cannot fetch posts/jobs: currentUserId not available.");
        // Original logic might not have explicitly set isLoading false here.
        // It would be handled by _fetchAllData potentially.
        // if(mounted) setState(() => isLoading = false);
        return;
      }

      final data = await db.getUserPostsAndJobs(widget.userId, loggedInUserId);
      if (!mounted) return;
      setState(() {
        posts = (data["posts"] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
        jobs = (data["jobs"] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
      });
    } catch (e) {
      print("Error fetching posts and jobs: $e");
      if (mounted) { // Good practice to clear on error
        setState(() { posts = []; jobs = []; });
      }
    }
    // isLoading=false is handled by _fetchAllData
  }


  // --- UI Building Methods (Applying Design to Original Logic) ---

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String displayRole = _getLocalizedRole(_rawDbRole, l10n);

    // Original Scaffold structure
    return Scaffold(
      // Apply background color
      backgroundColor: _backgroundColor, // Was Color(0xFF1E1E1E) in original, now matches HomePage
      body: isLoading
      // Apply themed loading indicator
          ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_accentColor)))
          : CustomScrollView( // Original CustomScrollView structure
        slivers: [
          SliverAppBar(
            // Original AppBar properties
            expandedHeight: 250, // Original value
            pinned: true, // Original value
            // Apply themed background and icon colors
            backgroundColor: _cardBackgroundColor, // Was Color(0xFF343a40), now matches HomePage cards
            iconTheme: const IconThemeData(color: _primaryTextColor), // Was Colors.white
            flexibleSpace: FlexibleSpaceBar(
              // Original FlexibleSpaceBar structure
              background: Container(
                // Apply themed background color
                  color: _cardBackgroundColor, // Was Color(0xFF343a40)
                  child: Padding(
                    // Original Padding
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      // Original Column structure
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // AppBar Content (Avatar, Name, Role, Connection Button)
                        // Apply top padding based on status bar + original spacing
                        SizedBox(height: MediaQuery.of(context).padding.top + 10), // Original spacing logic
                        if (widget.isCurrentUser) // Original condition
                          Align( // Original Alignment
                            alignment: Alignment.topRight,
                            child: ElevatedButton.icon(
                              onPressed: _logOut, // Original action
                              // Apply themed icon
                              icon: const Icon(Icons.logout, color: _primaryTextColor, size: 18), // Was Colors.white
                              // Apply themed text
                              label: Text(l10n.logOutButton, style: const TextStyle(fontSize: 14, color: _primaryTextColor)), // Was default style
                              // Apply themed button style
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accentColor.withOpacity(0.8), // Was Colors.redAccent
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Original padding
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Original shape
                                elevation: 0, // Flat look consistent with theme
                              ),
                            ),
                          ),
                        const SizedBox(height: 10), // Original spacing
                        // Apply themed CircleAvatar
                        CircleAvatar(
                          radius: 40, // Original radius
                          backgroundColor: _placeholderColor.withOpacity(0.3), // Was Colors.grey.shade700
                          // Use CachedNetworkImageProvider for consistency
                          backgroundImage: (profileImageUrl != null) ? CachedNetworkImageProvider(profileImageUrl!) : null, // Was NetworkImage
                          child: (profileImageUrl == null)
                          // Apply themed placeholder text/icon (original used Text)
                              ? const Icon(Icons.person, size: 40, color: _secondaryTextColor) // Changed from Text to Icon
                          // Was: Text(username?.isNotEmpty == true ? username![0].toUpperCase() : "?", style: const TextStyle(fontSize: 40, color: Colors.blueAccent, fontWeight: FontWeight.bold))
                              : null,
                        ),
                        const SizedBox(height: 10), // Original spacing
                        Text( // Original Username Text
                          username ?? l10n.roleUnknown, // Original logic
                          // Apply themed text style
                          style: const TextStyle(color: _primaryTextColor, fontSize: 24, fontWeight: FontWeight.bold), // Was Colors.white
                          textAlign: TextAlign.center, // Original alignment
                        ),
                        const SizedBox(height: 5), // Original spacing
                        Text( // Original Role Text
                          l10n.userProfileRoleLabel(displayRole), // Original logic
                          // Apply themed text style
                          style: const TextStyle(color: _secondaryTextColor, fontSize: 16), // Was Colors.white70
                          textAlign: TextAlign.center, // Original alignment
                        ),
                        const SizedBox(height: 10), // Original spacing
                        // Use original condition and call the themed button builder
                        if (!widget.isCurrentUser) _buildConnectionButton(l10n), // Calls themed button builder
                        const SizedBox(height: 16), // Original spacing
                      ],
                    ),
                  )
              ),
            ),
          ),

          SliverToBoxAdapter( // Original structure
            child: Padding(
              padding: const EdgeInsets.all(16.0), // Original padding
              child: Column(
                // Original Column structure
                crossAxisAlignment: CrossAxisAlignment.start, // Original alignment
                children: [

                  // Moved Team Button Section (Original Logic - Unchanged)
                  // Apply themed button style
                  if ((_rawDbRole == "ROLE_TEAM" || _rawDbRole == "ROLE_USER") && hasTeam) // Original condition
                    Padding( // Original padding
                      padding: const EdgeInsets.only(bottom: 20.0), // Original spacing
                      child: ElevatedButton.icon( // Using icon for consistency
                        onPressed: () { // Original action
                          Navigator.push(context, MaterialPageRoute(builder: (context) => TeamPage(userId: widget.userId, userRole: _rawDbRole!)));
                        },
                        // Apply themed icon and text
                        icon: const Icon(Icons.group, size: 18, color: _primaryTextColor),
                        label: Text(l10n.viewTeamButton, style: const TextStyle(color: _primaryTextColor)), // Original text
                        // Apply themed button style
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor, // Use theme accent
                          foregroundColor: _primaryTextColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Use consistent radius or original shape
                          elevation: 1,
                        ),
                      ),
                    ),
                  // End Moved Team Button Section


                  // Bio Section (Original structure)
                  // Apply themed title text style
                  Text(l10n.bioLabel, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: _primaryTextColor)), // Was Colors.blueAccent
                  // Apply themed divider color
                  Divider(thickness: 1, color: _cardBackgroundColor), // Was Colors.white30
                  // Apply themed body text style
                  Text(bio?.isNotEmpty == true ? bio! : l10n.userBioNone, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: _secondaryTextColor)), // Default style adjusted color
                  const SizedBox(height: 20), // Original spacing

                  // Connection Requests Section (Original structure and logic)
                  if (widget.isCurrentUser) // Original condition
                    _buildCollapsibleSection( // Use themed collapsible builder
                      title: l10n.connectionRequestsSectionTitle, // Original title
                      isVisible: showRequests, // Original state variable
                      onToggle: () => setState(() { showRequests = !showRequests; }), // Original action
                      child: connectionRequests.isEmpty // Original condition
                      // Apply themed empty state text style
                          ? Padding( // Add padding for better visual
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(child: Text(l10n.connectionRequestsNone, style: const TextStyle(fontSize: 14, color: _secondaryTextColor))), // Was font 16, white54
                      )
                          : Column( // Original structure
                        children: connectionRequests.map((request) {
                          // Original ListTile structure
                          return ListTile(
                            leading: CircleAvatar( // Add avatar for consistency
                              radius: 20,
                              backgroundColor: _placeholderColor.withOpacity(0.3),
                              backgroundImage: request['profile_pic_url'] != null
                                  ? CachedNetworkImageProvider(request['profile_pic_url']!)
                                  : null,
                              child: request['profile_pic_url'] == null
                                  ? const Icon(Icons.person, size: 20, color: _secondaryTextColor)
                                  : null,
                            ),
                            // Apply themed text styles
                            title: Text(request["username"] ?? l10n.roleUnknown, style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryTextColor)), // Was Colors.white
                            subtitle: Text(l10n.connectionRequestIncomingSubtitle, style: const TextStyle(color: _secondaryTextColor)), // Was Colors.white70
                            trailing: Row( // Original structure
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Apply themed icons
                                IconButton(icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent), tooltip: l10n.acceptRequestTooltip, onPressed: () => _handleRequest(request["id"], true)), // Was check, green
                                IconButton(icon: const Icon(Icons.highlight_off, color: Colors.redAccent), tooltip: l10n.declineRequestTooltip, onPressed: () => _handleRequest(request["id"], false)), // Was close, red
                              ],
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 0), // Adjust padding slightly
                          );
                        }).toList(),
                      ),
                    ),
                  if (widget.isCurrentUser) const SizedBox(height: 20), // Add consistent spacing

                  // --- Posts Section --- (Original structure and logic)
                  _buildCollapsibleSection( // Use themed collapsible builder
                    title: l10n.postsSectionTitle, // Original title
                    isVisible: showPosts, // Original state variable
                    onToggle: () => setState(() { showPosts = !showPosts; }), // Original action
                    child: posts.isEmpty // Original condition
                    // Apply themed empty state text style
                        ? Padding( // Add padding for better visual
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(child: Text(l10n.postsNone, style: const TextStyle(fontSize: 14, color: _secondaryTextColor))), // Was font 16, white54
                    )
                        : Column( // Original structure
                      children: posts.map((post) {
                        final int postId = post["id"] ?? 0;
                        final bool isLikedByCurrentUser = post["is_liked"] ?? false; // Capture initial state
                        final int initialLikes = post["likes_count"] ?? 0; // Capture initial count

                        // Return the widget for this specific post
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: PostWidget(
                            key: ValueKey(postId), // Use the defined postId
                            postId: postId,       // Pass the defined postId
                            content: post["content"] ?? '',
                            userId: post["user_id"] ?? 0,
                            username: post["username"] ?? l10n.roleUnknown,
                            // Pass the captured initial state, PostWidget manages its own internal state update visually
                            likes: initialLikes,
                            isLiked: isLikedByCurrentUser,
                            createdAt: post["created_at"] ?? DateTime.now().toIso8601String(),
                            profileImageUrl: post["profile_image_url"],
                            imageUrl: post["image_url"],
                            // --- onLikePressed uses the defined postId ---
                            onLikePressed: () async {
                              if (_loggedInUserId == null) return;
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              try {
                                // Use the postId defined above
                                final newCount = await db.toggleLikePost(postId, _loggedInUserId!);
                                if (!mounted) return;
                                // Update the source data list in the state
                                setState(() {
                                  final postIndex = posts.indexWhere((p) => p['id'] == postId);
                                  if (postIndex != -1) {
                                    posts[postIndex]['likes_count'] = newCount;
                                    posts[postIndex]['is_liked'] = !posts[postIndex]['is_liked']; // Toggle the flag in the source data
                                  }
                                });
                              } catch (e) {
                                print("Error toggling like from profile: $e");
                                if(mounted) {
                                  scaffoldMessenger.showSnackBar(
                                      SnackBar(content: Text(l10n.errorLikingPost), backgroundColor: Colors.redAccent)
                                  );
                                }
                              }
                            },
                            // --- onCommentPressed uses the defined postId ---
                            onCommentPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                barrierColor: Colors.black.withOpacity(0.6),
                                builder: (BuildContext context) {
                                  // Use the postId defined above
                                  return CommentsDialog(
                                    postId: postId,
                                    // onCommentAdded: () { }, // Optional
                                  );
                                },
                              );
                            },
                            onNicknameTap: null,
                          ),
                        );
                      }).toList(), // End of map function
                    ),
                  ),
                  const SizedBox(height: 20), // Spacing after Posts section


                  // --- Jobs Section --- (Original structure and logic)
                  _buildCollapsibleSection( // Use themed collapsible builder
                    title: l10n.jobsSectionTitle, // Original title
                    isVisible: showJobs, // Original state variable
                    onToggle: () => setState(() { showJobs = !showJobs; }), // Original action
                    child: jobs.isEmpty // Original condition
                    // Apply themed empty state text style
                        ? Padding( // Add padding for better visual
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(child: Text(l10n.jobsNone, style: const TextStyle(fontSize: 14, color: _secondaryTextColor))), // Was font 16, white54
                    )
                        : Column( // Original structure
                      children: jobs.map((job) {
                        // Use JobWidget directly - assuming it's themed similarly
                        return Padding(
                          // Use consistent vertical padding
                          padding: const EdgeInsets.symmetric(vertical: 4.0), // Was 8.0
                          child: JobWidget(
                            // Pass all original parameters
                            key: ValueKey(job["id"]), // Add key
                            jobId: job["id"] ?? 0,
                            title: job["title"] ?? '',
                            company: job["company"] ?? '',
                            description: job["description"] ?? '',
                            createdAt: job["created_at"] ?? DateTime.now().toIso8601String(),
                            postedBy: job["posted_by"] ?? 0,
                            currentUserId: _loggedInUserId,
                            posterRole: job["role"], // Original logic
                            onJobUpdated: () { _fetchPostsAndJobs(); }, // Original action
                            onApply: () { // Original action
                              if (widget.isCurrentUser && job["posted_by"] == widget.userId) {
                                // Original logic
                                if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.jobApplyErrorSelf), backgroundColor: Colors.orangeAccent));
                              } else {
                                // Original logic
                                print("Apply logic for job ${job['id']}");
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Apply action triggered for ${job['title']}"), backgroundColor: Colors.blueAccent));
                              }
                            },
                            // Pass original callback correctly
                            onViewApplicants: (widget.isCurrentUser && job["posted_by"] == widget.userId) ? () => _viewApplicants(job["id"]) : null, // Original logic
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24), // Add consistent bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  // Build connection button uses the 'connectionStatus' state variable (Original Logic - Unchanged)
  // Applies themed styling to the original button logic
  Widget _buildConnectionButton(AppLocalizations l10n) {
    final buttonStyle = ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), // Pill shape like theme examples
        elevation: 1,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
    );

    // Original switch statement logic preserved
    switch (connectionStatus) {
      case "connected":
        return ElevatedButton.icon(
            onPressed: _removeConnection, // Original action
            // Apply themed icon and text
            icon: const Icon(Icons.person_remove_outlined, size: 18, color: _primaryTextColor),
            label: Text(l10n.removeConnectionButton, style: TextStyle(color: _primaryTextColor)), // Original text
            // Apply themed style
            style: buttonStyle.copyWith(
              backgroundColor: MaterialStateProperty.all(_secondaryTextColor.withOpacity(0.5)), // Muted theme color
              foregroundColor: MaterialStateProperty.all(_primaryTextColor),
            )
        );
      case "pending": // Request sent BY current user TO this profile user
        return ElevatedButton.icon(
            onPressed: _cancelConnectionRequest, // Original action
            // Apply themed icon and text
            icon: const Icon(Icons.cancel_schedule_send_outlined, size: 18, color: _primaryTextColor),
            label: Text(l10n.cancelRequestButton, style: TextStyle(color: _primaryTextColor)), // Original text
            // Apply themed style
            style: buttonStyle.copyWith(
              backgroundColor: MaterialStateProperty.all(Colors.orangeAccent.withOpacity(0.8)), // Consistent orange
              foregroundColor: MaterialStateProperty.all(_primaryTextColor),
            )
        );
    // Note: Original logic didn't have a distinct "pending_incoming" state visible here.
    // Incoming requests are handled in the list section.
      case "self":
        return const SizedBox.shrink(); // Original logic: No button on own profile
      case "not_connected": // Falls through to default (Original Logic)
      default:
        return ElevatedButton.icon(
            onPressed: _sendConnectionRequest, // Original action
            // Apply themed icon and text
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18, color: _primaryTextColor),
            label: Text(l10n.connectButton, style: TextStyle(color: _primaryTextColor)), // Original text
            // Apply themed style
            style: buttonStyle.copyWith(
              backgroundColor: MaterialStateProperty.all(_accentColor), // Use theme accent color
              foregroundColor: MaterialStateProperty.all(_primaryTextColor),
            )
        );
    }
  }

  // Build collapsible section - (Original Logic - Unchanged)
  // Applies themed styling to the original structure
  Widget _buildCollapsibleSection({
    required String title,
    required bool isVisible,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    // Original Column structure
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell( // Original InkWell
          onTap: onToggle, // Original action
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0), // Original padding
            child: Row( // Original Row
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Apply themed title style
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryTextColor)), // Was 20, blueAccent
                // Apply themed icon color
                Icon(isVisible ? Icons.expand_less : Icons.expand_more, color: _secondaryTextColor), // Was blueAccent
              ],
            ),
          ),
        ),
        // Apply themed divider color
        Divider(thickness: 1, color: _cardBackgroundColor), // Was white30
        AnimatedCrossFade( // Original AnimatedCrossFade
          firstChild: Container(height: 0), // Prevent jump (good practice, might differ slightly from original)
          secondChild: Padding( // Add padding consistently
              padding: const EdgeInsets.only(top: 8.0),
              child: child
          ),
          crossFadeState: isVisible ? CrossFadeState.showSecond : CrossFadeState.showFirst, // Original state logic
          duration: const Duration(milliseconds: 300), // Original duration
          // Add curves for smoother animation consistent with theme examples
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeIn,
          sizeCurve: Curves.fastOutSlowIn,
        ),
      ],
    );
  }
}