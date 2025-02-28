import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

        //  Fetch and store user role in the local state variable
        String fetchedRole = await db.getUserRoles(userId);
        setState(() {
          userRole = fetchedRole.trim().toUpperCase();
        });

      }
    } catch (e) {
    }
  }


  // Show dialog for adding a new job
  void _showAddJobDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final companyController = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.cardColor, // Dark grey background
          title: Text(
            "Add Job Offer",
            style: theme.textTheme.titleLarge,
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: "Job Title",
                    labelStyle: theme.textTheme.bodyLarge,
                    hintText: "Enter job title",
                    hintStyle: theme.textTheme.bodyMedium,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white70),
                    ),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor, // Matches dark mode
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: "Job Description",
                    labelStyle: theme.textTheme.bodyLarge,
                    hintText: "Enter job description",
                    hintStyle: theme.textTheme.bodyMedium,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white70),
                    ),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: companyController,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: "Company Name",
                    labelStyle: theme.textTheme.bodyLarge,
                    hintText: "Enter company name",
                    hintStyle: theme.textTheme.bodyMedium,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white70),
                    ),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: theme.textTheme.bodyLarge),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final description = descriptionController.text.trim();
                final company = companyController.text.trim();

                if (title.isNotEmpty && description.isNotEmpty && company.isNotEmpty) {
                  await _addJob(title, description, company);
                  Navigator.pop(context); // Close dialog
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please fill in all fields")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor, // Uses the theme primary color
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error adding job offer")),
      );
    }
  }

  // Show job applicants + accept/reject logic
  void _showApplicantsDialog(int jobId) async {
    try {
      final theme = Theme.of(context);
      final applicants = await db.getApplicantsForJob(jobId);

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: theme.cardColor, // Dark grey background
            title: Text(
              "Job Applicants",
              style: theme.textTheme.titleLarge,
            ),
            content: applicants.isEmpty
                ? Text(
              "No applicants yet.",
              style: theme.textTheme.bodyLarge,
            )
                : SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: applicants.length,
                itemBuilder: (context, index) {
                  final applicant = applicants[index];

                  return Card(
                    color: theme.scaffoldBackgroundColor, // Dark mode card
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(
                        applicant["username"],
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 5),
                          Text(
                            "Email: ${applicant["email"]}",
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 5),
                          InkWell(
                            onTap: () async {
                              String url = applicant["resume_link"].trim();

                              // Ensure proper URL formatting
                              if (!url.startsWith("http://") && !url.startsWith("https://")) {
                                url = "https://$url";
                              } else if (url.startsWith("https:/") && !url.startsWith("https://")) {
                                url = url.replaceFirst("https:/", "https://"); // Fix malformed URL
                              }

                              final Uri resumeUrl = Uri.parse(url);

                              try {
                                bool canOpen = await canLaunchUrl(resumeUrl);

                                if (canOpen) {
                                  bool launched = await launchUrl(
                                    resumeUrl,
                                    mode: LaunchMode.externalApplication, // System browser
                                  );
                                  if (!launched) {
                                    throw "Launch failed";
                                  }
                                } else {
                                  throw "Cannot launch URL";
                                }
                              } catch (e) {
                                Clipboard.setData(ClipboardData(text: url));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Could not open the CV link.\nThe link has been copied to your clipboard.",
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                    action: SnackBarAction(
                                      label: "Open Browser",
                                      onPressed: () async {
                                        await launchUrl(resumeUrl, mode: LaunchMode.platformDefault);
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              "Resume: ${applicant["resume_link"]}",
                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                color: Theme.of(context).primaryColor,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        color: theme.scaffoldBackgroundColor, // Dark menu
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
                          PopupMenuItem<String>(
                            value: 'accept',
                            child: Text(
                              'Accept',
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'reject',
                            child: Text(
                              'Reject',
                              style: theme.textTheme.bodyLarge!
                                  .copyWith(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Close",
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error fetching applicants.")),
      );
    }
  }



  // Show dialog for applying to a job
  Future<void> _showCVDialog(int jobId, int jobPosterId) async {
    final cvLinkController = TextEditingController();

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Unable to retrieve user information")),
      );
      return;
    }

    // Fetch the job poster's role (team or sponsor)
    String? jobPosterRole = await db.getUserRoles(jobPosterId);

    if (jobPosterRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Unable to fetch job poster role.")),
      );
      return;
    }

    // If the job is posted by a team, check if the user is already in a team
    if (jobPosterRole == "team") {
      bool isInTeam = await db.isUserInTeam(currentUserId!);
      if (isInTeam) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Oops! You are already in a team.")),
        );
        return;
      }
    }

    // Show the application dialog
    String? cvLink = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);

        return AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor, // Always dark
          title: Text(
            "Apply for Job",
            style: theme.textTheme.titleLarge,
          ),
          content: TextField(
            controller: cvLinkController,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              labelText: "CV Link",
              labelStyle: theme.textTheme.bodyLarge,
              hintText: "https://yourcv.com",
              hintStyle: theme.inputDecorationTheme.hintStyle,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white70),
              ),
              prefixIcon: const Icon(Icons.link, color: Colors.white),
              filled: true,
              fillColor: theme.cardColor, // Dark grey
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel", style: theme.textTheme.bodyLarge),
            ),
            TextButton(
              onPressed: () {
                if (cvLinkController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(cvLinkController.text.trim());
                }
              },
              child: Text("Submit", style: TextStyle(color: theme.primaryColor)),
            ),
          ],
        );
      },
    );







  if (cvLink != null && cvLink.isNotEmpty) {
      await db.addApplication(
        jobId: jobId,
        userId: currentUserId!,
        resumeLink: cvLink,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Application submitted successfully!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide a valid CV link.")),
      );
    }
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
                  onApply: () => _showCVDialog(job["id"], job["posted_by"]),
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


    // 3️⃣ Update application status to "Accepted"
    await db.updateApplicationStatus(applicationId, "accepted");



    if(userRole ==  "ROLE_TEAM") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Applicant accepted and added to team!"))
      );
    }
    else{
      const SnackBar(content: Text("Applicant accepted and added to sponsorship!"));
    }

    try {
      // 1️⃣ Get the team ID associated with the job
      final int? teamId = await db.getTeamIdByJobId(jobId);

      if (teamId == null) {
        return;
      }


      // 2️⃣ Add the user to the team_members table
      bool addedToTeam = await db.addUserToTeam(
        teamId: teamId,
        userId: userId,
        role: "MEMBER",
      );

      if (!addedToTeam) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error adding user to team.")),
        );
        return;
      }



      // Refresh UI
      Navigator.pop(context);
      _showApplicantsDialog(jobId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error accepting applicant.")),
      );
    }
  }

}
