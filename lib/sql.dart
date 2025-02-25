import 'dart:math' as math;

import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class PostgresDB {
  // Singleton instance
  static final PostgresDB _instance = PostgresDB._internal();
  factory PostgresDB() => _instance;
  PostgresDB._internal();

  PostgreSQLConnection? _connection;


  // (NEW) StreamController to broadcast new messages
  final StreamController<Map<String, dynamic>> _messageStreamController =
  StreamController.broadcast();

  // (NEW) Public stream so your UI can listen to new messages
  Stream<Map<String, dynamic>> get messageStream =>
      _messageStreamController.stream;

  PostgreSQLConnection _createConnection() {
    return PostgreSQLConnection(
      "lockedinapp.cxw8gwiigwn7.eu-north-1.rds.amazonaws.com",
      5432,
      "postgres",
      username: "postgres",
      password: "LockedIn123",
      useSSL: true,
    );
  }

  Future<void> openConnection() async {
    if (_connection != null && !_connection!.isClosed) {
      print("✅ Connection is already open. No need to reopen.");
      return;
    }
    _connection = _createConnection();
    try {
      await _connection!.open();
      print("✅ Database connected!");

      // Ensure LISTEN starts properly
      await listenForNewMessages();
    } catch (e) {
      print("❌ Error connecting to database: $e");
      rethrow;
    }
  }




  bool _isOpeningConnection = false;
  Completer<void>? _connectionCompleter;

  Future<void> ensureConnection() async {
    if (_connection != null && !_connection!.isClosed) {
      print("✅ Connection is already open.");
      return;
    }

    if (_isOpeningConnection) {
      print("🛑 Connection is already being established. Waiting...");
      await _connectionCompleter?.future;
      return;
    }

    _isOpeningConnection = true;
    _connectionCompleter = Completer<void>();

    print("🔄 Reopening a new database connection...");

    try {
      _connection = _createConnection();
      await _connection!.open();
      print("✅ Database reconnected successfully!");

      // ✅ Restart message listener after reconnecting
      await listenForNewMessages();

      _connectionCompleter?.complete();
    } catch (e) {
      print("❌ Error reopening database connection: $e");
      _connectionCompleter?.completeError(e);
    } finally {
      _isOpeningConnection = false;
    }
  }


  void _restartMessageStream() {
    print("🔄 Restarting message listener...");

    // Close the existing stream safely
    _messageStreamController.close().then((_) {
      print("🔁 Stream closed, restarting listener...");

      // Create a new stream inside the same object without reassigning
      _listenForNewMessages();
    });

    print("✅ Message listener restarted!");
  }




  void _listenForNewMessages() async {
    if (_connection == null || _connection!.isClosed) {
      print("⚠️ Database connection is closed. Cannot listen for messages.");
      return;
    }

    print("👂 Listening for new messages...");

    await _connection!.execute("LISTEN new_message_event;");

    _connection!.notifications.listen((event) {
      print("📩 New message received: ${event.payload}");

      try {
        final newMessage = jsonDecode(event.payload) as Map<String, dynamic>;
        if (!_messageStreamController.isClosed) {
          _messageStreamController.add(newMessage);
        }
      } catch (e) {
        print("❌ Error parsing new message: $e");
      }
    });

    print("✅ Message listener set up successfully.");
  }




  Future<void> closeConnection({bool clearSession = false}) async {
    if (_connection != null && !_connection!.isClosed) {
      print("⚠️ Closing database connection...");

      if (clearSession) {
        print("! Clearing user session...");
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('currentUserEmail');
      }

      print("✅ Database remains open.");
    }
  }


  // (NEW) Listen for notifications on 'new_message'
  Future<void> listenForNewMessages() async {
    if (_connection == null || _connection!.isClosed) {
      print("⚠️ Database connection is closed. Cannot listen for messages.");
      return;
    }

    print("👂 Listening for new messages...");

    await _connection!.execute("LISTEN new_message;");
    print("✅ LISTEN command executed successfully.");

    _connection!.notifications.listen((event) {
      print("🔔 Received NOTIFY event: ${event.channel}, payload: ${event.payload}");

      if (event.channel == 'new_message') {
        try {
          final payload = jsonDecode(event.payload);
          print("📩 New message received: $payload");

          if (!_messageStreamController.isClosed) {
            _messageStreamController.add(payload);
          }
        } catch (e) {
          print("❌ Error parsing NOTIFY payload: $e");
        }
      }
    });

    print("✅ Message listener is running.");
  }




  // (NEW) Helper to send a new message
  Future<void> sendMessage({
    required int senderId,
    required int receiverId,
    required String content,
  }) async {
    await ensureConnection();

    try {
      await _connection!.query('''
        INSERT INTO messages (content, sender_id, receiver_id, created_at)
        VALUES (@content, @senderId, @receiverId, NOW())
      ''', substitutionValues: {
        'content': content,
        'senderId': senderId,
        'receiverId': receiverId,
      });
      print("✅ Message inserted. Trigger should notify automatically.");
    } catch (e) {
      print("Error sending message: $e");
      throw Exception("Failed to send message.");
    }
  }


  // Store the current user's email globally
  String? currentUserEmail;

  Future<void> saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentUserEmail', email);
  }

  Future<String?> loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('currentUserEmail');

    if (email == null) {
      // Fetch email from the database if not in SharedPreferences
      email = await _getEmailFromDatabase();

      if (email != null) {
        await prefs.setString('currentUserEmail', email);
      }
    }

    return email;
  }

  Future<String?> _getEmailFromDatabase() async {
    await ensureConnection(); // Ensure database connection is open

    try {
      final result = await _connection!.query(
        '''
      SELECT email FROM users
      WHERE id = @userId
      LIMIT 1
      ''',
        substitutionValues: {'userId': await getCurrentUserId()},
      );

      if (result.isNotEmpty) {
        return result.first[0] as String;
      }
    } catch (e) {
      print("❌ Error fetching email from database: $e");
    }

    return null;
  }




  /// Helper function to load a user's roles from user_roles
  Future<String> getUserRoles(int userId) async {
    await ensureConnection();

    try {
      final result = await _connection!.query(
        '''
      SELECT role
      FROM user_roles
      WHERE user_id = @userId
      LIMIT 1
      ''',
        substitutionValues: {'userId': userId},
      );

      if (result.isNotEmpty) {
        String fetchedRole = result.first[0] as String;
        print("Fetched role for user $userId: $fetchedRole"); // Debugging
        return fetchedRole;
      } else {
        print("⚠️ No role found for user $userId");
        return "Unknown Role";
      }
    } catch (e) {
      print(" Error fetching user role: $e");
      return "Unknown Role";
    }
  }


  // Sign in
  Future<Map<String, dynamic>?> signIn(String email, String password) async {
    await ensureConnection(); // Ensure database connection is open
    print("🟢 Signing in user: $email");

    try {
      final results = await _connection!.query(
        '''
      SELECT id, username, email, name, bio, profile_pic_url
      FROM users
      WHERE email = @email AND password = @password
      ''',
        substitutionValues: {
          "email": email,
          "password": password,
        },
      );

      if (results.isNotEmpty) {
        final row = results[0];
        final userId = row[0] as int;
        final userRoles = await getUserRoles(userId);

        final user = {
          "id": userId,
          "username": row[1],
          "email": row[2],
          "name": row[3],
          "bio": row[4],
          "profile_pic_url": row[5],
          "roles": userRoles,
        };

        // ✅ Save email & user details to SharedPreferences
        await _saveUserToPreferences(user);

        print("✅ User signed in successfully!");

        return user;
      } else {
        print("⚠️ User not found.");
        return null;
      }
    } catch (e) {
      print("❌ Error during sign-in: $e");
      return null;
    }
  }


  Future<void> _saveUserToPreferences(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentUserEmail', user['email']);
    await prefs.setInt('currentUserId', user['id']); // Store user ID
    await prefs.setString('username', user['username']); // Store username
    await prefs.setString('profilePic', user['profile_pic_url'] ?? '');
    await prefs.setString('role', user['roles'] ?? '');

    print("✅ User data saved to SharedPreferences!");
  }





  // Sign up
  Future<bool> signUp(Map<String, dynamic> userData) async {
    await ensureConnection(); // Ensure connection is open
    try {
      // Insert user into 'users' table
      final insertedUser = await _connection!.query(
        '''
      INSERT INTO users (username, password, email, name, bio, profile_pic_url)
      VALUES (@username, @password, @email, @name, @bio, @profile_pic_url)
      RETURNING id
      ''',
        substitutionValues: {
          "username": userData["username"],
          "password": userData["password"],
          "email": userData["email"],
          "name": userData["name"],
          "bio": userData["bio"],
          "profile_pic_url": userData["profile_pic_url"],
        },
      );

      if (insertedUser.isEmpty) {
        print("⚠️ Sign-up failed: No user was created.");
        return false;
      }

      final newUserId = insertedUser.first[0] as int;

      // Insert role into 'user_roles' table
      final role = userData["role"] ?? "ROLE_USER";
      await _connection!.query(
        '''
      INSERT INTO user_roles (user_id, role)
      VALUES (@userId, @role)
      ''',
        substitutionValues: {
          "userId": newUserId,
          "role": role,
        },
      );

      // ✅ Save email & user ID in SharedPreferences
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', userData["email"]);
      await prefs.setInt('user_id', newUserId);

      print("✅ User created successfully! ID: $newUserId");
      return true;
    } catch (e) {
      print("❌ Error during sign-up: $e");
      return false;
    }
  }



  // Get user by email
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    await ensureConnection(); // Ensure connection is open
    try {
      // First query the 'users' table
      final userResults = await _connection!.query('''
      SELECT id, username, password, email
      FROM users
      WHERE email = @email
    ''', substitutionValues: {
        'email': email,
      });

      if (userResults.isEmpty) {
        print("No user found for email: $email");
        return null;
      }

      final row = userResults.first;
      final userId = row[0] as int;
      final user = {
        "id": userId,
        "username": row[1],
        "password": row[2],
        "email": row[3],
      };

      // Fetch the single role from user_roles
      final roleResults = await _connection!.query(
        '''
      SELECT role
      FROM user_roles
      WHERE user_id = @userId
      ''',
        substitutionValues: {"userId": userId},
      );

      // If there's exactly one row, get that role
      if (roleResults.isNotEmpty) {
        final userRole = roleResults.first[0] as String;
        user["role"] = userRole;
      } else {
        // If there's no row, you can decide on a default or set it to null
        user["role"] = null;
      }

      return user;
    } catch (e) {
      print("Error during getUserByEmail: $e");
      return null;
    }
  }


  // Get current user ID



  // Paginated posts retrieval
  Future<List<Map<String, dynamic>>> getPostsPaginated({
    required int limit,
    required int offset,
  }) async {
    await ensureConnection(); // Ensure connection is open
    try {
      final results = await _connection!.query('''
        SELECT p.id, p.user_id, p.content, p.created_at::TEXT, p.likes_count,
               (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id) AS comments_count,
               u.username
        FROM posts p
        JOIN users u ON p.user_id = u.id
        ORDER BY p.created_at DESC
        LIMIT @limit OFFSET @offset
      ''', substitutionValues: {
        'limit': limit,
        'offset': offset,
      });

      return results.map((row) {
        return {
          "id": row[0],
          "user_id": row[1],
          "content": row[2],
          "created_at": row[3],
          "likes_count": row[4],
          "comments_count": row[5],
          "username": row[6], // Include username
        };
      }).toList();
    } catch (e) {
      print("Error during getPostsPaginated: $e");
      return [];
    }
  }

  // Create a post
  Future<void> createPost({required int userId, required String content}) async {
    if (content.isEmpty) {
      throw ArgumentError("Content cannot be empty.");
    }

    await ensureConnection(); // Ensure connection is open

    final timestamp = DateTime.now().toIso8601String();

    try {
      await _connection!.query(
        """
        INSERT INTO posts (user_id, content, created_at, likes_count)
        VALUES (@userId, @content, @createdAt, @likesCount)
        """,
        substitutionValues: {
          'userId': userId,
          'content': content,
          'createdAt': timestamp,
          'likesCount': 0,
        },
      );
      print("Post created successfully!");
    } catch (e) {
      print("Error during createPost: $e");
      throw Exception("Failed to create post: $e");
    }
  }

  Future<void> likePost(int postId) async {
    await ensureConnection(); // Ensure the connection is open

    try {
      await _connection!.query(
        """
        UPDATE posts
        SET likes_count = likes_count + 1
        WHERE id = @postId
        """,
        substitutionValues: {
          'postId': postId,
        },
      );
      print("Post $postId liked successfully!");
    } catch (e) {
      print("Error liking post: $e");
      throw Exception("Failed to like post: $e");
    }
  }

  Future<void> addComment({required int postId, required int userId, required String content}) async {
    if (content.isEmpty) {
      throw ArgumentError("Comment cannot be empty.");
    }

    await ensureConnection(); // Ensure connection is open

    final timestamp = DateTime.now().toIso8601String();

    try {
      await _connection!.query(
        """
        INSERT INTO comments (post_id, user_id, content, created_at)
        VALUES (@postId, @userId, @content, @createdAt)
        """,
        substitutionValues: {
          'postId': postId,
          'userId': userId,
          'content': content,
          'createdAt': timestamp,
        },
      );
      print("Comment added successfully!");
    } catch (e) {
      print("Error during addComment: $e");
      throw Exception("Failed to add comment: $e");
    }
  }

  // Get comments for a specific post
  Future<List<Map<String, dynamic>>> getComments(int postId) async {
    await ensureConnection(); // Ensure connection is open

    try {
      final results = await _connection!.query(
        """
        SELECT c.id, c.content, c.created_at::TEXT, u.username 
        FROM comments c
        JOIN users u ON c.user_id = u.id
        WHERE c.post_id = @postId
        ORDER BY c.created_at ASC
        """,
        substitutionValues: {'postId': postId},
      );

      return results.map((row) {
        return {
          "id": row[0],
          "content": row[1],
          "created_at": row[2],
          "username": row[3],
        };
      }).toList();
    } catch (e) {
      print("Error during getComments: $e");
      return [];
    }
  }

  // Add a new job offer
  Future<void> addJob({
    required String title,
    required String description,
    required String company,
    required int postedBy,
  }) async {
    await ensureConnection();

    try {
      await _connection!.query(
        """
        INSERT INTO jobs (title, description, company, posted_by, created_at)
        VALUES (@title, @description, @company, @postedBy, NOW())
        """,
        substitutionValues: {
          'title': title,
          'description': description,
          'company': company,
          'postedBy': postedBy,
        },
      );
      print("Job added successfully!");
    } catch (e) {
      print("Error adding job: $e");
      throw Exception("Failed to add job");
    }
  }

  // Retrieve all job offers
  Future<List<Map<String, dynamic>>> getJobs() async {
    await ensureConnection();

    try {
      // Option A) Simple join with user info but ignoring roles:
      // (If you want to also display roles, do a separate query or
      //  do an aggregate: e.g. using STRING_AGG for multiple roles.)
      final results = await _connection!.query(
        """
        SELECT j.id, j.title, j.description, j.company, j.posted_by, j.created_at::TEXT
        FROM jobs j
        JOIN users u ON j.posted_by = u.id
        ORDER BY j.created_at DESC
        """,
      );

      return results.map((row) {
        return {
          "id": row[0],
          "title": row[1],
          "description": row[2],
          "company": row[3],
          "posted_by": row[4],
          "created_at": row[5],
        };
      }).toList();
    } catch (e) {
      print("Error fetching jobs: $e");
      return [];
    }
  }

  Future<void> addApplication({
    required int jobId,
    required int userId,
    required String resumeLink,
  }) async {
    await ensureConnection();
    final query = '''
      INSERT INTO applications (job_id, user_id, resume_link, status, created_at)
      VALUES (@jobId, @userId, @resumeLink, 'submitted', CURRENT_TIMESTAMP);
    ''';

    await _connection!.query(query, substitutionValues: {
      'jobId': jobId,
      'userId': userId,
      'resumeLink': resumeLink,
    });
  }

  Future<List<Map<String, dynamic>>> getApplicantsForJob(int jobId) async {
    await ensureConnection(); // Ensure the database connection is open

    try {
      final results = await _connection!.query('''
        SELECT a.id, a.resume_link, u.username, u.email
        FROM applications a
        JOIN users u ON a.user_id = u.id
        WHERE a.job_id = @jobId
      ''', substitutionValues: {
        'jobId': jobId,
      });

      return results.map((row) {
        return {
          "application_id": row[0],
          "resume_link": row[1],
          "username": row[2],
          "email": row[3],
        };
      }).toList();
    } catch (e) {
      print("Error fetching applicants for job: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> getUserPostsAndJobs(int userId) async {
    await ensureConnection(); // Ensure the database connection is open

    try {
      // Fetch posts
      final postResults = await _connection!.query('''
        SELECT 
          p.id AS post_id, 
          p.content AS post_content, 
          p.created_at::TEXT AS post_created_at,
          p.likes_count, 
          u.username AS username,
          u.id AS user_id
        FROM posts p
        JOIN users u ON p.user_id = u.id
        WHERE u.id = @userId
        ORDER BY p.created_at DESC
      ''', substitutionValues: {
        'userId': userId,
      });

      final posts = postResults.map((row) {
        return {
          "id": row[0],
          "content": row[1],
          "created_at": row[2],
          "likes_count": row[3] ?? 0,
          "username": row[4],
          "user_id": row[5],
        };
      }).toList();

      // Fetch jobs
      final jobResults = await _connection!.query('''
        SELECT 
          j.id AS job_id, 
          j.title, 
          j.description, 
          j.company, 
          j.created_at::TEXT AS job_created_at, 
          j.posted_by AS user_id
        FROM jobs j
        WHERE j.posted_by = @userId
        ORDER BY j.created_at DESC
      ''', substitutionValues: {
        'userId': userId,
      });

      final jobs = jobResults.map((row) {
        return {
          "id": row[0],
          "title": row[1],
          "description": row[2],
          "company": row[3],
          "created_at": row[4],
          "user_id": row[5],
        };
      }).toList();

      return {"posts": posts, "jobs": jobs};
    } catch (e) {
      print("Error fetching posts and jobs: $e");
      return {"posts": [], "jobs": []};
    }
  }

  Future<int?> getCurrentUserId() async {
    await ensureConnection(); // Ensure database connection is active

    try {
      final result = await _connection!.query('''
            SELECT id FROM users WHERE email = @email
        ''', substitutionValues: {
        'email': await loadUserEmail(), // Fetch stored email from SharedPreferences
      });

      if (result.isNotEmpty) {
        final userId = result.first[0] as int;
        print("🔍 [SUCCESS] Retrieved User ID from database: $userId");
        return userId;
      } else {
        print("⚠️ [ERROR] User not found in database.");
        return null;
      }
    } catch (e) {
      print("❌ [DB ERROR] Failed to fetch user ID: $e");
      return null;
    }
  }


  // Check connection status between two users
  Future<Map<String, bool>> checkConnectionStatus({
    required int currentUserId,
    required int otherUserId,
  }) async {
    await ensureConnection();
    final result = await _connection!.query('''
      SELECT status FROM connections
      WHERE (user_id = @currentUserId AND connection_id = @otherUserId)
         OR (user_id = @otherUserId AND connection_id = @currentUserId)
    ''', substitutionValues: {
      'currentUserId': currentUserId,
      'otherUserId': otherUserId,
    });

    if (result.isEmpty) {
      return {"isConnected": false, "hasPendingRequest": false};
    }

    final status = result.first[0];
    return {
      "isConnected": status == 'accepted',
      "hasPendingRequest": status == 'pending',
    };
  }

  // Accept a connection request
  Future<void> acceptConnectionRequest(int requestId) async {
    await ensureConnection(); // Ensure the connection is open
    try {
      final result = await _connection!.query('''
        UPDATE connections
        SET status = 'accepted'
        WHERE id = @requestId
      ''', substitutionValues: {
        'requestId': requestId,
      });

      if (result.affectedRowCount == 0) {
        print("No rows were updated. Check if the row exists.");
      } else {
        print("Connection request accepted successfully!");
      }
    } catch (e) {
      print("Error accepting connection request: $e");
    }
  }

  // Decline a connection request
  Future<void> declineConnectionRequest(int requestId) async {
    await ensureConnection();
    await _connection!.query(
      '''
      DELETE FROM connections
      WHERE id = @requestId
      ''',
      substitutionValues: {'requestId': requestId},
    );
    print("Connection request declined: $requestId");
  }

  // Get connection requests for a user
  Future<List<Map<String, dynamic>>> getConnectionRequests(int userId) async {
    await ensureConnection();

    final results = await _connection!.query(
      '''
      SELECT c.id, u.username, c.status 
      FROM connections c
      JOIN users u ON c.user_id = u.id
      WHERE c.connection_id = @userId AND c.status = 'pending'
      ''',
      substitutionValues: {'userId': userId},
    );

    return results.map((row) {
      return {
        "id": row[0],       // Connection ID
        "username": row[1], // Requester's username
        "status": row[2],   // Request status (pending)
      };
    }).toList();
  }

  // Update the user's bio
  Future<void> updateUserBio(int userId, String newBio) async {
    await ensureConnection();
    await _connection!.query(
      '''
      UPDATE users
      SET bio = @newBio
      WHERE id = @userId
      ''',
      substitutionValues: {'newBio': newBio, 'userId': userId},
    );
    print("Bio updated for user $userId");
  }

  // Send a connection request
  Future<void> sendConnectionRequest({
    required int currentUserId,
    required int connectionId,
  }) async {
    await ensureConnection();
    try {
      await _connection!.query(
        '''
        INSERT INTO connections (user_id, connection_id, status, created_at)
        VALUES (@currentUserId, @connectionId, 'pending', NOW())
        ''',
        substitutionValues: {
          'currentUserId': currentUserId,
          'connectionId': connectionId,
        },
      );
      print("Connection request sent successfully!");
    } catch (e) {
      print("Error sending connection request: $e");
      throw Exception("Failed to send connection request.");
    }
  }

  Future<String> getConnectionStatus(int userId) async {
    await ensureConnection();
    try {
      final currentUserId = await getCurrentUserId();
      final result = await _connection!.query('''
        SELECT status 
        FROM connections 
        WHERE (user_id = @currentUserId AND connection_id = @userId) 
           OR (user_id = @userId AND connection_id = @currentUserId)
      ''', substitutionValues: {
        'currentUserId': currentUserId,
        'userId': userId,
      });

      if (result.isEmpty) return "not_connected";
      return result.first[0] as String;
    } catch (e) {
      print("Error fetching connection status: $e");
      return "not_connected";
    }
  }

  Future<void> cancelConnectionRequest({
    required int currentUserId,
    required int connectionId,
  }) async {
    await ensureConnection();
    try {
      await _connection!.query(
        '''
        DELETE FROM connections
        WHERE user_id = @currentUserId 
          AND connection_id = @connectionId 
          AND status = 'pending'
        ''',
        substitutionValues: {
          'currentUserId': currentUserId,
          'connectionId': connectionId,
        },
      );
      print("Connection request canceled successfully!");
    } catch (e) {
      print("Error canceling connection request: $e");
      throw Exception("Failed to cancel connection request.");
    }
  }

  Future<void> removeConnection({
    required int currentUserId,
    required int connectionId,
  }) async {
    await ensureConnection();
    try {
      await _connection!.query(
        '''
        DELETE FROM connections
        WHERE (user_id = @currentUserId AND connection_id = @connectionId) 
           OR (user_id = @connectionId AND connection_id = @currentUserId)
        ''',
        substitutionValues: {
          'currentUserId': currentUserId,
          'connectionId': connectionId,
        },
      );
      print("Connection removed successfully!");
    } catch (e) {
      print("Error removing connection: $e");
      throw Exception("Failed to remove connection.");
    }
  }

  Future<void> updateApplicationStatus(int applicationId, String status) async {
    await ensureConnection(); // Ensure the database connection is open
    try {
      await _connection!.query(
        '''
        UPDATE applications
        SET status = @status
        WHERE id = @applicationId
        ''',
        substitutionValues: {
          'applicationId': applicationId,
          'status': status,
        },
      );
      print("Application $applicationId updated to $status.");
    } catch (e) {
      print("Error updating application status: $e");
      throw Exception("Failed to update application status.");
    }
  }

  Future<void> deleteApplication(int applicationId) async {
    await ensureConnection(); // Ensure the database connection is open
    try {
      await _connection!.query(
        '''
        DELETE FROM applications
        WHERE id = @applicationId
        ''',
        substitutionValues: {
          'applicationId': applicationId,
        },
      );
      print("Application $applicationId deleted successfully.");
    } catch (e) {
      print("Error deleting application: $e");
      throw Exception("Failed to delete application.");
    }
  }

  Future<void> updateJob({
    required int jobId,
    required String title,
    required String description,
    required String company,
  }) async {
    await ensureConnection();
    try {
      await _connection!.query(
        '''
        UPDATE jobs
        SET title = @title, description = @description, company = @company
        WHERE id = @jobId
        ''',
        substitutionValues: {
          'jobId': jobId,
          'title': title,
          'description': description,
          'company': company,
        },
      );
      print("Job $jobId updated successfully.");
    } catch (e) {
      print("Error updating job: $e");
      throw Exception("Failed to update job.");
    }
  }

  Future<void> deleteJob(int jobId) async {
    await ensureConnection();
    try {
      await _connection!.query(
        '''
        DELETE FROM jobs
        WHERE id = @jobId
        ''',
        substitutionValues: {
          'jobId': jobId,
        },
      );
      print("Job $jobId deleted successfully.");
    } catch (e) {
      print("Error deleting job: $e");
      throw Exception("Failed to delete job.");
    }
  }

  Future<List<Map<String, dynamic>>> getAcceptedConnections(int userId) async {
    await ensureConnection();

    final results = await _connection!.query('''
    SELECT 
      CASE 
        WHEN user_id = @userId THEN connection_id
        ELSE user_id 
      END AS other_user_id,
      u.username
    FROM connections
    JOIN users u ON u.id = CASE 
      WHEN user_id = @userId THEN connection_id 
      ELSE user_id 
    END
    WHERE (user_id = @userId OR connection_id = @userId) 
      AND status = 'accepted'
  ''', substitutionValues: {'userId': userId});

    return results.map((row) {
      return {
        "connection_id": row[0], // The other person's user ID
        "username": row[1],      // Their username
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getChatHistory(int user1, int user2) async {
    await ensureConnection(); // Ensure database connection is open

    try {
      final results = await _connection!.query('''
      SELECT id, content, sender_id, receiver_id, created_at::TEXT
      FROM messages
      WHERE (sender_id = @user1 AND receiver_id = @user2)
         OR (sender_id = @user2 AND receiver_id = @user1)
      ORDER BY created_at ASC
    ''', substitutionValues: {
        'user1': user1,
        'user2': user2,
      });

      return results.map((row) {
        return {
          "id": row[0],
          "content": row[1],
          "sender_id": row[2],
          "receiver_id": row[3],
          "created_at": row[4], // Convert timestamp to string
        };
      }).toList();
    } catch (e) {
      print("❌ Error fetching chat history: $e");
      return [];
    }



  }

  Future<void> signOut() async {
    print("🔴 Logging out user...");

    // ✅ Only clear session when explicitly signing out
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentUserEmail');
    await prefs.remove('currentUserId');
    await prefs.remove('username');
    await prefs.remove('profilePic');
    await prefs.remove('role');

    print("✅ User logged out successfully. Database remains open.");
  }


  Future<int?> insertLargeObject(File file, int userId) async {
    await ensureConnection(); // Ensure connection is open

    try {
      print("📌 Starting transaction...");
      await _connection!.query('BEGIN');

      // 1️⃣ Create Large Object (returns an integer OID)
      final createResult = await _connection!.query('SELECT lo_create(0)::int AS oid');
      if (createResult.isEmpty || createResult.first.isEmpty || createResult.first[0] == null) {
        throw Exception("❌ lo_create() failed, returned an empty result!");
      }
      final int oid = createResult.first[0] as int;
      print("✅ Large Object created with OID: $oid");

      // 2️⃣ Open Large Object for Writing (WRITE mode)
      final openResult = await _connection!.query(
        'SELECT lo_open(@oid, 131072) AS fd', // WRITE Mode (131072 = INV_WRITE)
        substitutionValues: {'oid': oid},
      );
      if (openResult.isEmpty || openResult.first.isEmpty || openResult.first[0] == null) {
        throw Exception("❌ lo_open() failed for OID = $oid");
      }
      final int fd = openResult.first[0] as int;
      print("✅ Large Object opened with File Descriptor: $fd");

      // 3️⃣ Read File as Binary (Ensure True Binary Read)
      final Uint8List fileBytes = await file.readAsBytes();
      print("📌 Read file of size: ${fileBytes.length} bytes");

      // 4️⃣ **Ensure True Binary Insertion (Chunk Writing)**
      const int chunkSize = 8192; // PostgreSQL Large Object best practice
      for (int i = 0; i < fileBytes.length; i += chunkSize) {
        final Uint8List chunk = fileBytes.sublist(i, (i + chunkSize > fileBytes.length) ? fileBytes.length : i + chunkSize);
        try {
          await _connection!.query(
            "SELECT lowrite(@fd, @chunk::bytea)", // Explicitly cast chunk as bytea
            substitutionValues: {'fd': fd, 'chunk': chunk},
          );
        } catch (e) {
          print("❌ Error writing chunk at index $i: $e");
          throw Exception("❌ Failed to write chunk at $i");
        }
      }
      print("✅ Wrote all bytes correctly using chunk writing.");

      // 5️⃣ Close Large Object
      await _connection!.query('SELECT lo_close(@fd)', substitutionValues: {'fd': fd});
      print("✅ Large Object closed.");

      // 6️⃣ Save OID in users table
      await _connection!.query(
        'UPDATE users SET profile_pic_oid = @oidStr WHERE id = @userId',
        substitutionValues: {'oidStr': oid.toString(), 'userId': userId},
      );
      print("✅ Profile picture OID updated in database.");

      // 7️⃣ Commit Transaction
      await _connection!.query('COMMIT');
      print("✅ Transaction committed successfully!");

      return oid;
    } catch (e, stacktrace) {
      print("❌ Error inserting image LO: $e");
      await _connection!.query('ROLLBACK');
      print("❌ Transaction rolled back.");
      return null;
    }
  }













  // Future<Uint8List?> fetchLargeObject(String profilePicOid) async {
  //   await ensureConnection();
  //
  //   try {
  //     print("📌 Fetching profile image for OID: $profilePicOid");
  //     await _connection!.query('BEGIN');
  //
  //     // Convert OID from VARCHAR to INTEGER
  //     final int oid = int.tryParse(profilePicOid) ?? -1;
  //     if (oid < 0) {
  //       print("❌ Error: Invalid OID stored in profile_pic_oid.");
  //       await _connection!.query('ROLLBACK');
  //       return null;
  //     }
  //
  //     // 1️⃣ Open Large Object
  //     var result = await _connection!.query(
  //       "SELECT lo_open(@oid, 262144) AS fd", // 262144 = INV_READ
  //       substitutionValues: {'oid': oid},
  //     );
  //
  //     if (result.isEmpty || result.first.isEmpty || result.first[0] == null) {
  //       print("❌ Error: Failed to open Large Object (OID: $oid)");
  //       await _connection!.query('ROLLBACK');
  //       return null;
  //     }
  //
  //     final int fd = result.first[0];
  //     print("✅ Large Object opened with File Descriptor: $fd");
  //
  //     // 2️⃣ Read Large Object as binary
  //     result = await _connection!.query(
  //       "SELECT loread(@fd, 10000000)",
  //       substitutionValues: {'fd': fd},
  //     );
  //
  //     final dynamic rowValue = result.isNotEmpty ? result.first[0] : null;
  //     Uint8List? fileData;
  //
  //     if (rowValue != null && rowValue is List<int>) {
  //       fileData = Uint8List.fromList(rowValue);
  //
  //       // ✅ Debug: Print the first few bytes to check if it's a valid image format
  //       final firstBytes = fileData.take(8).toList();
  //       print('📸 Header bytes: $firstBytes');
  //
  //       print("✅ Successfully read ${fileData.length} bytes from OID: $oid");
  //     } else {
  //       print("❌ Error: Invalid binary data retrieved!");
  //     }
  //
  //     // 3️⃣ Close and commit
  //     await _connection!.query("SELECT lo_close(@fd)", substitutionValues: {'fd': fd});
  //     await _connection!.query('COMMIT');
  //
  //     return fileData;
  //   } catch (e) {
  //     await _connection!.query('ROLLBACK');
  //     print("❌ Error fetching Large Object: $e");
  //     return null;
  //   }
  // }

  Future<Uint8List?> fetchLargeObject(String profilePicOid) async {
    await ensureConnection();  // Ensure database connection

    try {
      print("📌 Fetching profile image for OID: $profilePicOid");
      await _connection!.query('BEGIN');  // Start transaction

      // Convert OID from string to integer
      final int oid = int.tryParse(profilePicOid) ?? -1;
      if (oid < 0) {
        print("❌ Error: Invalid OID stored in profile_pic_oid.");
        await _connection!.query('ROLLBACK');
        return null;
      }

      // 1️⃣ Open Large Object for reading
      final openResult = await _connection!.query(
        "SELECT lo_open(@oid, 262144) AS fd", // 262144 = INV_READ
        substitutionValues: {'oid': oid},
      );
      if (openResult.isEmpty || openResult.first.isEmpty || openResult.first[0] == null) {
        print("❌ Error: Failed to open Large Object (OID: $oid)");
        await _connection!.query('ROLLBACK');
        return null;
      }

      final int fd = openResult.first[0];
      print("✅ Large Object opened with File Descriptor: $fd");

      // 2️⃣ Read Large Object as **pure binary**
      final readResult = await _connection!.query(
        "SELECT loread(@fd, 10000000)", // Read up to 10MB
        substitutionValues: {'fd': fd},
      );

      await _connection!.query("SELECT lo_close(@fd)", substitutionValues: {'fd': fd});
      await _connection!.query('COMMIT');

      if (readResult.isEmpty || readResult.first.isEmpty || readResult.first[0] == null) {
        print("❌ Error: Image data is null!");
        return null;
      }

      final dynamic rowValue = readResult.first[0];

      // Ensure rowValue is a valid binary list
      if (rowValue is List<int>) {
        final Uint8List fileData = Uint8List.fromList(rowValue);
        print("✅ Successfully read ${fileData.length} bytes from OID: $oid");
        return fileData;
      } else {
        print("❌ Error: Retrieved data is not valid binary.");
        return null;
      }

    } catch (e, stack) {
      await _connection!.query('ROLLBACK');
      print("❌ Error fetching Large Object: $e\n$stack");
      return null;
    }
  }





  Future<Map<String, dynamic>?> getUserById(int userId) async {
    await ensureConnection();

    try {
      final result = await _connection!.query('''
      SELECT id, username, bio, profile_pic_oid
      FROM users
      WHERE id = @userId
    ''', substitutionValues: {'userId': userId});

      if (result.isEmpty) {
        return null;
      }

      final row = result[0];
      final roles = await getUserRoles(userId);

      return {
        "id": row[0],
        "username": row[1],
        "bio": row[2],
        "profile_pic_oid": row[3],  // ✅ Ensure profile_pic_oid is returned!
        "roles": roles,
      };
    } catch (e) {
      print("❌ Error fetching user by ID: $e");
      return null;
    }
  }


  Future<String?> getTestImageOid() async {
    await ensureConnection();  // Ensure DB connection is open

    try {
      final result = await _connection!.query('''
      SELECT image_oid FROM posts WHERE id = 1 LIMIT 1
    ''');

      if (result.isNotEmpty && result.first[0] != null) {
        final String oidStr = result.first[0].toString();
        print("🔍 Found test image OID: $oidStr");
        return oidStr;
      } else {
        print("❌ No test image found in posts.");
        return null;
      }
    } catch (e) {
      print("❌ Error fetching test image OID: $e");
      return null;
    }
  }


  Future<bool> updateUserProfilePicture(int userId, String profilePicOid) async {
    print("📌 Updating profile picture OID in database for user ID: $userId");

    try {
      await _connection!.query(
        'UPDATE users SET profile_pic_oid = @oid WHERE id = @userId',
        substitutionValues: {
          'oid': profilePicOid,
          'userId': userId,
        },
      );

      print("✅ Profile picture OID updated successfully.");
      return true;
    } catch (e, stacktrace) {
      print("❌ Error updating profile picture OID: $e");
      print("🛑 Stacktrace:\n$stacktrace");
      return false;
    }
  }

  Future<String?> saveLargeObject(String filePath) async {
    print("📌 Starting Java JAR to save large object...");

    try {
      Process process = await Process.start(
        'java',
        ['-jar', 'assets/upload_photo.jar', filePath],
      );

      // Capture output (Java should return the OID)
      String output = await process.stdout.transform(SystemEncoding().decoder).join();
      String errorOutput = await process.stderr.transform(SystemEncoding().decoder).join();

      // Ensure process exits properly
      int exitCode = await process.exitCode;
      process.kill(); // ✅ Close process

      print("📌 Java process exited with code: $exitCode");
      if (exitCode == 0) {
        print("✅ Java JAR returned OID: $output");
        return output.trim();
      } else {
        print("❌ Java JAR failed: $errorOutput");
        return null;
      }
    } catch (e, stacktrace) {
      print("❌ Error running Java JAR: $e");
      print("🛑 Stacktrace:\n$stacktrace");
      return null;
    }
  }





}

