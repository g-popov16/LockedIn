import 'dart:async';
import 'package:flutter/material.dart';
import '../sql.dart';
// 1. Import AppLocalizations
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// Optional: Import timeago if you want formatted timestamps (requires setup)
// import 'package:timeago/timeago.dart' as timeago;

class ChatPage extends StatefulWidget {
  final int otherUserId;
  final String otherUsername;

  const ChatPage({
    Key? key,
    required this.otherUserId,
    required this.otherUsername,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final PostgresDB db = PostgresDB();
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  int? _currentUserId; // Make nullable initially
  bool _isLoadingHistory = true; // State for loading history
  bool _isSending = false; // State for sending message

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    // Remove the async l10n initialization from here
    // AppLocalizations? l10n;
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //    if(mounted) l10n = AppLocalizations.of(context);
    // });

    try {
      final userId = await db.getCurrentUserId();
      if (!mounted) return;

      if (userId == null) {
        print("ChatPage: Could not get current user ID.");
        // --- Get l10n here ONLY if needed for the SnackBar ---
        final l10n = AppLocalizations.of(context)!; // Get it now, context is valid
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.chatErrorInit)) // Access directly
        );
        // --- End l10n access ---
        setState(() => _isLoadingHistory = false);
        return;
      }
      _currentUserId = userId;

      // Now load history
      await _loadChatHistory(_currentUserId!, widget.otherUserId);

      // Set up listener only after history is loaded and user ID is confirmed
      _messageSubscription?.cancel();
      _messageSubscription = db.messageStream.listen((newMsg) {
        // ... (rest of listener remains the same) ...
        if (!mounted) return;

        final sender = newMsg["sender_id"];
        final receiver = newMsg["receiver_id"];
        final msgId = newMsg["id"];

        final bool relevantChat = (_currentUserId != null &&
            ((sender == _currentUserId && receiver == widget.otherUserId) ||
                (sender == widget.otherUserId && receiver == _currentUserId)));

        if (!relevantChat) return;

        final bool alreadyExists = _messages.any((m) => m["id"] == msgId);
        if (alreadyExists) {
          print("ChatPage: Duplicate message received (ID: $msgId), skipping.");
          return;
        }

        setState(() { _messages.add(newMsg); });

        WidgetsBinding.instance.addPostFrameCallback((_) { _scrollToBottom(); });
      }, onError: (error) {
        print("Error listening to message stream: $error");
      });

    } catch (e) {
      print("Error initializing chat: $e");
      // --- Get l10n here ONLY if needed for the SnackBar ---
      if (mounted) { // Check mounted before accessing context/l10n
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.chatErrorInit)) // Access directly
        );
        setState(() => _isLoadingHistory = false);
      }
      // --- End l10n access ---
    }
  }


  Future<void> _loadChatHistory(int user1, int user2) async {
    if (!mounted) return;
    setState(() => _isLoadingHistory = true);
    try {
      final messages = await db.getChatHistory(user1, user2);
      if (!mounted) return; // Check after await
      setState(() {
        _messages.clear();
        _messages.addAll(messages);
        _isLoadingHistory = false; // History loaded
      });

      // Scroll to bottom after loading chat history
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });
    } catch (e) {
      print("Error loading chat history: $e");
      if (!mounted) return;
      setState(() => _isLoadingHistory = false); // Stop loading on error
      // Optionally show error to user
      // final l10n = AppLocalizations.of(context)!;
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.chatErrorInit)));
    }
  }

  void _sendMessage() async {
    // Get l10n and messenger safely
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null || _isSending) return; // Basic validation and prevent double send

    if (mounted) setState(() => _isSending = true); // Indicate sending state

    try {
      // No need to manually add to UI if the LISTEN mechanism works correctly
      await db.sendMessage(
        senderId: _currentUserId!,
        receiverId: widget.otherUserId,
        content: text,
      );
      // Check mounted after sending
      if (!mounted) return;
      _messageController.clear(); // Clear input on success
      // Scroll to bottom might happen automatically via listener, but can call manually too
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });

    } catch (e) {
      print("Error sending message: $e");
      // Check mounted before showing SnackBar
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        // Use localized error message
        SnackBar(content: Text(l10n.chatErrorSend)),
      );
    } finally {
      // Always reset sending state if mounted
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    // Check if controller is attached to a scroll view
    if (_scrollController.hasClients) {
      // Use addPostFrameCallback to ensure layout is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) { // Double-check client attachment
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 2. Get AppLocalizations instance
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[900], // Dark background consistent with message list
      appBar: AppBar(
        // 3. Use localized title with placeholder
        title: Text(l10n.chatPageTitle(widget.otherUsername)),
        backgroundColor: theme.appBarTheme.backgroundColor, // Use theme color
        elevation: 0,
        titleTextStyle: theme.appBarTheme.titleTextStyle,
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: Column(
        children: [
          // Chat messages area
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(child: Text("No messages yet.", style: TextStyle(color: Colors.grey[500]))) // TODO: Localize this?
                : Container( // Keep the slightly darker background for message list
              color: Colors.grey[900],
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), // Adjusted padding
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  // Ensure currentUserId is available for comparison
                  final bool isMe = (_currentUserId != null && msg["sender_id"] == _currentUserId);
                  final content = msg["content"] ?? "";
                  // Format timestamp (basic example, consider intl package for better formatting)
                  String formattedTimestamp = '';
                  if (msg["created_at"] != null) {
                    try {
                      final dt = DateTime.parse(msg["created_at"]);
                      // Example: HH:mm format
                      formattedTimestamp = "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
                      // Or use timeago package: formattedTimestamp = timeago.format(dt);
                    } catch (e) { formattedTimestamp = '...'; }
                  }

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5.0), // Increased vertical margin
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0), // Adjusted padding
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), // Limit bubble width
                      decoration: BoxDecoration(
                        // Use theme colors if desired, or keep specific ones
                        color: isMe ? theme.primaryColor.withOpacity(0.9) : theme.cardColor, // Example theme usage
                        borderRadius: BorderRadius.circular(12.0), // Slightly more rounded
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, // Align text left within bubble
                        mainAxisSize: MainAxisSize.min, // Prevent column from taking full width
                        children: [
                          Text(
                            content,
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white), // Use theme style
                          ),
                          const SizedBox(height: 4),
                          Align( // Align timestamp to the right within the bubble
                            alignment: Alignment.bottomRight,
                            child: Text(
                              formattedTimestamp,
                              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Message input area
          Container(
            // Use theme card color for input area background
            color: theme.cardColor, // Changed from grey[900]
            padding: EdgeInsets.only(
              // Use safe area padding at bottom, plus custom padding
                bottom: MediaQuery.of(context).padding.bottom + 8,
                left: 12, right: 12, top: 8
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end, // Align items to bottom for multi-line input
              children: [
                Expanded(
                  child: Container( // Container to style the TextField background/border
                    padding: const EdgeInsets.symmetric(horizontal: 12), // Padding inside the container
                    decoration: BoxDecoration(
                      // Use a slightly lighter background than main input area?
                      color: theme.scaffoldBackgroundColor, // Example: theme background
                      borderRadius: BorderRadius.circular(25), // Rounded corners
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: theme.textTheme.bodyLarge, // Use theme style
                      decoration: InputDecoration(
                        // 3. Use localized hint text
                          hintText: l10n.chatInputHint,
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none, // Remove default border
                          contentPadding: const EdgeInsets.symmetric(vertical: 10) // Adjust vertical padding
                      ),
                      keyboardType: TextInputType.multiline, // Allow multi-line
                      maxLines: 5, // Limit max lines
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences, // Capitalize sentences
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                IconButton(
                  // Show loading indicator while sending
                  icon: _isSending
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.send, color: theme.primaryColor), // Use theme primary color
                  onPressed: _isSending ? null : _sendMessage, // Disable while sending
                  tooltip: 'Send Message', // TODO: Localize tooltip
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}