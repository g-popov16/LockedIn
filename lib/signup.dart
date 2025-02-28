import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart'; // For password hashing
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'sql.dart'; // Database helper
import 'home_page.dart'; // Main page after sign-up
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/firebase_storage_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final FirebaseStorageService _firebaseStorage = FirebaseStorageService();
  final db = PostgresDB();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();

  String? _selectedRole;

  // ✅ Role mapping
  final Map<String, String> _roleMapping = {
    "User": "ROLE_USER",
    "Team": "ROLE_TEAM",
    "Sponsor": "ROLE_SPONSOR",
  };

  // ✅ Convert roleMapping keys to list when accessed
  List<String> get _roles => _roleMapping.keys.toList();

  File? _profileImage;

  @override
  void initState() {
    super.initState();
    db.openConnection();
  }

  @override
  void dispose() {
    db.closeConnection();
    super.dispose();
  }

  Future<void> pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> handleSignUp() async {
    print("📌 Starting sign-up process...");

    if (_formKey.currentState!.validate() && _selectedRole != null) {
      final hashedPassword = BCrypt.hashpw(
        passwordController.text.trim(),
        BCrypt.gensalt(),
      );

      final userEmail = emailController.text.trim();

      final userData = {
        "username": usernameController.text.trim(),
        "password": hashedPassword,
        "email": userEmail,
        "name": nameController.text.trim(),
        "bio": bioController.text.trim(),
        "profile_pic_url": "",
        "role": _roleMapping[_selectedRole] ?? "ROLE_USER",
      };

      print("📌 Attempting to sign up user with data: $userData");

      try {
        bool success = await db.signUp(userData);
        if (success) {
          print("✅ User signed up successfully!");

          // Retrieve newly created user ID
          final prefs = await SharedPreferences.getInstance();
          final newUserId = prefs.getInt('user_id');

          if (newUserId == null) {
            print("❌ Error: User ID not found after sign-up.");
            return;
          }

          // ✅ If role is "Team", ask for team name
          if (_selectedRole == "Team") {
            await _showTeamNameDialog(newUserId);
          }

          // ✅ If a profile image is selected, upload to Firebase Storage
          if (_profileImage != null) {
            print("📌 Uploading profile picture for user ID: $newUserId");

            // Upload image to Firebase Storage and get URL
            String? profilePicUrl = await _firebaseStorage.uploadProfilePicture(
              _profileImage!,
              newUserId.toString(),
            );

            if (profilePicUrl != null) {
              print("✅ Profile picture uploaded to Firebase: $profilePicUrl");

              // ✅ Update `profile_pic_url` in the database
              bool updateSuccess = await db.updateUserProfilePicture(
                newUserId,
                profilePicUrl,
              );

              if (updateSuccess) {
                print("✅ User profile picture URL updated in database.");
              } else {
                print("❌ Failed to update profile picture URL in database.");
              }
            } else {
              print("❌ Failed to upload profile picture to Firebase.");
            }
          } else {
            print("⚠ No profile picture to upload.");
          }

          // ✅ Save user session
          await db.saveUserEmail(userEmail);
          print("✅ User email saved locally.");

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account created successfully!")),
          );

          // ✅ Navigate to HomePage
          print("📌 Navigating to HomePage...");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage(userEmail: userEmail)),
          );
        } else {
          print("❌ Sign-up failed, check database logs.");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Sign-up failed. Please try again.")),
          );
        }
      } catch (e, stacktrace) {
        print("❌ Error during sign-up: $e");
        print("🛑 Stacktrace:\n$stacktrace");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An error occurred. Please try again.")),
        );
      }
    } else {
      print("⚠ Sign-up form validation failed or role is null.");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(
          "Create Account",
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : null,
                    child: _profileImage == null
                        ? const Icon(Icons.add_a_photo,
                            size: 50, color: Colors.grey)
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter your username'
                      : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    } else if (value.length < 6) {
                      return 'Password must be at least 6 characters long';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(),
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                        .hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter your name'
                      : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: bioController,
                  decoration: InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: "Select Role",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                  ),
                  items: _roles
                      .map((role) => DropdownMenuItem(
                    value: role,
                    child: Text(
                      role,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ))
                      .toList(),
                  onChanged: (value) async {
                    setState(() {
                      _selectedRole = value;
                    });

                  },
                  validator: (value) =>
                  value == null || value.isEmpty ? "Please select a role" : null,
                  style: Theme.of(context).textTheme.bodyLarge,
                  dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                    onPressed: handleSignUp,
                    child: Text(
                      "Sign Up",
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showTeamNameDialog(int userId) async {
    TextEditingController teamNameController = TextEditingController();

    String? teamName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Enter Team Name"),
          content: TextField(
            controller: teamNameController,
            decoration: const InputDecoration(
              hintText: "Team Name",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close without saving
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (teamNameController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(teamNameController.text.trim());
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (teamName != null) {
      await _saveTeamToDatabase(teamName, userId);
    }
  }

  Future<void> _saveTeamToDatabase(String teamName, int userId) async {
    try {
      final bool success = await db.createTeam({
        "name": teamName,
        "created_by": userId, // Use user ID from sign-up
      });

      if (success) {
        print("✅ Team '$teamName' created successfully.");
      } else {
        print("❌ Error creating team.");
      }
    } catch (e) {
      print("❌ Error saving team to database: $e");
    }
  }


}
