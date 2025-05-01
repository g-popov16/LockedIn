import 'package:flutter/material.dart';
import '../screens/user_profile_page.dart'; // Ensure this path is correct
import '../screens/edit_job_page.dart';    // Ensure this path is correct
import 'package:timeago/timeago.dart' as timeago;
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

class JobWidget extends StatelessWidget {
  final int jobId;
  final String title;
  final String company;
  final String description;
  final String createdAt;
  final int postedBy;
  final int? currentUserId;
  final String? posterRole; // e.g., "ROLE_TEAM", "ROLE_SPONSOR"

  final VoidCallback onApply;
  final VoidCallback? onViewApplicants;
  // Removed unused callbacks - add back if needed
  // final VoidCallback? onAcceptApplication;
  // final VoidCallback? onDeclineApplication;
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
    // this.onAcceptApplication,
    // this.onDeclineApplication,
    required this.onJobUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    String timeAgo = ''; // Default value
    try {
      // Safely parse DateTime
      final DateTime? createdTime = DateTime.tryParse(createdAt);
      if (createdTime != null) {
        timeAgo = timeago.format(createdTime, locale: Localizations.localeOf(context).languageCode); // Use locale for timeago
      }
    } catch (e) {
      print("Error parsing job createdAt date: $createdAt, Error: $e");
      timeAgo = '...'; // Placeholder on error
    }


    String viewRoleText;
    // Ensure comparison is case-insensitive and handles null
    final roleUpper = posterRole?.trim().toUpperCase();
    if (roleUpper == "ROLE_TEAM") {
      viewRoleText = l10n.viewTeamLink;
    } else if (roleUpper == "ROLE_SPONSOR") {
      viewRoleText = l10n.viewSponsorLink;
    } else {
      viewRoleText = l10n.viewPosterLink; // Generic fallback
    }

    // Determine if the current user is the poster
    final bool isPoster = currentUserId != null && currentUserId == postedBy;

    return Card(
      color: _cardBackgroundColor, // Use theme color
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardBorderRadius), // Use theme radius
      ),
      elevation: 1, // Subtle elevation
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6), // Adjust margin
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header Row: Title & Timestamp ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded( // Allow title to take available space
                  child: Text(
                    title,
                    maxLines: 2, // Allow two lines for title
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17, // Slightly smaller title
                      fontWeight: FontWeight.bold,
                      color: _primaryTextColor, // Theme text color
                    ),
                  ),
                ),
                Padding( // Add padding to timestamp
                  padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                  child: Text(
                    timeAgo,
                    style: TextStyle(color: _secondaryTextColor, fontSize: 12), // Theme text color
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // --- Sub-Header Row: Company & Poster Link ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible( // Allow company name to wrap/ellipsis if needed
                  child: Text(
                    // Use placeholder directly in l10n key definition (e.g., "Company: {companyName}")
                    l10n.jobCompanyLabel(company),
                    style: TextStyle(fontSize: 14, color: _secondaryTextColor), // Theme text color
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Show link only if NOT the poster viewing their own job
                if (!isPoster)
                  Padding( // Add padding to link
                    padding: const EdgeInsets.only(left: 8.0),
                    child: InkWell( // Use InkWell for better tap feedback
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfilePage(
                              userId: postedBy, // Navigate to poster's profile
                              isCurrentUser: false, // It's not the current user's profile page
                            ),
                          ),
                        );
                      },
                      child: Text(
                        viewRoleText,
                        style: TextStyle(
                          color: _accentColor, // Use theme accent for link
                          fontWeight: FontWeight.w500, // Medium weight
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // --- Description ---
            Text(
              description,
              style: TextStyle(fontSize: 14, color: _secondaryTextColor, height: 1.4), // Theme text color + line height
              maxLines: 3, // Limit description lines initially
              overflow: TextOverflow.ellipsis,
              // TODO: Consider adding an "Expand" button if description is often long
            ),
            const SizedBox(height: 16),

            // --- Action Buttons ---
            Row(
              mainAxisAlignment: isPoster ? MainAxisAlignment.end : MainAxisAlignment.start, // Align based on who is viewing
              children: [
                // Apply Button (Visible if NOT the poster)
                if (!isPoster)
                  ElevatedButton.icon(
                    onPressed: onApply, // Callback from JobsPage
                    icon: Icon(Icons.send_outlined, size: 16, color: _primaryTextColor), // Icon + Text
                    label: Text(l10n.applyButton, style: TextStyle(color: _primaryTextColor)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor, // Theme accent color
                      foregroundColor: _primaryTextColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),

                // Poster Actions (Visible only TO the poster)
                if (isPoster) ...[
                  // View Applicants Button
                  OutlinedButton.icon( // Use OutlinedButton for secondary action
                    onPressed: onViewApplicants, // Callback from JobsPage (enabled only if isPoster)
                    icon: Icon(Icons.people_outline, size: 16, color: _secondaryTextColor),
                    label: Text(l10n.viewApplicantsButton, style: TextStyle(color: _secondaryTextColor, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _secondaryTextColor.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8), // Space between buttons

                  // Edit Button
                  OutlinedButton.icon( // Use OutlinedButton
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditJobPage(
                            jobId: jobId,
                            initialTitle: title,
                            initialCompany: company,
                            initialDescription: description,
                            onJobUpdated: onJobUpdated, // Pass the callback
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.edit_outlined, size: 16, color: _secondaryTextColor),
                    label: Text(l10n.editButton, style: TextStyle(color: _secondaryTextColor, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _secondaryTextColor.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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