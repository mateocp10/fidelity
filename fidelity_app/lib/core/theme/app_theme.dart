import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta de colores "Pop-Minimalism" (Emote Agency Style)
  static const Color _background = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFF2F2F2);
  static const Color _primary = Color(0xFF000000); // Negro puro
  static const Color _accentPurple = Color(0xFF8A84FF);
  static const Color _accentPink = Color(0xFFFF4FD0);
  static const Color _accentYellow = Color(0xFFFFBF43);
  static const Color _accentGreen = Color(0xFF76D672);
  static const Color _textPrimary = Color(0xFF000000);
  static const Color _textSecondary = Color(0xFF666666);
  static const Color _error = Color(0xFFFF4949);

  static const double _radiusLarge = 48.0;
  static const double _radiusMedium = 24.0;
  static const double _radiusPill = 999.0;

  // Animaciones centralizadas (DRY / NO_HARDCODING)
  static const Duration animDurationStandard = Duration(milliseconds: 600);
  static const Duration animDurationQuick = Duration(milliseconds: 400);
  static const Duration animDurationSlow = Duration(milliseconds: 800);
  static const Curve animCurveStandard = Curves.easeOutQuart;
  static const Curve animCurveElastic = Curves.easeOutBack;
  static const double animSlideYBegin = 0.1;

  static IconData getCategoryIcon(String? categoryName) {
    final name = (categoryName ?? '').toLowerCase();
    
    if (name.contains('cafe') || name.contains('panaderia') || name.contains('pasteleria')) return Icons.local_cafe;
    if (name.contains('restaurante') || name.contains('bar')) return Icons.restaurant;
    if (name.contains('disco') || name.contains('club')) return Icons.nightlife;
    if (name.contains('peluqueria') || name.contains('barberia') || name.contains('estetica')) return Icons.content_cut;
    if (name.contains('gym') || name.contains('deportivo')) return Icons.fitness_center;
    if (name.contains('spa')) return Icons.spa;
    if (name.contains('moda') || name.contains('accesorios') || name.contains('calzado')) return Icons.shopping_bag;
    if (name.contains('ferreteria')) return Icons.home_repair_service;
    if (name.contains('lavanderia') || name.contains('tintoreria')) return Icons.local_laundry_service;
    if (name.contains('taller') || name.contains('mecanico') || name.contains('lubricadora')) return Icons.build;
    if (name.contains('farmacia')) return Icons.medication;
    if (name.contains('veterinaria') || name.contains('pet')) return Icons.pets;
    if (name.contains('tecnologia')) return Icons.devices;
    
    return Icons.store;
  }

  // Soporte y Contacto
  static const String supportWhatsApp = '+593995371895';
  static const String supportEmail = 'fidelitysistemadefidelizacion@gmail.com';

  static Duration animDelayStaggered(int index) => Duration(milliseconds: index * 50);

  static ThemeData get popTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: _primary,
        onPrimary: Colors.white,
        secondary: _accentPurple,
        onSecondary: Colors.white,
        error: _error,
        onError: Colors.white,
        surface: _background,
        onSurface: _textPrimary,
      ),

      scaffoldBackgroundColor: _background,

      appBarTheme: AppBarTheme(
        backgroundColor: _background,
        foregroundColor: _textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.anton(
          color: _textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w400, // Anton solo tiene regular
          letterSpacing: 0.5,
        ),
      ),

      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0, // El estilo Emote no usa sombras pesadas
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusLarge),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusPill),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusMedium),
          borderSide: const BorderSide(color: _primary, width: 2.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 20,
        ),
        labelStyle: GoogleFonts.poppins(
          color: _textSecondary,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: _primary,
      ),

      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.anton(
          fontSize: 36,
          fontWeight: FontWeight.w400,
          color: _textPrimary,
          letterSpacing: 0.5,
          height: 1.1,
        ),
        headlineMedium: GoogleFonts.anton(
          fontSize: 28,
          fontWeight: FontWeight.w400,
          color: _textPrimary,
          letterSpacing: 0.5,
          height: 1.15,
        ),
        titleLarge: GoogleFonts.anton(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          color: _textPrimary,
          letterSpacing: 0.5,
        ),
        titleMedium: GoogleFonts.anton(
          fontSize: 20,
          fontWeight: FontWeight.w400,
          color: _textPrimary,
          letterSpacing: 0.3,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: _textPrimary,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _textSecondary,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: _textSecondary,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _primary,
        ),
      ),
    );
  }

  // Alias para compatibilidad y facilitar el uso directo
  static const Color primary = _primary;
  static const Color accentPurple = _accentPurple;
  static const Color accentPink = _accentPink;
  static const Color accentYellow = _accentYellow;
  static const Color accentGreen = _accentGreen;
  static const Color surface = _surface;
  
  // Getter legacy para no romper main.dart inmediatamente si usa AppTheme.warmTheme
  static ThemeData get warmTheme => popTheme; 
}

