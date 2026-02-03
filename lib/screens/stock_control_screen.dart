/// ProMould Stock Control Screen
/// Spare parts inventory management for Material Handlers

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/spare_parts_service.dart';
import '../services/rbac_service.dart';
import '../config/permissions.dart';

class StockControlScreen extends StatefulWidget {
  final String username;
  final int level;

  const StockControlScreen({
    super.key,
    required this.username,
    required this.level,
  });

  @override
  State<StockControlScreen> createState() => _StockControlScreenState();
}

class _StockControlScreenState extends State<StockControlScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SparePart> _parts = [];
  List<PartRequest> _pendingRequests = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _parts = SparePartsService.getAllParts();
      _pendingRequests = SparePartsService.getPendingRequests();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('Stock Control'),
        backgroundColor: const Color(0xFF0F1419),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4CC9F0),
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: 'Inventory'),
            Tab(icon: Icon(Icons.add_box), text: 'Receive'),
            Tab(icon: Icon(Icons.outbox), text: 'Issue'),
            Tab(icon: Icon(Icons.pending_actions), text: 'Requests'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _InventoryTab(
                  parts: _parts,
                  searchQuery: _searchQuery,
                  onSearchChanged: (q) => setState(() => _searchQuery = q),
                  onRefresh: _loadData,
                ),
                _ReceiveTab(
                  parts: _parts,
                  username: widget.username,
                  onRefresh: _loadData,
                ),
                _IssueTab(
                  parts: _parts,
                  username: widget.username,
                  onRefresh: _loadData,
                ),
                _RequestsTab(
                  requests: _pendingRequests,
                  parts: _parts,
                  username: widget.username,
                  onRefresh: _loadData,
                ),
              ],
            ),
    );
  }
}

// ============ INVENTORY TAB ============

class _InventoryTab extends StatelessWidget {
  final List<SparePart> parts;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;

  const _InventoryTab({
    required this.parts,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final filteredParts = parts.where((p) {
      if (searchQuery.isEmpty) return true;
      final query = searchQuery.toLowerCase();
      return p.name.toLowerCase().contains(query) ||
          p.partNumber.toLowerCase().contains(query) ||
          p.category.name.toLowerCase().contains(query);
    }).toList();

    final lowStock = filteredParts.where((p) => p.needsReorder).toList();
    final stats = SparePartsService.getStatistics();

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: CustomScrollView(
        slivers: [
          // Stats cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total Parts',
                          value: '${stats['totalParts']}',
                          icon: Icons.inventory_2,
                          color: const Color(0xFF4CC9F0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Low Stock',
                          value: '${stats['lowStockParts']}',
                          icon: Icons.warning,
                          color: lowStock.isNotEmpty ? Colors.orange : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Stock Value',
                          value: '\$${stats['totalStockValue']}',
                          icon: Icons.attach_money,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Pending Requests',
                          value: '${stats['pendingRequests']}',
                          icon: Icons.pending,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search parts...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFF1A1F2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

          // Low stock alert
          if (lowStock.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${lowStock.length} part${lowStock.length > 1 ? 's' : ''} below reorder level',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Parts list
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final part = filteredParts[index];
                  return _PartCard(part: part);
                },
                childCount: filteredParts.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1F2E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartCard extends StatelessWidget {
  final SparePart part;

  const _PartCard({required this.part});

  Color _getCategoryColor() {
    switch (part.category) {
      case PartCategory.heater:
        return Colors.red;
      case PartCategory.thermocouple:
        return Colors.orange;
      case PartCategory.sensor:
        return Colors.blue;
      case PartCategory.valve:
        return Colors.purple;
      case PartCategory.fitting:
        return Colors.teal;
      case PartCategory.seal:
        return Colors.green;
      case PartCategory.lubricant:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLow = part.needsReorder;
    final categoryColor = _getCategoryColor();

    return Card(
      color: const Color(0xFF1A1F2E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.settings, color: categoryColor),
        ),
        title: Text(
          part.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${part.partNumber} • ${part.category.name.toUpperCase()}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (part.location != null)
              Text(
                'Location: ${part.location}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${part.currentQty.toInt()}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isLow ? Colors.orange : const Color(0xFF4CC9F0),
              ),
            ),
            Text(
              part.unit,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            if (isLow)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LOW',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============ RECEIVE TAB ============

class _ReceiveTab extends StatefulWidget {
  final List<SparePart> parts;
  final String username;
  final VoidCallback onRefresh;

  const _ReceiveTab({
    required this.parts,
    required this.username,
    required this.onRefresh,
  });

  @override
  State<_ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends State<_ReceiveTab> {
  String? _selectedPartId;
  final _qtyController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _receiveStock() async {
    if (_selectedPartId == null || _qtyController.text.isEmpty) return;

    final qty = double.tryParse(_qtyController.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SparePartsService.receiveStock(
        partId: _selectedPartId!,
        quantity: qty,
        reference: _referenceController.text.isNotEmpty
            ? _referenceController.text
            : null,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        performedBy: widget.username,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock received successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _qtyController.clear();
        _referenceController.clear();
        _notesController.clear();
        setState(() => _selectedPartId = null);
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canReceive = RBACService.hasPermission(Permission.stockControlReceive);

    if (!canReceive) {
      return const Center(
        child: Text(
          'You do not have permission to receive stock',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: const Color(0xFF1A1F2E),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Receive Stock',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPartId,
                decoration: const InputDecoration(
                  labelText: 'Select Part',
                  border: OutlineInputBorder(),
                ),
                items: widget.parts
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.partNumber} - ${p.name}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPartId = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Reference (PO#, Invoice#)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _receiveStock,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_box),
                  label: const Text('Receive Stock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ ISSUE TAB ============

class _IssueTab extends StatefulWidget {
  final List<SparePart> parts;
  final String username;
  final VoidCallback onRefresh;

  const _IssueTab({
    required this.parts,
    required this.username,
    required this.onRefresh,
  });

  @override
  State<_IssueTab> createState() => _IssueTabState();
}

class _IssueTabState extends State<_IssueTab> {
  String? _selectedPartId;
  final _qtyController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _issueStock() async {
    if (_selectedPartId == null || _qtyController.text.isEmpty) return;

    final qty = double.tryParse(_qtyController.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SparePartsService.issueStock(
        partId: _selectedPartId!,
        quantity: qty,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        performedBy: widget.username,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock issued successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _qtyController.clear();
        _notesController.clear();
        setState(() => _selectedPartId = null);
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canIssue = RBACService.hasPermission(Permission.stockControlIssue);

    if (!canIssue) {
      return const Center(
        child: Text(
          'You do not have permission to issue stock',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: const Color(0xFF1A1F2E),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Issue Stock',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPartId,
                decoration: const InputDecoration(
                  labelText: 'Select Part',
                  border: OutlineInputBorder(),
                ),
                items: widget.parts
                    .where((p) => p.currentQty > 0)
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                              '${p.partNumber} - ${p.name} (${p.currentQty.toInt()} ${p.unit})'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPartId = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason / Notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _issueStock,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.outbox),
                  label: const Text('Issue Stock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B6B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ REQUESTS TAB ============

class _RequestsTab extends StatelessWidget {
  final List<PartRequest> requests;
  final List<SparePart> parts;
  final String username;
  final VoidCallback onRefresh;

  const _RequestsTab({
    required this.requests,
    required this.parts,
    required this.onRefresh,
  });

  SparePart? _getPart(String partId) {
    try {
      return parts.firstWhere((p) => p.id == partId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _fulfillRequest(BuildContext context, PartRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fulfill Request'),
        content: Text('Issue ${request.quantity} units to fulfill this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Fulfill'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SparePartsService.fulfillRequest(
          requestId: request.id,
          processedBy: username,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request fulfilled'),
              backgroundColor: Colors.green,
            ),
          );
          onRefresh();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green.shade400),
            const SizedBox(height: 16),
            const Text(
              'No pending requests',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          final part = _getPart(request.partId);

          return Card(
            color: const Color(0xFF1A1F2E),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          part?.name ?? 'Unknown Part',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Qty: ${request.quantity.toInt()}',
                          style: const TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    request.reason,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(
                        request.requestedBy,
                        style:
                            const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.access_time,
                          size: 14, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, HH:mm').format(request.requestedAt),
                        style:
                            const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _fulfillRequest(context, request),
                      icon: const Icon(Icons.check),
                      label: const Text('Fulfill Request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
