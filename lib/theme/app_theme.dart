import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // --- Modern / Dark Colors (Original Default - DO NOT TOUCH) ---
  static const Color primary = Color(0xFF2563EB); 
  static const Color secondary = Color(0xFF7C3AED); 
  static const Color background = Color(0xFF0F172A); 
  static const Color surface = Color(0xFF1E293B); 
  static const Color textBody = Color(0xFF94A3B8);
  static const Color textHeading = Colors.white;

  // --- Premium Zirve Style (Navy & Slate White) ---
  static const Color mgmtPrimary = Color(0xFF1B3B5F);    // Zirve Navy (Header/Nav)
  static const Color mgmtAccent = Color(0xFF007BFF);     // Classic Royal Blue
  static const Color mgmtSuccess = Color(0xFF28A745);    
  static const Color mgmtWarning = Color(0xFFDC3545);    
  static const Color mgmtBackground = Color(0xFFF5F7FA); // Slate White
  static const Color mgmtSurface = Colors.white;         // Pure White Cards
  static const Color mgmtBorder = Color(0xFFE1E8EF);    
  static const Color mgmtTextBody = Color(0xFF5D7185);   // Slate Grey 600
  static const Color mgmtTextHeading = Color(0xFF1B3B5F); // Navy Heading

  // Compatibility Aliases
  static const Color mgmtSecondary = mgmtTextBody;

  // Solid Background Gradient for Zirve Style
  static const LinearGradient mgmtBackgroundGradient = LinearGradient(
    colors: [Color(0xFFF5F7FA), Color(0xFFF5F7FA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  // MODERN THEME (Original Dark & Glassy - KEPT UNTOUCHED)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(color: AppColors.textHeading, fontWeight: FontWeight.bold),
        bodyLarge: GoogleFonts.outfit(color: AppColors.textBody),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        centerTitle: true,
        titleTextStyle: TextStyle(color: AppColors.textHeading, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  // PREMIUM THEME (Zirve Management - Corporate White & Navy)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.mgmtPrimary,
      scaffoldBackgroundColor: AppColors.mgmtBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.mgmtPrimary,
        brightness: Brightness.light,
        primary: AppColors.mgmtPrimary,
        secondary: AppColors.mgmtAccent,
        surface: AppColors.mgmtSurface,
        onPrimary: Colors.white,
        onSurface: AppColors.mgmtTextHeading,
        surfaceTint: Colors.white,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(color: AppColors.mgmtTextHeading, fontWeight: FontWeight.w800, fontSize: 32),
        titleLarge: GoogleFonts.outfit(color: AppColors.mgmtTextHeading, fontWeight: FontWeight.w700, fontSize: 18),
        bodyLarge: GoogleFonts.outfit(color: AppColors.mgmtTextBody, fontSize: 16),
        bodyMedium: GoogleFonts.outfit(color: AppColors.mgmtTextBody, fontSize: 14),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.mgmtPrimary,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white, size: 22),
        actionsIconTheme: IconThemeData(color: Colors.white, size: 22),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.mgmtPrimary,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        elevation: 10,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: AppColors.mgmtSurface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE1E8EF), width: 1), 
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.mgmtAccent,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE1E8EF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE1E8EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.mgmtAccent, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.mgmtTextBody, fontWeight: FontWeight.w500),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE1E8EF),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
