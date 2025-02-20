import 'package:flutter/material.dart';
import '../screens/user_profile_page.dart';
import '../screens/edit_job_page.dart';
import 'package:timeago/timeago.dart' as timeago;

class JobWidget extends StatelessWidget {
  final int jobId;
  final String title;
  final String company;
  final String description;
  final String createdAt;
  final int postedBy;
  final int? currentUserId;
  final String? posterRole;

  final VoidCallback onApply;
  final VoidCallback? onViewApplicants;
  final VoidCallback? onAcceptApplication; // Accept application callback
  final VoidCallback? onDeclineApplication; // Decline application callback

  // This is critical for reloading the jobs list in the parent (JobsPage):
  final VoidCallback onJobUpdated;

  const JobWidget({
    super.key,
    required this.jobId,
    required this.title,
    required this.company,
    required this.description,
    required this.createdAt,
    required this.postedBy,
    this.currentUserId,
    this.posterRole,
    required this.onApply,
    this.onViewApplicants,
    this.onAcceptApplication,
    this.onDeclineApplication,
    required this.onJobUpdated, // Pass from JobsPage
  });

  @override
  Widget build(BuildContext context) {
    final DateTime createdTime = DateTime.parse(createdAt);
    final String timeAgo = timeago.format(createdTime);

    String viewRoleText;
    if (posterRole == "team") {
      viewRoleText = "View Team";
    } else if (posterRole == "sponsor") {
      viewRoleText = "View Sponsor";
    } else {
      viewRoleText = "View Poster";
    }

    return Card(
      color: const Color(0xFF343a40), // Dark card color
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + Timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            timeAgo,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
              ],
            ),
            const SizedBox(height: 8),

            // Company + Poster Role
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
          Text(
            "Company: $company",
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          if (currentUserId != postedBy)
            GestureDetector(
              onTap: () {
                Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfilePage(
                userId: postedBy,
                isCurrentUser: currentUserId == postedBy,
              ),
            ),
                );
              },
              child: Text(
                viewRoleText,
                style: const TextStyle(
            color: Colors.blueAccent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
                ),
              ),
            ),
              ],
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              description,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 12),

            // Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
          ElevatedButton(
            onPressed: onApply,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C), // 'Apply' color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Apply",
              style: TextStyle(color: Colors.black),
            ),
          ),
          // Buttons for the job poster
          if (currentUserId == postedBy) ...[
            ElevatedButton(
              onPressed: onViewApplicants,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "View Applicants",
                style: TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Go to EditJobPage, pass in a callback to update the list
                Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditJobPage(
                jobId: jobId,
                initialTitle: title,
                initialCompany: company,
                initialDescription: description,
                onJobUpdated: onJobUpdated, // triggers refresh
              ),
            ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, // Edit job color
                shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Edit",
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
