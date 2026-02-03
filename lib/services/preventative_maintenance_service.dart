/// ProMould Preventative Maintenance Service
/// Manages maintenance schedules, service intervals, and auto-task creation

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import 'audit_service.dart';
import 'log_service.dart';
import 'sync_service.dart';
import 'task_service.dart';

/// Maintenance schedule frequency
enum MaintenanceFrequency {
  daily,
  weekly,
  biweekly,
  monthly,
  quarterly,
  biannual,
  annual,
  cycles,  // Based on cycle count
  hours,   // Based on running hours
}

/// Maintenance schedule status
enum ScheduleStatus {
  active,
  paused,
  completed,
  overdue,
}

/// Maintenance type
enum MaintenanceType {
  inspection,
  lubrication,
  cleaning,
  calibration,
  replacement,
  overhaul,
  safety,
  other,
}

/// Maintenance schedule definition
class MaintenanceSchedule {
  final String id;
  final String name;
  final String description;
  final MaintenanceType type;
  final MaintenanceFrequency frequency;
  final int frequencyValue; // e.g., every 1000 cycles, every 8 hours
  final String? machineId;
  final String? mouldId;
  final List<String> checklistItems;
  final int estimatedMinutes;
  final String? assignedRole; // e.g., 'setter'
  final ScheduleStatus status;
  final DateTime? lastCompleted;
  final DateTime? nextDue;
  final int completionCount;
  final DateTime createdAt;
  final String? createdBy;

  MaintenanceSchedule({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.frequency,
    this.frequencyValue = 1,
    this.machineId,
    this.mouldId,
    this.checklistItems = const [],
    this.estimatedMinutes = 30,
    this.assignedRole,
    this.status = ScheduleStatus.active,
    this.lastCompleted,
    this.nextDue,
    this.completionCount = 0,
    required this.createdAt,
    this.createdBy,
  });

  bool get isOverdue {
    if (nextDue == null) return false;
    return DateTime.now().isAfter(nextDue!);
  }

  int get daysUntilDue {
    if (nextDue == null) return 999;
    return nextDue!.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'type': type.name,
        'frequency': frequency.name,
        'frequencyValue': frequencyValue,
        'machineId': machineId,
        'mouldId': mouldId,
        'checklistItems': checklistItems,
        'estimatedMinutes': estimatedMinutes,
        'assignedRole': assignedRole,
        'status': status.name,
        'lastCompleted': lastCompleted?.toIso8601String(),
        'nextDue': nextDue?.toIso8601String(),
        'completionCount': completionCount,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
      };

  factory MaintenanceSchedule.fromMap(Map<String, dynamic> map) {
    return MaintenanceSchedule(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      type: MaintenanceType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => MaintenanceType.other,
      ),
      frequency: MaintenanceFrequency.values.firstWhere(
        (f) => f.name == map['frequency'],
        orElse: () => MaintenanceFrequency.monthly,
      ),
      frequencyValue: map['frequencyValue'] ?? 1,
      machineId: map['machineId'],
      mouldId: map['mouldId'],
      checklistItems: List<String>.from(map['checklistItems'] ?? []),
      estimatedMinutes: map['estimatedMinutes'] ?? 30,
      assignedRole: map['assignedRole'],
      status: ScheduleStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => ScheduleStatus.active,
      ),
      lastCompleted: map['lastCompleted'] != null
          ? DateTime.tryParse(map['lastCompleted'])
          : null,
      nextDue: map['nextDue'] != null ? DateTime.tryParse(map['nextDue']) : null,
      completionCount: map['completionCount'] ?? 0,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      createdBy: map['createdBy'],
    );
  }

  MaintenanceSchedule copyWith({
    String? id,
    String? name,
    String? description,
    MaintenanceType? type,
    MaintenanceFrequency? frequency,
    int? frequencyValue,
    String? machineId,
    String? mouldId,
    List<String>? checklistItems,
    int? estimatedMinutes,
    String? assignedRole,
    ScheduleStatus? status,
    DateTime? lastCompleted,
    DateTime? nextDue,
    int? completionCount,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return MaintenanceSchedule(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      frequency: frequency ?? this.frequency,
      frequencyValue: frequencyValue ?? this.frequencyValue,
      machineId: machineId ?? this.machineId,
      mouldId: mouldId ?? this.mouldId,
      checklistItems: checklistItems ?? this.checklistItems,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      assignedRole: assignedRole ?? this.assignedRole,
      status: status ?? this.status,
      lastCompleted: lastCompleted ?? this.lastCompleted,
      nextDue: nextDue ?? this.nextDue,
      completionCount: completionCount ?? this.completionCount,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

/// Maintenance history record
class MaintenanceRecord {
  final String id;
  final String scheduleId;
  final String scheduleName;
  final String? machineId;
  final String? mouldId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String performedBy;
  final Map<String, bool> checklistResults;
  final String? notes;
  final List<String> partsUsed;
  final int actualMinutes;
  final bool passed;

  MaintenanceRecord({
    required this.id,
    required this.scheduleId,
    required this.scheduleName,
    this.machineId,
    this.mouldId,
    required this.startedAt,
    this.completedAt,
    required this.performedBy,
    this.checklistResults = const {},
    this.notes,
    this.partsUsed = const [],
    this.actualMinutes = 0,
    this.passed = true,
  });

  bool get isComplete => completedAt != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'scheduleId': scheduleId,
        'scheduleName': scheduleName,
        'machineId': machineId,
        'mouldId': mouldId,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'performedBy': performedBy,
        'checklistResults': checklistResults,
        'notes': notes,
        'partsUsed': partsUsed,
        'actualMinutes': actualMinutes,
        'passed': passed,
      };

  factory MaintenanceRecord.fromMap(Map<String, dynamic> map) {
    return MaintenanceRecord(
      id: map['id'] ?? '',
      scheduleId: map['scheduleId'] ?? '',
      scheduleName: map['scheduleName'] ?? '',
      machineId: map['machineId'],
      mouldId: map['mouldId'],
      startedAt: DateTime.tryParse(map['startedAt'] ?? '') ?? DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'])
          : null,
      performedBy: map['performedBy'] ?? '',
      checklistResults: Map<String, bool>.from(map['checklistResults'] ?? {}),
      notes: map['notes'],
      partsUsed: List<String>.from(map['partsUsed'] ?? []),
      actualMinutes: map['actualMinutes'] ?? 0,
      passed: map['passed'] ?? true,
    );
  }

  MaintenanceRecord copyWith({
    String? id,
    String? scheduleId,
    String? scheduleName,
    String? machineId,
    String? mouldId,
    DateTime? startedAt,
    DateTime? completedAt,
    String? performedBy,
    Map<String, bool>? checklistResults,
    String? notes,
    List<String>? partsUsed,
    int? actualMinutes,
    bool? passed,
  }) {
    return MaintenanceRecord(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      scheduleName: scheduleName ?? this.scheduleName,
      machineId: machineId ?? this.machineId,
      mouldId: mouldId ?? this.mouldId,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      performedBy: performedBy ?? this.performedBy,
      checklistResults: checklistResults ?? this.checklistResults,
      notes: notes ?? this.notes,
      partsUsed: partsUsed ?? this.partsUsed,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      passed: passed ?? this.passed,
    );
  }
}

/// Preventative Maintenance Service
class PreventativeMaintenanceService {
  static const _uuid = Uuid();
  static Box? _schedulesBox;
  static Box? _recordsBox;
  static Box? _machinesBox;
  static Box? _mouldsBox;

  /// Initialize the service
  static Future<void> initialize() async {
    _schedulesBox = Hive.isBoxOpen('maintenanceSchedulesBox')
        ? Hive.box('maintenanceSchedulesBox')
        : await Hive.openBox('maintenanceSchedulesBox');

    _recordsBox = Hive.isBoxOpen('maintenanceRecordsBox')
        ? Hive.box('maintenanceRecordsBox')
        : await Hive.openBox('maintenanceRecordsBox');

    _machinesBox = Hive.isBoxOpen(HiveBoxes.machines)
        ? Hive.box(HiveBoxes.machines)
        : await Hive.openBox(HiveBoxes.machines);

    _mouldsBox = Hive.isBoxOpen(HiveBoxes.moulds)
        ? Hive.box(HiveBoxes.moulds)
        : await Hive.openBox(HiveBoxes.moulds);

    // Check for overdue schedules and create tasks
    await _checkOverdueSchedules();

    LogService.info('PreventativeMaintenanceService initialized');
  }

  // ============ SCHEDULE MANAGEMENT ============

  /// Get all maintenance schedules
  static List<MaintenanceSchedule> getAllSchedules() {
    final data = _schedulesBox?.values.cast<Map>().toList() ?? [];
    return data
        .map((d) => MaintenanceSchedule.fromMap(Map<String, dynamic>.from(d)))
        .toList()
      ..sort((a, b) => (a.nextDue ?? DateTime(2100))
          .compareTo(b.nextDue ?? DateTime(2100)));
  }

  /// Get schedules for a specific machine
  static List<MaintenanceSchedule> getMachineSchedules(String machineId) {
    return getAllSchedules().where((s) => s.machineId == machineId).toList();
  }

  /// Get schedules for a specific mould
  static List<MaintenanceSchedule> getMouldSchedules(String mouldId) {
    return getAllSchedules().where((s) => s.mouldId == mouldId).toList();
  }

  /// Get overdue schedules
  static List<MaintenanceSchedule> getOverdueSchedules() {
    return getAllSchedules()
        .where((s) => s.status == ScheduleStatus.active && s.isOverdue)
        .toList();
  }

  /// Get upcoming schedules (due within days)
  static List<MaintenanceSchedule> getUpcomingSchedules({int days = 7}) {
    final cutoff = DateTime.now().add(Duration(days: days));
    return getAllSchedules()
        .where((s) =>
            s.status == ScheduleStatus.active &&
            s.nextDue != null &&
            s.nextDue!.isBefore(cutoff))
        .toList();
  }

  /// Create a new maintenance schedule
  static Future<MaintenanceSchedule> createSchedule({
    required String name,
    required String description,
    required MaintenanceType type,
    required MaintenanceFrequency frequency,
    int frequencyValue = 1,
    String? machineId,
    String? mouldId,
    List<String> checklistItems = const [],
    int estimatedMinutes = 30,
    String? assignedRole,
    String? createdBy,
  }) async {
    final schedule = MaintenanceSchedule(
      id: _uuid.v4(),
      name: name,
      description: description,
      type: type,
      frequency: frequency,
      frequencyValue: frequencyValue,
      machineId: machineId,
      mouldId: mouldId,
      checklistItems: checklistItems,
      estimatedMinutes: estimatedMinutes,
      assignedRole: assignedRole,
      status: ScheduleStatus.active,
      nextDue: _calculateNextDue(frequency, frequencyValue, null),
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );

    await _schedulesBox?.put(schedule.id, schedule.toMap());
    await SyncService.push('maintenanceSchedulesBox', schedule.id, schedule.toMap());

    await AuditService.logCreate(
      entityType: 'MaintenanceSchedule',
      entityId: schedule.id,
      createdValue: schedule.toMap(),
    );

    LogService.info('Maintenance schedule created: ${schedule.name}');
    return schedule;
  }

  /// Update a maintenance schedule
  static Future<MaintenanceSchedule?> updateSchedule(
    String scheduleId, {
    String? name,
    String? description,
    MaintenanceType? type,
    MaintenanceFrequency? frequency,
    int? frequencyValue,
    List<String>? checklistItems,
    int? estimatedMinutes,
    String? assignedRole,
    ScheduleStatus? status,
  }) async {
    final data = _schedulesBox?.get(scheduleId) as Map?;
    if (data == null) return null;

    final existing = MaintenanceSchedule.fromMap(Map<String, dynamic>.from(data));
    final updated = existing.copyWith(
      name: name,
      description: description,
      type: type,
      frequency: frequency,
      frequencyValue: frequencyValue,
      checklistItems: checklistItems,
      estimatedMinutes: estimatedMinutes,
      assignedRole: assignedRole,
      status: status,
    );

    await _schedulesBox?.put(scheduleId, updated.toMap());
    await SyncService.push('maintenanceSchedulesBox', scheduleId, updated.toMap());

    await AuditService.logUpdate(
      entityType: 'MaintenanceSchedule',
      entityId: scheduleId,
      beforeValue: existing.toMap(),
      afterValue: updated.toMap(),
    );

    return updated;
  }

  /// Delete a maintenance schedule
  static Future<void> deleteSchedule(String scheduleId) async {
    final data = _schedulesBox?.get(scheduleId) as Map?;
    if (data == null) return;

    await _schedulesBox?.delete(scheduleId);

    await AuditService.logDelete(
      entityType: 'MaintenanceSchedule',
      entityId: scheduleId,
      deletedValue: Map<String, dynamic>.from(data),
    );

    LogService.info('Maintenance schedule deleted: $scheduleId');
  }

  // ============ MAINTENANCE EXECUTION ============

  /// Start a maintenance task
  static Future<MaintenanceRecord> startMaintenance({
    required String scheduleId,
    required String performedBy,
  }) async {
    final scheduleData = _schedulesBox?.get(scheduleId) as Map?;
    if (scheduleData == null) {
      throw Exception('Schedule not found: $scheduleId');
    }

    final schedule =
        MaintenanceSchedule.fromMap(Map<String, dynamic>.from(scheduleData));

    final record = MaintenanceRecord(
      id: _uuid.v4(),
      scheduleId: scheduleId,
      scheduleName: schedule.name,
      machineId: schedule.machineId,
      mouldId: schedule.mouldId,
      startedAt: DateTime.now(),
      performedBy: performedBy,
    );

    await _recordsBox?.put(record.id, record.toMap());
    await SyncService.push('maintenanceRecordsBox', record.id, record.toMap());

    await AuditService.logCreate(
      entityType: 'MaintenanceRecord',
      entityId: record.id,
      createdValue: record.toMap(),
    );

    LogService.info('Maintenance started: ${schedule.name} by $performedBy');
    return record;
  }

  /// Complete a maintenance task
  static Future<MaintenanceRecord?> completeMaintenance({
    required String recordId,
    required Map<String, bool> checklistResults,
    String? notes,
    List<String> partsUsed = const [],
    bool passed = true,
  }) async {
    final recordData = _recordsBox?.get(recordId) as Map?;
    if (recordData == null) return null;

    final existing = MaintenanceRecord.fromMap(Map<String, dynamic>.from(recordData));
    final completedAt = DateTime.now();
    final actualMinutes = completedAt.difference(existing.startedAt).inMinutes;

    final completed = existing.copyWith(
      completedAt: completedAt,
      checklistResults: checklistResults,
      notes: notes,
      partsUsed: partsUsed,
      actualMinutes: actualMinutes,
      passed: passed,
    );

    await _recordsBox?.put(recordId, completed.toMap());
    await SyncService.push('maintenanceRecordsBox', recordId, completed.toMap());

    // Update the schedule
    await _updateScheduleAfterCompletion(existing.scheduleId);

    await AuditService.logUpdate(
      entityType: 'MaintenanceRecord',
      entityId: recordId,
      beforeValue: {'completedAt': null},
      afterValue: {
        'completedAt': completedAt.toIso8601String(),
        'passed': passed,
        'actualMinutes': actualMinutes,
      },
    );

    LogService.info('Maintenance completed: ${existing.scheduleName} (${actualMinutes}min)');
    return completed;
  }

  /// Update schedule after maintenance completion
  static Future<void> _updateScheduleAfterCompletion(String scheduleId) async {
    final data = _schedulesBox?.get(scheduleId) as Map?;
    if (data == null) return;

    final schedule = MaintenanceSchedule.fromMap(Map<String, dynamic>.from(data));
    final now = DateTime.now();
    final nextDue = _calculateNextDue(schedule.frequency, schedule.frequencyValue, now);

    final updated = schedule.copyWith(
      lastCompleted: now,
      nextDue: nextDue,
      completionCount: schedule.completionCount + 1,
      status: ScheduleStatus.active,
    );

    await _schedulesBox?.put(scheduleId, updated.toMap());
    await SyncService.push('maintenanceSchedulesBox', scheduleId, updated.toMap());
  }

  // ============ MAINTENANCE HISTORY ============

  /// Get maintenance history for a schedule
  static List<MaintenanceRecord> getScheduleHistory(String scheduleId) {
    final data = _recordsBox?.values.cast<Map>().toList() ?? [];
    return data
        .map((d) => MaintenanceRecord.fromMap(Map<String, dynamic>.from(d)))
        .where((r) => r.scheduleId == scheduleId)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  /// Get maintenance history for a machine
  static List<MaintenanceRecord> getMachineHistory(String machineId) {
    final data = _recordsBox?.values.cast<Map>().toList() ?? [];
    return data
        .map((d) => MaintenanceRecord.fromMap(Map<String, dynamic>.from(d)))
        .where((r) => r.machineId == machineId)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  /// Get maintenance history for a mould
  static List<MaintenanceRecord> getMouldHistory(String mouldId) {
    final data = _recordsBox?.values.cast<Map>().toList() ?? [];
    return data
        .map((d) => MaintenanceRecord.fromMap(Map<String, dynamic>.from(d)))
        .where((r) => r.mouldId == mouldId)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  /// Get all maintenance records
  static List<MaintenanceRecord> getAllRecords({DateTime? since}) {
    final data = _recordsBox?.values.cast<Map>().toList() ?? [];
    return data
        .map((d) => MaintenanceRecord.fromMap(Map<String, dynamic>.from(d)))
        .where((r) => since == null || r.startedAt.isAfter(since))
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  // ============ AUTO-TASK CREATION ============

  /// Check for overdue schedules and create tasks
  static Future<void> _checkOverdueSchedules() async {
    final overdue = getOverdueSchedules();

    for (final schedule in overdue) {
      // Check if a task already exists for this schedule
      final existingTasks = TaskService.getTasksByEntity(
        'MaintenanceSchedule',
        schedule.id,
      );

      final hasOpenTask = existingTasks.any((t) =>
          t.status != TaskStatus.completed && t.status != TaskStatus.cancelled);

      if (!hasOpenTask) {
        await _createMaintenanceTask(schedule);
      }
    }
  }

  /// Create a task for a maintenance schedule
  static Future<void> _createMaintenanceTask(MaintenanceSchedule schedule) async {
    String title = 'PM: ${schedule.name}';
    String description = schedule.description;

    if (schedule.machineId != null) {
      final machine = _machinesBox?.get(schedule.machineId) as Map?;
      if (machine != null) {
        title = 'PM: ${schedule.name} - ${machine['name']}';
      }
    }

    if (schedule.mouldId != null) {
      final mould = _mouldsBox?.get(schedule.mouldId) as Map?;
      if (mould != null) {
        title = 'PM: ${schedule.name} - ${mould['name']}';
      }
    }

    await TaskService.createTask(
      title: title,
      description: description,
      priority: schedule.isOverdue ? TaskPriority.high : TaskPriority.medium,
      dueDate: schedule.nextDue ?? DateTime.now(),
      entityType: 'MaintenanceSchedule',
      entityId: schedule.id,
      createdBy: 'System',
    );

    // Update schedule status to overdue
    final updated = schedule.copyWith(status: ScheduleStatus.overdue);
    await _schedulesBox?.put(schedule.id, updated.toMap());

    LogService.warning('Auto-created maintenance task: $title');
  }

  /// Run scheduled check (call periodically)
  static Future<void> runScheduledCheck() async {
    await _checkOverdueSchedules();
  }

  // ============ HELPER METHODS ============

  /// Calculate next due date based on frequency
  static DateTime _calculateNextDue(
    MaintenanceFrequency frequency,
    int value,
    DateTime? lastCompleted,
  ) {
    final base = lastCompleted ?? DateTime.now();

    switch (frequency) {
      case MaintenanceFrequency.daily:
        return base.add(Duration(days: value));
      case MaintenanceFrequency.weekly:
        return base.add(Duration(days: 7 * value));
      case MaintenanceFrequency.biweekly:
        return base.add(Duration(days: 14 * value));
      case MaintenanceFrequency.monthly:
        return DateTime(base.year, base.month + value, base.day);
      case MaintenanceFrequency.quarterly:
        return DateTime(base.year, base.month + (3 * value), base.day);
      case MaintenanceFrequency.biannual:
        return DateTime(base.year, base.month + (6 * value), base.day);
      case MaintenanceFrequency.annual:
        return DateTime(base.year + value, base.month, base.day);
      case MaintenanceFrequency.cycles:
      case MaintenanceFrequency.hours:
        // For cycle/hour based, return a far future date
        // Actual triggering is based on counter values
        return DateTime(2100);
    }
  }

  /// Get frequency display text
  static String getFrequencyText(MaintenanceFrequency frequency, int value) {
    switch (frequency) {
      case MaintenanceFrequency.daily:
        return value == 1 ? 'Daily' : 'Every $value days';
      case MaintenanceFrequency.weekly:
        return value == 1 ? 'Weekly' : 'Every $value weeks';
      case MaintenanceFrequency.biweekly:
        return 'Every 2 weeks';
      case MaintenanceFrequency.monthly:
        return value == 1 ? 'Monthly' : 'Every $value months';
      case MaintenanceFrequency.quarterly:
        return 'Quarterly';
      case MaintenanceFrequency.biannual:
        return 'Every 6 months';
      case MaintenanceFrequency.annual:
        return value == 1 ? 'Annually' : 'Every $value years';
      case MaintenanceFrequency.cycles:
        return 'Every $value cycles';
      case MaintenanceFrequency.hours:
        return 'Every $value hours';
    }
  }

  /// Get maintenance statistics
  static Map<String, dynamic> getStatistics({DateTime? since}) {
    final records = getAllRecords(since: since);
    final schedules = getAllSchedules();

    final completed = records.where((r) => r.isComplete).length;
    final passed = records.where((r) => r.passed).length;
    final totalMinutes = records.fold<int>(0, (sum, r) => sum + r.actualMinutes);
    final overdue = schedules.where((s) => s.isOverdue).length;
    final upcoming = getUpcomingSchedules(days: 7).length;

    return {
      'totalSchedules': schedules.length,
      'activeSchedules': schedules.where((s) => s.status == ScheduleStatus.active).length,
      'overdueSchedules': overdue,
      'upcomingSchedules': upcoming,
      'completedRecords': completed,
      'passRate': completed > 0 ? (passed / completed * 100).toStringAsFixed(1) : '0',
      'totalMaintenanceMinutes': totalMinutes,
      'averageMinutes': completed > 0 ? (totalMinutes / completed).round() : 0,
    };
  }
}
