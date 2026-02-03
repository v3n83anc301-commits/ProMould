/// ProMould App Shell
/// Persistent sidebar navigation with top bar

import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../../services/rbac_service.dart';
import '../../services/shift_service.dart';
import '../../services/alert_service.dart';
import '../../config/permissions.dart';

/// Navigation item definition
class NavItem {
  final String id;
  final String label;
  final IconData icon;
  final Widget screen;
  final Permission? permission;
  final List<NavItem>? children;
  final bool dividerBefore;

  const NavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.screen,
    this.permission,
    this.children,
    this.dividerBefore = false,
  });
}

/// App Shell with persistent sidebar
class AppShell extends StatefulWidget {
  final String username;
  final int level;
  final List<NavItem> navItems;
  final VoidCallback onLogout;
  final int initialIndex;

  const AppShell({
    super.key,
    required this.username,
    required this.level,
    required this.navItems,
    required this.onLogout,
    this.initialIndex = 0,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _selectedIndex;
  bool _sidebarExpanded = true;
  late List<NavItem> _filteredNavItems;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _filterNavItems();
  }

  void _filterNavItems() {
    _filteredNavItems = widget.navItems.where((item) {
      if (item.permission == null) return true;
      return RBACService.hasPermission(item.permission!);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1200;
    final isTablet = screenWidth >= 768 && screenWidth < 1200;

    // Auto-collapse sidebar on tablet
    if (isTablet && _sidebarExpanded) {
      _sidebarExpanded = false;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Sidebar
          _Sidebar(
            items: _filteredNavItems,
            selectedIndex: _selectedIndex,
            expanded: _sidebarExpanded,
            username: widget.username,
            level: widget.level,
            onItemSelected: (index) => setState(() => _selectedIndex = index),
            onToggleExpanded: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
            onLogout: widget.onLogout,
          ),

          // Main content
          Expanded(
            child: Column(
              children: [
                // Top bar
                _TopBar(
                  title: _filteredNavItems.isNotEmpty
                      ? _filteredNavItems[_selectedIndex].label
                      : '',
                  username: widget.username,
                  onMenuTap: isDesktop
                      ? null
                      : () => setState(() => _sidebarExpanded = !_sidebarExpanded),
                ),

                // Content
                Expanded(
                  child: _filteredNavItems.isNotEmpty
                      ? _filteredNavItems[_selectedIndex].screen
                      : const Center(child: Text('No content')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sidebar navigation
class _Sidebar extends StatelessWidget {
  final List<NavItem> items;
  final int selectedIndex;
  final bool expanded;
  final String username;
  final int level;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onToggleExpanded;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.items,
    required this.selectedIndex,
    required this.expanded,
    required this.username,
    required this.level,
    required this.onItemSelected,
    required this.onToggleExpanded,
    required this.onLogout,
  });

  String _getRoleName() {
    switch (level) {
      case 4:
        return 'Admin';
      case 3:
        return 'Supervisor';
      case 2:
        return 'Material Handler';
      case 1:
        return 'Setter';
      default:
        return 'Operator';
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = expanded ? AppSpacing.sidebarWidth : AppSpacing.sidebarCollapsedWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        children: [
          // Logo/Brand
          _buildHeader(),

          const Divider(height: 1),

          // Navigation items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Column(
                  children: [
                    if (item.dividerBefore)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Divider(height: 1),
                      ),
                    _NavItemTile(
                      item: item,
                      selected: index == selectedIndex,
                      expanded: expanded,
                      onTap: () => onItemSelected(index),
                    ),
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1),

          // User section
          _buildUserSection(),

          // Collapse toggle
          _buildCollapseToggle(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: AppSpacing.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Icon(
              Icons.precision_manufacturing,
              color: Colors.black,
              size: 20,
            ),
          ),
          if (expanded) ...[
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ProMould',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'v9.0',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserSection() {
    return Container(
      padding: EdgeInsets.all(expanded ? AppSpacing.lg : AppSpacing.sm),
      child: expanded
          ? Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: AppTypography.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _getRoleName(),
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 20),
                  onPressed: onLogout,
                  tooltip: 'Logout',
                ),
              ],
            )
          : IconButton(
              icon: const Icon(Icons.logout, size: 20),
              onPressed: onLogout,
              tooltip: 'Logout',
            ),
    );
  }

  Widget _buildCollapseToggle() {
    return InkWell(
      onTap: onToggleExpanded,
      child: Container(
        height: 48,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border),
          ),
        ),
        child: Center(
          child: Icon(
            expanded ? Icons.chevron_left : Icons.chevron_right,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Navigation item tile
class _NavItemTile extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  const _NavItemTile({
    required this.item,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? AppSpacing.sm : AppSpacing.xs,
        vertical: 2,
      ),
      child: Material(
        color: selected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            height: 44,
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? AppSpacing.md : 0,
            ),
            child: Row(
              mainAxisAlignment:
                  expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                if (expanded) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? AppColors.primary : AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Top bar with shift info and alerts
class _TopBar extends StatelessWidget {
  final String title;
  final String username;
  final VoidCallback? onMenuTap;

  const _TopBar({
    required this.title,
    required this.username,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          if (onMenuTap != null) ...[
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: onMenuTap,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],

          // Page title
          Text(
            title,
            style: AppTypography.headlineMedium,
          ),

          const Spacer(),

          // Shift indicator
          _ShiftIndicator(),

          const SizedBox(width: AppSpacing.lg),

          // Alerts button
          _AlertsButton(),

          const SizedBox(width: AppSpacing.md),

          // Time
          _TimeDisplay(),
        ],
      ),
    );
  }
}

class _ShiftIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final shift = ShiftService.getCurrentShift();
    final shiftName = shift?['name'] as String? ?? 'No Shift';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            shiftName,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final activeAlerts = AlertService.getActiveAlerts();
    final count = activeAlerts.length;

    return Stack(
      children: [
        IconButton(
          icon: Icon(
            count > 0 ? Icons.notifications_active : Icons.notifications_outlined,
            color: count > 0 ? AppColors.warning : AppColors.textSecondary,
          ),
          onPressed: () {
            // TODO: Show alerts panel
          },
          tooltip: '$count active alerts',
        ),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _TimeDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final time =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

        return Text(
          time,
          style: AppTypography.titleMedium.copyWith(
            fontFamily: 'monospace',
            color: AppColors.textSecondary,
          ),
        );
      },
    );
  }
}
