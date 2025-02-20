import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

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

      // (NEW) Once connected, begin listening for new messages
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

    // Mark connection as completed
    _connectionCompleter?.complete();
  } catch (e) {
    print("❌ Error reopening database connection: $e");
    _connectionCompleter?.completeError(e);
  } finally {
    _isOpeningConnection = false;
  }
}




  Future<void> closeConnection() async {
  if (_connection != null && !_connection!.isClosed) {
    print("⚠️ Clearing user session instead of closing database connection...");
    
    // Clear only the session data instead of closing the database
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentUserEmail');
    
    print("✅ User session cleared. Database remains open.");
  }
}


  // (NEW) Listen for notifications on 'new_message'
  Future<void> listenForNewMessages() async {
    if (_connection == null) return;

    // Execute the LISTEN command
    await _connection!.query("LISTEN new_message");

    // Any new NOTIFY on 'new_message' triggers this subscription
    _connection!.notifications.listen((event) {
      if (event.channel == 'new_message') {
        try {
          final payload = jsonDecode(event.payload);
          print("🔔 Received new message: $payload");
          // Push it into our Stream so the UI can react
          _messageStreamController.add(payload);
        } catch (e) {
          print("Error parsing NOTIFY payload: $e");
        }
      }
    });

    print("🔊 Now listening on channel 'new_message'.");
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
    return prefs.getString('currentUserEmail');
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
  await ensureConnection(); // Make sure the connection is open
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

      // Save email to session storage
      await saveUserEmail(user["email"]);
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


  // Sign up
  Future<bool> signUp(Map<String, dynamic> userData) async {
  await ensureConnection(); // Ensure connection is open
  try {
    // Insert basic user info into 'users'
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

    final newUserId = insertedUser.first[0] as int;

    // Insert exactly ONE role
    // userData["role"] might be a single string like "ROLE_USER" or "ROLE_ADMIN"
    final role = userData["role"] ?? "ROLE_USER";

    // Insert into 'user_roles' (one row per user)
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

    print("User created successfully!");
    return true;
  } catch (e) {
    print("Error during sign-up: $e");
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
  Future<int?> getCurrentUserId() async {
    try {
      // Retrieve the email of the current user from SharedPreferences
      final email = await loadUserEmail();
      if (email != null) {
        // Query the database for the user's ID
        final user = await getUserByEmail(email);
        if (user != null) {
          return user['id']; // Return the user's ID
        }
      }
    } catch (e) {
      print("Error retrieving current user ID: $e");
    }
    return null; // Return null if user ID cannot be retrieved
  }

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

  Future<Map<String, dynamic>?> getUserById(int userId) async {
    await ensureConnection();

    try {
      final result = await _connection!.query(
        """
        SELECT id, username, bio, profile_pic_url
        FROM users
        WHERE id = @userId
        """,
        substitutionValues: {'userId': userId},
      );

      if (result.isEmpty) {
        return null;
      }

      // parse the result
      final row = result[0];
      // fetch roles from user_roles
      final roles = await getUserRoles(userId);

      return {
        "id": row[0],
        "username": row[1],
        "bio": row[2],
        "profile_pic_url": row[3],
        "roles": roles,
      };
    } catch (e) {
      print("Error fetching user by ID: $e");
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

  // Clear session but do not close database connection
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('currentUserEmail');

  print("✅ User logged out successfully. Database remains open.");
}




  
}

