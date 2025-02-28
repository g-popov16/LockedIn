import 'package:flutter/material.dart';

class LuxTheme {
  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color(0xFF2C3E50), // Lux primary color
      scaffoldBackgroundColor: const Color(0xFFECF0F1), // Background color
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF2C3E50),
        secondary: const Color(0xFFE74C3C), // Lux accent color
        surface: Colors.white,
        error: const Color(0xFFC0392B),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: const Color(0xFF2C3E50),
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2C3E50),
        elevation: 2,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
        bodyMedium: TextStyle(color: Color(0xFF2C3E50), fontSize: 14),
        titleLarge: TextStyle(
          color: Color(0xFF2C3E50),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: const CardTheme(
        color: Colors.white,
        shadowColor: Colors.black26,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      buttonTheme: const ButtonThemeData(
        buttonColor: Color(0xFFE74C3C), // Lux button color
        textTheme: ButtonTextTheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE74C3C), // Lux button color
          foregroundColor: Colors.white, // Button text color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFE74C3C),
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF2C3E50)),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        hintStyle: TextStyle(color: Colors.grey),
      ),
    );
  }
}
