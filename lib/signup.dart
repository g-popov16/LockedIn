import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart'; // For password hashing
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'sql.dart'; // Database helper
import 'home_page.dart'; // Main page after sign-up
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_large_object/flutter_large_object.dart';
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
  final List<String> _roles = ["ROLE_USER", "ROLE_SPONSOR", "ROLE_TEAM"];
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
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);

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
        "profile_pic_url": "", // Placeholder for profile picture URL (changed from profile_pic_oid)
        "role": _selectedRole!.toLowerCase(),
      };

      print("📌 Attempting to sign up user with data: $userData");

      try {
        bool success = await db.signUp(userData);
        if (success) {
          print("✅ User signed up successfully!");

          // 1️⃣ Retrieve new user ID from SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          final newUserId = prefs.getInt('user_id');
          print("📌 Retrieved user ID from SharedPreferences: $newUserId");

          // 2️⃣ If a profile image is selected, upload to Firebase Storage
          String? profilePicUrl;
          if (_profileImage != null && newUserId != null) {
            print("📌 Uploading profile picture for user ID: $newUserId");

            profilePicUrl = await _firebaseStorage.uploadProfilePicture(_profileImage!, newUserId.toString());

            if (profilePicUrl != null) {
              print("✅ Profile picture uploaded to Firebase: $profilePicUrl");

              // 3️⃣ Update user in database with new profile_pic_url
              bool updateSuccess = await db.updateUserProfilePicture(newUserId, profilePicUrl);
              if (updateSuccess) {
                print("✅ User profile picture URL updated in database.");
              } else {
                print("❌ Failed to update profile picture URL in database.");
              }
            } else {
              print("❌ Failed to upload profile picture to Firebase.");
            }
          } else {
            print("⚠ No profile picture to upload or user ID is null.");
          }

          // 4️⃣ Save user session
          await db.saveUserEmail(userEmail);
          print("✅ User email saved locally.");

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account created successfully!")),
          );

          // 5️⃣ Navigate to HomePage
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

  Future<String?> saveLargeObject(String filePath) async {
    if (Platform.isAndroid) {
      print("📌 Using Java JAR-based implementation on Android...");
      return await runJarForLargeObject(filePath);
    } else {
      print("❌ Unsupported platform.");
      return null;
    }
  }

  Future<String?> runJarForLargeObject(String filePath) async {
    try {
      const MethodChannel _channel = MethodChannel('flutter/large_object');
      return await _channel.invokeMethod('saveLargeObject', {'filePath': filePath});
    } catch (e, stacktrace) {
      print("❌ Error running Java JAR: $e");
      print("🛑 Stacktrace:\n$stacktrace");
      return null;
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
                        ? const Icon(Icons.add_a_photo, size: 50, color: Colors.grey)
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
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter your username' : null,
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
                    } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
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
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter your name' : null,
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
                    border: OutlineInputBorder(),
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                  ),
                  items: _roles
                      .map((role) => DropdownMenuItem(
                    value: role,
                    child: Text(role, style: Theme.of(context).textTheme.bodyLarge),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value;
                    });
                  },
                  validator: (value) => value == null || value.isEmpty ? "Please select a role" : null,
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
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
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
}
