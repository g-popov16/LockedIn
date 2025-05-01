import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../sql.dart';
import '../widgets/job_widget.dart'; // Ensure this path is correct
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// --- Define Theme Colors (Matching other files) ---
const Color _backgroundColor = Color(0xFF121212);
const Color _cardBackgroundColor = Color(0xFF1F1F1F);
const Color _accentColor = Color(0xFFE85D5D);
const Color _primaryTextColor = Colors.white;
const Color _secondaryTextColor = Colors.white70;
const Color _placeholderColor = Colors.grey;
const Color _iconColor = Colors.white70;
const double _cardBorderRadius = 12.0;
// --- End Theme Colors ---

class JobsPage extends StatefulWidget {
  final String userRole; // Expecting raw DB role like "ROLE_TEAM"

  const JobsPage({super.key, required this.userRole});

  @override
  _JobsPageState createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final PostgresDB db = PostgresDB();
  List<Map<String, dynamic>> jobs = [];
  bool isLoading = true;
  int? currentUserId;
  String? _currentUserRoleState; // State variable derived from widget.userRole

  @override
  void initState() {
    super.initState();
    _currentUserRoleState = widget.userRole.trim().toUpperCase();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      await _fetchCurrentUserId();
      if (!mounted) return;
      await _fetchJobs();
    } catch (e) {
      print("Error during initial data fetch: $e");
      if(mounted) {
        // Use key from provided JSON
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.addJobError), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }


  Future<void> _fetchJobs() async {
    try {
      final fetchedJobs = await db.getJobs();
      if (!mounted) return;
      setState(() {
        jobs = fetchedJobs;
      });
    } catch (e) {
      print("Error fetching jobs: $e");
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      // Use key from provided JSON
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.addJobError), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _fetchCurrentUserId() async {
    try {
      int? userId = await db.getCurrentUserId();
      if (!mounted) return;
      setState(() {
        currentUserId = userId;
      });
    } catch (e) {
      print("Error fetching current user ID: $e");
      if (mounted) {
        setState(() { currentUserId = null; });
        final l10n = AppLocalizations.of(context)!;
        // Use key from provided JSON
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorUnableToRetrieveUserInfo), backgroundColor: Colors.redAccent));
      }
    }
  }


  // Show dialog for adding a new job
  void _showAddJobDialog() {
    final l10n = AppLocalizations.of(context)!;
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final companyController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _cardBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardBorderRadius)),
          // Use key from provided JSON
          title: Text(l10n.addJobOfferTitle, style: TextStyle(color: _primaryTextColor, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Use keys from provided JSON
                _buildDialogTextField(controller: titleController, label: l10n.jobTitleLabel, hint: l10n.jobTitleHint),
                const SizedBox(height: 12),
                // Use keys from provided JSON
                _buildDialogTextField(controller: descriptionController, label: l10n.jobDescriptionLabel, hint: l10n.jobDescriptionHint, maxLines: 3),
                const SizedBox(height: 12),
                // Use keys from provided JSON
                _buildDialogTextField(controller: companyController, label: l10n.companyNameLabel, hint: l10n.companyNameHint),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              // Use key from provided JSON
              child: Text(l10n.cancelButton, style: TextStyle(color: _secondaryTextColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final description = descriptionController.text.trim();
                final company = companyController.text.trim();
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                if (title.isNotEmpty && description.isNotEmpty && company.isNotEmpty) {
                  if (!mounted) return;
                  Navigator.pop(context);
                  await _addJob(title, description, company);
                } else {
                  if (!mounted) return;
                  scaffoldMessenger.showSnackBar(
                    // Use key from provided JSON
                    SnackBar(content: Text(l10n.addJobFieldsRequiredError), backgroundColor: Colors.orangeAccent),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: _primaryTextColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
              // Use key from provided JSON
              child: Text(l10n.addJobButton),
            ),
          ],
        );
      },
    ).then((_) {
      titleController.dispose();
      descriptionController.dispose();
      companyController.dispose();
    });
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: _primaryTextColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _secondaryTextColor),
        hintText: hint,
        hintStyle: TextStyle(color: _secondaryTextColor.withOpacity(0.5)),
        filled: true,
        fillColor: _backgroundColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _secondaryTextColor.withOpacity(0.5))
        ),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _secondaryTextColor.withOpacity(0.5))
        ),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _accentColor)
        ),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
    );
  }


  Future<void> _addJob(String title, String description, String company) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (currentUserId == null) {
      scaffoldMessenger.showSnackBar(
        // Use key from provided JSON
        SnackBar(content: Text(l10n.errorUnableToRetrieveUserInfo), backgroundColor: Colors.redAccent),
      );
      return;
    }

    try {
      await db.addJob(title: title, description: description, company: company, postedBy: currentUserId!);
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        // Use key from provided JSON
        SnackBar(content: Text(l10n.addJobSuccess), backgroundColor: Colors.green),
      );
      _fetchJobs();
    } catch (e) {
      print("Error adding job: $e");
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        // Use key from provided JSON
        SnackBar(content: Text(l10n.addJobError), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showApplicantsDialog(int jobId) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator(color: _accentColor)));

    try {
      final applicants = await db.getApplicantsForJob(jobId);
      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (BuildContext contextDialog) {
          return AlertDialog(
            backgroundColor: _cardBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardBorderRadius)),
            // Use key from provided JSON
            title: Text(l10n.jobApplicantsTitle, style: TextStyle(color: _primaryTextColor, fontWeight: FontWeight.bold)),
            content: applicants.isEmpty
                ? Text(
              // Use key from provided JSON
              l10n.jobApplicantsNone,
              style: TextStyle(color: _secondaryTextColor),
            )
                : SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(contextDialog).size.height * 0.5,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: applicants.length,
                itemBuilder: (contextList, index) {
                  final applicant = applicants[index];
                  final applicantUserId = applicant["user_id"] as int?;
                  final applicationId = applicant["application_id"] as int?;
                  final String? applicantUsername = applicant["username"];
                  final String? applicantEmail = applicant["email"];
                  final String? resumeLink = applicant["resume_link"] as String?;

                  if (applicationId == null || applicantUserId == null) {
                    print("Missing application ID ($applicationId) or user ID ($applicantUserId) for applicant: $applicant");
                    return const SizedBox.shrink();
                  }

                  return Card(
                    color: _backgroundColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      // Use key from provided JSON
                      title: Text(applicantUsername ?? l10n.unknownUser, style: TextStyle(color: _primaryTextColor)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            // Use key from provided JSON (ensure placeholder syntax matches .arb)
                            l10n.jobApplicantEmailLabel(applicantEmail ?? 'N/A'),
                            style: TextStyle(color: _secondaryTextColor, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          if (resumeLink != null && resumeLink.isNotEmpty)
                            InkWell(
                              onTap: () async {
                                String url = resumeLink.trim();
                                Uri? resumeUri = Uri.tryParse(url);

                                if (resumeUri == null || (!resumeUri.isScheme("http") && !resumeUri.isScheme("https"))) {
                                  resumeUri = Uri.tryParse("https://$url");
                                }

                                if (resumeUri != null) {
                                  try {
                                    if (await canLaunchUrl(resumeUri)) {
                                      await launchUrl(resumeUri, mode: LaunchMode.externalApplication);
                                    } else {
                                      throw Exception('Cannot launch URL');
                                    }
                                  } catch (e) {
                                    print("Error launching URL $resumeUri: $e");
                                    if (!mounted) return;
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        // Use key from provided JSON
                                        content: Text(l10n.jobApplicantResumeOpenError),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                } else {
                                  print("Invalid resume URL format: $resumeLink");
                                  if (!mounted) return;
                                  scaffoldMessenger.showSnackBar(
                                    // Use key from provided JSON
                                    SnackBar(content: Text(l10n.jobApplicantResumeOpenError), backgroundColor: Colors.redAccent),
                                  );
                                }
                              },
                              child: Text(
                                // Use key from provided JSON (ensure placeholder syntax matches .arb)
                                l10n.jobApplicantResumeLabel(resumeLink),
                                style: TextStyle(
                                  color: _accentColor,
                                  decoration: TextDecoration.underline,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          // Use key from provided JSON (ensure placeholder syntax matches .arb)
                          else Text(l10n.jobApplicantResumeLabel('N/A'), style: TextStyle(color: _secondaryTextColor, fontSize: 12)),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        color: _cardBackgroundColor,
                        icon: Icon(Icons.more_vert, color: _iconColor),
                        // Use key from provided JSON (if available, otherwise use generic 'Actions')
                        tooltip: l10n.actions, // Assuming 'actions' key exists for general tooltips
                        onSelected: (value) async {
                          Navigator.pop(contextDialog);

                          if (value == 'accept') {
                            String? actualPosterRole;
                            try {
                              int? posterId = jobs.firstWhere((job) => job['id'] == jobId)['posted_by'];
                              if(posterId != null) {
                                actualPosterRole = await db.getUserRoles(posterId);
                              }
                            } catch (e) {
                              print("Could not get poster role for accept logic: $e");
                            }
                            if (!mounted) return;
                            await _acceptApplicant(jobId, applicantUserId, applicationId, actualPosterRole?.trim().toUpperCase());
                          } else if (value == 'reject') {
                            try {
                              await db.deleteApplication(applicationId);
                              if (!mounted) return;
                              scaffoldMessenger.showSnackBar(
                                // Use key from provided JSON
                                SnackBar(content: Text(l10n.applicationRejectedSuccess), backgroundColor: Colors.orangeAccent),
                              );
                              _showApplicantsDialog(jobId);
                            } catch(e) {
                              print("Error rejecting application: $e");
                              if (!mounted) return;
                              // Use key from provided JSON
                              scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.errorAcceptingApplicant), backgroundColor: Colors.redAccent));
                            }
                          }
                        },
                        itemBuilder: (BuildContext contextPopup) => <PopupMenuEntry<String>>[
                          // Use keys from provided JSON
                          PopupMenuItem<String>(value: 'accept', child: Text(l10n.acceptButton, style: TextStyle(color: _primaryTextColor))),
                          PopupMenuItem<String>(value: 'reject', child: Text(l10n.rejectButton, style: TextStyle(color: _accentColor))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(contextDialog),
                // Use key from provided JSON
                child: Text(l10n.closeButton, style: TextStyle(color: _accentColor)),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print("Error showing applicants dialog: $e");
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        // Use key from provided JSON
        SnackBar(content: Text(l10n.jobApplicantsFetchError), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _showCVDialog(int jobId, int jobPosterId) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final cvLinkController = TextEditingController();

    if (currentUserId == null) {
      // Use key from provided JSON
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.errorUnableToRetrieveUserInfo), backgroundColor: Colors.redAccent));
      return;
    }

    bool canApply = true;
    String? errorMessage;
    try {
      bool alreadyApplied = await db.hasUserApplied(jobId, currentUserId!);
      if(!mounted) return;
      if(alreadyApplied) {
        canApply = false;
        // Use key from provided JSON (Add "alreadyAppliedError" key to your .arb file)
        errorMessage = l10n.alreadyAppliedError; // Assuming key "alreadyAppliedError" exists
      } else {
        String? jobPosterRole = await db.getUserRoles(jobPosterId);
        if (!mounted) return;

        if (jobPosterRole == null) {
          canApply = false;
          // Use key from provided JSON
          errorMessage = l10n.errorFetchJobPosterRole;
        } else if (jobPosterRole.trim().toUpperCase() == "ROLE_TEAM") {
          bool isInTeam = await db.isUserInTeam(currentUserId!);
          if (!mounted) return;
          if (isInTeam) {
            canApply = false;
            // Use key from provided JSON
            errorMessage = l10n.applyJobAlreadyInTeamError;
          }
        }
      }
    } catch (e) {
      print("Error during pre-application checks: $e");
      canApply = false;
      // Use key from provided JSON
      errorMessage = l10n.errorFetchJobPosterRole;
    }

    if (!mounted) return;

    if (!canApply) {
      // Use key from provided JSON (Add "cannotApplyError" key to your .arb file)
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(errorMessage ?? l10n.cannotApplyError), backgroundColor: Colors.orangeAccent)); // Assuming key "cannotApplyError" exists
      return;
    }

    String? cvLink = await showDialog<String>(
      context: context,
      builder: (BuildContext contextDialog) {
        return AlertDialog(
          backgroundColor: _cardBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardBorderRadius)),
          // Use key from provided JSON
          title: Text(l10n.applyJobTitle, style: TextStyle(color: _primaryTextColor, fontWeight: FontWeight.bold)),
          content: _buildDialogTextField(
            controller: cvLinkController,
            // Use keys from provided JSON
            label: l10n.cvLinkLabel,
            hint: l10n.cvLinkHint,
            keyboardType: TextInputType.url,
          ),
          actions: [
            // Use key from provided JSON
            TextButton(onPressed: () => Navigator.of(contextDialog).pop(), child: Text(l10n.cancelButton, style: TextStyle(color: _secondaryTextColor))),
            ElevatedButton(
              onPressed: () {
                if (cvLinkController.text.trim().isNotEmpty) {
                  Navigator.of(contextDialog).pop(cvLinkController.text.trim());
                } else {
                  ScaffoldMessenger.of(contextDialog).showSnackBar(
                    // Use key from provided JSON
                      SnackBar(content: Text(l10n.cvLinkRequiredError), backgroundColor: Colors.orangeAccent, behavior: SnackBarBehavior.floating)
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _accentColor, foregroundColor: _primaryTextColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              // Use key from provided JSON
              child: Text(l10n.submitButton),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(mounted) {
        cvLinkController.dispose();
      }
    });


    if (!mounted) return;

    if (cvLink != null && cvLink.isNotEmpty) {
      try {
        await db.addApplication(jobId: jobId, userId: currentUserId!, resumeLink: cvLink);
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          // Use key from provided JSON
          SnackBar(content: Text(l10n.applicationSubmitSuccess), backgroundColor: Colors.green),
        );
      } catch(e) {
        print("Error submitting application: $e");
        if (!mounted) return;
        // Use key from provided JSON
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.addJobError), backgroundColor: Colors.redAccent));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: _accentColor))
          : RefreshIndicator(
        onRefresh: _fetchJobs,
        color: _accentColor,
        backgroundColor: _cardBackgroundColor,
        child: jobs.isEmpty
        // Use key from provided JSON
            ? Center(child: Text(l10n.jobsNone, style: TextStyle(color: _secondaryTextColor, fontSize: 16)))
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 28, 8, 80),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index];
            final posterRoleValue = job["role"] as String?;
            final jobId = job["id"] as int? ?? 0;
            final jobPosterId = job["posted_by"] as int? ?? 0;

            return JobWidget(
              key: ValueKey(jobId),
              jobId: jobId,
              title: job["title"] ?? '',
              company: job["company"] ?? '',
              description: job["description"] ?? '',
              createdAt: job["created_at"] ?? DateTime.now().toIso8601String(),
              postedBy: jobPosterId,
              currentUserId: currentUserId,
              posterRole: posterRoleValue,
              onApply: () => _showCVDialog(jobId, jobPosterId),
              onViewApplicants: (currentUserId != null && jobPosterId == currentUserId)
                  ? () => _showApplicantsDialog(jobId)
                  : null,
              onJobUpdated: _fetchJobs,
            );
          },
        ),
      ),
      floatingActionButton:
      (_currentUserRoleState != null && (_currentUserRoleState == "ROLE_TEAM" || _currentUserRoleState == "ROLE_SPONSOR"))
          ? FloatingActionButton(
        onPressed: _showAddJobDialog,
        // Use key from provided JSON
        tooltip: l10n.addJobFabTooltip,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: _accentColor,
        foregroundColor: _primaryTextColor,
        child: const Icon(Icons.add),
      )
          : null,
    );
  }

  Future<void> _acceptApplicant(int jobId, int userId, int applicationId, String? actualPosterRole) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      int? teamId;
      if (actualPosterRole == "ROLE_TEAM") {
        teamId = await db.getTeamIdByJobId(jobId);
        if (!mounted) return;
        if (teamId == null) {
          print("Error: Could not find team ID for job $jobId posted by a team role.");
          // Use key from provided JSON
          scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.errorAddingUserToTeam), backgroundColor: Colors.redAccent));
          return;
        }
        bool addedToTeam = await db.addUserToTeam(teamId: teamId, userId: userId, role: "MEMBER");
        if (!mounted) return;
        if (!addedToTeam) {
          // Use key from provided JSON
          scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.errorAddingUserToTeam), backgroundColor: Colors.redAccent));
          return;
        }
      }

      await db.updateApplicationStatus(applicationId, "accepted");
      if (!mounted) return;

      String successMessage;
      if (actualPosterRole == "ROLE_TEAM") {
        // Use key from provided JSON
        successMessage = l10n.applicantAcceptedTeam;
      } else if (actualPosterRole == "ROLE_SPONSOR") {
        // Use key from provided JSON
        successMessage = l10n.applicantAcceptedSponsor;
      } else {
        // Use key from provided JSON
        successMessage = l10n.connectRequestAcceptedSuccess; // Generic success
      }
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(successMessage), backgroundColor: Colors.green));

      if (mounted) {
        _showApplicantsDialog(jobId);
      }
    } catch (e) {
      print("Error accepting applicant: $e");
      if (!mounted) return;
      // Use key from provided JSON
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.errorAcceptingApplicant), backgroundColor: Colors.redAccent));
    }
  }

} // End of _JobsPageState