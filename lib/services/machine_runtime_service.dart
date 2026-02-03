/// ProMould Machine Runtime Service
/// Manages machine status, downtime tracking, and OEE calculations

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import 'audit_service.dart';
import 'log_service.dart';
import 'sync_service.dart';

/// Machine operational status
enum MachineStatus {
  running,
  idle,
  down,
  maintenance,
  setup,
  unknown,
}

/// Downtime category for classification
enum DowntimeCategory {
  mechanical,
  electrical,
  material,
  mouldChange,
  setup,
  quality,
  planned,
  other,
}

/// Machine runtime snapshot
class MachineRuntime {
  final String machineId;
  final String machineName;
  final MachineStatus status;
  final DateTime? statusSince;
  final String? currentJobId;
  final String? currentMouldId;
  final int cycleCount;
  final double? lastCycleTime;
  final double? targetCycleTime;
  final double oee;
  final double availability;
  final double performance;
  final double quality;

  MachineRuntime({
    required this.machineId,
    required this.machineName,
    required this.status,
    this.statusSince,
    this.currentJobId,
    this.currentMouldId,
    this.cycleCount = 0,
    this.lastCycleTime,
    this.targetCycleTime,
    this.oee = 0.0,
    this.availability = 0.0,
    this.performance = 0.0,
    this.quality = 0.0,
  });

  Map<String, dynamic> toMap() => {
        'machineId': machineId,
        'machineName': machineName,
        'status': status.name,
        'statusSince': statusSince?.toIso8601String(),
        'currentJobId': currentJobId,
        'currentMouldId': currentMouldId,
        'cycleCount': cycleCount,
        'lastCycleTime': lastCycleTime,
        'targetCycleTime': targetCycleTime,
        'oee': oee,
        'availability': availability,
        'performance': performance,
        'quality': quality,
      };

  factory MachineRuntime.fromMap(Map<String, dynamic> map) {
    return MachineRuntime(
      machineId: map['machineId'] ?? '',
      machineName: map['machineName'] ?? '',
      status: MachineStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => MachineStatus.unknown,
      ),
      statusSince: map['statusSince'] != null
          ? DateTime.tryParse(map['statusSince'])
          : null,
      currentJobId: map['currentJobId'],
      currentMouldId: map['currentMouldId'],
      cycleCount: map['cycleCount'] ?? 0,
      lastCycleTime: map['lastCycleTime']?.toDouble(),
      targetCycleTime: map['targetCycleTime']?.toDouble(),
      oee: (map['oee'] ?? 0.0).toDouble(),
      availability: (map['availability'] ?? 0.0).toDouble(),
      performance: (map['performance'] ?? 0.0).toDouble(),
      quality: (map['quality'] ?? 0.0).toDouble(),
    );
  }
}

/// Downtime event record
class DowntimeEvent {
  final String id;
  final String machineId;
  final DowntimeCategory category;
  final String reason;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationMinutes;
  final String? photoUrl;
  final String? reportedBy;
  final String? resolvedBy;
  final bool isPlanned;

  DowntimeEvent({
    required this.id,
    required this.machineId,
    required this.category,
    required this.reason,
    required this.startTime,
    this.endTime,
    this.durationMinutes = 0,
    this.photoUrl,
    this.reportedBy,
    this.resolvedBy,
    this.isPlanned = false,
  });

  bool get isActive => endTime == null;

  int get actualDuration {
    if (endTime != null) {
      return endTime!.difference(startTime).inMinutes;
    }
    return DateTime.now().difference(startTime).inMinutes;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'machineId': machineId,
        'category': category.name,
        'reason': reason,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'durationMinutes': durationMinutes,
        'photoUrl': photoUrl,
        'reportedBy': reportedBy,
        'resolvedBy': resolvedBy,
        'isPlanned': isPlanned,
      };

  factory DowntimeEvent.fromMap(Map<String, dynamic> map) {
    return DowntimeEvent(
      id: map['id'] ?? '',
      machineId: map['machineId'] ?? '',
      category: DowntimeCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => DowntimeCategory.other,
      ),
      reason: map['reason'] ?? '',
      startTime:
          DateTime.tryParse(map['startTime'] ?? '') ?? DateTime.now(),
      endTime: map['endTime'] != null ? DateTime.tryParse(map['endTime']) : null,
      durationMinutes: map['durationMinutes'] ?? 0,
      photoUrl: map['photoUrl'],
      reportedBy: map['reportedBy'],
      resolvedBy: map['resolvedBy'],
      isPlanned: map['isPlanned'] ?? false,
    );
  }

  DowntimeEvent copyWith({
    String? id,
    String? machineId,
    DowntimeCategory? category,
    String? reason,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    String? photoUrl,
    String? reportedBy,
    String? resolvedBy,
    bool? isPlanned,
  }) {
    return DowntimeEvent(
      id: id ?? this.id,
      machineId: machineId ?? this.machineId,
      category: category ?? this.category,
      reason: reason ?? this.reason,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      photoUrl: photoUrl ?? this.photoUrl,
      reportedBy: reportedBy ?? this.reportedBy,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      isPlanned: isPlanned ?? this.isPlanned,
    );
  }
}

/// OEE calculation result
class OEEResult {
  final double oee;
  final double availability;
  final double performance;
  final double quality;
  final int plannedMinutes;
  final int actualRunMinutes;
  final int downtimeMinutes;
  final int totalParts;
  final int goodParts;
  final int scrapParts;
  final double targetCycleTime;
  final double actualCycleTime;

  OEEResult({
    required this.oee,
    required this.availability,
    required this.performance,
    required this.quality,
    required this.plannedMinutes,
    required this.actualRunMinutes,
    required this.downtimeMinutes,
    required this.totalParts,
    required this.goodParts,
    required this.scrapParts,
    required this.targetCycleTime,
    required this.actualCycleTime,
  });

  Map<String, dynamic> toMap() => {
        'oee': oee,
        'availability': availability,
        'performance': performance,
        'quality': quality,
        'plannedMinutes': plannedMinutes,
        'actualRunMinutes': actualRunMinutes,
        'downtimeMinutes': downtimeMinutes,
        'totalParts': totalParts,
        'goodParts': goodParts,
        'scrapParts': scrapParts,
        'targetCycleTime': targetCycleTime,
        'actualCycleTime': actualCycleTime,
      };
}

/// Machine Runtime Service
class MachineRuntimeService {
  static const _uuid = Uuid();
  static Box? _machinesBox;
  static Box? _runtimeBox;
  static Box? _downtimeBox;
  static Box? _inputsBox;

  /// Initialize the service
  static Future<void> initialize() async {
    _machinesBox = Hive.isBoxOpen(HiveBoxes.machines)
        ? Hive.box(HiveBoxes.machines)
        : await Hive.openBox(HiveBoxes.machines);

    _runtimeBox = Hive.isBoxOpen('machineRuntimeBox')
        ? Hive.box('machineRuntimeBox')
        : await Hive.openBox('machineRuntimeBox');

    _downtimeBox = Hive.isBoxOpen(HiveBoxes.downtime)
        ? Hive.box(HiveBoxes.downtime)
        : await Hive.openBox(HiveBoxes.downtime);

    _inputsBox = Hive.isBoxOpen(HiveBoxes.inputs)
        ? Hive.box(HiveBoxes.inputs)
        : await Hive.openBox(HiveBoxes.inputs);

    LogService.info('MachineRuntimeService initialized');
  }

  // ============ MACHINE STATUS ============

  /// Get current runtime status for a machine
  static MachineRuntime? getMachineRuntime(String machineId) {
    final data = _runtimeBox?.get(machineId) as Map?;
    if (data == null) return null;
    return MachineRuntime.fromMap(Map<String, dynamic>.from(data));
  }

  /// Get runtime status for all machines
  static List<MachineRuntime> getAllMachineRuntimes() {
    final machines = _machinesBox?.values.cast<Map>().toList() ?? [];
    return machines.map((m) {
      final machineId = m['id'] as String;
      final runtime = getMachineRuntime(machineId);
      if (runtime != null) return runtime;

      // Return default runtime if none exists
      return MachineRuntime(
        machineId: machineId,
        machineName: m['name'] as String? ?? 'Unknown',
        status: MachineStatus.unknown,
      );
    }).toList();
  }

  /// Update machine status
  static Future<MachineRuntime> updateMachineStatus({
    required String machineId,
    required MachineStatus status,
    String? jobId,
    String? mouldId,
    String? updatedBy,
  }) async {
    final machine = _machinesBox?.get(machineId) as Map?;
    final machineName = machine?['name'] as String? ?? 'Unknown';

    final existing = getMachineRuntime(machineId);
    final previousStatus = existing?.status ?? MachineStatus.unknown;

    final runtime = MachineRuntime(
      machineId: machineId,
      machineName: machineName,
      status: status,
      statusSince: DateTime.now(),
      currentJobId: jobId ?? existing?.currentJobId,
      currentMouldId: mouldId ?? existing?.currentMouldId,
      cycleCount: existing?.cycleCount ?? 0,
      lastCycleTime: existing?.lastCycleTime,
      targetCycleTime: existing?.targetCycleTime,
    );

    await _runtimeBox?.put(machineId, runtime.toMap());
    await SyncService.push('machineRuntimeBox', machineId, runtime.toMap());

    // Audit the status change
    await AuditService.logStatusChange(
      entityType: 'MachineRuntime',
      entityId: machineId,
      previousStatus: previousStatus.name,
      newStatus: status.name,
      changedBy: updatedBy,
    );

    LogService.info('Machine $machineId status changed: ${previousStatus.name} -> ${status.name}');
    return runtime;
  }

  /// Record a cycle completion
  static Future<void> recordCycle({
    required String machineId,
    required double cycleTime,
    int goodParts = 1,
    int scrapParts = 0,
  }) async {
    final existing = getMachineRuntime(machineId);
    if (existing == null) return;

    final updated = MachineRuntime(
      machineId: existing.machineId,
      machineName: existing.machineName,
      status: existing.status,
      statusSince: existing.statusSince,
      currentJobId: existing.currentJobId,
      currentMouldId: existing.currentMouldId,
      cycleCount: existing.cycleCount + 1,
      lastCycleTime: cycleTime,
      targetCycleTime: existing.targetCycleTime,
    );

    await _runtimeBox?.put(machineId, updated.toMap());
  }

  // ============ DOWNTIME MANAGEMENT ============

  /// Start a downtime event
  static Future<DowntimeEvent> startDowntime({
    required String machineId,
    required DowntimeCategory category,
    required String reason,
    String? reportedBy,
    String? photoUrl,
    bool isPlanned = false,
  }) async {
    final event = DowntimeEvent(
      id: _uuid.v4(),
      machineId: machineId,
      category: category,
      reason: reason,
      startTime: DateTime.now(),
      reportedBy: reportedBy,
      photoUrl: photoUrl,
      isPlanned: isPlanned,
    );

    await _downtimeBox?.put(event.id, event.toMap());
    await SyncService.push(HiveBoxes.downtime, event.id, event.toMap());

    // Update machine status to down
    await updateMachineStatus(
      machineId: machineId,
      status: isPlanned ? MachineStatus.maintenance : MachineStatus.down,
      updatedBy: reportedBy,
    );

    await AuditService.logCreate(
      entityType: 'DowntimeEvent',
      entityId: event.id,
      createdValue: event.toMap(),
    );

    LogService.info('Downtime started for machine $machineId: ${category.name} - $reason');
    return event;
  }

  /// End a downtime event
  static Future<DowntimeEvent?> endDowntime({
    required String downtimeId,
    String? resolvedBy,
  }) async {
    final data = _downtimeBox?.get(downtimeId) as Map?;
    if (data == null) return null;

    final event = DowntimeEvent.fromMap(Map<String, dynamic>.from(data));
    final endTime = DateTime.now();
    final duration = endTime.difference(event.startTime).inMinutes;

    final updated = event.copyWith(
      endTime: endTime,
      durationMinutes: duration,
      resolvedBy: resolvedBy,
    );

    await _downtimeBox?.put(downtimeId, updated.toMap());
    await SyncService.push(HiveBoxes.downtime, downtimeId, updated.toMap());

    // Update machine status back to idle
    await updateMachineStatus(
      machineId: event.machineId,
      status: MachineStatus.idle,
      updatedBy: resolvedBy,
    );

    await AuditService.logUpdate(
      entityType: 'DowntimeEvent',
      entityId: downtimeId,
      beforeValue: {'endTime': null, 'durationMinutes': 0},
      afterValue: {'endTime': endTime.toIso8601String(), 'durationMinutes': duration},
    );

    LogService.info('Downtime ended for machine ${event.machineId}: $duration minutes');
    return updated;
  }

  /// Get active downtime events
  static List<DowntimeEvent> getActiveDowntimes() {
    final events = _downtimeBox?.values.cast<Map>().toList() ?? [];
    return events
        .map((e) => DowntimeEvent.fromMap(Map<String, dynamic>.from(e)))
        .where((e) => e.isActive)
        .toList();
  }

  /// Get downtime events for a machine
  static List<DowntimeEvent> getMachineDowntimes(String machineId, {DateTime? since}) {
    final events = _downtimeBox?.values.cast<Map>().toList() ?? [];
    return events
        .map((e) => DowntimeEvent.fromMap(Map<String, dynamic>.from(e)))
        .where((e) => e.machineId == machineId)
        .where((e) => since == null || e.startTime.isAfter(since))
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// Get all downtime events within a time range
  static List<DowntimeEvent> getDowntimeEvents({
    DateTime? since,
    DateTime? until,
    String? machineId,
    DowntimeCategory? category,
  }) {
    final events = _downtimeBox?.values.cast<Map>().toList() ?? [];
    return events
        .map((e) => DowntimeEvent.fromMap(Map<String, dynamic>.from(e)))
        .where((e) => machineId == null || e.machineId == machineId)
        .where((e) => category == null || e.category == category)
        .where((e) => since == null || e.startTime.isAfter(since))
        .where((e) => until == null || e.startTime.isBefore(until))
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  // ============ OEE CALCULATIONS ============

  /// Calculate OEE for a machine over a time period
  static OEEResult calculateOEE({
    required String machineId,
    required DateTime startTime,
    required DateTime endTime,
    double? targetCycleTime,
  }) {
    final plannedMinutes = endTime.difference(startTime).inMinutes;

    // Get downtime for the period
    final downtimes = getMachineDowntimes(machineId, since: startTime)
        .where((d) => d.startTime.isBefore(endTime))
        .toList();

    int downtimeMinutes = 0;
    for (final d in downtimes) {
      final effectiveStart = d.startTime.isBefore(startTime) ? startTime : d.startTime;
      final effectiveEnd = d.endTime == null
          ? endTime
          : (d.endTime!.isAfter(endTime) ? endTime : d.endTime!);
      downtimeMinutes += effectiveEnd.difference(effectiveStart).inMinutes;
    }

    final actualRunMinutes = (plannedMinutes - downtimeMinutes).clamp(0, plannedMinutes);

    // Get production data for the period
    final inputs = _inputsBox?.values.cast<Map>().toList() ?? [];
    final machineInputs = inputs.where((i) {
      final inputDate = DateTime.tryParse(i['date']?.toString() ?? '');
      return i['machineId'] == machineId &&
          inputDate != null &&
          inputDate.isAfter(startTime) &&
          inputDate.isBefore(endTime);
    }).toList();

    final goodParts = machineInputs.fold<int>(0, (sum, i) => sum + (i['shots'] as int? ?? 0));
    final scrapParts = machineInputs.fold<int>(0, (sum, i) => sum + (i['scrap'] as int? ?? 0));
    final totalParts = goodParts + scrapParts;

    // Calculate metrics
    final availability = plannedMinutes > 0 ? actualRunMinutes / plannedMinutes : 0.0;

    // Get target cycle time from machine or mould
    final machine = _machinesBox?.get(machineId) as Map?;
    final effectiveTargetCycle = targetCycleTime ?? (machine?['cycleTime'] as num?)?.toDouble() ?? 30.0;

    // Calculate ideal output based on run time and target cycle
    final idealOutput = actualRunMinutes > 0 ? (actualRunMinutes * 60) / effectiveTargetCycle : 0.0;
    final performance = idealOutput > 0 ? (totalParts / idealOutput).clamp(0.0, 1.0) : 0.0;

    final quality = totalParts > 0 ? goodParts / totalParts : 0.0;

    final oee = (availability * performance * quality).clamp(0.0, 1.0);

    // Calculate actual cycle time
    final actualCycleTime = totalParts > 0 ? (actualRunMinutes * 60) / totalParts : 0.0;

    return OEEResult(
      oee: oee,
      availability: availability,
      performance: performance,
      quality: quality,
      plannedMinutes: plannedMinutes,
      actualRunMinutes: actualRunMinutes,
      downtimeMinutes: downtimeMinutes,
      totalParts: totalParts,
      goodParts: goodParts,
      scrapParts: scrapParts,
      targetCycleTime: effectiveTargetCycle,
      actualCycleTime: actualCycleTime,
    );
  }

  /// Calculate OEE for current shift
  static OEEResult calculateShiftOEE(String machineId) {
    // Assume 8-hour shift starting at 6:00 or 14:00 or 22:00
    final now = DateTime.now();
    final hour = now.hour;

    DateTime shiftStart;
    if (hour >= 6 && hour < 14) {
      shiftStart = DateTime(now.year, now.month, now.day, 6);
    } else if (hour >= 14 && hour < 22) {
      shiftStart = DateTime(now.year, now.month, now.day, 14);
    } else {
      // Night shift
      if (hour >= 22) {
        shiftStart = DateTime(now.year, now.month, now.day, 22);
      } else {
        shiftStart = DateTime(now.year, now.month, now.day - 1, 22);
      }
    }

    return calculateOEE(
      machineId: machineId,
      startTime: shiftStart,
      endTime: now,
    );
  }

  // ============ DASHBOARD DATA ============

  /// Get shift dashboard data for all machines
  static Map<String, dynamic> getShiftDashboard() {
    final runtimes = getAllMachineRuntimes();

    int running = 0;
    int idle = 0;
    int down = 0;
    int maintenance = 0;

    for (final r in runtimes) {
      switch (r.status) {
        case MachineStatus.running:
          running++;
          break;
        case MachineStatus.idle:
          idle++;
          break;
        case MachineStatus.down:
          down++;
          break;
        case MachineStatus.maintenance:
        case MachineStatus.setup:
          maintenance++;
          break;
        default:
          idle++;
      }
    }

    final activeDowntimes = getActiveDowntimes();

    return {
      'totalMachines': runtimes.length,
      'running': running,
      'idle': idle,
      'down': down,
      'maintenance': maintenance,
      'activeDowntimes': activeDowntimes.length,
      'runtimes': runtimes.map((r) => r.toMap()).toList(),
    };
  }

  /// Get downtime summary by category
  static Map<DowntimeCategory, int> getDowntimeSummary({
    DateTime? since,
    String? machineId,
  }) {
    final events = getDowntimeEvents(since: since, machineId: machineId);
    final summary = <DowntimeCategory, int>{};

    for (final category in DowntimeCategory.values) {
      summary[category] = 0;
    }

    for (final event in events) {
      summary[event.category] = (summary[event.category] ?? 0) + event.actualDuration;
    }

    return summary;
  }
}
