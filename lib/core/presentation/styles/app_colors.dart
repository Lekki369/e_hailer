import 'package:flutter/material.dart';

abstract class AppColors {
  // Brand colors
  static const Color primary = Color(0xFF0F172A); // Deep slate/navy
  static const Color primaryLight = Color(0xFF1E293B);
  static const Color secondary = Color(0xFFFF6B35); // Logistics action orange/amber
  static const Color secondaryLight = Color(0xFFFF8C5A);

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Neutral surfaces
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color divider = Color(0xFFE2E8F0);

  // Text colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnPrimary = Colors.white;
}
