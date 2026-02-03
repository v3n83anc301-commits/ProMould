/// ProMould Quality Control Service
/// Manages inspections, holds, SPC data, and quality trends

import 'dart:math';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import 'audit_service.dart';
import 'log_service.dart';
import 'sync_service.dart';

/// Inspection type
enum InspectionType {
  firstArticle,
  inProcess,
  final_,
  receiving,
  periodic,
}

/// Inspection result
enum InspectionResult {
  pass,
  fail,
  conditional,
  pending,
}

/// Hold status
enum HoldStatus {
  active,
  released,
  scrapped,
  reworked,
}

/// Reject reason category
enum RejectCategory {
  dimensional,
  visual,
  functional,
  material,
  contamination,
  packaging,
  documentation,
  other,
}

/// Quality inspection record
class QualityInspection {
  final String id;
  final InspectionType type;
  final String? jobId;
  final String? machineId;
  final String? mouldId;
  final String? partNumber;
  final int sampleSize;
  final int passCount;
  final int failCount;
  final InspectionResult result;
  final List<InspectionMeasurement> measurements;
  final List<String> defectsFound;
  final String? notes;
  final String inspectedBy;
  final DateTime inspectedAt;
  final String? approvedBy;
  final DateTime? approvedAt;

  QualityInspection({
    required this.id,
    required this.type,
    this.jobId,
    this.machineId,
    this.mouldId,
    this.partNumber,
    required this.sampleSize,
    required this.passCount,
    required this.failCount,
    required this.result,
    this.measurements = const [],
    this.defectsFound = const [],
    this.notes,
    required this.inspectedBy,
    required this.inspectedAt,
    this.approvedBy,
    this.approvedAt,
  });

  double get passRate => sampleSize > 0 ? passCount / sampleSize : 0.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'jobId': jobId,
        'machineId': machineId,
        'mouldId': mouldId,
        'partNumber': partNumber,
        'sampleSize': sampleSize,
        'passCount': passCount,
        'failCount': failCount,
        'result': result.name,
        'measurements': measurements.map((m) => m.toMap()).toList(),
        'defectsFound': defectsFound,
        'notes': notes,
        'inspectedBy': inspectedBy,
        'inspectedAt': inspectedAt.toIso8601String(),
        'approvedBy': approvedBy,
        'approvedAt': approvedAt?.toIso8601String(),
      };

  factory QualityInspection.fromMap(Map<String, dynamic> map) {
    return QualityInspection(
      id: map['id'] ?? '',
      type: InspectionType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => InspectionType.inProcess,
      ),
      jobId: map['jobId'],
      machineId: map['machineId'],
      mouldId: map['mouldId'],
      partNumber: map['partNumber'],
      sampleSize: map['sampleSize'] ?? 0,
      passCount: map['passCount'] ?? 0,
      failCount: map['failCount'] ?? 0,
      result: InspectionResult.values.firstWhere(
        (r) => r.name == map['result'],
        orElse: () => InspectionResult.pending,
      ),
      measurements: (map['measurements'] as List?)
              ?.map((m) => InspectionMeasurement.fromMap(Map<String, dynamic>.from(m)))
              .toList() ??
          [],
      defectsFound: List<String>.from(map['defectsFound'] ?? []),
      notes: map['notes'],
      inspectedBy: map['inspectedBy'] ?? '',
      inspectedAt: DateTime.tryParse(map['inspectedAt'] ?? '') ?? DateTime.now(),
      approvedBy: map['approvedBy'],
      approvedAt: map['approvedAt'] != null
          ? DateTime.tryParse(map['approvedAt'])
          : null,
    );
  }
}

/// Individual measurement in an inspection
class InspectionMeasurement {
  final String characteristic;
  final double nominal;
  final double tolerance;
  final double actual;
  final String unit;
  final bool inSpec;

  InspectionMeasurement({
    required this.characteristic,
    required this.nominal,
    required this.tolerance,
    required this.actual,
    this.unit = 'mm',
    required this.inSpec,
  });

  double get deviation => actual - nominal;
  double get deviationPercent => nominal != 0 ? (deviation / nominal * 100) : 0;

  Map<String, dynamic> toMap() => {
        'characteristic': characteristic,
        'nominal': nominal,
        'tolerance': tolerance,
        'actual': actual,
        'unit': unit,
        'inSpec': inSpec,
      };

  factory InspectionMeasurement.fromMap(Map<String, dynamic> map) {
    return InspectionMeasurement(
      characteristic: map['characteristic'] ?? '',
      nominal: (map['nominal'] ?? 0).toDouble(),
      tolerance: (map['tolerance'] ?? 0).toDouble(),
      actual: (map['actual'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'mm',
      inSpec: map['inSpec'] ?? false,
    );
  }
}

/// Quality hold record
class QualityHold {
  final String id;
  final String? jobId;
  final String? machineId;
  final String? mouldId;
  final String? partNumber;
  final int quantity;
  final RejectCategory category;
  final String reason;
  final String? location;
  final HoldStatus status;
  final String createdBy;
  final DateTime createdAt;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolution;
  final String? dispositionNotes;

  QualityHold({
    required this.id,
    this.jobId,
    this.machineId,
    this.mouldId,
    this.partNumber,
    required this.quantity,
    required this.category,
    required this.reason,
    this.location,
    this.status = HoldStatus.active,
    required this.createdBy,
    required this.createdAt,
    this.resolvedBy,
    this.resolvedAt,
    this.resolution,
    this.dispositionNotes,
  });

  bool get isActive => status == HoldStatus.active;

  Map<String, dynamic> toMap() => {
        'id': id,
        'jobId': jobId,
        'machineId': machineId,
        'mouldId': mouldId,
        'partNumber': partNumber,
        'quantity': quantity,
        'category': category.name,
        'reason': reason,
        'location': location,
        'status': status.name,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'resolvedBy': resolvedBy,
        'resolvedAt': resolvedAt?.toIso8601String(),
        'resolution': resolution,
        'dispositionNotes': dispositionNotes,
      };

  factory QualityHold.fromMap(Map<String, dynamic> map) {
    return QualityHold(
      id: map['id'] ?? '',
      jobId: map['jobId'],
      machineId: map['machineId'],
      mouldId: map['mouldId'],
      partNumber: map['partNumber'],
      quantity: map['quantity'] ?? 0,
      category: RejectCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => RejectCategory.other,
      ),
      reason: map['reason'] ?? '',
      location: map['location'],
      status: HoldStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => HoldStatus.active,
      ),
      createdBy: map['createdBy'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      resolvedBy: map['resolvedBy'],
      resolvedAt: map['resolvedAt'] != null
          ? DateTime.tryParse(map['resolvedAt'])
          : null,
      resolution: map['resolution'],
      dispositionNotes: map['dispositionNotes'],
    );
  }
}

/// SPC data point
class SPCDataPoint {
  final String id;
  final String characteristic;
  final String? machineId;
  final String? mouldId;
  final double value;
  final DateTime timestamp;
  final String? operator;

  SPCDataPoint({
    required this.id,
    required this.characteristic,
    this.machineId,
    this.mouldId,
    required this.value,
    required this.timestamp,
    this.operator,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'characteristic': characteristic,
        'machineId': machineId,
        'mouldId': mouldId,
        'value': value,
        'timestamp': timestamp.toIso8601String(),
        'operator': operator,
      };

  factory SPCDataPoint.fromMap(Map<String, dynamic> map) {
    return SPCDataPoint(
      id: map['id'] ?? '',
      characteristic: map['characteristic'] ?? '',
      machineId: map['machineId'],
      mouldId: map['mouldId'],
      value: (map['value'] ?? 0).toDouble(),
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      operator: map['operator'],
    );
  }
}

/// SPC chart data with control limits
class SPCChartData {
  final String characteristic;
  final List<SPCDataPoint> dataPoints;
  final double mean;
  final double stdDev;
  final double ucl; // Upper Control Limit
  final double lcl; // Lower Control Limit
  final double usl; // Upper Spec Limit
  final double lsl; // Lower Spec Limit
  final double cpk;
  final bool inControl;

  SPCChartData({
    required this.characteristic,
    required this.dataPoints,
    required this.mean,
    required this.stdDev,
    required this.ucl,
    required this.lcl,
    required this.usl,
    required this.lsl,
    required this.cpk,
    required this.inControl,
  });
}

/// Quality Control Service
class QualityControlService {
  static const _uuid = Uuid();
  static Box? _inspectionsBox;
  static Box? _holdsBox;
  static Box? _spcBox;

  /// Initialize the service
  static Future<void> initialize() async {
    _inspectionsBox = Hive.isBoxOpen('qualityInspectionsBox')
        ? Hive.box('qualityInspectionsBox')
        : await Hive.openBox('qualityInspectionsBox');

    _holdsBox = Hive.isBoxOpen('qualityHoldsBox')
        ? Hive.box('qualityHoldsBox')
        : await Hive.openBox('qualityHoldsBox');

    _spcBox = Hive.isBoxOpen('spcDataBox')
        ? Hive.box('spcDataBox')
        : await Hive.openBox('spcDataBox');

    LogService.info('QualityControlService initialized');
  }

  // ============ INSPECTIONS ============

  /// Create a new inspection
  static Future<QualityInspection> createInspection({
    required InspectionType type,
    String? jobId,
    String? machineId,
    String? mouldId,
    String? partNumber,
    required int sampleSize,
    required int passCount,
    required int failCount,
    List<InspectionMeasurement> measurements = const [],
    List<String> defectsFound = const [],
    String? notes,
    required String inspectedBy,
  }) async {
    final result = _determineResult(passCount, failCount, sampleSize);

    final inspection = QualityInspection(
      id: _uuid.v4(),
      type: type,
      jobId: jobId,
      machineId: machineId,
      mouldId: mouldId,
      partNumber: partNumber,
      sampleSize: sampleSize,
      passCount: passCount,
      failCount: failCount,
      result: result,
      measurements: measurements,
      defectsFound: defectsFound,
      notes: notes,
      inspectedBy: inspectedBy,
      inspectedAt: DateTime.now(),
    );

    await _inspectionsBox?.put(inspection.id, inspection.toMap());
    await SyncService.push('qualityInspectionsBox', inspection.id, inspection.toMap());

    await AuditService.logCreate(
      entityType: 'QualityInspection',
      entityId: inspection.id,
      createdValue: inspection.toMap(),
    );

    // Record SPC data from measurements
    for (final m in measurements) {
      await recordSPCData(
        characteristic: m.characteristic,
        value: m.actual,
        machineId: machineId,
        mouldId: mouldId,
        operator: inspectedBy,
      );
    }

    LogService.info('Inspection created: ${type.name} - ${result.name}');
    return inspection;
  }

  /// Get all inspections
  static List<QualityInspection> getAllInspections({
    DateTime? since,
    InspectionType? type,
    InspectionResult? result,
  }) {
    final data = _inspectionsBox?.values.cast<Map>().toList() ?? [];
    return data
        .map((d) => QualityInspection.fromMap(Map<String, dynamic>.from(d)))
        .where((i) => since == null || i.inspectedAt.isAfter(since))
        .where((i) => type == null || i.type == type)
        .where((i) => result == null || i.result == result)
        .toList()
      ..sort((a, b) => b.inspectedAt.compareTo(a.inspectedAt));
  }

  /// Get inspections for a job
  static List<QualityInspection> getJobInspections(String jobId) {
    return getAllInspections().where((i) => i.jobId == jobId).toList();
  }

  /// Get first article inspection for a job
  static QualityInspection? getFirstArticleInspection(String jobId) {
    final inspections = getJobInspections(jobId)
        .where((i) => i.type == InspectionType.firstArticle)
        .toList();
    return inspections.isNotEmpty ? inspections.first : null;
  }

  /// Determine inspection result
  static InspectionResult _determineResult(int pass, int fail, int total) {
    if (total == 0) return InspectionResult.pending;
    final passRate = pass / total;
    if (passRate >= 1.0) return InspectionResult.pass;
    if (passRate >= 0.95) return InspectionResult.conditional;
    return InspectionResult.fail;
  }

  // ============ QUALITY HOLDS ============

  /// Create a quality hold
  static Future<QualityHold> createHold({
    String? jobId,
    String? machineId,
    String? mouldId,
    String? partNumber,
    required int quantity,
    required RejectCategory category,
    required String reason,
    String? location,
    required String createdBy,
  }) async {
    final hold = QualityHold(
      id: _uuid.v4(),
      jobId: jobId,
      machineId: machineId,
      mouldId: mouldId,
      partNumber: partNumber,
      quantity: quantity,
      category: category,
      reason: reason,
      location: location,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );

    await _holdsBox?.put(hold.id, hold.toMap());
    await SyncService.push('qualityHoldsBox', hold.id, hold.toMap());

    await AuditService.logCreate(
      entityType: 'QualityHold',
      entityId: hold.id,
      createdValue: hold.toMap(),
    );

    LogService.warning('Quality hold created: ${category.name} - $quantity units');
    return hold;
  }

  /// Get all holds
  static List<QualityHold> getAllHolds({HoldStatus? status}) {
    final data = _holdsBox?.values.cast<Map>().toList() ?? [];
    return data
        .map((d) => QualityHold.fromMap(Map<String, dynamic>.from(d)))
        .where((h) => status == null || h.status == status)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get active holds
  static List<QualityHold> getActiveHolds() {
    return getAllHolds(status: HoldStatus.active);
  }

  /// Release a hold
  static Future<QualityHold?> releaseHold({
    required String holdId,
    required String resolvedBy,
    String? notes,
  }) async {
    return _resolveHold(
      holdId: holdId,
      status: HoldStatus.released,
      resolvedBy: resolvedBy,
      resolution: 'Released',
      notes: notes,
    );
  }

  /// Scrap a hold
  static Future<QualityHold?> scrapHold({
    required String holdId,
    required String resolvedBy,
    String? notes,
  }) async {
    return _resolveHold(
      holdId: holdId,
      status: HoldStatus.scrapped,
      resolvedBy: resolvedBy,
      resolution: 'Scrapped',
      notes: notes,
    );
  }

  /// Rework a hold
  static Future<QualityHold?> reworkHold({
    required String holdId,
    required String resolvedBy,
    String? notes,
  }) async {
    return _resolveHold(
      holdId: holdId,
      status: HoldStatus.reworked,
      resolvedBy: resolvedBy,
      resolution: 'Reworked',
      notes: notes,
    );
  }

  /// Resolve a hold
  static Future<QualityHold?> _resolveHold({
    required String holdId,
    required HoldStatus status,
    required String resolvedBy,
    required String resolution,
    String? notes,
  }) async {
    final data = _holdsBox?.get(holdId) as Map?;
    if (data == null) return null;

    final existing = QualityHold.fromMap(Map<String, dynamic>.from(data));
    final resolved = QualityHold(
      id: existing.id,
      jobId: existing.jobId,
      machineId: existing.machineId,
      mouldId: existing.mouldId,
      partNumber: existing.partNumber,
      quantity: existing.quantity,
      category: existing.category,
      reason: existing.reason,
      location: existing.location,
      status: status,
      createdBy: existing.createdBy,
      createdAt: existing.createdAt,
      resolvedBy: resolvedBy,
      resolvedAt: DateTime.now(),
      resolution: resolution,
      dispositionNotes: notes,
    );

    await _holdsBox?.put(holdId, resolved.toMap());
    await SyncService.push('qualityHoldsBox', holdId, resolved.toMap());

    await AuditService.logStatusChange(
      entityType: 'QualityHold',
      entityId: holdId,
      previousStatus: existing.status.name,
      newStatus: status.name,
      changedBy: resolvedBy,
    );

    LogService.info('Quality hold resolved: $holdId - ${status.name}');
    return resolved;
  }

  // ============ SPC DATA ============

  /// Record SPC data point
  static Future<SPCDataPoint> recordSPCData({
    required String characteristic,
    required double value,
    String? machineId,
    String? mouldId,
    String? operator,
  }) async {
    final dataPoint = SPCDataPoint(
      id: _uuid.v4(),
      characteristic: characteristic,
      machineId: machineId,
      mouldId: mouldId,
      value: value,
      timestamp: DateTime.now(),
      operator: operator,
    );

    await _spcBox?.put(dataPoint.id, dataPoint.toMap());
    return dataPoint;
  }

  /// Get SPC data for a characteristic
  static List<SPCDataPoint> getSPCData({
    required String characteristic,
    String? machineId,
    String? mouldId,
    DateTime? since,
    int? limit,
  }) {
    final data = _spcBox?.values.cast<Map>().toList() ?? [];
    var points = data
        .map((d) => SPCDataPoint.fromMap(Map<String, dynamic>.from(d)))
        .where((p) => p.characteristic == characteristic)
        .where((p) => machineId == null || p.machineId == machineId)
        .where((p) => mouldId == null || p.mouldId == mouldId)
        .where((p) => since == null || p.timestamp.isAfter(since))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (limit != null && points.length > limit) {
      points = points.sublist(points.length - limit);
    }

    return points;
  }

  /// Calculate SPC chart data
  static SPCChartData? calculateSPCChart({
    required String characteristic,
    required double usl,
    required double lsl,
    String? machineId,
    String? mouldId,
    int dataPoints = 30,
  }) {
    final data = getSPCData(
      characteristic: characteristic,
      machineId: machineId,
      mouldId: mouldId,
      limit: dataPoints,
    );

    if (data.length < 5) return null;

    final values = data.map((d) => d.value).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;

    // Calculate standard deviation
    final squaredDiffs = values.map((v) => pow(v - mean, 2));
    final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;
    final stdDev = sqrt(variance);

    // Control limits (3-sigma)
    final ucl = mean + (3 * stdDev);
    final lcl = mean - (3 * stdDev);

    // Check if in control
    final outOfControl = values.any((v) => v > ucl || v < lcl);

    // Calculate Cpk
    final cpkUpper = (usl - mean) / (3 * stdDev);
    final cpkLower = (mean - lsl) / (3 * stdDev);
    final cpk = min(cpkUpper, cpkLower);

    return SPCChartData(
      characteristic: characteristic,
      dataPoints: data,
      mean: mean,
      stdDev: stdDev,
      ucl: ucl,
      lcl: lcl,
      usl: usl,
      lsl: lsl,
      cpk: cpk,
      inControl: !outOfControl,
    );
  }

  // ============ QUALITY TRENDS ============

  /// Get reject trends by category
  static Map<RejectCategory, int> getRejectTrends({DateTime? since}) {
    final holds = getAllHolds();
    final filtered = since != null
        ? holds.where((h) => h.createdAt.isAfter(since)).toList()
        : holds;

    final trends = <RejectCategory, int>{};
    for (final category in RejectCategory.values) {
      trends[category] = 0;
    }

    for (final hold in filtered) {
      trends[hold.category] = (trends[hold.category] ?? 0) + hold.quantity;
    }

    return trends;
  }

  /// Get inspection pass rate trend
  static List<Map<String, dynamic>> getPassRateTrend({
    int days = 30,
    String? machineId,
  }) {
    final since = DateTime.now().subtract(Duration(days: days));
    final inspections = getAllInspections(since: since)
        .where((i) => machineId == null || i.machineId == machineId)
        .toList();

    // Group by day
    final byDay = <String, List<QualityInspection>>{};
    for (final i in inspections) {
      final day = '${i.inspectedAt.year}-${i.inspectedAt.month.toString().padLeft(2, '0')}-${i.inspectedAt.day.toString().padLeft(2, '0')}';
      byDay.putIfAbsent(day, () => []).add(i);
    }

    return byDay.entries.map((e) {
      final dayInspections = e.value;
      final totalSamples = dayInspections.fold<int>(0, (sum, i) => sum + i.sampleSize);
      final totalPass = dayInspections.fold<int>(0, (sum, i) => sum + i.passCount);
      final passRate = totalSamples > 0 ? totalPass / totalSamples : 0.0;

      return {
        'date': e.key,
        'inspections': dayInspections.length,
        'samples': totalSamples,
        'passRate': passRate,
      };
    }).toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  }

  /// Get quality statistics
  static Map<String, dynamic> getStatistics({DateTime? since}) {
    final inspections = getAllInspections(since: since);
    final holds = getAllHolds();
    final activeHolds = holds.where((h) => h.isActive).toList();

    final totalSamples = inspections.fold<int>(0, (sum, i) => sum + i.sampleSize);
    final totalPass = inspections.fold<int>(0, (sum, i) => sum + i.passCount);
    final totalFail = inspections.fold<int>(0, (sum, i) => sum + i.failCount);
    final passRate = totalSamples > 0 ? totalPass / totalSamples : 0.0;

    final holdQuantity = activeHolds.fold<int>(0, (sum, h) => sum + h.quantity);

    final firstArticles = inspections.where((i) => i.type == InspectionType.firstArticle).toList();
    final faPassRate = firstArticles.isNotEmpty
        ? firstArticles.where((i) => i.result == InspectionResult.pass).length / firstArticles.length
        : 0.0;

    return {
      'totalInspections': inspections.length,
      'totalSamples': totalSamples,
      'totalPass': totalPass,
      'totalFail': totalFail,
      'overallPassRate': (passRate * 100).toStringAsFixed(1),
      'activeHolds': activeHolds.length,
      'holdQuantity': holdQuantity,
      'firstArticlePassRate': (faPassRate * 100).toStringAsFixed(1),
      'rejectTrends': getRejectTrends(since: since),
    };
  }
}
