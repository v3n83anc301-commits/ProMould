/// ProMould Design System - Stat Card Component
/// Displays a metric with icon, value, and optional trend

import 'package:flutter/material.dart';
import '../theme/theme.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final String? subtitle;
  final double? trend;
  final VoidCallback? onTap;
  final bool compact;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
    this.trend,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.cardRadius,
        child: Padding(
          padding: compact ? AppSpacing.cardPaddingCompact : AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: effectiveColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(
                      icon,
                      color: effectiveColor,
                      size: compact ? AppSpacing.iconMd : AppSpacing.iconLg,
                    ),
                  ),
                  const Spacer(),
                  if (trend != null) _buildTrend(),
                ],
              ),
              SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
              Text(
                value,
                style: compact
                    ? AppTypography.headlineMedium.copyWith(color: effectiveColor)
                    : AppTypography.displaySmall.copyWith(color: effectiveColor),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                title,
                style: AppTypography.labelMedium,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: AppTypography.caption,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrend() {
    final isPositive = trend! >= 0;
    final trendColor = isPositive ? AppColors.success : AppColors.error;
    final trendIcon = isPositive ? Icons.trending_up : Icons.trending_down;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: trendColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trendIcon, size: 14, color: trendColor),
          const SizedBox(width: 2),
          Text(
            '${isPositive ? '+' : ''}${trend!.toStringAsFixed(1)}%',
            style: AppTypography.labelSmall.copyWith(color: trendColor),
          ),
        ],
      ),
    );
  }
}

/// Row of stat cards with consistent spacing
class StatCardRow extends StatelessWidget {
  final List<StatCard> cards;
  final double spacing;

  const StatCardRow({
    super.key,
    required this.cards,
    this.spacing = AppSpacing.md,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: cards
          .map((card) => Expanded(child: card))
          .toList()
          .expand((widget) => [widget, SizedBox(width: spacing)])
          .toList()
        ..removeLast(),
    );
  }
}
