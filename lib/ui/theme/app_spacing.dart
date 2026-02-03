/// ProMould Design System - Spacing & Dimensions
/// Consistent spacing scale and radius values

import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  // ============ SPACING SCALE ============
  
  /// 4px - Extra small
  static const double xs = 4.0;
  
  /// 8px - Small
  static const double sm = 8.0;
  
  /// 12px - Medium small
  static const double md = 12.0;
  
  /// 16px - Medium (default)
  static const double lg = 16.0;
  
  /// 20px - Medium large
  static const double xl = 20.0;
  
  /// 24px - Large
  static const double xxl = 24.0;
  
  /// 32px - Extra large
  static const double xxxl = 32.0;
  
  /// 48px - Huge
  static const double huge = 48.0;

  // ============ PADDING PRESETS ============
  
  /// Page padding
  static const EdgeInsets pagePadding = EdgeInsets.all(lg);
  
  /// Card padding
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  
  /// Card padding compact
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(md);
  
  /// List item padding
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );
  
  /// Section padding
  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: xxl,
  );
  
  /// Input padding
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  // ============ BORDER RADIUS ============
  
  /// Small radius (4px)
  static const double radiusSm = 4.0;
  
  /// Medium radius (8px)
  static const double radiusMd = 8.0;
  
  /// Large radius (12px)
  static const double radiusLg = 12.0;
  
  /// Extra large radius (16px)
  static const double radiusXl = 16.0;
  
  /// Full/Pill radius
  static const double radiusFull = 999.0;

  // ============ BORDER RADIUS PRESETS ============
  
  /// Card border radius
  static final BorderRadius cardRadius = BorderRadius.circular(radiusMd);
  
  /// Button border radius
  static final BorderRadius buttonRadius = BorderRadius.circular(radiusMd);
  
  /// Input border radius
  static final BorderRadius inputRadius = BorderRadius.circular(radiusMd);
  
  /// Badge border radius
  static final BorderRadius badgeRadius = BorderRadius.circular(radiusSm);
  
  /// Chip border radius
  static final BorderRadius chipRadius = BorderRadius.circular(radiusFull);

  // ============ ICON SIZES ============
  
  /// Small icon (16px)
  static const double iconSm = 16.0;
  
  /// Medium icon (20px)
  static const double iconMd = 20.0;
  
  /// Large icon (24px)
  static const double iconLg = 24.0;
  
  /// Extra large icon (32px)
  static const double iconXl = 32.0;
  
  /// Huge icon (48px)
  static const double iconHuge = 48.0;

  // ============ COMPONENT SIZES ============
  
  /// Sidebar width (expanded)
  static const double sidebarWidth = 260.0;
  
  /// Sidebar width (collapsed)
  static const double sidebarCollapsedWidth = 72.0;
  
  /// Top bar height
  static const double topBarHeight = 64.0;
  
  /// Button height
  static const double buttonHeight = 48.0;
  
  /// Button height compact
  static const double buttonHeightCompact = 36.0;
  
  /// Input height
  static const double inputHeight = 48.0;
  
  /// Card min height
  static const double cardMinHeight = 80.0;
  
  /// Avatar size small
  static const double avatarSm = 32.0;
  
  /// Avatar size medium
  static const double avatarMd = 40.0;
  
  /// Avatar size large
  static const double avatarLg = 48.0;

  // ============ HELPER METHODS ============
  
  /// Horizontal spacing
  static SizedBox horizontal(double width) => SizedBox(width: width);
  
  /// Vertical spacing
  static SizedBox vertical(double height) => SizedBox(height: height);
  
  /// Gap widget
  static Widget gap(double size) => SizedBox(width: size, height: size);
}
