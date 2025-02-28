import 'package:flutter/material.dart';
import '../sql.dart';

class TeamPage extends StatefulWidget {
  final int userId;
  final String userRole; // ROLE_TEAM or ROLE_USER

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
    setState(() {
      isLoading = true;
    });

    try {
      // 🔹 Get Team ID from user ID
      final team = await db.getTeamByUserId(widget.userId);

      if (team == null) {
        print("❌ No team found for user ${widget.userId}");
        setState(() {
          isLoading = false;
        });
        return;
      }

      print("✅ Team Data: $team");

      final teamId = team["id"];
      final leaderId = team["created_by"];

      // 🔹 Get Team Members
      final members = await db.getTeamMembers(teamId);

      setState(() {
        teamInfo = team;
        teamMembers = members;
        teamLeaderId = leaderId;
        isLoading = false;
      });
    } catch (e) {
      print("❌ Error fetching team data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _leaveTeam() async {
    if (teamInfo == null) return;
    final teamId = teamInfo!["id"];

    try {
      bool success = await db.leaveTeam(widget.userId, teamId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You have left the team.")),
        );
        Navigator.pop(context); // Go back after leaving
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error leaving the team.")),
        );
      }
    } catch (e) {
      print("❌ Error leaving team: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("An error occurred.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text("Team"),
        backgroundColor: const Color(0xFF2C3E50),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : teamInfo == null
          ? const Center(
        child: Text(
          "You are not part of any team.",
          style: TextStyle(color: Colors.white),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 TEAM NAME
            Text(
              "Team: ${teamInfo!["name"]}",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),

            // 🔹 TEAM LEADER
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.blueGrey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                title: Text(
                  "Leader: ${teamInfo!["leader_name"] ?? "Unknown"}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                leading: const Icon(Icons.verified, color: Colors.yellow),
              ),
            ),
            const SizedBox(height: 20),

            // 🔹 TEAM MEMBERS LIST
            const Text(
              "Team Members",
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
            const Divider(color: Colors.white30),

            teamMembers.isEmpty
                ? const Text(
              "No members yet.",
              style: TextStyle(color: Colors.white54),
            )
                : Column(
              children: teamMembers.map((member) {
                return ListTile(
                  title: Text(
                    member["username"],
                    style: const TextStyle(color: Colors.white),
                  ),
                  leading: const Icon(Icons.person, color: Colors.white),
                  trailing: widget.userId != teamLeaderId
                      ? IconButton(
                    icon: const Icon(Icons.exit_to_app, color: Colors.red),
                    onPressed: _leaveTeam,
                  )
                      : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
