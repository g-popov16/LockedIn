// lib/theme.dart
import 'package:flutter/material.dart';

final ThemeData sleekDarkTheme = ThemeData(
  brightness: Brightness.dark,
  // Use a modern dark background color palette
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blueAccent, // Or your brand color
    brightness: Brightness.dark,
    background: const Color(0xFF121212), // Very dark grey, common in modern apps
    surface: const Color(0xFF1E1E1E), // Slightly lighter for cards/surfaces
    onBackground: Colors.white,
    onSurface: Colors.white,
    primary: Colors.blueAccent,
    onPrimary: Colors.black,
    secondary: Colors.tealAccent,
    onSecondary: Colors.black,
    error: Colors.redAccent,
    onError: Colors.black,
  ),
  scaffoldBackgroundColor: const Color(0xFF121212), // Match background
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E1E1E), // Match surface or a distinct header color
    elevation: 0, // Flat appbar is common
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20.0,
      fontWeight: FontWeight.w600, // Slightly bolder title
    ),
    iconTheme: IconThemeData(color: Colors.white),
  ),
  cardTheme: CardTheme(
    color: const Color(0xFF1E1E1E), // Match surface
    elevation: 1.0, // Subtle elevation
    margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0), // Tighter vertical spacing, no horizontal margin (list padding handles it)
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.0), // Slightly more rounded
    ),
    clipBehavior: Clip.antiAlias, // Ensures content respects rounded corners
  ),
  textTheme: TextTheme(
    // Define text styles for consistency
    titleMedium: TextStyle( // For usernames, etc.
      color: Colors.white.withOpacity(0.9),
      fontWeight: FontWeight.w600,
      fontSize: 16,
    ),
    bodyLarge: TextStyle( // For main post content
      color: Colors.white.withOpacity(0.85),
      fontSize: 15,
      height: 1.4, // Improve readability
    ),
    bodyMedium: TextStyle( // General medium text
      color: Colors.white.withOpacity(0.8),
      fontSize: 14,
    ),
    bodySmall: TextStyle( // For timestamps, subtle text
      color: Colors.white.withOpacity(0.6),
      fontSize: 12,
    ),
    labelSmall: TextStyle( // For button text like 'Likes', 'Comments'
      color: Colors.white.withOpacity(0.7),
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
  ).apply( // Ensure default font color is appropriate for dark theme
    bodyColor: Colors.white.withOpacity(0.85),
    displayColor: Colors.white,
  ),
  iconTheme: IconThemeData(
    color: Colors.white.withOpacity(0.8),
    size: 22.0,
  ),
  dividerTheme: DividerThemeData(
    color: Colors.white.withOpacity(0.1),
    thickness: 1,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: const Color(0xFF1E1E1E), // Match surface/appbar
    selectedItemColor: Colors.blueAccent, // Use primary color for selected
    unselectedItemColor: Colors.white.withOpacity(0.6), // Dim unselected
    type: BottomNavigationBarType.fixed,
    showUnselectedLabels: true, // Keep labels visible
    selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    unselectedLabelStyle: const TextStyle(fontSize: 12),
    elevation: 2.0, // Optional elevation for separation
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: Colors.blueAccent, // Use primary color
    foregroundColor: Colors.black, // Contrast color for icon
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.8),
      borderRadius: BorderRadius.circular(4),
    ),
    textStyle: const TextStyle(color: Colors.white),
  ),
  // Add other theme properties as needed (TextButtonTheme, etc.)
);

// You might also want a light theme:
// final ThemeData sleekLightTheme = ThemeData(...);