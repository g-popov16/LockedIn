import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart'; // For password hashing
import 'package:shared_preferences/shared_preferences.dart'; // For session persistence
import 'sql.dart'; // Your PostgresDB helper
import 'signup.dart'; // SignUp page
import 'home_page.dart'; // MainPage after successful sign-in
import 'dart:async';

void main() {
  
  WidgetsFlutterBinding.ensureInitialized(); // Ensure plugins are initialized
  runApp(const LinkedInSignInApp());
}

class LinkedInSignInApp extends StatelessWidget {
  const LinkedInSignInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
  // Scaffold and background colors
  scaffoldBackgroundColor: const Color(0xFF1E1E1E),
  primaryColor: const Color(0xFFE74C3C), // Accent color for buttons
  inputDecorationTheme: const InputDecorationTheme(
      hintStyle: TextStyle(color: Colors.grey), // Keeps hint text grey
    ),

  // Updated TextTheme
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), // headline1 replacement
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), // headline6 replacement
    bodyLarge: TextStyle(fontSize: 16, color: Colors.white), // bodyText1 replacement
    bodyMedium: TextStyle(fontSize: 14, color: Colors.white70), // bodyText2 replacement
  ),

  // AppBar theme
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF2C3E50), // Dark grey
    iconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  ),

  // BottomNavigationBar theme
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFF2C3E50), // Same as AppBar for consistency
    selectedItemColor: Color(0xFFE74C3C), // Accent red for selected items
    unselectedItemColor: Colors.white70,
  ),

  // Card theme
  cardColor: const Color(0xFF2C2C2C), // Slightly lighter than scaffold background
  cardTheme: CardTheme(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 2,
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
  ),

  // FloatingActionButton theme
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFFE74C3C),
    foregroundColor: Colors.white, // Icon color
  ),
),

      home: const SplashScreen(), // Start with the SplashScreen
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _displayText = "";
  final String _fullText = "LockedIn"; // The text to spell out
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2), // Adjust duration as needed
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();
    _spellOutText(); // Start spelling out text
  }

  Future<void> _spellOutText() async {
    for (int i = 0; i < _fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 100), () {
        setState(() {
          _displayText += _fullText[_currentIndex];
          _currentIndex++;
        });
      });
    }
    // Add a 2-second delay after finishing the animation
    await Future.delayed(const Duration(seconds: 2));
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('currentUserEmail'); // Check for saved email
    print("DEBUG: Email from session in SplashScreen: $email");

    if (email != null) {
      print("DEBUG: Navigating to HomePage with email: $email");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(userEmail: email),
        ),
      );
    } else {
      print("DEBUG: No session found. Navigating to SignInPage.");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Text(
              _displayText,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent.withOpacity(_animation.value),
              ),
            );
          },
        ),
      ),
    );
  }
}




  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()), // Show a loading spinner
    );
  }



class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final db = PostgresDB(); // Database instance
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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

  Future<void> _handleSignIn() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      try {
        final user = await db.getUserByEmail(email);

        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No account found with that email.', style: Theme.of(context).textTheme.bodyMedium)),
          );
          return;
        }

        final hashedPassword = user['password'];
        final isPasswordCorrect = BCrypt.checkpw(password, hashedPassword);

        if (!isPasswordCorrect) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid password. Please try again.', style: Theme.of(context).textTheme.bodyMedium)),
          );
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentUserEmail', email);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(userEmail: email),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during sign-in: $e', style: Theme.of(context).textTheme.bodyMedium)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Themed background
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        centerTitle: true,
        title: Text(
          "Sign In",
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome Back!",
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  style: Theme.of(context).textTheme.bodyLarge, // Themed text
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Theme.of(context).primaryColor),
                    ),
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
                  controller: _passwordController,
                  style: Theme.of(context).textTheme.bodyLarge, // Themed text
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Theme.of(context).primaryColor),
                    ),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor, // Themed button color
                    ),
                    onPressed: _handleSignIn,
                    child: Text(
                      "Sign In",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () {
                      // Navigate to Sign-Up page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpPage(),
                        ),
                      );
                    },
                    child: Text(
                      "Don't have an account? Create one",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).primaryColor),
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

