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
      return;
    }
    _connection = _createConnection();
    try {
      await _connection!.open();

      // Ensure LISTEN starts properly
      await listenForNewMessages();
    } catch (e) {
      rethrow;
    }
  }

  bool _isOpeningConnection = false;
  Completer<void>? _connectionCompleter;

  Future<void> ensureConnection() async {
    if (_connection != null && !_connection!.isClosed) {
      return;
    }

    if (_isOpeningConnection) {
      await _connectionCompleter?.future;
      return;
    }

    _isOpeningConnection = true;
    _connectionCompleter = Completer<void>();


    try {
      _connection = _createConnection();
      await _connection!.open();

      //  Restart message listener after reconnecting
      await listenForNewMessages();

      _connectionCompleter?.complete();
    } catch (e) {
      _connectionCompleter?.completeError(e);
    } finally {
      _isOpeningConnection = false;
    }
  }

  void _restartMessageStream() {

    // Close the existing stream safely
    _messageStreamController.close().then((_) {

      // Create a new stream inside the same object without reassigning
      _listenForNewMessages();
    });

  }

  void _listenForNewMessages() async {
    if (_connection == null || _connection!.isClosed) {
      return;
    }


    await _connection!.execute("LISTEN new_message_event;");

    _connection!.notifications.listen((event) {

      try {
        final newMessage = jsonDecode(event.payload) as Map<String, dynamic>;
        if (!_messageStreamController.isClosed) {
          _messageStreamController.add(newMessage);
        }
      } catch (e) {
      }
    });

  }

  Future<void> closeConnection({bool clearSession = false}) async {
    if (_connection != null && !_connection!.isClosed) {

      if (clearSession) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('currentUserEmail');
      }

    }
  }

  // (NEW) Listen for notifications on 'new_message'
  Future<void> listenForNewMessages() async {
    if (_connection == null || _connection!.isClosed) {
      return;
    }


    await _connection!.execute("LISTEN new_message;");

    _connection!.notifications.listen((event) {

      if (event.channel == 'new_message') {
        try {
          final payload = jsonDecode(event.payload);

          if (!_messageStreamController.isClosed) {
            _messageStreamController.add(payload);
          }
        } catch (e) {
        }
      }
    });

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
    } catch (e) {
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
        // Debugging
        return fetchedRole;
      } else {
        return "Unknown Role";
      }
    } catch (e) {
      return "Unknown Role";
    }
  }

  // Sign in
  Future<Map<String, dynamic>?> signIn(String email, String password) async {
    await ensureConnection(); // Ensure database connection is open

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

        //  Save email & user details to SharedPreferences
        await _saveUserToPreferences(user);


        return user;
      } else {
        return null;
      }
    } catch (e) {
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

      //  Save email & user ID in SharedPreferences
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', userData["email"]);
      await prefs.setInt('user_id', newUserId);

      return true;
    } catch (e) {
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
      return null;
    }
  }

  // Get current user ID

  // Paginated posts retrieval
  Future<List<Map<String, dynamic>>> getPostsPaginated({
    required int limit,
    required int offset,
    required int currentUserId,
  }) async {
    await ensureConnection();

    final results = await _connection!.query('''
  SELECT 
    p.id,
    p.user_id,
    p.content,
    p.created_at::TEXT,
    u.username,
    p.image_url,  -- 🔍 This field might not be returning valid data!
    -- Check if this user has liked the post
    CASE 
      WHEN EXISTS (
        SELECT 1 FROM post_likes pl 
        WHERE pl.post_id = p.id 
        AND pl.user_id = @currentUserId
      ) THEN TRUE ELSE FALSE
    END AS is_liked
  FROM posts p
  JOIN users u ON p.user_id = u.id
  ORDER BY p.created_at DESC
  LIMIT @limit OFFSET @offset
  ''', substitutionValues: {
      'limit': limit,
      'offset': offset,
      'currentUserId': currentUserId,
    });

    return results.map((row) {
      return {
        "id": row[0] as int? ?? 0,
        "user_id": row[1] as int? ?? 0,
        "content": row[2] as String? ?? "",
        "created_at": row[3] as String? ?? "",
        "username": row[4] as String? ?? "Unknown",
        "image_url": row[5] as String? ?? "",
        "is_liked": row[6] as bool? ?? false,
      };
    }).toList();
  }





  // Create a post
  Future<void> createPost({
    required int userId,
    required String content,
    String? imageUrl, // Add optional image URL
  }) async {
    if (content.isEmpty && imageUrl == null) {
      throw ArgumentError("Post must have text or an image.");
    }

    await ensureConnection();

    final timestamp = DateTime.now().toIso8601String();

    try {
      await _connection!.query(
        """
  INSERT INTO posts (user_id, content, created_at, image_url)
  VALUES (@userId, @content, @createdAt, @imageUrl)
  """,
        substitutionValues: {
          'userId': userId,
          'content': content,
          'createdAt': timestamp,
          'imageUrl': imageUrl,
        },
      );

    } catch (e) {
      throw Exception("Failed to create post: $e");
    }
  }

  Future<int> toggleLikePost(int postId, int userId) async {
    await ensureConnection();

    // 1) Check if user has already liked the post
    final check = await _connection!.query(
      '''
    SELECT 1
    FROM post_likes
    WHERE user_id = @userId AND post_id = @postId
    LIMIT 1
    ''',
      substitutionValues: {
        'userId': userId,
        'postId': postId,
      },
    );

    if (check.isEmpty) {
      // 2) If no row exists -> Insert row (like the post)
      await _connection!.query('''
      INSERT INTO post_likes (user_id, post_id)
      VALUES (@userId, @postId)
    ''', substitutionValues: {
        'userId': userId,
        'postId': postId,
      });
    } else {
      // 3) If row exists -> Remove row (unlike the post)
      await _connection!.query('''
      DELETE FROM post_likes
      WHERE user_id = @userId AND post_id = @postId
    ''', substitutionValues: {
        'userId': userId,
        'postId': postId,
      });
    }

    // 4) Calculate the current like count by counting rows in post_likes
    final countResult = await _connection!.query(
      '''
    SELECT COUNT(*)
    FROM post_likes
    WHERE post_id = @postId
    ''',
      substitutionValues: {'postId': postId},
    );

    // 5) Return the updated like count
    return countResult.isNotEmpty ? countResult.first[0] as int : 0;
  }


  Future<void> addComment(
      {required int postId,
      required int userId,
      required String content}) async {
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
    } catch (e) {
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
    } catch (e) {
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
    await ensureConnection();
    try {
      final result = await _connection!.query(
        '''
      SELECT 
        a.id AS application_id, 
        a.user_id AS user_id, 
        u.username, 
        u.email, 
        a.resume_link
      FROM applications a
      JOIN users u ON a.user_id = u.id
      WHERE a.job_id = @jobId
      ''',
        substitutionValues: {'jobId': jobId},
      );

      List<Map<String, dynamic>> applicants = result.map((row) {
        return {
          "application_id": row[0] is int ? row[0] : int.tryParse(row[0].toString()) ?? -1,
          "user_id": row[1] is int ? row[1] : int.tryParse(row[1].toString()) ?? -1,
          "username": row[2]?.toString() ?? "Unknown",
          "email": row[3]?.toString() ?? "No email",
          "resume_link": row[4]?.toString() ?? "",
        };
      }).toList();

      return applicants;
    } catch (e) {
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
      return {"posts": [], "jobs": []};
    }
  }

  Future<int?> getCurrentUserId() async {
    await ensureConnection(); // Ensure database connection is active

    try {
      final result = await _connection!.query('''
            SELECT id FROM users WHERE email = @email
        ''', substitutionValues: {
        'email':
            await loadUserEmail(), // Fetch stored email from SharedPreferences
      });

      if (result.isNotEmpty) {
        final userId = result.first[0] as int;
        return userId;
      } else {
        return null;
      }
    } catch (e) {
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
      } else {
      }
    } catch (e) {
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
        "id": row[0], // Connection ID
        "username": row[1], // Requester's username
        "status": row[2], // Request status (pending)
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
        "username": row[1], // Their username
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getChatHistory(
      int user1, int user2) async {
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
      return [];
    }
  }

  Future<void> signOut() async {

    //  Only clear session when explicitly signing out
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentUserEmail');
    await prefs.remove('currentUserId');
    await prefs.remove('username');
    await prefs.remove('profilePic');
    await prefs.remove('role');

  }

  Future<Map<String, dynamic>?> getUserById(int userId) async {
    await ensureConnection();

    try {
      final result = await _connection!.query('''
    SELECT id, username, bio, profile_pic_url  --  Fetch profile_pic_url
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
        "profile_pic_url": row[3], //  Return profile_pic_url
        "roles": roles,
      };
    } catch (e) {
      return null;
    }
  }

  Future<String?> getTestImageOid() async {
    await ensureConnection(); // Ensure DB connection is open

    try {
      final result = await _connection!.query('''
      SELECT image_oid FROM posts WHERE id = 1 LIMIT 1
    ''');

      if (result.isNotEmpty && result.first[0] != null) {
        final String oidStr = result.first[0].toString();
        return oidStr;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateUserProfilePicture(
      int userId, String profilePicUrl) async {

    try {
      await _connection!.query(
        'UPDATE users SET profile_pic_url = @url WHERE id = @userId',
        substitutionValues: {
          'url': profilePicUrl, // Change 'oid' to 'url'
          'userId': userId,
        },
      );

      return true;
    } catch (e, stacktrace) {
      return false;
    }
  }

  Future<bool> createTeam(Map<String, dynamic> teamData) async {
    try {
      await ensureConnection();

      final result = await _connection!.query(
        "INSERT INTO teams (name, created_by) VALUES (@name, @created_by) RETURNING id",
        substitutionValues: {
          "name": teamData["name"],
          "created_by": teamData["created_by"],
        },
      );

      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<int?> getTeamIdByJobId(int jobId) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        '''
      SELECT t.id AS team_id 
      FROM teams t
      JOIN jobs j ON j.posted_by = t.created_by
      WHERE j.id = @jobId
      ''',
        substitutionValues: {'jobId': jobId},
      );

      if (result.isNotEmpty && result[0][0] != null) {
        int teamId = int.tryParse(result[0][0].toString()) ?? -1;
        return teamId;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }


  Future<bool> addUserToTeam({
    required int teamId,
    required int userId,
    required String role,
  }) async {
    try {
      await ensureConnection();
      await _connection!.query(
        "INSERT INTO team_members (team_id, user_id, role) VALUES (@teamId, @userId, @role)",
        substitutionValues: {
          "teamId": teamId,
          "userId": userId,
          "role": role,
        },
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getTeamByUserId(int userId) async {
    await ensureConnection();

    try {
      final result = await _connection!.query(
        '''
      SELECT t.id, t.name, t.created_by, u.username AS leader_name
      FROM teams t
      JOIN users u ON t.created_by = u.id
      WHERE t.id = (
        SELECT team_id FROM team_members WHERE user_id = @userId
        UNION
        SELECT id FROM teams WHERE created_by = @userId
        LIMIT 1
      )
      ''',
        substitutionValues: {'userId': userId},
      );

      if (result.isNotEmpty) {
        return {
          "id": result.first[0] as int,
          "name": result.first[1] as String,
          "created_by": result.first[2] as int, // Team Leader's ID
          "leader_name": result.first[3] as String, // Team Leader's Name
        };
      }

      return null;
    } catch (e) {
      return null;
    }
  }



  Future<List<Map<String, dynamic>>> getTeamMembers(int teamId) async {
    await ensureConnection();

    try {
      final result = await _connection!.query(
        '''
      SELECT u.id, u.username
      FROM team_members tm
      JOIN users u ON tm.user_id = u.id
      WHERE tm.team_id = @teamId

      UNION

      SELECT u.id, u.username
      FROM teams t
      JOIN users u ON t.created_by = u.id
      WHERE t.id = @teamId
      ''',
        substitutionValues: {'teamId': teamId},
      );

      return result.map((row) => {
        "id": row[0] as int,
        "username": row[1] as String,
      }).toList();
    } catch (e) {
      return [];
    }
  }



  Future<bool> leaveTeam(int userId, int teamId) async {
    await ensureConnection();

    try {
      //  First, check if the user is the team leader
      final leaderCheck = await _connection!.query(
        '''
      SELECT 1 FROM teams WHERE created_by = @userId AND id = @teamId
      ''',
        substitutionValues: {'userId': userId, 'teamId': teamId},
      );

      if (leaderCheck.isNotEmpty) {
        return false; // Prevent the leader from leaving
      }

      //  If not the leader, remove from `team_members`
      await _connection!.query(
        '''
      DELETE FROM team_members WHERE user_id = @userId AND team_id = @teamId
      ''',
        substitutionValues: {'userId': userId, 'teamId': teamId},
      );

      return true;
    } catch (e) {
      return false;
    }
  }



  Future<bool> isUserInTeam(int userId) async {
    await ensureConnection();

    try {
      final result = await _connection!.query(
        '''
      SELECT 1 FROM team_members WHERE user_id = @userId LIMIT 1
      ''',
        substitutionValues: {'userId': userId},
      );

      return result.isNotEmpty; // Returns true if user is in a team
    } catch (e) {
      return false;
    }
  }


  Future<bool> isUserTeamCreator(int userId) async {
    await ensureConnection();

    try {
      final result = await _connection!.query(
        '''
      SELECT 1 FROM teams WHERE created_by = @userId LIMIT 1
      ''',
        substitutionValues: {'userId': userId},
      );

      return result.isNotEmpty; // Returns true if user created a team
    } catch (e) {
      return false;
    }
  }
}
