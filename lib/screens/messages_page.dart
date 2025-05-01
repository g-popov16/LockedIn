import 'package:flutter/material.dart';
import '../sql.dart';
import 'chat_page.dart';
// 1. Import AppLocalizations
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({Key? key}) : super(key: key);

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final PostgresDB db = PostgresDB();
  // Use Future directly in FutureBuilder to ensure it refetches on state changes if needed
  // late Future<List<Map<String, dynamic>>> _connectionsFuture;

  @override
  void initState() {
    super.initState();
    // No need to assign future here, FutureBuilder will call the function
    // _connectionsFuture = fetchConnections();
  }

  // Fetch connections directly for FutureBuilder
  Future<List<Map<String, dynamic>>> fetchConnections() async {
    // getCurrentUserId() might return null, handle it
    final currentUserId = await db.getCurrentUserId();
    if (currentUserId == null) {
      print("MessagesPage: Current User ID is null."); // Debugging
      // Return empty list or throw an error based on desired behavior
      return [];
    }
    try {
      return await db.getAcceptedConnections(currentUserId);
    } catch (e) {
      print("Error fetching connections: $e");
      // Re-throw or return empty list based on how you want to handle errors
      // Returning empty list to show "No connections" message on error
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2. Get AppLocalizations instance
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context); // Get theme for consistent styling

    return Scaffold(
      // Use theme background color, but allow override if needed
        backgroundColor: theme.scaffoldBackgroundColor, // Or Colors.black if specific override needed
        appBar: AppBar(
          // 3. Use localized title
          title: Text(l10n.messagesPageTitle),
          elevation: 0,
          // Use theme AppBar color
          backgroundColor: theme.appBarTheme.backgroundColor,
          titleTextStyle: theme.appBarTheme.titleTextStyle, // Use theme title style
          iconTheme: theme.appBarTheme.iconTheme, // Use theme icon theme
        ),
        // Use a RefreshIndicator for easy reloading
        body: RefreshIndicator(
          onRefresh: () async {
            // Trigger a rebuild which causes FutureBuilder to call fetchConnections again
            setState(() {});
          },
          child: FutureBuilder<List<Map<String, dynamic>>>(
            // Call fetchConnections directly here
            future: fetchConnections(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                // Optionally log the specific error: print("Error in FutureBuilder: ${snapshot.error}");
                return Center(
                  child: Text(
                    // 3. Use localized prefix and error message
                    "${l10n.errorPrefix}${snapshot.error}", // Concatenate
                    style: TextStyle(color: theme.colorScheme.error), // Use theme error color
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final connections = snapshot.data ?? [];

              if (connections.isEmpty) {
                return Center(
                  child: Text(
                    // 3. Use localized empty state message
                    l10n.messagesNoConnections,
                    // Use theme text style, maybe bodyMedium or titleMedium
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              // Use ListView.separated for dividers
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                itemCount: connections.length,
                separatorBuilder: (context, index) => Divider(
                  color: Colors.grey[800], // Dark divider
                  height: 1,
                  thickness: 1,
                  indent: 70, // Indent divider past avatar
                ),
                itemBuilder: (context, index) {
                  final conn = connections[index];
                  final otherUserId = conn["connection_id"]; // Assuming this key is correct
                  // 3. Use localized unknown user as fallback
                  final username = conn["username"] ?? l10n.unknownUser;

                  // Ensure otherUserId is valid before allowing navigation
                  if (otherUserId == null || otherUserId is! int) {
                    print("Invalid otherUserId for connection: $conn"); // Debugging
                    return const SizedBox.shrink(); // Don't render if ID is invalid
                  }


                  return ListTile(
                    // Use theme card color for background if desired, or keep transparent
                    // tileColor: theme.cardColor, // Example: theme card color
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    leading: CircleAvatar(
                      radius: 24, // Slightly larger
                      backgroundColor: theme.colorScheme.primaryContainer, // Use theme color
                      child: Text(
                        username.isNotEmpty ? username[0].toUpperCase() : "?",
                        style: TextStyle(
                          fontSize: 18,
                          color: theme.colorScheme.onPrimaryContainer, // Use theme color
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      username,
                      style: theme.textTheme.titleMedium?.copyWith(color: Colors.white), // Use theme style
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      // 3. Use localized subtitle text
                      l10n.messagesTapToChat,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[400]), // Use theme style
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            // Ensure correct types are passed
                            otherUserId: otherUserId as int, // Cast to int after check
                            otherUsername: username,
                          ),
                        ),
                      );
                    },
                    // Optional: Add visual feedback on tap
                    splashColor: theme.splashColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Match Card shape if using tileColor
                  );
                },
              );
            },
          ),
        )
    );
  }
}