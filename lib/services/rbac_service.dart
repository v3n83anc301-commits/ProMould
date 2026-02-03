/// ProMould RBAC Service
/// Role-Based Access Control enforcement at service layer

import 'package:hive/hive.dart';
import '../core/constants.dart';
import '../config/permissions.dart';
import '../models/user_model.dart';
import 'log_service.dart';
import 'audit_service.dart';

/// RBAC Service - enforces permissions across the application
class RBACService {
  static Box? _usersBox;
  static User? _currentUser;

  /// Initialize the RBAC service
  static Future<void> initialize() async {
    _usersBox = await Hive.openBox(HiveBoxes.users);
    LogService.info('RBACService initialized');
  }

  /// Set the current user (called on login)
  static void setCurrentUser(User user) {
    _currentUser = user;
    LogService.info('RBAC context set for user: ${user.username} (${user.role.displayName})');
  }

  /// Clear the current user (called on logout)
  static void clearCurrentUser() {
    _currentUser = null;
    LogService.info('RBAC context cleared');
  }

  /// Invalidate and reload user permissions (call after permission changes)
  static Future<void> invalidateUser(String userId) async {
    if (_currentUser?.id == userId) {
      // Reload user from storage
      if (_usersBox != null) {
        for (var key in _usersBox!.keys) {
          final userData = _usersBox!.get(key) as Map?;
          if (userData != null && userData['id'] == userId) {
            _currentUser = User.fromMap(Map<String, dynamic>.from(userData));
            LogService.info('RBAC cache invalidated and reloaded for user: $userId');
            return;
          }
        }
      }
    }
    LogService.debug('RBAC invalidation requested for user: $userId (not current user)');
  }

  /// Force refresh current user from storage
  static Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;
    await invalidateUser(_currentUser!.id);
  }

  /// Get the current user
  static User? get currentUser => _currentUser;

  /// Get the current user's role
  static UserRole? get currentRole => _currentUser?.role;

  /// Check if there is a logged-in user
  static bool get isLoggedIn => _currentUser != null;

  // ============ PERMISSION CHECKS ============

  /// Check if current user has a specific permission
  static bool hasPermission(Permission permission) {
    if (_currentUser == null) return false;
    return PermissionMatrix.hasPermission(_currentUser!.role, permission);
  }

  /// Check if current user has all of the specified permissions
  static bool hasAllPermissions(List<Permission> permissions) {
    if (_currentUser == null) return false;
    return permissions.every(
        (p) => PermissionMatrix.hasPermission(_currentUser!.role, p));
  }

  /// Check if current user has any of the specified permissions
  static bool hasAnyPermission(List<Permission> permissions) {
    if (_currentUser == null) return false;
    return permissions
        .any((p) => PermissionMatrix.hasPermission(_currentUser!.role, p));
  }

  /// Check permission and return result with reason
  static PermissionCheckResult checkPermission(Permission permission) {
    if (_currentUser == null) {
      return const PermissionCheckResult.denied('No user logged in');
    }
    return PermissionService.check(_currentUser!.role, permission);
  }

  /// Enforce permission - throws if not allowed
  static void enforcePermission(Permission permission) {
    final result = checkPermission(permission);
    if (!result.allowed) {
      LogService.warning(
          'Permission denied: ${permission.name} for user ${_currentUser?.username}');
      throw PermissionDeniedException(permission, result.reason);
    }
  }

  /// Enforce all permissions - throws if any not allowed
  static void enforceAllPermissions(List<Permission> permissions) {
    for (final permission in permissions) {
      enforcePermission(permission);
    }
  }

  /// Enforce any permission - throws if none allowed
  static void enforceAnyPermission(List<Permission> permissions) {
    if (!hasAnyPermission(permissions)) {
      throw PermissionDeniedException(
        permissions.first,
        'None of the required permissions are granted',
      );
    }
  }

  // ============ ROLE CHECKS ============

  /// Check if current user has at least the specified role level
  static bool hasRoleLevel(int level) {
    if (_currentUser == null) return false;
    return _currentUser!.role.level >= level;
  }

  /// Check if current user is a specific role
  static bool isRole(UserRole role) {
    if (_currentUser == null) return false;
    return _currentUser!.role == role;
  }

  /// Check if current user is Production Manager
  static bool get isProductionManager =>
      _currentUser?.role == UserRole.productionManager;

  /// Check if current user is Setter
  static bool get isSetter => _currentUser?.role == UserRole.setter;

  /// Check if current user is Operator
  static bool get isOperator => _currentUser?.role == UserRole.operator;

  /// Check if current user is Material Handler
  static bool get isMaterialHandler =>
      _currentUser?.role == UserRole.materialHandler;

  /// Check if current user is QC
  static bool get isQC => _currentUser?.role == UserRole.qc;

  /// Check if current user can manage another user
  static bool canManageUser(User targetUser) {
    if (_currentUser == null) return false;
    return _currentUser!.canManage(targetUser);
  }

  // ============ SCREEN ACCESS ============

  /// Check if current user can access a screen
  static bool canAccessScreen(String screenName) {
    if (_currentUser == null) return false;

    // Map screen names to required permissions
    final screenPermissions = _getScreenPermissions(screenName);
    if (screenPermissions.isEmpty) return true; // No restrictions

    return hasAnyPermission(screenPermissions);
  }

  /// Get required permissions for a screen
  static List<Permission> _getScreenPermissions(String screenName) {
    switch (screenName.toLowerCase()) {
      // User Management
      case 'manage_users':
      case 'user_permissions':
        return [Permission.usersView];

      // Machine Management
      case 'manage_machines':
      case 'machine_detail':
        return [Permission.machinesView];

      // Mould Management
      case 'manage_moulds':
      case 'mould_passport':
        return [Permission.mouldsView];

      // Job Management
      case 'manage_jobs':
      case 'job_queue':
      case 'planning':
        return [Permission.jobsView];

      // Material Management
      case 'manage_materials':
      case 'stock':
        return [Permission.materialsView];

      // Quality Control
      case 'quality_control':
      case 'inspections':
        return [Permission.qualityView];

      // Maintenance
      case 'maintenance':
      case 'checklists':
        return [Permission.maintenanceView];

      // Analytics
      case 'analytics':
      case 'oee':
      case 'reports':
        return [Permission.analyticsView];

      // Settings
      case 'settings':
        return [Permission.settingsView];

      // Audit
      case 'audit':
        return [Permission.auditView];

      // Default - accessible to all
      default:
        return [];
    }
  }

  /// Get list of accessible screens for current user
  static List<String> getAccessibleScreens() {
    if (_currentUser == null) return [];

    final allScreens = [
      'dashboard',
      'timeline',
      'inputs',
      'issues',
      'my_tasks',
      'manage_machines',
      'machine_detail',
      'manage_moulds',
      'mould_passport',
      'manage_jobs',
      'job_queue',
      'planning',
      'manage_materials',
      'stock',
      'quality_control',
      'inspections',
      'maintenance',
      'checklists',
      'downtime',
      'analytics',
      'oee',
      'reports',
      'manage_users',
      'user_permissions',
      'settings',
      'audit',
    ];

    return allScreens.where((screen) => canAccessScreen(screen)).toList();
  }

  // ============ ACTION GUARDS ============

  /// Guard for creating entities
  static Future<T> guardCreate<T>({
    required Permission permission,
    required Future<T> Function() action,
    required String entityType,
  }) async {
    enforcePermission(permission);

    try {
      final result = await action();
      LogService.info(
          'Create $entityType by ${_currentUser?.username} - Success');
      return result;
    } catch (e) {
      LogService.error(
          'Create $entityType by ${_currentUser?.username} - Failed', e);
      rethrow;
    }
  }

  /// Guard for updating entities
  static Future<T> guardUpdate<T>({
    required Permission permission,
    required Future<T> Function() action,
    required String entityType,
    required String entityId,
  }) async {
    enforcePermission(permission);

    try {
      final result = await action();
      LogService.info(
          'Update $entityType/$entityId by ${_currentUser?.username} - Success');
      return result;
    } catch (e) {
      LogService.error(
          'Update $entityType/$entityId by ${_currentUser?.username} - Failed',
          e);
      rethrow;
    }
  }

  /// Guard for deleting entities
  static Future<void> guardDelete({
    required Permission permission,
    required Future<void> Function() action,
    required String entityType,
    required String entityId,
  }) async {
    enforcePermission(permission);

    try {
      await action();
      LogService.info(
          'Delete $entityType/$entityId by ${_currentUser?.username} - Success');
    } catch (e) {
      LogService.error(
          'Delete $entityType/$entityId by ${_currentUser?.username} - Failed',
          e);
      rethrow;
    }
  }

  /// Guard for override actions (requires reason)
  static Future<T> guardOverride<T>({
    required Permission permission,
    required Future<T> Function() action,
    required String entityType,
    required String entityId,
    required String reason,
  }) async {
    enforcePermission(permission);

    if (reason.trim().isEmpty) {
      throw ArgumentError('Override actions require a reason');
    }

    try {
      final result = await action();

      await AuditService.logOverride(
        entityType: entityType,
        entityId: entityId,
        beforeValue: {},
        afterValue: {},
        reason: reason,
        metadata: {'overrideBy': _currentUser?.username},
      );

      LogService.info(
          'Override $entityType/$entityId by ${_currentUser?.username} - Success');
      return result;
    } catch (e) {
      LogService.error(
          'Override $entityType/$entityId by ${_currentUser?.username} - Failed',
          e);
      rethrow;
    }
  }

  // ============ MENU VISIBILITY ============

  /// Get menu items visible to current user
  static List<MenuItem> getVisibleMenuItems() {
    if (_currentUser == null) return [];

    final allItems = [
      MenuItem(
        id: 'dashboard',
        title: 'Dashboard',
        icon: 'dashboard',
        permissions: [],
      ),
      MenuItem(
        id: 'timeline',
        title: 'Timeline',
        icon: 'timeline',
        permissions: [],
      ),
      MenuItem(
        id: 'inputs',
        title: 'Inputs',
        icon: 'input',
        permissions: [Permission.productionLogEntry],
      ),
      MenuItem(
        id: 'issues',
        title: 'Issues',
        icon: 'warning',
        permissions: [],
      ),
      MenuItem(
        id: 'my_tasks',
        title: 'My Tasks',
        icon: 'task',
        permissions: [Permission.tasksViewOwn],
      ),
      MenuItem(
        id: 'machines',
        title: 'Machines',
        icon: 'precision_manufacturing',
        permissions: [Permission.machinesView],
        minLevel: 3,
      ),
      MenuItem(
        id: 'moulds',
        title: 'Moulds',
        icon: 'view_in_ar',
        permissions: [Permission.mouldsView],
        minLevel: 3,
      ),
      MenuItem(
        id: 'jobs',
        title: 'Jobs',
        icon: 'work',
        permissions: [Permission.jobsView],
        minLevel: 3,
      ),
      MenuItem(
        id: 'planning',
        title: 'Planning',
        icon: 'calendar_today',
        permissions: [Permission.jobsReorder],
        minLevel: 3,
      ),
      MenuItem(
        id: 'quality',
        title: 'Quality Control',
        icon: 'verified',
        permissions: [Permission.qualityView],
      ),
      MenuItem(
        id: 'materials',
        title: 'Materials',
        icon: 'inventory',
        permissions: [Permission.materialsView],
      ),
      MenuItem(
        id: 'maintenance',
        title: 'Maintenance',
        icon: 'build',
        permissions: [Permission.maintenanceView],
        minLevel: 3,
      ),
      MenuItem(
        id: 'analytics',
        title: 'Analytics',
        icon: 'analytics',
        permissions: [Permission.analyticsView],
        minLevel: 4,
      ),
      MenuItem(
        id: 'users',
        title: 'Users',
        icon: 'people',
        permissions: [Permission.usersView],
        minLevel: 4,
      ),
      MenuItem(
        id: 'settings',
        title: 'Settings',
        icon: 'settings',
        permissions: [Permission.settingsView],
        minLevel: 4,
      ),
    ];

    return allItems.where((item) {
      // Check minimum level
      if (item.minLevel != null && !hasRoleLevel(item.minLevel!)) {
        return false;
      }

      // Check permissions
      if (item.permissions.isEmpty) return true;
      return hasAnyPermission(item.permissions);
    }).toList();
  }
}

/// Menu item for navigation
class MenuItem {
  final String id;
  final String title;
  final String icon;
  final List<Permission> permissions;
  final int? minLevel;

  const MenuItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.permissions,
    this.minLevel,
  });
}

/// Exception thrown when permission is denied
class PermissionDeniedException implements Exception {
  final Permission permission;
  final String? reason;

  PermissionDeniedException(this.permission, [this.reason]);

  @override
  String toString() =>
      'PermissionDeniedException: ${permission.name} - ${reason ?? "Access denied"}';
}
