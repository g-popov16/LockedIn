import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'sql.dart'; // Assuming sql.dart is in the same directory or correct path
import 'home_page.dart'; // Assuming home_page.dart is in the same directory or correct path
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/firebase_storage_service.dart'; // Assuming this path is correct
// 1. Import AppLocalizations
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Import packages for the new UI
import 'package:google_fonts/google_fonts.dart';
import 'package:ionicons/ionicons.dart';
import 'package:loading_overlay/loading_overlay.dart'; // Import LoadingOverlay

// --- ADD IMPORTS FOR CUSTOM COMPONENTS ---
// !!! Adjust path if you placed files elsewhere !!!
import 'package:lockedin/components/text_form_builder.dart'; // Change lockedin
import 'package:lockedin/components/password_text_field.dart'; // Change lockedin
import 'package:lockedin/main.dart'; // Import SignInPage (adjust path if needed)

// Ensure you have the custom_card.dart file if TextFormBuilder depends on it
// import 'package:lockedin/components/custom_card.dart';


class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // --- Colors Inherited from Theme ---

  final FirebaseStorageService _firebaseStorage = FirebaseStorageService();
  final db = PostgresDB();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController nameController = TextEditingController(); // This maps to 'Full Name'
  final TextEditingController bioController = TextEditingController();

  String? _selectedRole; // Stores the *internal English key* (e.g., "User", "Team")
  final Map<String, String> _roleMapping = {
    "User": "ROLE_USER",
    "Team": "ROLE_TEAM",
    "Sponsor": "ROLE_SPONSOR",
  };
  List<String> get _roles => _roleMapping.keys.toList();

  File? _profileImage;
  bool _isLoading = false; // State variable for LoadingOverlay

  // --- Focus Nodes ---
  final FocusNode _usernameFN = FocusNode();
  final FocusNode _emailFN = FocusNode();
  final FocusNode _nameFN = FocusNode();
  final FocusNode _passwordFN = FocusNode();
  final FocusNode _bioFN = FocusNode();
  final FocusNode _roleFN = FocusNode();
  // ---

  @override
  void initState() {
    super.initState();
    // db.openConnection();
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    emailController.dispose();
    nameController.dispose();
    bioController.dispose();
    _usernameFN.dispose();
    _emailFN.dispose();
    _nameFN.dispose();
    _passwordFN.dispose();
    _bioFN.dispose();
    _roleFN.dispose();
    // db.closeConnection();
    super.dispose();
  }

  Future<void> pickImage() async {
    if (_isLoading) return;
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  // --- handleSignUp logic (with pushAndRemoveUntil on success) ---
  Future<void> handleSignUp() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    FocusScope.of(context).unfocus();
    final dbRoleValue = _selectedRole != null ? _roleMapping[_selectedRole!] : null; // Get DB value from selected English key

    if (_formKey.currentState!.validate() && dbRoleValue != null) {
      setState(() { _isLoading = true; });

      try {
        await db.openConnection();
        final hashedPassword = BCrypt.hashpw(passwordController.text.trim(), BCrypt.gensalt());
        final userEmail = emailController.text.trim();
        final userData = {
          "username": usernameController.text.trim(),
          "password": hashedPassword, "email": userEmail,
          "name": nameController.text.trim(), "bio": bioController.text.trim(),
          "profile_pic_url": "", "role": dbRoleValue,
        };

        bool success = await db.signUp(userData);
        if (!mounted) return;

        if (success) {
          final prefs = await SharedPreferences.getInstance();
          final newUserId = prefs.getInt('user_id');

          if (newUserId == null) {
            if (!mounted) return;
            scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.errorUnableToRetrieveUserInfo)));
            await db.closeConnection(); return; // Return without setting isLoading false (finally handles it)
          }

          if (_selectedRole == "Team") { // Check using the English key
            if (!mounted) return;
            await _showTeamNameDialog(newUserId);
            if (!mounted) return;
          }

          if (_profileImage != null) {
            String? profilePicUrl = await _firebaseStorage.uploadProfilePicture(_profileImage!, newUserId.toString());
            if (!mounted) return;
            if (profilePicUrl != null) {
              await db.updateUserProfilePicture(newUserId, profilePicUrl);
            } else { print("Profile picture upload failed."); }
          }

          if (!mounted) return;
          scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.signUpSuccess)));
          if (!mounted) return;
          // Navigate to Home on successful sign up and remove previous routes
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => HomePage(userEmail: userEmail)),
                  (Route<dynamic> route) => false // Remove all routes below the new route
          );

        } else {
          if (!mounted) return;
          scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.signUpFailedError)));
        }
      } catch (e, stacktrace) {
        print('Sign Up Error: $e \n$stacktrace');
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.signUpGeneralError)));
      } finally {
        // Ensure connection is closed and loading stopped
        await db.closeConnection();
        if (mounted) { setState(() { _isLoading = false; }); }
      }
    } else {
      if (!mounted) return;
      if (_selectedRole == null && _formKey.currentState?.validate() == true) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.roleRequiredError)));
      } else if (_formKey.currentState?.validate() == false) {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Please correct the errors in the form.")));
        // TODO: Add 'formValidationError' key to your AppLocalizations (.arb) files
      }
    }
  }

  // --- UPDATED build Method with AppBar ---
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Create localized map for dropdown display
    final Map<String, String> localizedRolesDisplay = {
      "User": l10n.roleUser, "Team": l10n.roleTeam, "Sponsor": l10n.roleSponsor,
    };
    final List<String> localizedRoleOptions = localizedRolesDisplay.values.toList();
    final String? currentLocalizedSelection = _selectedRole != null ? localizedRolesDisplay[_selectedRole!] : null;


    final Widget loadingIndicator = CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
    );
    final Color textAccentColor = colorScheme.primary;

    return LoadingOverlay(
      isLoading: _isLoading,
      progressIndicator: loadingIndicator,
      child: Scaffold(
        // --- ADD AppBar with Back Button ---
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Ionicons.arrow_back, color: theme.appBarTheme.iconTheme?.color), // Use theme icon color
            onPressed: () {
              // Navigate back to the previous screen (SignInPage)
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            tooltip: MaterialLocalizations.of(context).backButtonTooltip, // Standard tooltip
          ),
          // title: Text(l10n.signUpTitle), // Optional Title
          backgroundColor: theme.appBarTheme.backgroundColor,
          elevation: theme.appBarTheme.elevation,
        ),
        // --- End AppBar ---
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20.0), // Match SignInPage padding
          children: [
            // Removed top SizedBox, AppBar adds space now
            SizedBox(height: MediaQuery.of(context).size.height * 0.02), // Smaller top padding
            Center(
              child: Text(
                l10n.signUpTitle, // Re-use Sign Up Title here if AppBar title is empty
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 5.0),
            Center(
              child: Text(
                // TODO: Add localization key: "Create an account to get started"
                "Create an account to get started",
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w300,
                  color: textAccentColor.withOpacity(0.9),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20.0),
            Center(
              child: GestureDetector(
                onTap: pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade800,
                  backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                  child: _profileImage == null
                      ? Icon(Ionicons.camera_outline, size: 40, color: Colors.grey.shade500)
                      : null,
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  l10n.profilePicturePrompt,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
                ),
              ),
            ),
            const SizedBox(height: 25.0),
            buildForm(context, l10n, localizedRoleOptions, currentLocalizedSelection, localizedRolesDisplay),
            const SizedBox(height: 15.0),
            Center(
              child: TextButton(
                onPressed: () {
                  // Navigate back to SignIn page
                  if (Navigator.canPop(context)) { Navigator.pop(context); }
                  else { Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignInPage())); }
                },
                // TODO: Add localization key: "Already have an account? Log In"
                child: const Text("Already have an account? Log In"),
              ),
            ),
            const SizedBox(height: 20.0), // Bottom padding
          ],
        ),
      ),
    );
  }

  // --- buildForm Method (Remains the same) ---
  Widget buildForm(BuildContext context, AppLocalizations l10n, List<String> localizedRoleOptions, String? currentLocalizedSelection, Map<String, String> localizedRolesDisplay) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color iconColor = colorScheme.primary;
    final Color focusBorderColor = colorScheme.primary;
    final Color buttonBackgroundColor = colorScheme.primary;
    final Color buttonForegroundColor = colorScheme.onPrimary;
    final Color fieldFillColor = Colors.white;
    final Color fieldTextColor = Colors.black87;
    final Color fieldHintColor = Colors.grey.shade500;
    final OutlineInputBorder formFieldBorder = OutlineInputBorder( borderRadius: const BorderRadius.all(Radius.circular(30.0)), borderSide: BorderSide( color: fieldFillColor, width: 0.0 ) );
    final OutlineInputBorder formFieldFocusBorder = OutlineInputBorder( borderRadius: const BorderRadius.all(Radius.circular(30.0)), borderSide: BorderSide( color: focusBorderColor, width: 1.0 ) );
    const double formIconSize = 15.0;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          TextFormBuilder( enabled: !_isLoading, controller: usernameController, prefix: Ionicons.person_outline, hintText: l10n.usernameLabel, textInputAction: TextInputAction.next, validateFunction: (v) => v==null||v.isEmpty?l10n.usernameRequiredError:null, focusNode: _usernameFN, nextFocusNode: _emailFN ),
          const SizedBox(height: 15.0),
          TextFormBuilder( enabled: !_isLoading, controller: emailController, prefix: Ionicons.mail_outline, hintText: l10n.emailLabel, textInputAction: TextInputAction.next, textInputType: TextInputType.emailAddress, validateFunction: (v){if(v==null||v.isEmpty){return l10n.emailRequiredError;}else if(!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)){return l10n.emailInvalidError;}return null;}, focusNode: _emailFN, nextFocusNode: _nameFN ),
          const SizedBox(height: 15.0),
          TextFormBuilder( enabled: !_isLoading, controller: nameController, prefix: Ionicons.person_circle_outline, hintText: l10n.fullNameLabel, textInputAction: TextInputAction.next, validateFunction: (v) => v==null||v.isEmpty?l10n.fullNameRequiredError:null, focusNode: _nameFN, nextFocusNode: _passwordFN ),
          const SizedBox(height: 15.0),
          PasswordFormBuilder( enabled: !_isLoading, controller: passwordController, prefix: Ionicons.lock_closed_outline, suffix: Ionicons.eye_outline, hintText: l10n.passwordLabel, textInputAction: TextInputAction.next, obscureText: true, validateFunction: (v){if(v==null||v.isEmpty){return l10n.passwordRequiredError;}else if(v.length<6){return l10n.passwordLengthError;}return null;}, focusNode: _passwordFN, nextFocusNode: _bioFN ),
          const SizedBox(height: 15.0),
          TextFormBuilder( enabled: !_isLoading, controller: bioController, prefix: Ionicons.document_text_outline, hintText: l10n.bioLabel, textInputAction: TextInputAction.next, validateFunction: (v) => null, focusNode: _bioFN, nextFocusNode: _roleFN ),
          const SizedBox(height: 15.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButtonFormField<String>(
              value: currentLocalizedSelection,
              focusNode: _roleFN,
              style: TextStyle( fontSize: 15.0, color: fieldTextColor ),
              decoration: InputDecoration( prefixIcon: Icon(Ionicons.briefcase_outline, size: formIconSize, color: iconColor), hintText: l10n.selectRoleLabel, hintStyle: TextStyle(fontSize: 15.0, color: fieldHintColor), filled: true, fillColor: fieldFillColor, contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0), border: formFieldBorder, enabledBorder: formFieldBorder, focusedBorder: formFieldFocusBorder, errorStyle: TextStyle( color: Colors.red[700], fontSize: 12.0) ),
              items: localizedRoleOptions.map((localizedRole) => DropdownMenuItem( value: localizedRole, child: Text(localizedRole) )).toList(),
              onChanged: _isLoading ? null : (localizedValue) {
                if (localizedValue != null) {
                  String? originalKey = localizedRolesDisplay.entries.firstWhere( (entry) => entry.value == localizedValue, orElse: () => const MapEntry("", "") ).key;
                  if (originalKey.isNotEmpty) { setState(() { _selectedRole = originalKey; }); }
                  FocusScope.of(context).unfocus();
                }
              },
              validator: (value) => value == null || value.isEmpty ? l10n.roleRequiredError : null,
              dropdownColor: Colors.grey[800],
              icon: Icon(Ionicons.chevron_down_outline, color: fieldHintColor, size: 20),
            ),
          ),
          const SizedBox(height: 25.0),
          Container(
            height: 45.0, width: 180.0,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom( backgroundColor: buttonBackgroundColor, foregroundColor: buttonForegroundColor, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(40.0) ) ),
              onPressed: _isLoading ? null : handleSignUp,
              child: Text( l10n.signUpButtonText.toUpperCase(), style: const TextStyle( fontSize: 12.0, fontWeight: FontWeight.w600 ) ),
            ),
          ),
        ],
      ),
    );
  }


  // --- Dialog methods remain the same ---
  Future<void> _showTeamNameDialog(int userId) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    TextEditingController teamNameController = TextEditingController();
    String? teamName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          title: Text(l10n.enterTeamNameTitle, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface)),
          content: TextField( controller: teamNameController, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface), decoration: InputDecoration( hintText: l10n.teamNameHint ), cursorColor: theme.colorScheme.primary ),
          actions: [
            TextButton( onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancelButton) ),
            TextButton( onPressed: () { if (teamNameController.text.trim().isNotEmpty) { Navigator.of(context).pop(teamNameController.text.trim()); } }, child: Text(l10n.saveButton) ),
          ],
        );
      },
    );
    if (mounted && teamName != null) { await _saveTeamToDatabase(teamName, userId); }
  }
  Future<void> _saveTeamToDatabase(String teamName, int userId) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try { await db.createTeam({"name": teamName, "created_by": userId}); }
    catch (e) { if (mounted) { scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.signUpGeneralError))); } }
    finally { }
  }

} // End of _SignUpPageState