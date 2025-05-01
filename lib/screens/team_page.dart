import 'package:flutter/material.dart';
import '../sql.dart';
// 1. Import AppLocalizations
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TeamPage extends StatefulWidget {
  final int userId;
  final String userRole; // Expecting raw DB role like "ROLE_TEAM", "ROLE_USER"

  const TeamPage({super.key, required this.userId, required this.userRole});

  @override
  _TeamPageState createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  final PostgresDB db = PostgresDB();
  bool isLoading = true;
  Map<String, dynamic>? teamInfo;
  List<Map<String, dynamic>> teamMembers = [];
  int? teamLeaderId;

  @override
  void initState() {
    super.initState();
    _fetchTeamData();
  }

  Future<void> _fetchTeamData() async {
    // Set loading state safely
    if (mounted) {
      setState(() { isLoading = true; });
    } else {
      return; // Don't fetch if not mounted
    }

    try {
      // Get Team Info (includes team id, name, created_by (leader id), leader_name)
      final team = await db.getTeamByUserId(widget.userId);
      if (!mounted) return;

      if (team == null) {
        setState(() { teamInfo = null; isLoading = false; });
        return;
      }

      final teamId = team["id"];
      final leaderId = team["created_by"];

      // Get Team Members
      final members = await db.getTeamMembers(teamId);
      if (!mounted) return;

      setState(() {
        teamInfo = team;
        teamMembers = members;
        teamLeaderId = leaderId;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching team data: $e");
      if (mounted) {
        setState(() { isLoading = false; });
      }
    }
  }

  Future<void> _leaveTeam() async {
    // Get l10n instance and ScaffoldMessenger safely
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (teamInfo == null) return; // Should not happen if button is shown
    final teamId = teamInfo!["id"];

    try {
      bool success = await db.leaveTeam(widget.userId, teamId);
      if (!mounted) return;

      if (success) {
        scaffoldMessenger.showSnackBar(
          // Use localized success message
          SnackBar(content: Text(l10n.teamLeaveSuccess)),
        );
        // Check mounted again before popping
        if(mounted) Navigator.pop(context);
      } else {
        scaffoldMessenger.showSnackBar(
          // Use localized error message
          SnackBar(content: Text(l10n.teamLeaveError)),
        );
      }
    } catch (e) {
      print("Error in _leaveTeam: $e");
      // Check mounted before showing generic error
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          // Use localized generic error message
          SnackBar(content: Text(l10n.teamLeaveGeneralError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2. Get AppLocalizations instance
    final l10n = AppLocalizations.of(context)!;

    // Determine if the current user is the leader (using the ID passed to the page)
    // Note: This assumes widget.userId is the ID of the person viewing the page.
    final bool isViewerLeader = (teamLeaderId != null && widget.userId == teamLeaderId);
    // Determine if the current user can leave (not the leader)
    final bool canViewerLeave = !isViewerLeader && teamInfo != null;


    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        // Use localized title
        title: Text(l10n.teamPageTitle),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white), // Ensure back button is white
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle, // Use theme style
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : teamInfo == null
          ? Center( // Center the 'not in team' message
        child: Text(
          // Use localized message
          l10n.teamNotInTeam,
          style: Theme.of(context).textTheme.bodyLarge, // Use theme text style
          textAlign: TextAlign.center,
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team Name
            Text(
              // Use localized label with placeholder
              l10n.teamPageNameLabel(teamInfo!["name"] ?? l10n.roleUnknown), // Provide fallback
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),

            // Team Leader
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(color: Colors.blueGrey, borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                title: Text(
                  // Use localized label with placeholder
                  l10n.teamPageLeaderLabel(teamInfo!["leader_name"] ?? l10n.roleUnknown), // Provide fallback
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                leading: const Icon(Icons.verified_user, color: Colors.yellow), // Changed icon slightly
              ),
            ),
            const SizedBox(height: 20),

            // Team Members List
            Text(
              // Use localized section title
              l10n.teamMembersSectionTitle,
              style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const Divider(color: Colors.white30),

            Expanded( // Make the list scrollable if it exceeds space
              child: teamMembers.isEmpty
                  ? Text(
                // Use localized empty message
                l10n.teamMembersNone,
                style: const TextStyle(color: Colors.white54),
              )
                  : ListView.builder( // Use ListView.builder for efficiency
                itemCount: teamMembers.length,
                itemBuilder: (context, index) {
                  final member = teamMembers[index];
                  final bool isThisMemberLeader = (member["id"] == teamLeaderId);
                  // Determine if the *viewer* can make *this member* leave (only leader can kick?)
                  // Or if *this member* is the viewer and can leave themselves
                  final bool showLeaveButtonForThisMember = (widget.userId == member["id"] && !isThisMemberLeader);
                  // TODO: Add logic for leader kicking members if needed

                  return ListTile(
                    title: Text(
                      member["username"] ?? l10n.roleUnknown, // Handle null username
                      style: const TextStyle(color: Colors.white),
                    ),
                    leading: Icon(
                        isThisMemberLeader ? Icons.star : Icons.person, // Show star for leader
                        color: isThisMemberLeader ? Colors.yellow : Colors.white
                    ),
                    // Show leave button only for the viewing user IF they are not the leader
                    trailing: showLeaveButtonForThisMember
                        ? IconButton(
                      icon: const Icon(Icons.exit_to_app, color: Colors.red),
                      tooltip: l10n.leaveTeamButtonTooltip, // Localized tooltip
                      onPressed: _leaveTeam, // Calls the leave function for the current user
                    )
                        : null, // No button for others or the leader
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}