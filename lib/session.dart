import 'package:shared_preferences/shared_preferences.dart';

Future<void> saveUserEmail(String email) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('currentUserEmail', email);
}

Future<String?> loadUserEmail() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('currentUserEmail');
}
