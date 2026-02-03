/// ProMould Spare Parts & Consumables Inventory (MRO) Service
/// Manages parts catalog, stock levels, transactions, and requests

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import 'audit_service.dart';
import 'log_service.dart';
import 'sync_service.dart';

/// Part category
enum PartCategory {
  heater,
  thermocouple,
  sensor,
  valve,
  fitting,
  seal,
  bearing,
  motor,
  pump,
  filter,
  lubricant,
  spray,
  tool,
  consumable,
  other,
}

/// Transaction type
enum TransactionType {
  receive,
  issue,
  return_,
  adjust,
  transfer,
  scrap,
  cycleCount,
}

/// Request status
enum RequestStatus {
  pending,
  approved,
  rejected,
  fulfilled,
  cancelled,
}

/// Spare part definition
class SparePart {
  final String id;
  final String partNumber;
  final String name;
  final String description;
  final PartCategory category;
  final String unit;
  final double currentQty;
  final double minQty;
  final double maxQty;
  final double reorderQty;
  final String? location;
  final String? binNumber;
  final double unitCost;
  final String? preferredSupplier;
  final List<String> compatibleMachines;
  final List<String> compatibleMoulds;
  final bool isActive;
  final DateTime createdAt;
  final String? createdBy;

  SparePart({
    required this.id,
    required this.partNumber,
    required this.name,
    this.description = '',
    required this.category,
    this.unit = 'EA',
    this.currentQty = 0,
    this.minQty = 0,
    this.maxQty = 100,
    this.reorderQty = 10,
    this.location,
    this.binNumber,
    this.unitCost = 0,
    this.preferredSupplier,
    this.compatibleMachines = const [],
    this.compatibleMoulds = const [],
    this.isActive = true,
    required this.createdAt,
    this.createdBy,
  });

  bool get isBelowMin => currentQty < minQty;
  bool get needsReorder => currentQty <= reorderQty;
  double get stockValue => currentQty * unitCost;

  Map<String, dynamic> toMap() => {
        'id': id,
        'partNumber': partNumber,
        'name': name,
        'description': description,
        'category': category.name,
        'unit': unit,
        'currentQty': currentQty,
        'minQty': minQty,
        'maxQty': maxQty,
        'reorderQty': reorderQty,
        'location': location,
        'binNumber': binNumber,
        'unitCost': unitCost,
        'preferredSupplier': preferredSupplier,
        'compatibleMachines': compatibleMachines,
        'compatibleMoulds': compatibleMoulds,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
      };

  factory SparePart.fromMap(Map<String, dynamic> map) {
    return SparePart(
      id: map['id'] ?? '',
      partNumber: map['partNumber'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: PartCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => PartCategory.other,
      ),
      unit: map['unit'] ?? 'EA',
      currentQty: (map['currentQty'] ?? 0).toDouble(),
      minQty: (map['minQty'] ?? 0).toDouble(),
      maxQty: (map['maxQty'] ?? 100).toDouble(),
      reorderQty: (map['reorderQty'] ?? 10).toDouble(),
      location: map['location'],
      binNumber: map['binNumber'],
      unitCost: (map['unitCost'] ?? 0).toDouble(),
      preferredSupplier: map['preferredSupplier'],
      compatibleMachines: List<String>.from(map['compatibleMachines'] ?? []),
      compatibleMoulds: List<String>.from(map['compatibleMoulds'] ?? []),
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      createdBy: map['createdBy'],
    );
  }

  SparePart copyWith({
    String? partNumber,
    String? name,
    String? description,
    PartCategory? category,
    String? unit,
    double? currentQty,
    double? minQty,
    double? maxQty,
    double? reorderQty,
    String? location,
    String? binNumber,
    double? unitCost,
    String? preferredSupplier,
    List<String>? compatibleMachines,
    List<String>? compatibleMoulds,
    bool? isActive,
  }) {
    return SparePart(
      id: id,
      partNumber: partNumber ?? this.partNumber,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      currentQty: currentQty ?? this.currentQty,
      minQty: minQty ?? this.minQty,
      maxQty: maxQty ?? this.maxQty,
      reorderQty: reorderQty ?? this.reorderQty,
      location: location ?? this.location,
      binNumber: binNumber ?? this.binNumber,
      unitCost: unitCost ?? this.unitCost,
      preferredSupplier: preferredSupplier ?? this.preferredSupplier,
      compatibleMachines: compatibleMachines ?? this.compatibleMachines,
      compatibleMoulds: compatibleMoulds ?? this.compatibleMoulds,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      createdBy: createdBy,
    );
  }
}

/// Stock transaction record
class StockTransaction {
  final String id;
  final String partId;
  final TransactionType type;
  final double quantity;
  final double previousQty;
  final double newQty;
  final String? reference;
  final String? machineId;
  final String? mouldId;
  final String? maintenanceRecordId;
  final String? notes;
  final String performedBy;
  final DateTime performedAt;
  final String? approvedBy;
  final DateTime? approvedAt;

  StockTransaction({
    required this.id,
    required this.partId,
    required this.type,
    required this.quantity,
    required this.previousQty,
    required this.newQty,
    this.reference,
    this.machineId,
    this.mouldId,
    this.maintenanceRecordId,
    this.notes,
    required this.performedBy,
    required this.performedAt,
    this.approvedBy,
    this.approvedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'partId': partId,
        'type': type.name,
        'quantity': quantity,
        'previousQty': previousQty,
        'newQty': newQty,
        'reference': reference,
        'machineId': machineId,
        'mouldId': mouldId,
        'maintenanceRecordId': maintenanceRecordId,
        'notes': notes,
        'performedBy': performedBy,
        'performedAt': performedAt.toIso8601String(),
        'approvedBy': approvedBy,
        'approvedAt': approvedAt?.toIso8601String(),
      };

  factory StockTransaction.fromMap(Map<String, dynamic> map) {
    return StockTransaction(
      id: map['id'] ?? '',
      partId: map['partId'] ?? '',
      type: TransactionType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => TransactionType.adjust,
      ),
      quantity: (map['quantity'] ?? 0).toDouble(),
      previousQty: (map['previousQty'] ?? 0).toDouble(),
      newQty: (map['newQty'] ?? 0).toDouble(),
      reference: map['reference'],
      machineId: map['machineId'],
      mouldId: map['mouldId'],
      maintenanceRecordId: map['maintenanceRecordId'],
      notes: map['notes'],
      performedBy: map['performedBy'] ?? '',
      performedAt: DateTime.tryParse(map['performedAt'] ?? '') ?? DateTime.now(),
      approvedBy: map['approvedBy'],
      approvedAt: map['approvedAt'] != null ? DateTime.tryParse(map['approvedAt']) : null,
    );
  }
}

/// Part request from maintenance
class PartRequest {
  final String id;
  final String partId;
  final double quantity;
  final String? maintenanceRecordId;
  final String? machineId;
  final String reason;
  final RequestStatus status;
  final String requestedBy;
  final DateTime requestedAt;
  final String? processedBy;
  final DateTime? processedAt;
  final String? rejectionReason;

  PartRequest({
    required this.id,
    required this.partId,
    required this.quantity,
    this.maintenanceRecordId,
    this.machineId,
    required this.reason,
    this.status = RequestStatus.pending,
    required this.requestedBy,
    required this.requestedAt,
    this.processedBy,
    this.processedAt,
    this.rejectionReason,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'partId': partId,
        'quantity': quantity,
        'maintenanceRecordId': maintenanceRecordId,
        'machineId': machineId,
        'reason': reason,
        'status': status.name,
        'requestedBy': requestedBy,
        'requestedAt': requestedAt.toIso8601String(),
        'processedBy': processedBy,
        'processedAt': processedAt?.toIso8601String(),
        'rejectionReason': rejectionReason,
      };

  factory PartRequest.fromMap(Map<String, dynamic> map) {
    return PartRequest(
      id: map['id'] ?? '',
      partId: map['partId'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      maintenanceRecordId: map['maintenanceRecordId'],
      machineId: map['machineId'],
      reason: map['reason'] ?? '',
      status: RequestStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => RequestStatus.pending,
      ),
      requestedBy: map['requestedBy'] ?? '',
      requestedAt: DateTime.tryParse(map['requestedAt'] ?? '') ?? DateTime.now(),
      processedBy: map['processedBy'],
      processedAt: map['processedAt'] != null ? DateTime.tryParse(map['processedAt']) : null,
      rejectionReason: map['rejectionReason'],
    );
  }
}

/// Spare Parts Service
class SparePartsService {
  static const _uuid = Uuid();
  static Box? _partsBox;
  static Box? _transactionsBox;
  static Box? _requestsBox;

  static Future<void> initialize() async {
    _partsBox = Hive.isBoxOpen('sparePartsBox')
        ? Hive.box('sparePartsBox')
        : await Hive.openBox('sparePartsBox');
    _transactionsBox = Hive.isBoxOpen('stockTransactionsBox')
        ? Hive.box('stockTransactionsBox')
        : await Hive.openBox('stockTransactionsBox');
    _requestsBox = Hive.isBoxOpen('partRequestsBox')
        ? Hive.box('partRequestsBox')
        : await Hive.openBox('partRequestsBox');
    LogService.info('SparePartsService initialized');
  }

  // ============ PARTS CATALOG ============

  static List<SparePart> getAllParts({bool activeOnly = true}) {
    final data = _partsBox?.values.cast<Map>().toList() ?? [];
    return data
        .map((d) => SparePart.fromMap(Map<String, dynamic>.from(d)))
        .where((p) => !activeOnly || p.isActive)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  static SparePart? getPart(String partId) {
    final data = _partsBox?.get(partId) as Map?;
    return data != null ? SparePart.fromMap(Map<String, dynamic>.from(data)) : null;
  }

  static List<SparePart> getLowStockParts() {
    return getAllParts().where((p) => p.needsReorder).toList();
  }

  static Future<SparePart> createPart({
    required String partNumber,
    required String name,
    String description = '',
    required PartCategory category,
    String unit = 'EA',
    double minQty = 0,
    double maxQty = 100,
    double reorderQty = 10,
    String? location,
    String? binNumber,
    double unitCost = 0,
    String? preferredSupplier,
    List<String> compatibleMachines = const [],
    List<String> compatibleMoulds = const [],
    required String createdBy,
  }) async {
    final part = SparePart(
      id: _uuid.v4(),
      partNumber: partNumber,
      name: name,
      description: description,
      category: category,
      unit: unit,
      minQty: minQty,
      maxQty: maxQty,
      reorderQty: reorderQty,
      location: location,
      binNumber: binNumber,
      unitCost: unitCost,
      preferredSupplier: preferredSupplier,
      compatibleMachines: compatibleMachines,
      compatibleMoulds: compatibleMoulds,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );

    await _partsBox?.put(part.id, part.toMap());
    await SyncService.push('sparePartsBox', part.id, part.toMap());
    await AuditService.logCreate(entityType: 'SparePart', entityId: part.id, newValue: part.toMap());
    LogService.info('Spare part created: ${part.name}');
    return part;
  }

  // ============ STOCK TRANSACTIONS ============

  static Future<StockTransaction> receiveStock({
    required String partId,
    required double quantity,
    String? reference,
    String? notes,
    required String performedBy,
  }) async {
    return _createTransaction(
      partId: partId,
      type: TransactionType.receive,
      quantity: quantity,
      reference: reference,
      notes: notes,
      performedBy: performedBy,
    );
  }

  static Future<StockTransaction> issueStock({
    required String partId,
    required double quantity,
    String? machineId,
    String? mouldId,
    String? maintenanceRecordId,
    String? notes,
    required String performedBy,
  }) async {
    return _createTransaction(
      partId: partId,
      type: TransactionType.issue,
      quantity: -quantity,
      machineId: machineId,
      mouldId: mouldId,
      maintenanceRecordId: maintenanceRecordId,
      notes: notes,
      performedBy: performedBy,
    );
  }

  static Future<StockTransaction> adjustStock({
    required String partId,
    required double newQty,
    required String reason,
    required String performedBy,
    String? approvedBy,
  }) async {
    final part = getPart(partId);
    if (part == null) throw Exception('Part not found');

    final adjustment = newQty - part.currentQty;
    return _createTransaction(
      partId: partId,
      type: TransactionType.adjust,
      quantity: adjustment,
      notes: reason,
      performedBy: performedBy,
      approvedBy: approvedBy,
    );
  }

  static Future<StockTransaction> _createTransaction({
    required String partId,
    required TransactionType type,
    required double quantity,
    String? reference,
    String? machineId,
    String? mouldId,
    String? maintenanceRecordId,
    String? notes,
    required String performedBy,
    String? approvedBy,
  }) async {
    final part = getPart(partId);
    if (part == null) throw Exception('Part not found');

    final previousQty = part.currentQty;
    final newQty = previousQty + quantity;

    if (newQty < 0) throw Exception('Insufficient stock');

    final transaction = StockTransaction(
      id: _uuid.v4(),
      partId: partId,
      type: type,
      quantity: quantity.abs(),
      previousQty: previousQty,
      newQty: newQty,
      reference: reference,
      machineId: machineId,
      mouldId: mouldId,
      maintenanceRecordId: maintenanceRecordId,
      notes: notes,
      performedBy: performedBy,
      performedAt: DateTime.now(),
      approvedBy: approvedBy,
      approvedAt: approvedBy != null ? DateTime.now() : null,
    );

    // Update part quantity
    final updatedPart = part.copyWith(currentQty: newQty);
    await _partsBox?.put(partId, updatedPart.toMap());
    await _transactionsBox?.put(transaction.id, transaction.toMap());
    await SyncService.push('sparePartsBox', partId, updatedPart.toMap());
    await SyncService.push('stockTransactionsBox', transaction.id, transaction.toMap());

    await AuditService.logUpdate(
      entityType: 'SparePart',
      entityId: partId,
      beforeValue: {'currentQty': previousQty},
      afterValue: {'currentQty': newQty, 'transactionType': type.name},
    );

    LogService.info('Stock ${type.name}: ${part.name} qty $previousQty -> $newQty');
    return transaction;
  }

  static List<StockTransaction> getPartTransactions(String partId, {int? limit}) {
    final data = _transactionsBox?.values.cast<Map>().toList() ?? [];
    var transactions = data
        .map((d) => StockTransaction.fromMap(Map<String, dynamic>.from(d)))
        .where((t) => t.partId == partId)
        .toList()
      ..sort((a, b) => b.performedAt.compareTo(a.performedAt));
    if (limit != null) transactions = transactions.take(limit).toList();
    return transactions;
  }

  // ============ PART REQUESTS ============

  static Future<PartRequest> createRequest({
    required String partId,
    required double quantity,
    String? maintenanceRecordId,
    String? machineId,
    required String reason,
    required String requestedBy,
  }) async {
    final request = PartRequest(
      id: _uuid.v4(),
      partId: partId,
      quantity: quantity,
      maintenanceRecordId: maintenanceRecordId,
      machineId: machineId,
      reason: reason,
      requestedBy: requestedBy,
      requestedAt: DateTime.now(),
    );

    await _requestsBox?.put(request.id, request.toMap());
    await SyncService.push('partRequestsBox', request.id, request.toMap());
    await AuditService.logCreate(entityType: 'PartRequest', entityId: request.id, newValue: request.toMap());
    LogService.info('Part request created: $partId qty $quantity');
    return request;
  }

  static List<PartRequest> getPendingRequests() {
    final data = _requestsBox?.values.cast<Map>().toList() ?? [];
    return data
        .map((d) => PartRequest.fromMap(Map<String, dynamic>.from(d)))
        .where((r) => r.status == RequestStatus.pending)
        .toList()
      ..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
  }

  static Future<PartRequest?> fulfillRequest({
    required String requestId,
    required String processedBy,
  }) async {
    final data = _requestsBox?.get(requestId) as Map?;
    if (data == null) return null;

    final request = PartRequest.fromMap(Map<String, dynamic>.from(data));

    // Issue the stock
    await issueStock(
      partId: request.partId,
      quantity: request.quantity,
      machineId: request.machineId,
      maintenanceRecordId: request.maintenanceRecordId,
      notes: 'Fulfilled request: ${request.reason}',
      performedBy: processedBy,
    );

    final fulfilled = PartRequest(
      id: request.id,
      partId: request.partId,
      quantity: request.quantity,
      maintenanceRecordId: request.maintenanceRecordId,
      machineId: request.machineId,
      reason: request.reason,
      status: RequestStatus.fulfilled,
      requestedBy: request.requestedBy,
      requestedAt: request.requestedAt,
      processedBy: processedBy,
      processedAt: DateTime.now(),
    );

    await _requestsBox?.put(requestId, fulfilled.toMap());
    await SyncService.push('partRequestsBox', requestId, fulfilled.toMap());
    LogService.info('Part request fulfilled: $requestId');
    return fulfilled;
  }

  // ============ STATISTICS ============

  static Map<String, dynamic> getStatistics() {
    final parts = getAllParts();
    final lowStock = parts.where((p) => p.needsReorder).length;
    final totalValue = parts.fold<double>(0, (sum, p) => sum + p.stockValue);
    final pendingRequests = getPendingRequests().length;

    return {
      'totalParts': parts.length,
      'lowStockParts': lowStock,
      'totalStockValue': totalValue.toStringAsFixed(2),
      'pendingRequests': pendingRequests,
    };
  }
}
