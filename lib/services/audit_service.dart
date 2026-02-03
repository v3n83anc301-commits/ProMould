/// ProMould Audit Service
/// Immutable audit logging for all system actions
/// Every data change, override, and significant action is logged

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import 'log_service.dart';
import 'sync_service.dart';

/// Audit log entry - immutable once created
class AuditEntry {
  final String id;
  final String entityType;
  final String entityId;
  final AuditAction action;
  final String userId;
  final String userName;
  final UserRole userRole;
  final DateTime timestamp;
  final Map<String, dynamic>? beforeValue;
  final Map<String, dynamic>? afterValue;
  final String? reason; // Required for overrides
  final String? ipAddress;
  final String? deviceInfo;
  final Map<String, dynamic>? metadata;

  AuditEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.timestamp,
    this.beforeValue,
    this.afterValue,
    this.reason,
    this.ipAddress,
    this.deviceInfo,
    this.metadata,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'entityType': entityType,
        'entityId': entityId,
        'action': action.name,
        'userId': userId,
        'userName': userName,
        'userRole': userRole.name,
        'timestamp': timestamp.toIso8601String(),
        'beforeValue': beforeValue,
        'afterValue': afterValue,
        'reason': reason,
        'ipAddress': ipAddress,
        'deviceInfo': deviceInfo,
        'metadata': metadata,
      };

  factory AuditEntry.fromMap(Map<String, dynamic> map) => AuditEntry(
        id: map['id'] as String,
        entityType: map['entityType'] as String,
        entityId: map['entityId'] as String,
        action: AuditAction.values.firstWhere(
          (a) => a.name == map['action'],
          orElse: () => AuditAction.update,
        ),
        userId: map['userId'] as String,
        userName: map['userName'] as String,
        userRole: UserRole.values.firstWhere(
          (r) => r.name == map['userRole'],
          orElse: () => UserRole.operator,
        ),
        timestamp: DateTime.parse(map['timestamp'] as String),
        beforeValue: map['beforeValue'] as Map<String, dynamic>?,
        afterValue: map['afterValue'] as Map<String, dynamic>?,
        reason: map['reason'] as String?,
        ipAddress: map['ipAddress'] as String?,
        deviceInfo: map['deviceInfo'] as String?,
        metadata: map['metadata'] as Map<String, dynamic>?,
      );

  /// Check if this is an override action (requires reason)
  bool get isOverride => action == AuditAction.override;

  /// Get a summary of what changed
  String get changeSummary {
    if (beforeValue == null && afterValue == null) {
      return action.displayName;
    }
    if (beforeValue == null) {
      return 'Created new $entityType';
    }
    if (afterValue == null) {
      return 'Deleted $entityType';
    }

    // Find changed fields
    final changes = <String>[];
    for (final key in afterValue!.keys) {
      final before = beforeValue![key];
      final after = afterValue![key];
      if (before != after) {
        changes.add('$key: $before → $after');
      }
    }
    return changes.isEmpty ? 'No changes' : changes.join(', ');
  }
}

/// Audit service - singleton for logging all actions
class AuditService {
  static const _uuid = Uuid();
  static Box? _box;

  // Current user context (set on login)
  static String? _currentUserId;
  static String? _currentUserName;
  static UserRole? _currentUserRole;
  static String? _deviceInfo;

  /// Initialize the audit service
  static Future<void> initialize() async {
    _box = await Hive.openBox(HiveBoxes.auditLogs);
    LogService.info('AuditService initialized');
  }

  /// Set current user context (called on login)
  static void setUserContext({
    required String userId,
    required String userName,
    required UserRole userRole,
    String? deviceInfo,
  }) {
    _currentUserId = userId;
    _currentUserName = userName;
    _currentUserRole = userRole;
    _deviceInfo = deviceInfo;
    LogService.info('Audit context set for user: $userName');
  }

  /// Clear user context (called on logout)
  static void clearUserContext() {
    _currentUserId = null;
    _currentUserName = null;
    _currentUserRole = null;
    _deviceInfo = null;
  }

  /// Log a create action
  static Future<AuditEntry> logCreate({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> data,
    Map<String, dynamic>? metadata,
  }) async {
    return _log(
      entityType: entityType,
      entityId: entityId,
      action: AuditAction.create,
      afterValue: data,
      metadata: metadata,
    );
  }

  /// Log an update action
  static Future<AuditEntry> logUpdate({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> beforeValue,
    required Map<String, dynamic> afterValue,
    Map<String, dynamic>? metadata,
  }) async {
    return _log(
      entityType: entityType,
      entityId: entityId,
      action: AuditAction.update,
      beforeValue: beforeValue,
      afterValue: afterValue,
      metadata: metadata,
    );
  }

  /// Log a delete action
  static Future<AuditEntry> logDelete({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> data,
    Map<String, dynamic>? metadata,
  }) async {
    return _log(
      entityType: entityType,
      entityId: entityId,
      action: AuditAction.delete,
      beforeValue: data,
      metadata: metadata,
    );
  }

  /// Log an override action (REQUIRES reason)
  static Future<AuditEntry> logOverride({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> beforeValue,
    required Map<String, dynamic> afterValue,
    required String reason,
    Map<String, dynamic>? metadata,
  }) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('Override actions require a reason');
    }
    return _log(
      entityType: entityType,
      entityId: entityId,
      action: AuditAction.override,
      beforeValue: beforeValue,
      afterValue: afterValue,
      reason: reason,
      metadata: metadata,
    );
  }

  /// Log a status change
  static Future<AuditEntry> logStatusChange({
    required String entityType,
    required String entityId,
    required String fromStatus,
    required String toStatus,
    String? reason,
    Map<String, dynamic>? metadata,
  }) async {
    return _log(
      entityType: entityType,
      entityId: entityId,
      action: AuditAction.statusChange,
      beforeValue: {'status': fromStatus},
      afterValue: {'status': toStatus},
      reason: reason,
      metadata: metadata,
    );
  }

  /// Log an assignment
  static Future<AuditEntry> logAssignment({
    required String entityType,
    required String entityId,
    required String assignedTo,
    String? previousAssignee,
    String? reason,
    Map<String, dynamic>? metadata,
  }) async {
    return _log(
      entityType: entityType,
      entityId: entityId,
      action: AuditAction.assignment,
      beforeValue: previousAssignee != null ? {'assignee': previousAssignee} : null,
      afterValue: {'assignee': assignedTo},
      reason: reason,
      metadata: metadata,
    );
  }

  /// Log a reconciliation
  static Future<AuditEntry> logReconciliation({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> beforeValue,
    required Map<String, dynamic> afterValue,
    required String reason,
    Map<String, dynamic>? metadata,
  }) async {
    return _log(
      entityType: entityType,
      entityId: entityId,
      action: AuditAction.reconciliation,
      beforeValue: beforeValue,
      afterValue: afterValue,
      reason: reason,
      metadata: metadata,
    );
  }

  /// Log a login
  static Future<AuditEntry> logLogin({
    required String userId,
    required String userName,
    required UserRole userRole,
    String? deviceInfo,
    Map<String, dynamic>? metadata,
  }) async {
    // Temporarily set context for this log
    final entry = AuditEntry(
      id: _uuid.v4(),
      entityType: 'User',
      entityId: userId,
      action: AuditAction.login,
      userId: userId,
      userName: userName,
      userRole: userRole,
      timestamp: DateTime.now(),
      deviceInfo: deviceInfo,
      metadata: metadata,
    );

    await _save(entry);
    return entry;
  }

  /// Log a logout
  static Future<AuditEntry> logLogout({
    required String userId,
    required String userName,
    required UserRole userRole,
    String? deviceInfo,
    Map<String, dynamic>? metadata,
  }) async {
    final entry = AuditEntry(
      id: _uuid.v4(),
      entityType: 'User',
      entityId: userId,
      action: AuditAction.logout,
      userId: userId,
      userName: userName,
      userRole: userRole,
      timestamp: DateTime.now(),
      deviceInfo: deviceInfo,
      metadata: metadata,
    );

    await _save(entry);
    return entry;
  }

  /// Log an escalation
  static Future<AuditEntry> logEscalation({
    required String entityType,
    required String entityId,
    required int fromLevel,
    required int toLevel,
    required String escalatedTo,
    String? reason,
    Map<String, dynamic>? metadata,
  }) async {
    return _log(
      entityType: entityType,
      entityId: entityId,
      action: AuditAction.escalation,
      beforeValue: {'escalationLevel': fromLevel},
      afterValue: {'escalationLevel': toLevel, 'escalatedTo': escalatedTo},
      reason: reason,
      metadata: metadata,
    );
  }

  /// Log an approval
  static Future<AuditEntry> logApproval({
    required String entityType,
    required String entityId,
    String? reason,
    Map<String, dynamic>? metadata,
  }) async {
    return _log(
      entityType: entityType,
      entityId: entityId,
      action: AuditAction.approval,
      reason: reason,
      metadata: metadata,
    );
  }

  /// Log a rejection
  static Future<AuditEntry> logRejection({
    required String entityType,
    required String entityId,
    required String reason,
    Map<String, dynamic>? metadata,
  }) async {
    return _log(
      entityType: entityType,
      entityId: entityId,
      action: AuditAction.rejection,
      reason: reason,
      metadata: metadata,
    );
  }

  /// Internal logging method
  static Future<AuditEntry> _log({
    required String entityType,
    required String entityId,
    required AuditAction action,
    Map<String, dynamic>? beforeValue,
    Map<String, dynamic>? afterValue,
    String? reason,
    Map<String, dynamic>? metadata,
  }) async {
    final entry = AuditEntry(
      id: _uuid.v4(),
      entityType: entityType,
      entityId: entityId,
      action: action,
      userId: _currentUserId ?? 'system',
      userName: _currentUserName ?? 'System',
      userRole: _currentUserRole ?? UserRole.operator,
      timestamp: DateTime.now(),
      beforeValue: beforeValue,
      afterValue: afterValue,
      reason: reason,
      deviceInfo: _deviceInfo,
      metadata: metadata,
    );

    await _save(entry);
    return entry;
  }

  /// Save audit entry (local + remote)
  static Future<void> _save(AuditEntry entry) async {
    try {
      // Save locally
      await _box?.put(entry.id, entry.toMap());

      // Sync to Firebase
      await SyncService.push(HiveBoxes.auditLogs, entry.id, entry.toMap());

      LogService.audit(
        '${entry.action.displayName}: ${entry.entityType}/${entry.entityId}',
      );
    } catch (e) {
      LogService.error('Failed to save audit entry', e);
    }
  }

  /// Query audit logs for an entity
  static List<AuditEntry> getForEntity(String entityType, String entityId) {
    if (_box == null) return [];

    return _box!.values
        .where((map) =>
            map['entityType'] == entityType && map['entityId'] == entityId)
        .map((map) => AuditEntry.fromMap(Map<String, dynamic>.from(map)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Query audit logs by user
  static List<AuditEntry> getByUser(String userId, {int? limit}) {
    if (_box == null) return [];

    var entries = _box!.values
        .where((map) => map['userId'] == userId)
        .map((map) => AuditEntry.fromMap(Map<String, dynamic>.from(map)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (limit != null && entries.length > limit) {
      entries = entries.take(limit).toList();
    }

    return entries;
  }

  /// Query audit logs by action type
  static List<AuditEntry> getByAction(AuditAction action, {int? limit}) {
    if (_box == null) return [];

    var entries = _box!.values
        .where((map) => map['action'] == action.name)
        .map((map) => AuditEntry.fromMap(Map<String, dynamic>.from(map)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (limit != null && entries.length > limit) {
      entries = entries.take(limit).toList();
    }

    return entries;
  }

  /// Query audit logs by date range
  static List<AuditEntry> getByDateRange(DateTime start, DateTime end) {
    if (_box == null) return [];

    return _box!.values
        .map((map) => AuditEntry.fromMap(Map<String, dynamic>.from(map)))
        .where((entry) =>
            entry.timestamp.isAfter(start) && entry.timestamp.isBefore(end))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Get all override actions (for compliance review)
  static List<AuditEntry> getOverrides({int? limit}) {
    return getByAction(AuditAction.override, limit: limit);
  }

  /// Get recent activity
  static List<AuditEntry> getRecent({int limit = 50}) {
    if (_box == null) return [];

    return _box!.values
        .map((map) => AuditEntry.fromMap(Map<String, dynamic>.from(map)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp))
      ..take(limit);
  }

  /// Export audit logs for compliance
  static List<Map<String, dynamic>> exportForCompliance({
    DateTime? startDate,
    DateTime? endDate,
    String? entityType,
    AuditAction? action,
  }) {
    if (_box == null) return [];

    var entries = _box!.values
        .map((map) => AuditEntry.fromMap(Map<String, dynamic>.from(map)));

    if (startDate != null) {
      entries = entries.where((e) => e.timestamp.isAfter(startDate));
    }
    if (endDate != null) {
      entries = entries.where((e) => e.timestamp.isBefore(endDate));
    }
    if (entityType != null) {
      entries = entries.where((e) => e.entityType == entityType);
    }
    if (action != null) {
      entries = entries.where((e) => e.action == action);
    }

    return entries.map((e) => e.toMap()).toList()
      ..sort((a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String));
  }
}
