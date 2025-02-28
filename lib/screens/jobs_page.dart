import 'package:flutter/material.dart';
import '../sql.dart';
import '../widgets/job_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class JobsPage extends StatefulWidget {
  final String userRole;

  const JobsPage({super.key, required this.userRole});

  @override
  _JobsPageState createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final PostgresDB db = PostgresDB();
  List<Map<String, dynamic>> jobs = [];
  bool isLoading = true;
  int? currentUserId;
  String? userRole;

  @override
  void initState() {
    super.initState();
    _fetchJobs();
    _fetchCurrentUserId();
  }

  Future<void> _fetchJobs() async {
    setState(() => isLoading = true);

    try {
      final fetchedJobs = await db.getJobs();
      setState(() {
        jobs = fetchedJobs;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching jobs: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchCurrentUserId() async {
    try {
      int? userId = await db.getCurrentUserId();
      if (userId != null) {
        setState(() {
          currentUserId = userId;
        });

        // ✅ Fetch and store user role in the local state variable
        String fetchedRole = await db.getUserRoles(userId);
        setState(() {
          userRole = fetchedRole.trim().toUpperCase();
        });

        print("🔍 User Role Retrieved: $userRole");
      }
    } catch (e) {
      print("❌ Error fetching current user ID or role: $e");
    }
  }


  // Show dialog for adding a new job
  void _showAddJobDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final companyController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Add Job Offer"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: "Job Title",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: "Job Description",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: companyController,
                  decoration: const InputDecoration(
                    labelText: "Company Name",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final description = descriptionController.text.trim();
                final company = companyController.text.trim();

                if (title.isNotEmpty &&
                    description.isNotEmpty &&
                    company.isNotEmpty) {
                  await _addJob(title, description, company);
                  Navigator.pop(context); // Close dialog
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please fill in all fields")),
                  );
                }
              },
              child: const Text("Add Job"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addJob(String title, String description, String company) async {
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Unable to retrieve user info")),
      );
      return;
    }

    try {
      await db.addJob(
        title: title,
        description: description,
        company: company,
        postedBy: currentUserId!,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Job offer added successfully!")),
      );
      _fetchJobs(); // Refresh list
    } catch (e) {
      print("Error adding job: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error adding job offer")),
      );
    }
  }

  // Show job applicants + accept/reject logic
  void _showApplicantsDialog(int jobId) async {
    try {
      final applicants = await db.getApplicantsForJob(jobId);

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Job Applicants"),
            content: applicants.isEmpty
                ? const Text("No applicants yet.")
                : SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: applicants.length,
                itemBuilder: (context, index) {
                  final applicant = applicants[index];
                  return ListTile(
                    title: Text(applicant["username"]),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Email: ${applicant["email"]}"),
                        const SizedBox(height: 5),
                        Text("Resume: ${applicant["resume_link"]}"),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'accept') {
                          await _acceptApplicant(
                            jobId,
                            applicant["user_id"],
                            applicant["application_id"],
                          );
                        } else if (value == 'reject') {
                          await db.deleteApplication(
                            applicant["application_id"],
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Application rejected!"),
                            ),
                          );
                          Navigator.pop(context);
                          _showApplicantsDialog(jobId);
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'accept',
                          child: Text('Accept'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'reject',
                          child: Text('Reject'),
                        ),
                      ],
                    ),
                    onTap: () async {
                      String url = applicant["resume_link"].trim();
                      if (!url.startsWith("http://") &&
                          !url.startsWith("https://")) {
                        url = "https://$url";
                      }

                      final Uri resumeUrl = Uri.parse(url);
                      if (await canLaunchUrl(resumeUrl)) {
                        await launchUrl(
                          resumeUrl,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Could not open the CV link."),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print("Error showing applicants: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error fetching applicants.")),
      );
    }
  }


  // Show dialog for applying to a job
  void _showCVDialog(int jobId) async {
    final cvLinkController = TextEditingController();

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: Unable to retrieve user information"),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Apply for Job"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Paste your CV link below:"),
              const SizedBox(height: 10),
              TextField(
                controller: cvLinkController,
                decoration: const InputDecoration(
                  labelText: "CV Link",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final cvLink = cvLinkController.text.trim();
                if (cvLink.isNotEmpty) {
                  await db.addApplication(
                    jobId: jobId,
                    userId: currentUserId!,
                    resumeLink: cvLink,
                  );
                  Navigator.pop(context); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Application submitted successfully!")),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please provide a valid CV link."),
                    ),
                  );
                }
              },
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading || currentUserId == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                return JobWidget(
                  jobId: job["id"],
                  title: job["title"],
                  company: job["company"],
                  description: job["description"],
                  createdAt: job["created_at"],
                  postedBy: job["posted_by"],
                  currentUserId: currentUserId,
                  posterRole: job["role"],
                  onApply: () => _showCVDialog(job["id"]),
                  onViewApplicants: job["posted_by"] == currentUserId
                      ? () => _showApplicantsDialog(job["id"])
                      : null,
                  // 1) Accept / Decline are optional callbacks from your code
                  onAcceptApplication: null,
                  onDeclineApplication: null,
                  // 2) The crucial callback to refresh after editing/deleting
                  onJobUpdated: _fetchJobs,
                );
              },
            ),
      floatingActionButton:
      (userRole != null &&
          (userRole == "ROLE_TEAM" || userRole == "ROLE_SPONSOR"))
          ? FloatingActionButton(
        onPressed: _showAddJobDialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.add),
      )
          : null,

    );
  }

  Future<void> _acceptApplicant(int jobId, int userId, int applicationId) async {
    print("🟡 Accept button clicked: Job ID: $jobId, User ID: $userId, Application ID: $applicationId");

    try {
      // 1️⃣ Get the team ID associated with the job
      final int? teamId = await db.getTeamIdByJobId(jobId);

      if (teamId == null) {
        print("❌ Error: No team found for job ID $jobId.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: No team associated with this job.")),
        );
        return;
      }

      print("✅ Team ID found: $teamId. Adding user to team...");

      // 2️⃣ Add the user to the team_members table
      bool addedToTeam = await db.addUserToTeam(
        teamId: teamId,
        userId: userId,
        role: "MEMBER",
      );

      if (!addedToTeam) {
        print("❌ Error adding user to team.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error adding user to team.")),
        );
        return;
      }

      print("✅ User added to team successfully!");

      // 3️⃣ Update application status to "Accepted"
      await db.updateApplicationStatus(applicationId, "accepted");

      print("✅ Application status updated to 'Accepted'");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Applicant accepted and added to team!")),
      );

      // Refresh UI
      Navigator.pop(context);
      _showApplicantsDialog(jobId);
    } catch (e) {
      print("❌ Error accepting applicant: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error accepting applicant.")),
      );
    }
  }



}
