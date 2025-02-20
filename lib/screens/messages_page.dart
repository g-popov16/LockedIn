import 'package:flutter/material.dart';
import '../sql.dart'; 
import 'chat_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({Key? key}) : super(key: key);

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final PostgresDB db = PostgresDB();
  late Future<List<Map<String, dynamic>>> _connectionsFuture;

  @override
  void initState() {
    super.initState();
    _connectionsFuture = fetchConnections();
  }

  Future<List<Map<String, dynamic>>> fetchConnections() async {
    final currentUserId = await db.getCurrentUserId();
    if (currentUserId == null) {
      print("⚠️ No current user logged in.");
      return [];
    }
    return await db.getAcceptedConnections(currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Dark background color for the entire screen
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Messages"),
        elevation: 0,
        backgroundColor: Colors.grey[900],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _connectionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final connections = snapshot.data ?? [];

          if (connections.isEmpty) {
            // Using a white or grey text so it’s visible on dark background
            return Center(
              child: Text(
                "No connections found.",
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.grey[400]),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: connections.length,
            itemBuilder: (context, index) {
              final conn = connections[index];
              final otherUserId = conn["connection_id"];
              final username = conn["username"] ?? "Unknown";

              return Card(
                color: Colors.grey[850],  // Dark color for card background
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blueGrey[700],
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : "?",
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  title: Text(
                    username,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: const Text(
                    "Tap to chat",
                    style: TextStyle(color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          otherUserId: otherUserId,
                          otherUsername: username,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
