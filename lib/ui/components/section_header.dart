/// ProMould Design System - Section Header Component
/// Consistent section headers with optional actions

import 'package:flutter/material.dart';
import '../theme/theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onActionTap;
  final String? actionLabel;
  final EdgeInsets? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onActionTap,
    this.actionLabel,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSpacing.iconMd, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle!, style: AppTypography.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (onActionTap != null && actionLabel != null)
            TextButton(
              onPressed: onActionTap,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Divider with optional label
class SectionDivider extends StatelessWidget {
  final String? label;
  final EdgeInsets? padding;

  const SectionDivider({
    super.key,
    this.label,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Padding(
        padding: padding ?? const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: const Divider(),
      );
    }

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              label!,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
