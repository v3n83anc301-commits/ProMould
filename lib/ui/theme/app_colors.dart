/// ProMould Design System - Color Palette
/// Enterprise industrial dark theme

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ============ BACKGROUND COLORS ============
  
  /// Primary background - deepest dark
  static const Color background = Color(0xFF0A0E1A);
  
  /// Surface color for cards and elevated elements
  static const Color surface = Color(0xFF0F1419);
  
  /// Elevated surface for modals and overlays
  static const Color surfaceElevated = Color(0xFF1A1F2E);
  
  /// Card background
  static const Color card = Color(0xFF1A1F2E);
  
  /// Input field background
  static const Color inputFill = Color(0xFF1A1F2E);

  // ============ PRIMARY COLORS ============
  
  /// Primary accent - cyan/teal
  static const Color primary = Color(0xFF4CC9F0);
  
  /// Primary variant - darker
  static const Color primaryDark = Color(0xFF3BA8CC);
  
  /// Primary light
  static const Color primaryLight = Color(0xFF7DD8F5);

  // ============ SEMANTIC COLORS ============
  
  /// Success - green
  static const Color success = Color(0xFF4ADE80);
  
  /// Warning - orange/amber
  static const Color warning = Color(0xFFFBBF24);
  
  /// Error/Danger - red
  static const Color error = Color(0xFFFF6B6B);
  
  /// Info - blue
  static const Color info = Color(0xFF60A5FA);

  // ============ STATUS COLORS ============
  
  /// Running/Active status
  static const Color statusRunning = Color(0xFF4ADE80);
  
  /// Idle status
  static const Color statusIdle = Color(0xFFFBBF24);
  
  /// Down/Error status
  static const Color statusDown = Color(0xFFFF6B6B);
  
  /// Maintenance status
  static const Color statusMaintenance = Color(0xFF60A5FA);
  
  /// Setup status
  static const Color statusSetup = Color(0xFF8B5CF6);

  // ============ TEXT COLORS ============
  
  /// Primary text - white
  static const Color textPrimary = Color(0xFFFFFFFF);
  
  /// Secondary text - muted white
  static const Color textSecondary = Color(0xFFB0B0B0);
  
  /// Tertiary text - very muted
  static const Color textTertiary = Color(0xFF6B7280);
  
  /// Disabled text
  static const Color textDisabled = Color(0xFF4B5563);

  // ============ BORDER COLORS ============
  
  /// Default border
  static const Color border = Color(0xFF2D3748);
  
  /// Focused border
  static const Color borderFocused = Color(0xFF4CC9F0);
  
  /// Error border
  static const Color borderError = Color(0xFFFF6B6B);

  // ============ CATEGORY COLORS ============
  
  static const Color categoryMechanical = Color(0xFFF97316);
  static const Color categoryElectrical = Color(0xFFFBBF24);
  static const Color categoryMaterial = Color(0xFF8B5CF6);
  static const Color categoryMouldChange = Color(0xFF3B82F6);
  static const Color categorySetup = Color(0xFF06B6D4);
  static const Color categoryQuality = Color(0xFFEC4899);
  static const Color categoryPlanned = Color(0xFF22C55E);

  // ============ HELPER METHODS ============
  
  /// Get status color by name
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'running':
      case 'active':
      case 'complete':
      case 'completed':
        return statusRunning;
      case 'idle':
      case 'pending':
      case 'waiting':
        return statusIdle;
      case 'down':
      case 'error':
      case 'failed':
        return statusDown;
      case 'maintenance':
        return statusMaintenance;
      case 'setup':
        return statusSetup;
      default:
        return textSecondary;
    }
  }

  /// Get color with opacity
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
}
