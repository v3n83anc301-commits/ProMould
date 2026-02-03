/// ProMould Permission Matrix
/// Defines all permissions per role - enforced at service layer

import '../core/constants.dart';

/// Permission categories
enum PermissionCategory {
  users,
  floors,
  machines,
  moulds,
  jobs,
  materials,
  tools,
  quality,
  maintenance,
  tasks,
  alerts,
  shifts,
  analytics,
  settings,
  audit,
}

/// Individual permissions
enum Permission {
  // User Management
  usersView,
  usersCreate,
  usersEdit,
  usersDelete,
  usersAssignRole,

  // Floor Management
  floorsView,
  floorsCreate,
  floorsEdit,
  floorsDelete,

  // Machine Management
  machinesView,
  machinesCreate,
  machinesEdit,
  machinesDelete,
  machinesChangeStatus,
  machinesOverrideCounter,
  machinesAssignOperator,

  // Mould Management
  mouldsView,
  mouldsCreate,
  mouldsEdit,
  mouldsDelete,
  mouldsChangeStatus,
  mouldsScheduleChange,
  mouldsExecuteChange,
  mouldsViewPassport,

  // Job Management
  jobsView,
  jobsCreate,
  jobsEdit,
  jobsDelete,
  jobsStart,
  jobsStop,
  jobsPause,
  jobsComplete,
  jobsReorder,
  jobsOverridePriority,
  jobsOverrideDueDate,

  // Material Management
  materialsView,
  materialsCreate,
  materialsEdit,
  materialsDelete,
  materialsIssue,
  materialsReturn,
  materialsAdjust,
  materialsReconcile,

  // Tool Management
  toolsView,
  toolsCreate,
  toolsEdit,
  toolsDelete,
  toolsCheckout,
  toolsReturn,
  toolsCalibrate,

  // Quality Control
  qualityView,
  qualityCreateInspection,
  qualityEditInspection,
  qualityCreateHold,
  qualityReleaseHold,
  qualityScrapHold,
  qualityOverrideHold,

  // Maintenance
  maintenanceView,
  maintenanceCreateChecklist,
  maintenanceEditChecklist,
  maintenanceExecuteChecklist,
  maintenanceCreateWorkOrder,
  maintenanceCompleteWorkOrder,
  maintenanceOverride,

  // Machine Runtime & Downtime
  runtimeView,
  runtimeUpdateStatus,
  logDowntime,
  resolveDowntime,
  oeeView,

  // Task Management
  tasksView,
  tasksViewOwn,
  tasksCreate,
  tasksAssign,
  tasksReassign,
  tasksComplete,
  tasksEscalate,
  tasksCancel,

  // Alert Management
  alertsView,
  alertsAcknowledge,
  alertsResolve,
  alertsSnooze,
  alertsConfigure,

  // Shift Management
  shiftsView,
  shiftsCreate,
  shiftsEdit,
  shiftsDelete,
  shiftsAssignUsers,
  shiftsInitiateHandover,
  shiftsCompleteHandover,

  // Production Logging
  productionLogEntry,
  productionLogScrap,
  productionLogDowntime,
  productionReconcile,

  // Analytics & Reporting
  analyticsView,
  analyticsExport,
  analyticsCreateReport,
  analyticsScheduleReport,

  // Settings
  settingsView,
  settingsEdit,
  settingsSystemConfig,

  // Audit
  auditView,
  auditExport,
}

/// Permission matrix - defines which roles have which permissions
class PermissionMatrix {
  static final Map<UserRole, Set<Permission>> _matrix = {
    UserRole.operator: {
      // View permissions
      Permission.machinesView,
      Permission.mouldsView,
      Permission.jobsView,
      Permission.materialsView,
      Permission.tasksViewOwn,
      Permission.alertsView,
      Permission.shiftsView,

      // Action permissions
      Permission.productionLogEntry,
      Permission.productionLogScrap,
      Permission.productionLogDowntime,
      Permission.tasksComplete,
      Permission.alertsAcknowledge,
    },

    UserRole.materialHandler: {
      // View permissions
      Permission.machinesView,
      Permission.mouldsView,
      Permission.jobsView,
      Permission.materialsView,
      Permission.tasksViewOwn,
      Permission.alertsView,
      Permission.shiftsView,

      // Material-specific permissions
      Permission.materialsIssue,
      Permission.materialsReturn,
      Permission.materialsAdjust,

      // Action permissions
      Permission.tasksComplete,
      Permission.alertsAcknowledge,
    },

    UserRole.qc: {
      // View permissions
      Permission.machinesView,
      Permission.mouldsView,
      Permission.jobsView,
      Permission.materialsView,
      Permission.qualityView,
      Permission.tasksViewOwn,
      Permission.alertsView,
      Permission.shiftsView,

      // Quality-specific permissions
      Permission.qualityCreateInspection,
      Permission.qualityEditInspection,
      Permission.qualityCreateHold,
      Permission.qualityReleaseHold,
      Permission.qualityScrapHold,

      // Action permissions
      Permission.productionLogScrap,
      Permission.tasksComplete,
      Permission.alertsAcknowledge,
    },

    UserRole.setter: {
      // View permissions
      Permission.machinesView,
      Permission.mouldsView,
      Permission.mouldsViewPassport,
      Permission.jobsView,
      Permission.materialsView,
      Permission.toolsView,
      Permission.qualityView,
      Permission.maintenanceView,
      Permission.tasksView,
      Permission.alertsView,
      Permission.shiftsView,
      Permission.runtimeView,
      Permission.oeeView,

      // Machine permissions
      Permission.machinesChangeStatus,
      Permission.machinesAssignOperator,

      // Mould permissions
      Permission.mouldsExecuteChange,

      // Tool permissions
      Permission.toolsCheckout,
      Permission.toolsReturn,

      // Maintenance permissions
      Permission.maintenanceExecuteChecklist,
      Permission.maintenanceCompleteWorkOrder,

      // Production permissions
      Permission.productionLogEntry,
      Permission.productionLogScrap,
      Permission.productionLogDowntime,

      // Runtime & Downtime permissions
      Permission.runtimeUpdateStatus,
      Permission.logDowntime,
      Permission.resolveDowntime,

      // Job permissions
      Permission.jobsStart,
      Permission.jobsStop,
      Permission.jobsPause,

      // Task permissions
      Permission.tasksComplete,
      Permission.tasksEscalate,

      // Alert permissions
      Permission.alertsAcknowledge,
      Permission.alertsResolve,
    },

    UserRole.productionManager: {
      // ALL permissions
      ...Permission.values,
    },
  };

  /// Check if a role has a specific permission
  static bool hasPermission(UserRole role, Permission permission) {
    return _matrix[role]?.contains(permission) ?? false;
  }

  /// Get all permissions for a role
  static Set<Permission> getPermissions(UserRole role) {
    return _matrix[role] ?? {};
  }

  /// Check if a role can perform an action (convenience method)
  static bool canPerform(UserRole role, Permission permission) {
    return hasPermission(role, permission);
  }

  /// Get all roles that have a specific permission
  static List<UserRole> rolesWithPermission(Permission permission) {
    return UserRole.values
        .where((role) => hasPermission(role, permission))
        .toList();
  }
}

/// Permission check result with reason
class PermissionCheckResult {
  final bool allowed;
  final String? reason;

  const PermissionCheckResult.allowed()
      : allowed = true,
        reason = null;

  const PermissionCheckResult.denied(this.reason) : allowed = false;

  @override
  String toString() =>
      allowed ? 'Allowed' : 'Denied: ${reason ?? "Unknown reason"}';
}

/// Permission service for runtime checks
class PermissionService {
  /// Check if current user can perform action
  static PermissionCheckResult check(UserRole userRole, Permission permission) {
    if (PermissionMatrix.hasPermission(userRole, permission)) {
      return const PermissionCheckResult.allowed();
    }
    return PermissionCheckResult.denied(
      'Role ${userRole.displayName} does not have permission: ${permission.name}',
    );
  }

  /// Check multiple permissions (all must pass)
  static PermissionCheckResult checkAll(
      UserRole userRole, List<Permission> permissions) {
    for (final permission in permissions) {
      final result = check(userRole, permission);
      if (!result.allowed) {
        return result;
      }
    }
    return const PermissionCheckResult.allowed();
  }

  /// Check multiple permissions (any must pass)
  static PermissionCheckResult checkAny(
      UserRole userRole, List<Permission> permissions) {
    for (final permission in permissions) {
      final result = check(userRole, permission);
      if (result.allowed) {
        return result;
      }
    }
    return PermissionCheckResult.denied(
      'Role ${userRole.displayName} does not have any of the required permissions',
    );
  }

  /// Get minimum role level required for a permission
  static int minimumRoleLevel(Permission permission) {
    int minLevel = 999;
    for (final role in UserRole.values) {
      if (PermissionMatrix.hasPermission(role, permission)) {
        if (role.level < minLevel) {
          minLevel = role.level;
        }
      }
    }
    return minLevel;
  }
}
