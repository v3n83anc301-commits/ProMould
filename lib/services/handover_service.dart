/// ProMould Shift Handover Service
/// Manages shift handovers with immutable snapshots

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/shift_handover_model.dart';
import '../models/shift_model.dart';
import 'log_service.dart';
import 'sync_service.dart';
import 'audit_service.dart';
import 'shift_service.dart';

class HandoverService {
  static const _uuid = Uuid();
  static Box? _handoversBox;
  static Box? _machinesBox;
  static Box? _jobsBox;
  static Box? _issuesBox;
  static Box? _tasksBox;
  static Box? _qualityHoldsBox;
  static Box? _materialsBox;
  static Box? _mouldsBox;
  static Box? _inputsBox;
  static Box? _scrapBox;
  static Box? _downtimeBox;

  /// Initialize the handover service
  static Future<void> initialize() async {
    _handoversBox = await Hive.openBox(HiveBoxes.handovers);
    _machinesBox = await Hive.openBox(HiveBoxes.machines);
    _jobsBox = await Hive.openBox(HiveBoxes.jobs);
    _issuesBox = await Hive.openBox(HiveBoxes.issues);
    _tasksBox = await Hive.openBox(HiveBoxes.tasks);
    _qualityHoldsBox = await Hive.openBox(HiveBoxes.qualityHolds);
    _materialsBox = await Hive.openBox(HiveBoxes.materials);
    _mouldsBox = await Hive.openBox(HiveBoxes.moulds);
    _inputsBox = await Hive.openBox(HiveBoxes.inputs);
    _scrapBox = await Hive.openBox(HiveBoxes.scrap);
    _downtimeBox = await Hive.openBox(HiveBoxes.downtime);
    LogService.info('HandoverService initialized');
  }

  // ============ HANDOVER CRUD ============

  /// Get all handovers
  static List<ShiftHandover> getAllHandovers() {
    if (_handoversBox == null) return [];

    return _handoversBox!.values
        .map((map) => ShiftHandover.fromMap(Map<String, dynamic>.from(map)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get handover by ID
  static ShiftHandover? getHandover(String id) {
    if (_handoversBox == null) return null;

    final map = _handoversBox!.get(id);
    if (map == null) return null;

    return ShiftHandover.fromMap(Map<String, dynamic>.from(map));
  }

  /// Get handovers for a date
  static List<ShiftHandover> getHandoversForDate(DateTime date) {
    return getAllHandovers().where((h) {
      return h.handoverDate.year == date.year &&
          h.handoverDate.month == date.month &&
          h.handoverDate.day == date.day;
    }).toList();
  }

  /// Get handovers for a shift
  static List<ShiftHandover> getHandoversForShift(String shiftId) {
    return getAllHandovers().where((h) => h.shiftId == shiftId).toList();
  }

  /// Get pending handovers
  static List<ShiftHandover> getPendingHandovers() {
    return getAllHandovers().where((h) => h.isPending || h.isInProgress).toList();
  }

  /// Get latest handover for current shift
  static ShiftHandover? getLatestHandoverForCurrentShift() {
    final currentShift = ShiftService.getCurrentShift();
    if (currentShift == null) return null;

    final today = DateTime.now();
    final handovers = getHandoversForDate(today)
        .where((h) => h.shiftId == currentShift.id)
        .toList();

    if (handovers.isEmpty) return null;
    return handovers.first;
  }

  // ============ HANDOVER WORKFLOW ============

  /// Initiate a new handover
  static Future<ShiftHandover> initiateHandover({
    required String outgoingUserId,
    required String outgoingUserName,
  }) async {
    final currentShift = ShiftService.getCurrentShift();
    if (currentShift == null) {
      throw StateError('Cannot initiate handover - no active shift');
    }

    final handover = ShiftHandover(
      id: _uuid.v4(),
      shiftId: currentShift.id,
      handoverDate: DateTime.now(),
      outgoingUserId: outgoingUserId,
      outgoingUserName: outgoingUserName,
      createdAt: DateTime.now(),
    );

    await _handoversBox?.put(handover.id, handover.toMap());
    await SyncService.push(HiveBoxes.handovers, handover.id, handover.toMap());

    await AuditService.logCreate(
      entityType: 'ShiftHandover',
      entityId: handover.id,
      data: {
        'shiftId': currentShift.id,
        'outgoingUser': outgoingUserName,
      },
    );

    LogService.info('Handover initiated by $outgoingUserName');
    return handover;
  }

  /// Start the handover (capture snapshot)
  static Future<ShiftHandover?> startHandover(String handoverId) async {
    final handover = getHandover(handoverId);
    if (handover == null) return null;

    // Capture immutable snapshot
    final snapshot = await _captureSnapshot();

    final started = handover.start(snapshot);
    await _handoversBox?.put(handoverId, started.toMap());
    await SyncService.push(HiveBoxes.handovers, handoverId, started.toMap());

    await AuditService.logStatusChange(
      entityType: 'ShiftHandover',
      entityId: handoverId,
      fromStatus: handover.status.name,
      toStatus: started.status.name,
    );

    LogService.info('Handover started with snapshot: $handoverId');
    return started;
  }

  /// Outgoing user signs off
  static Future<ShiftHandover?> signOffOutgoing(String handoverId) async {
    final handover = getHandover(handoverId);
    if (handover == null) return null;

    final signedOff = handover.signOffOutgoing();
    await _handoversBox?.put(handoverId, signedOff.toMap());
    await SyncService.push(HiveBoxes.handovers, handoverId, signedOff.toMap());

    await AuditService.logUpdate(
      entityType: 'ShiftHandover',
      entityId: handoverId,
      beforeValue: {'outgoingSignOff': false},
      afterValue: {'outgoingSignOff': true},
    );

    LogService.info('Outgoing user signed off: $handoverId');
    return signedOff;
  }

  /// Incoming user acknowledges
  static Future<ShiftHandover?> acknowledgeIncoming(
    String handoverId,
    String userId,
    String userName,
  ) async {
    final handover = getHandover(handoverId);
    if (handover == null) return null;

    final acknowledged = handover.acknowledgeIncoming(userId, userName);
    await _handoversBox?.put(handoverId, acknowledged.toMap());
    await SyncService.push(HiveBoxes.handovers, handoverId, acknowledged.toMap());

    await AuditService.logUpdate(
      entityType: 'ShiftHandover',
      entityId: handoverId,
      beforeValue: {'incomingAcknowledgment': false},
      afterValue: {
        'incomingAcknowledgment': true,
        'incomingUser': userName,
      },
    );

    LogService.info('Incoming user acknowledged: $handoverId by $userName');
    return acknowledged;
  }

  /// Add notes to handover
  static Future<ShiftHandover?> addNotes(
    String handoverId, {
    String? notes,
    String? safetyNotes,
    String? specialInstructions,
  }) async {
    final handover = getHandover(handoverId);
    if (handover == null) return null;

    final updated = handover.copyWith(
      notes: notes ?? handover.notes,
      safetyNotes: safetyNotes ?? handover.safetyNotes,
      specialInstructions: specialInstructions ?? handover.specialInstructions,
    );

    await _handoversBox?.put(handoverId, updated.toMap());
    await SyncService.push(HiveBoxes.handovers, handoverId, updated.toMap());

    LogService.info('Handover notes updated: $handoverId');
    return updated;
  }

  /// Skip handover (with audit)
  static Future<ShiftHandover?> skipHandover(
    String handoverId,
    String reason,
  ) async {
    final handover = getHandover(handoverId);
    if (handover == null) return null;

    final skipped = handover.skip();
    await _handoversBox?.put(handoverId, skipped.toMap());
    await SyncService.push(HiveBoxes.handovers, handoverId, skipped.toMap());

    await AuditService.logOverride(
      entityType: 'ShiftHandover',
      entityId: handoverId,
      beforeValue: {'status': handover.status.name},
      afterValue: {'status': skipped.status.name},
      reason: reason,
    );

    LogService.warning('Handover skipped: $handoverId - $reason');
    return skipped;
  }

  // ============ PUBLIC API FOR UI ============

  /// Public method to capture snapshot for preview
  static Future<HandoverSnapshot> captureSnapshot() async {
    return _captureSnapshot();
  }

  /// Public method to create a handover with snapshot
  static Future<ShiftHandover> createHandover({
    required String shiftId,
    required String outgoingUserId,
    required String outgoingUserName,
    String? notes,
    String? safetyNotes,
    String? specialInstructions,
  }) async {
    // Initiate the handover
    final handover = await initiateHandover(
      shiftId: shiftId,
      outgoingUserId: outgoingUserId,
      outgoingUserName: outgoingUserName,
    );

    // Start it (capture snapshot)
    final started = await startHandover(handover.id);
    if (started == null) {
      throw Exception('Failed to start handover');
    }

    // Add notes if provided
    if (notes != null || safetyNotes != null || specialInstructions != null) {
      final updated = started.copyWith(
        notes: notes,
        safetyNotes: safetyNotes,
        specialInstructions: specialInstructions,
      );
      await _handoversBox?.put(started.id, updated.toMap());
      await SyncService.push(HiveBoxes.handovers, started.id, updated.toMap());
      return updated;
    }

    return started;
  }

  /// Public method to acknowledge handover
  static Future<ShiftHandover?> acknowledgeHandover({
    required String handoverId,
    required String userId,
    required String userName,
  }) async {
    return acknowledgeIncoming(handoverId, userId, userName);
  }

  // ============ SNAPSHOT CAPTURE ============

  /// Capture immutable snapshot of current factory state
  static Future<HandoverSnapshot> _captureSnapshot() async {
    final machines = await _captureMachineSnapshots();
    final jobs = await _captureJobSnapshots();
    final issues = await _captureIssueSnapshots();
    final tasks = await _captureTaskSnapshots();
    final qualityHolds = await _captureQualityHoldSnapshots();
    final materials = await _captureMaterialSnapshots();
    final maintenance = await _captureMaintenanceSnapshots();
    final production = await _captureProductionSummary();

    return HandoverSnapshot(
      capturedAt: DateTime.now(),
      machines: machines,
      jobs: jobs,
      openIssues: issues,
      pendingTasks: tasks,
      qualityHolds: qualityHolds,
      materialStatus: materials,
      maintenanceStatus: maintenance,
      productionSummary: production,
    );
  }

  /// Capture machine snapshots
  static Future<List<MachineSnapshot>> _captureMachineSnapshots() async {
    if (_machinesBox == null) return [];

    final snapshots = <MachineSnapshot>[];

    for (final map in _machinesBox!.values) {
      final machine = Map<String, dynamic>.from(map);
      final machineId = machine['id'] as String;

      // Get current job for this machine
      String? currentJobNumber;
      String? currentMouldNumber;
      int? partsProduced;
      double? scrapRate;

      if (_jobsBox != null) {
        for (final jobMap in _jobsBox!.values) {
          final job = Map<String, dynamic>.from(jobMap);
          if (job['machineId'] == machineId && job['status'] == 'running') {
            currentJobNumber = job['jobNumber'] as String?;

            // Get mould info
            if (_mouldsBox != null && job['mouldId'] != null) {
              final mouldMap = _mouldsBox!.get(job['mouldId']);
              if (mouldMap != null) {
                currentMouldNumber =
                    (Map<String, dynamic>.from(mouldMap))['mouldNumber'] as String?;
              }
            }

            // Calculate parts produced (simplified)
            partsProduced = job['quantityProduced'] as int? ?? 0;
            break;
          }
        }
      }

      snapshots.add(MachineSnapshot(
        machineId: machineId,
        machineName: machine['name'] as String? ?? 'Unknown',
        status: machine['status'] as String? ?? 'idle',
        currentJobNumber: currentJobNumber,
        currentMouldNumber: currentMouldNumber,
        partsProduced: partsProduced,
        scrapRate: scrapRate,
      ));
    }

    return snapshots;
  }

  /// Capture job snapshots
  static Future<List<JobSnapshot>> _captureJobSnapshots() async {
    if (_jobsBox == null) return [];

    final snapshots = <JobSnapshot>[];

    for (final map in _jobsBox!.values) {
      final job = Map<String, dynamic>.from(map);
      final status = job['status'] as String? ?? 'pending';

      // Only include active jobs
      if (status == 'running' || status == 'queued' || status == 'paused') {
        final quantityRequired = job['quantityRequired'] as int? ?? 0;
        final quantityProduced = job['quantityProduced'] as int? ?? 0;
        final progress =
            quantityRequired > 0 ? (quantityProduced / quantityRequired) * 100 : 0.0;

        snapshots.add(JobSnapshot(
          jobId: job['id'] as String,
          jobNumber: job['jobNumber'] as String? ?? 'Unknown',
          status: status,
          quantityRequired: quantityRequired,
          quantityProduced: quantityProduced,
          progressPercentage: progress,
        ));
      }
    }

    return snapshots;
  }

  /// Capture issue snapshots
  static Future<List<IssueSnapshot>> _captureIssueSnapshots() async {
    if (_issuesBox == null) return [];

    final snapshots = <IssueSnapshot>[];

    for (final map in _issuesBox!.values) {
      final issue = Map<String, dynamic>.from(map);
      final status = issue['status'] as String? ?? 'open';

      // Only include open issues
      if (status == 'open' || status == 'inProgress') {
        String? machineName;
        if (_machinesBox != null && issue['machineId'] != null) {
          final machineMap = _machinesBox!.get(issue['machineId']);
          if (machineMap != null) {
            machineName =
                (Map<String, dynamic>.from(machineMap))['name'] as String?;
          }
        }

        snapshots.add(IssueSnapshot(
          issueId: issue['id'] as String,
          title: issue['title'] as String? ?? 'Unknown Issue',
          severity: issue['severity'] as String? ?? 'medium',
          machineName: machineName,
        ));
      }
    }

    return snapshots;
  }

  /// Capture task snapshots
  static Future<List<TaskSnapshot>> _captureTaskSnapshots() async {
    if (_tasksBox == null) return [];

    final snapshots = <TaskSnapshot>[];

    for (final map in _tasksBox!.values) {
      final task = Map<String, dynamic>.from(map);
      final status = task['status'] as String? ?? 'pending';

      // Only include open tasks
      if (status == 'pending' ||
          status == 'assigned' ||
          status == 'inProgress' ||
          status == 'blocked') {
        final dueAt = task['dueAt'] as String?;
        final isOverdue = dueAt != null && DateTime.parse(dueAt).isBefore(DateTime.now());

        snapshots.add(TaskSnapshot(
          taskId: task['id'] as String,
          title: task['title'] as String? ?? 'Unknown Task',
          priority: task['priority'] as String? ?? 'medium',
          assigneeName: task['assigneeName'] as String?,
          isOverdue: isOverdue,
        ));
      }
    }

    return snapshots;
  }

  /// Capture quality hold snapshots
  static Future<List<QualityHoldSnapshot>> _captureQualityHoldSnapshots() async {
    if (_qualityHoldsBox == null) return [];

    final snapshots = <QualityHoldSnapshot>[];

    for (final map in _qualityHoldsBox!.values) {
      final hold = Map<String, dynamic>.from(map);
      final status = hold['status'] as String? ?? 'active';

      // Only include active holds
      if (status == 'active') {
        snapshots.add(QualityHoldSnapshot(
          holdId: hold['id'] as String,
          jobNumber: hold['jobNumber'] as String? ?? 'Unknown',
          reason: hold['reason'] as String? ?? 'Unknown',
          quantity: hold['quantity'] as int? ?? 0,
          severity: hold['severity'] as String? ?? 'medium',
        ));
      }
    }

    return snapshots;
  }

  /// Capture material snapshots
  static Future<List<MaterialSnapshot>> _captureMaterialSnapshots() async {
    if (_materialsBox == null) return [];

    final snapshots = <MaterialSnapshot>[];

    for (final map in _materialsBox!.values) {
      final material = Map<String, dynamic>.from(map);
      final currentStock = (material['currentStock'] as num?)?.toDouble() ?? 0;
      final reorderPoint = (material['reorderPoint'] as num?)?.toDouble() ?? 0;

      snapshots.add(MaterialSnapshot(
        materialId: material['id'] as String,
        materialName: material['name'] as String? ?? 'Unknown',
        currentStock: currentStock,
        isLow: currentStock <= reorderPoint,
      ));
    }

    return snapshots;
  }

  /// Capture maintenance snapshots
  static Future<List<MaintenanceSnapshot>> _captureMaintenanceSnapshots() async {
    if (_mouldsBox == null) return [];

    final snapshots = <MaintenanceSnapshot>[];

    for (final map in _mouldsBox!.values) {
      final mould = Map<String, dynamic>.from(map);
      final shotsSinceMaintenance =
          mould['shotsSinceLastMaintenance'] as int? ?? 0;
      final maintenanceInterval = mould['maintenanceIntervalShots'] as int? ?? 50000;
      final isDue = shotsSinceMaintenance >= maintenanceInterval;

      snapshots.add(MaintenanceSnapshot(
        mouldId: mould['id'] as String,
        mouldNumber: mould['mouldNumber'] as String? ?? 'Unknown',
        isDue: isDue,
        shotsSinceMaintenance: shotsSinceMaintenance,
      ));
    }

    return snapshots;
  }

  /// Capture production summary for current shift
  static Future<ProductionSummary> _captureProductionSummary() async {
    final currentShift = ShiftService.getCurrentShift();
    if (currentShift == null) {
      return const ProductionSummary(
        totalParts: 0,
        totalScrap: 0,
        scrapRate: 0,
        downtimeMinutes: 0,
        jobsCompleted: 0,
        issuesReported: 0,
      );
    }

    final shiftStart = currentShift.getStartDateTime(DateTime.now());

    // Count production from inputs
    int totalParts = 0;
    if (_inputsBox != null) {
      for (final map in _inputsBox!.values) {
        final input = Map<String, dynamic>.from(map);
        final timestamp = input['timestamp'] as String?;
        if (timestamp != null && DateTime.parse(timestamp).isAfter(shiftStart)) {
          totalParts += (input['quantity'] as int? ?? 0);
        }
      }
    }

    // Count scrap
    int totalScrap = 0;
    if (_scrapBox != null) {
      for (final map in _scrapBox!.values) {
        final scrap = Map<String, dynamic>.from(map);
        final timestamp = scrap['timestamp'] as String?;
        if (timestamp != null && DateTime.parse(timestamp).isAfter(shiftStart)) {
          totalScrap += (scrap['quantity'] as int? ?? 0);
        }
      }
    }

    // Calculate scrap rate
    final scrapRate =
        totalParts > 0 ? (totalScrap / (totalParts + totalScrap)) * 100 : 0.0;

    // Count downtime
    int downtimeMinutes = 0;
    if (_downtimeBox != null) {
      for (final map in _downtimeBox!.values) {
        final downtime = Map<String, dynamic>.from(map);
        final startTime = downtime['startTime'] as String?;
        if (startTime != null && DateTime.parse(startTime).isAfter(shiftStart)) {
          downtimeMinutes += (downtime['durationMinutes'] as int? ?? 0);
        }
      }
    }

    // Count completed jobs
    int jobsCompleted = 0;
    if (_jobsBox != null) {
      for (final map in _jobsBox!.values) {
        final job = Map<String, dynamic>.from(map);
        final completedAt = job['completedAt'] as String?;
        if (completedAt != null &&
            DateTime.parse(completedAt).isAfter(shiftStart)) {
          jobsCompleted++;
        }
      }
    }

    // Count issues reported
    int issuesReported = 0;
    if (_issuesBox != null) {
      for (final map in _issuesBox!.values) {
        final issue = Map<String, dynamic>.from(map);
        final createdAt = issue['createdAt'] as String?;
        if (createdAt != null && DateTime.parse(createdAt).isAfter(shiftStart)) {
          issuesReported++;
        }
      }
    }

    return ProductionSummary(
      totalParts: totalParts,
      totalScrap: totalScrap,
      scrapRate: scrapRate,
      downtimeMinutes: downtimeMinutes,
      jobsCompleted: jobsCompleted,
      issuesReported: issuesReported,
    );
  }

  // ============ HANDOVER COMPARISON ============

  /// Compare two handovers
  static HandoverComparison? compareHandovers(
    String handoverId1,
    String handoverId2,
  ) {
    final h1 = getHandover(handoverId1);
    final h2 = getHandover(handoverId2);

    if (h1?.snapshot == null || h2?.snapshot == null) return null;

    final s1 = h1!.snapshot!;
    final s2 = h2!.snapshot!;

    return HandoverComparison(
      handover1: h1,
      handover2: h2,
      partsDifference:
          s2.productionSummary.totalParts - s1.productionSummary.totalParts,
      scrapDifference:
          s2.productionSummary.totalScrap - s1.productionSummary.totalScrap,
      downtimeDifference: s2.productionSummary.downtimeMinutes -
          s1.productionSummary.downtimeMinutes,
      jobsCompletedDifference: s2.productionSummary.jobsCompleted -
          s1.productionSummary.jobsCompleted,
    );
  }
}

/// Handover comparison result
class HandoverComparison {
  final ShiftHandover handover1;
  final ShiftHandover handover2;
  final int partsDifference;
  final int scrapDifference;
  final int downtimeDifference;
  final int jobsCompletedDifference;

  HandoverComparison({
    required this.handover1,
    required this.handover2,
    required this.partsDifference,
    required this.scrapDifference,
    required this.downtimeDifference,
    required this.jobsCompletedDifference,
  });
}
