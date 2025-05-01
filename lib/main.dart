import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Keep this
import 'sql.dart';
import 'signup.dart'; // Assuming this is the correct name for your SignUpPage file
import 'home_page.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart'; // Import google_fonts

// --- Add import for the Introduction Screen ---
import 'introduction_animation/introduction_animation_screen.dart'; // Adjust path if needed

// 1. Import Flutter localization packages
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// --- Imports needed for the Login UI ---
import 'package:ionicons/ionicons.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:flutter/cupertino.dart'; // Needed for CupertinoPageRoute if navigating to Register like original Login
// import 'package:image_picker/image_picker.dart'; // Removed - Not needed here
// import 'dart:io'; // Removed - Not needed here
// import '../utils/firebase_storage_service.dart'; // Removed - Not needed here


// --- ADD IMPORTS FOR CUSTOM COMPONENTS ---
// !!! Adjust path if you placed files elsewhere !!!
import 'package:lockedin/components/text_form_builder.dart'; // Assuming path is lib/components/
import 'package:lockedin/components/password_text_field.dart'; // Assuming path is lib/components/


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Ensure Firebase is initialized

  runApp(const LockedIn());
}


class LockedIn extends StatelessWidget {
  const LockedIn({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    const Color primaryAppColor = Color(0xFFE74C3C); // Example Red/Orange Accent

    return MaterialApp(
      title: 'LockedIn',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('bg', ''),
        // Add other supported locales here
      ],
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: primaryAppColor,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryAppColor,
          brightness: Brightness.dark,
          primary: primaryAppColor,
          secondary: primaryAppColor,
          background: const Color(0xFF121212),
          surface: const Color(0xFF1E1E1E),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.white,
          onSurface: Colors.white.withOpacity(0.87),
          error: Colors.redAccent[100] ?? Colors.redAccent,
          onError: Colors.black,
        ),
        textTheme: GoogleFonts.interTextTheme( baseTheme.textTheme ).apply(
          bodyColor: Colors.white.withOpacity(0.87),
          displayColor: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1E1E1E),
          iconTheme: IconThemeData(color: Colors.white.withOpacity(0.9)),
          elevation: 0,
          titleTextStyle: GoogleFonts.inter(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
            hintStyle: TextStyle(color: Colors.grey[600]),
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
            filled: true,
            fillColor: const Color(0xFF2C2C2C),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            border: OutlineInputBorder( borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none ),
            enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none ),
            focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: primaryAppColor, width: 1.5) ),
            errorBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Colors.red.shade400, width: 1.0) ),
            focusedErrorBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Colors.red.shade400, width: 1.5) ),
            errorStyle: TextStyle(color: Colors.redAccent[100] ?? Colors.redAccent)
        ),
        cardTheme: CardTheme(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40.0))
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryAppColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(38.0) ),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
            textStyle: GoogleFonts.inter( fontSize: 16, fontWeight: FontWeight.w600 ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryAppColor,
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
        dialogBackgroundColor: const Color(0xFF2C2C2C),
      ),
      home: const SplashScreen(),
    );
  }
}


// --- SplashScreen ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController( duration: const Duration(seconds: 2), vsync: this );
    _animation = Tween<double>(begin: 0, end: 1).animate( CurvedAnimation(parent: _controller, curve: Curves.easeIn) );
    _controller.forward();
    _startNavigationLogic();
  }
  Future<void> _startNavigationLogic() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) { _checkIntroAndSession(); }
  }
  // Checks SharedPreferences for intro flag and active session (currentUserEmail)
  Future<void> _checkIntroAndSession() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenIntro = prefs.getBool('hasSeenIntro') ?? false;
    if (!mounted) return;
    if (!hasSeenIntro) {
      Navigator.pushReplacement( context, MaterialPageRoute(builder: (context) => const IntroductionAnimationScreen()), );
    } else {
      final email = prefs.getString('currentUserEmail'); // Check for saved email
      if (!mounted) return;
      if (email != null && email.isNotEmpty) {
        // Session exists, go to Home
        Navigator.pushReplacement( context, MaterialPageRoute(builder: (context) => HomePage(userEmail: email)), );
      } else {
        // No session, go to Sign In
        Navigator.pushReplacement( context, MaterialPageRoute(builder: (context) => const SignInPage()), );
      }
    }
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    AppLocalizations? l10n = AppLocalizations.of(context);
    String appName = l10n?.splashScreenAppName ?? 'LockedIn';

    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Text(
            appName,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ) ?? const TextStyle( fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white, ),
          ),
        ),
      ),
    );
  }
}


// --- SignInPage (Image Removed) ---
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final db = PostgresDB();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  final FocusNode _emailFN = FocusNode();
  final FocusNode _passFN = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFN.dispose();
    _passFN.dispose();
    super.dispose();
  }

  // Saves session info (email, id etc) to SharedPreferences on success
  Future<void> _handleSignIn() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final currentFocus = FocusScope.of(context);

    if (currentFocus.hasFocus) { currentFocus.unfocus(); }

    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });
      try {
        await db.openConnection();
      } catch (e) {
        if (mounted) {
          setState(() { _isLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.signUpGeneralError)));
        }
        return;
      }
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      try {
        final user = await db.getUserByEmail(email);
        if (user == null) {
          if (!mounted) return;
          scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.signInErrorNotFound)));
          await db.closeConnection(); setState(() { _isLoading = false; }); return;
        }
        final hashedPassword = user['password'];
        final isPasswordCorrect = BCrypt.checkpw(password, hashedPassword);
        if (!isPasswordCorrect) {
          if (!mounted) return;
          scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.signInErrorInvalidPassword)));
          await db.closeConnection(); setState(() { _isLoading = false; }); return;
        }
        // --- SAVING SESSION INFO ---
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentUserEmail', email);
        await prefs.setInt('currentUserId', user['id']);
        await prefs.setString('username', user['username'] ?? '');
        await prefs.setString('profilePic', user['profile_pic_url'] ?? '');
        // --- END SESSION SAVING ---

        if (!mounted) return;
        Navigator.pushReplacement( context, MaterialPageRoute(builder: (context) => HomePage(userEmail: email)), );
      } catch (e) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.signInErrorGeneral(e.toString()))));
      } finally {
        await db.closeConnection();
        if (mounted) { setState(() { _isLoading = false; }); }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Widget loadingIndicator = CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
    );
    final Color textAccentColor = colorScheme.primary;

    return LoadingOverlay(
      isLoading: _isLoading,
      progressIndicator: loadingIndicator,
      child: Scaffold(
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20.0),
          children: [
            // Adjusted spacing since image is removed
            SizedBox(height: MediaQuery.of(context).size.height / 4), // Increased top spacing

            // --- IMAGE REMOVED ---
            // SizedBox(
            //   height: 170.0,
            //   width: MediaQuery.of(context).size.width,
            //   child: Image.asset( ... ),
            // ),
            // const SizedBox(height: 10.0), // Removed space after image

            Center(
              child: Text(
                l10n.welcomeBack,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 5.0),
            Center(
              child: Text(
                "Log into your account and get started!", // Hardcoded string
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w300,
                  color: textAccentColor.withOpacity(0.9),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30.0), // Increased space before form
            buildForm(context, l10n), // Build the form section
            const SizedBox(height: 15.0), // Increased space after form
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.push( context, MaterialPageRoute(builder: (context) => const SignUpPage()) );
                },
                child: Text(l10n.createAccountLink),
              ),
            ),
            const SizedBox(height: 20.0), // Add some padding at the bottom
          ],
        ),
      ),
    );
  }


  Widget buildForm(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color buttonBackgroundColor = colorScheme.primary;
    final Color buttonForegroundColor = colorScheme.onPrimary;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          TextFormBuilder(
            enabled: !_isLoading,
            controller: _emailController,
            prefix: Ionicons.mail_outline,
            hintText: l10n.emailLabel,
            textInputAction: TextInputAction.next,
            textInputType: TextInputType.emailAddress,
            validateFunction: (value) {
              if (value == null || value.isEmpty) { return l10n.emailRequiredError; }
              else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) { return l10n.emailInvalidError; }
              return null;
            },
            focusNode: _emailFN,
            nextFocusNode: _passFN,
          ),
          const SizedBox(height: 15.0),
          PasswordFormBuilder(
            enabled: !_isLoading,
            controller: _passwordController,
            prefix: Ionicons.lock_closed_outline,
            suffix: Ionicons.eye_outline,
            hintText: l10n.passwordLabel,
            textInputAction: TextInputAction.done,
            validateFunction: (value) {
              if (value == null || value.isEmpty) { return l10n.passwordRequiredError; }
              return null;
            },
            submitAction: _handleSignIn,
            obscureText: true,
            focusNode: _passFN,
          ),
          const SizedBox(height: 25.0), // Spacing before button
          Container(
            height: 45.0, width: 180.0,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonBackgroundColor,
                foregroundColor: buttonForegroundColor,
                shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(40.0) ),
              ),
              onPressed: _isLoading ? null : _handleSignIn,
              child: Text(
                l10n.signInButtonText.toUpperCase(),
                style: const TextStyle( fontSize: 12.0, fontWeight: FontWeight.w600 ),
              ),
            ),
          ),
        ],
      ),
    );
  }

} // End of _SignInPageState

// --- Placeholders for other required files ---
// (Ensure SignUpPage, HomePage, IntroductionAnimationScreen, sql.dart, components/text_form_builder.dart, components/password_text_field.dart exist and are correctly imported)