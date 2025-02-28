import 'dart:async';
import 'package:flutter/material.dart';
import '../sql.dart';

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
  late int _currentUserId;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _loadChatHistory(int user1, int user2) async {
    try {
      final messages = await db.getChatHistory(user1, user2);
      setState(() {
        _messages.clear();
        _messages.addAll(messages);
      });

      // Scroll to bottom after loading chat history
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print("❌ Error loading chat history: $e");
    }
  }

  Future<void> _initChat() async {
    final userId = await db.getCurrentUserId();
    if (userId == null) {
      print("⚠️ No logged-in user found");
      return;
    }
    _currentUserId = userId;

    await _loadChatHistory(_currentUserId, widget.otherUserId);

    _messageSubscription?.cancel();
    _messageSubscription = db.messageStream.listen((newMsg) {
      print("📩 [NEW MESSAGE RECEIVED]: $newMsg");

      final sender = newMsg["sender_id"];
      final receiver = newMsg["receiver_id"];
      final msgId = newMsg["id"];

      final relevantChat =
          (sender == _currentUserId && receiver == widget.otherUserId) ||
              (sender == widget.otherUserId && receiver == _currentUserId);

      if (!relevantChat) return;

      final alreadyExists = _messages.any((m) => m["id"] == msgId);
      if (alreadyExists) {
        print("🔎 Duplicate message with id $msgId. Ignoring.");
        return;
      }

      // ✅ Update UI & Scroll Down
      setState(() {
        _messages.add(newMsg);
      });

      _scrollToBottom();
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      await db.ensureConnection(); // Ensure database connection is open
      await db.sendMessage(
        senderId: _currentUserId,
        receiverId: widget.otherUserId,
        content: text,
      );
      _messageController.clear();

      // Manually add the message to the chat UI
      setState(() {
        _messages.add({
          "id": DateTime.now().millisecondsSinceEpoch, // Temporary ID
          "sender_id": _currentUserId,
          "receiver_id": widget.otherUserId,
          "content": text,
          "created_at": DateTime.now()
              .toIso8601String(), // Fake timestamp for immediate UI update
        });
      });

      _scrollToBottom();
    } catch (e) {
      print("❌ Error sending message: $e");
    }
  }

  void _scrollToBottom() {
    if (_messages.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Chat with ${widget.otherUsername}"),
        backgroundColor: Colors.grey[900],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: Container(
              color: Colors.grey[900],
              child: ListView.builder(
                controller: _scrollController, // ✅ Add ScrollController
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isMe = (msg["sender_id"] == _currentUserId);
                  final content = msg["content"] ?? "";
                  final timestamp = msg["created_at"] ?? "";

                  return Align(
                    alignment:
                    isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      padding: const EdgeInsets.all(10.0),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blueGrey[700] : Colors.grey[800],
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: const Offset(1, 2),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            content,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timestamp,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Message input area
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              color: Colors.grey[900],
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Type a message...",
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
