/// ProMould Design System - Status Badge Component
/// Displays status indicators with consistent styling

import 'package:flutter/material.dart';
import '../theme/theme.dart';

enum BadgeSize { small, medium, large }
enum BadgeVariant { filled, outlined, subtle }

class StatusBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final BadgeSize size;
  final BadgeVariant variant;
  final VoidCallback? onTap;

  const StatusBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.size = BadgeSize.medium,
    this.variant = BadgeVariant.subtle,
    this.onTap,
  });

  /// Factory for status-based badges
  factory StatusBadge.status(String status, {BadgeSize size = BadgeSize.medium}) {
    return StatusBadge(
      label: status.toUpperCase(),
      color: AppColors.getStatusColor(status),
      size: size,
    );
  }

  /// Factory for success badge
  factory StatusBadge.success(String label, {BadgeSize size = BadgeSize.medium}) {
    return StatusBadge(
      label: label,
      color: AppColors.success,
      icon: Icons.check_circle,
      size: size,
    );
  }

  /// Factory for warning badge
  factory StatusBadge.warning(String label, {BadgeSize size = BadgeSize.medium}) {
    return StatusBadge(
      label: label,
      color: AppColors.warning,
      icon: Icons.warning,
      size: size,
    );
  }

  /// Factory for error badge
  factory StatusBadge.error(String label, {BadgeSize size = BadgeSize.medium}) {
    return StatusBadge(
      label: label,
      color: AppColors.error,
      icon: Icons.error,
      size: size,
    );
  }

  /// Factory for info badge
  factory StatusBadge.info(String label, {BadgeSize size = BadgeSize.medium}) {
    return StatusBadge(
      label: label,
      color: AppColors.info,
      icon: Icons.info,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;
    final (padding, fontSize, iconSize) = _getSizeValues();

    Color backgroundColor;
    Color textColor;
    Border? border;

    switch (variant) {
      case BadgeVariant.filled:
        backgroundColor = effectiveColor;
        textColor = Colors.black;
        break;
      case BadgeVariant.outlined:
        backgroundColor = Colors.transparent;
        textColor = effectiveColor;
        border = Border.all(color: effectiveColor);
        break;
      case BadgeVariant.subtle:
        backgroundColor = effectiveColor.withOpacity(0.15);
        textColor = effectiveColor;
        break;
    }

    final badge = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: badge,
      );
    }

    return badge;
  }

  (EdgeInsets, double, double) _getSizeValues() {
    switch (size) {
      case BadgeSize.small:
        return (
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          10.0,
          12.0,
        );
      case BadgeSize.medium:
        return (
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          12.0,
          14.0,
        );
      case BadgeSize.large:
        return (
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          14.0,
          16.0,
        );
    }
  }
}

/// Dot indicator for status
class StatusDot extends StatelessWidget {
  final Color color;
  final double size;
  final bool pulse;

  const StatusDot({
    super.key,
    required this.color,
    this.size = 8,
    this.pulse = false,
  });

  factory StatusDot.status(String status, {double size = 8, bool pulse = false}) {
    return StatusDot(
      color: AppColors.getStatusColor(status),
      size: size,
      pulse: pulse,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: pulse
            ? [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
