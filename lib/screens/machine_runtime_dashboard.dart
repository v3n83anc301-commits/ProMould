/// ProMould Machine Runtime Dashboard
/// Real-time machine status, downtime tracking, and OEE monitoring

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/machine_runtime_service.dart';
import '../services/rbac_service.dart';
import '../config/permissions.dart';

class MachineRuntimeDashboard extends StatefulWidget {
  final String username;
  final int level;

  const MachineRuntimeDashboard({
    super.key,
    required this.username,
    required this.level,
  });

  @override
  State<MachineRuntimeDashboard> createState() => _MachineRuntimeDashboardState();
}

class _MachineRuntimeDashboardState extends State<MachineRuntimeDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _refreshTimer;
  Map<String, dynamic> _dashboardData = {};
  List<DowntimeEvent> _activeDowntimes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _dashboardData = MachineRuntimeService.getShiftDashboard();
      _activeDowntimes = MachineRuntimeService.getActiveDowntimes();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('Machine Runtime'),
        backgroundColor: const Color(0xFF0F1419),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4CC9F0),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.warning_amber), text: 'Downtime'),
            Tab(icon: Icon(Icons.analytics), text: 'OEE'),
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
                _OverviewTab(
                  dashboardData: _dashboardData,
                  onRefresh: _loadData,
                ),
                _DowntimeTab(
                  activeDowntimes: _activeDowntimes,
                  onRefresh: _loadData,
                  username: widget.username,
                ),
                _OEETab(
                  runtimes: (_dashboardData['runtimes'] as List?)
                          ?.map((r) => MachineRuntime.fromMap(Map<String, dynamic>.from(r)))
                          .toList() ??
                      [],
                  onRefresh: _loadData,
                ),
              ],
            ),
    );
  }
}

// ============ OVERVIEW TAB ============

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> dashboardData;
  final VoidCallback onRefresh;

  const _OverviewTab({
    required this.dashboardData,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final total = dashboardData['totalMachines'] ?? 0;
    final running = dashboardData['running'] ?? 0;
    final idle = dashboardData['idle'] ?? 0;
    final down = dashboardData['down'] ?? 0;
    final maintenance = dashboardData['maintenance'] ?? 0;
    final activeDowntimes = dashboardData['activeDowntimes'] ?? 0;

    final runtimes = (dashboardData['runtimes'] as List?)
            ?.map((r) => MachineRuntime.fromMap(Map<String, dynamic>.from(r)))
            .toList() ??
        [];

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status summary cards
            Row(
              children: [
                Expanded(
                  child: _StatusCard(
                    title: 'Running',
                    count: running,
                    total: total,
                    color: Colors.green,
                    icon: Icons.play_circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatusCard(
                    title: 'Idle',
                    count: idle,
                    total: total,
                    color: Colors.orange,
                    icon: Icons.pause_circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatusCard(
                    title: 'Down',
                    count: down,
                    total: total,
                    color: Colors.red,
                    icon: Icons.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatusCard(
                    title: 'Maintenance',
                    count: maintenance,
                    total: total,
                    color: Colors.blue,
                    icon: Icons.build,
                  ),
                ),
              ],
            ),

            // Active downtime alert
            if (activeDowntimes > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$activeDowntimes active downtime event${activeDowntimes > 1 ? 's' : ''}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Machine list
            const SizedBox(height: 24),
            const Text(
              'Machine Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...runtimes.map((r) => _MachineStatusCard(runtime: r)),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final int count;
  final int total;
  final Color color;
  final IconData icon;

  const _StatusCard({
    required this.title,
    required this.count,
    required this.total,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';

    return Card(
      color: const Color(0xFF1A1F2E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              '$percentage%',
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _MachineStatusCard extends StatelessWidget {
  final MachineRuntime runtime;

  const _MachineStatusCard({required this.runtime});

  Color _getStatusColor() {
    switch (runtime.status) {
      case MachineStatus.running:
        return Colors.green;
      case MachineStatus.idle:
        return Colors.orange;
      case MachineStatus.down:
        return Colors.red;
      case MachineStatus.maintenance:
      case MachineStatus.setup:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (runtime.status) {
      case MachineStatus.running:
        return Icons.play_circle;
      case MachineStatus.idle:
        return Icons.pause_circle;
      case MachineStatus.down:
        return Icons.error;
      case MachineStatus.maintenance:
        return Icons.build;
      case MachineStatus.setup:
        return Icons.settings;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final statusSince = runtime.statusSince;
    final duration = statusSince != null
        ? DateTime.now().difference(statusSince)
        : Duration.zero;

    return Card(
      color: const Color(0xFF1A1F2E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_getStatusIcon(), color: statusColor),
        ),
        title: Text(
          runtime.machineName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              runtime.status.name.toUpperCase(),
              style: TextStyle(color: statusColor, fontSize: 12),
            ),
            if (statusSince != null)
              Text(
                'Since ${_formatDuration(duration)}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
          ],
        ),
        trailing: runtime.cycleCount > 0
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${runtime.cycleCount}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CC9F0),
                    ),
                  ),
                  const Text(
                    'cycles',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }
}

// ============ DOWNTIME TAB ============

class _DowntimeTab extends StatelessWidget {
  final List<DowntimeEvent> activeDowntimes;
  final VoidCallback onRefresh;
  final String username;

  const _DowntimeTab({
    required this.activeDowntimes,
    required this.onRefresh,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    final canLogDowntime = RBACService.can(Permission.logDowntime);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: activeDowntimes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No active downtime',
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'All machines operational',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: activeDowntimes.length,
              itemBuilder: (context, index) {
                final event = activeDowntimes[index];
                return _DowntimeCard(
                  event: event,
                  canResolve: canLogDowntime,
                  onResolve: () => _resolveDowntime(context, event),
                );
              },
            ),
      floatingActionButton: canLogDowntime
          ? FloatingActionButton.extended(
              onPressed: () => _logNewDowntime(context),
              icon: const Icon(Icons.add),
              label: const Text('Log Downtime'),
              backgroundColor: const Color(0xFFFF6B6B),
            )
          : null,
    );
  }

  Future<void> _logNewDowntime(BuildContext context) async {
    // Show dialog to log new downtime
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _LogDowntimeDialog(username: username),
    );

    if (result != null) {
      await MachineRuntimeService.startDowntime(
        machineId: result['machineId'],
        category: result['category'],
        reason: result['reason'],
        reportedBy: username,
        isPlanned: result['isPlanned'] ?? false,
      );
      onRefresh();
    }
  }

  Future<void> _resolveDowntime(BuildContext context, DowntimeEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Downtime'),
        content: Text('Mark downtime for machine as resolved?\n\nDuration: ${event.actualDuration} minutes'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await MachineRuntimeService.endDowntime(
        downtimeId: event.id,
        resolvedBy: username,
      );
      onRefresh();
    }
  }
}

class _DowntimeCard extends StatelessWidget {
  final DowntimeEvent event;
  final bool canResolve;
  final VoidCallback onResolve;

  const _DowntimeCard({
    required this.event,
    required this.canResolve,
    required this.onResolve,
  });

  Color _getCategoryColor() {
    switch (event.category) {
      case DowntimeCategory.mechanical:
        return Colors.orange;
      case DowntimeCategory.electrical:
        return Colors.yellow;
      case DowntimeCategory.material:
        return Colors.purple;
      case DowntimeCategory.mouldChange:
        return Colors.blue;
      case DowntimeCategory.setup:
        return Colors.cyan;
      case DowntimeCategory.quality:
        return Colors.pink;
      case DowntimeCategory.planned:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = event.actualDuration;
    final categoryColor = _getCategoryColor();

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    event.category.name.toUpperCase(),
                    style: TextStyle(
                      color: categoryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        '$duration min',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event.reason,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.white54),
                const SizedBox(width: 4),
                Text(
                  'Started ${DateFormat('HH:mm').format(event.startTime)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (event.reportedBy != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.person, size: 14, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(
                    event.reportedBy!,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
            if (canResolve) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onResolve,
                  icon: const Icon(Icons.check),
                  label: const Text('Resolve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LogDowntimeDialog extends StatefulWidget {
  final String username;

  const _LogDowntimeDialog({required this.username});

  @override
  State<_LogDowntimeDialog> createState() => _LogDowntimeDialogState();
}

class _LogDowntimeDialogState extends State<_LogDowntimeDialog> {
  String? _selectedMachineId;
  DowntimeCategory _category = DowntimeCategory.mechanical;
  final _reasonController = TextEditingController();
  bool _isPlanned = false;

  @override
  Widget build(BuildContext context) {
    final runtimes = MachineRuntimeService.getAllMachineRuntimes();

    return AlertDialog(
      title: const Text('Log Downtime'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedMachineId,
              decoration: const InputDecoration(labelText: 'Machine'),
              items: runtimes
                  .map((r) => DropdownMenuItem(
                        value: r.machineId,
                        child: Text(r.machineName),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedMachineId = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<DowntimeCategory>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: DowntimeCategory.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.name.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? DowntimeCategory.other),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Describe the issue...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _isPlanned,
              onChanged: (v) => setState(() => _isPlanned = v),
              title: const Text('Planned downtime'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedMachineId != null && _reasonController.text.isNotEmpty
              ? () => Navigator.pop(context, {
                    'machineId': _selectedMachineId,
                    'category': _category,
                    'reason': _reasonController.text,
                    'isPlanned': _isPlanned,
                  })
              : null,
          child: const Text('Log'),
        ),
      ],
    );
  }
}

// ============ OEE TAB ============

class _OEETab extends StatelessWidget {
  final List<MachineRuntime> runtimes;
  final VoidCallback onRefresh;

  const _OEETab({
    required this.runtimes,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: runtimes.length,
        itemBuilder: (context, index) {
          final runtime = runtimes[index];
          final oee = MachineRuntimeService.calculateShiftOEE(runtime.machineId);
          return _OEECard(
            machineName: runtime.machineName,
            oeeResult: oee,
          );
        },
      ),
    );
  }
}

class _OEECard extends StatelessWidget {
  final String machineName;
  final OEEResult oeeResult;

  const _OEECard({
    required this.machineName,
    required this.oeeResult,
  });

  Color _getOEEColor(double value) {
    if (value >= 0.85) return Colors.green;
    if (value >= 0.60) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final oeeColor = _getOEEColor(oeeResult.oee);

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
                    machineName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: oeeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(oeeResult.oee * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: oeeColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _OEEMetric(
                    label: 'Availability',
                    value: oeeResult.availability,
                    color: _getOEEColor(oeeResult.availability),
                  ),
                ),
                Expanded(
                  child: _OEEMetric(
                    label: 'Performance',
                    value: oeeResult.performance,
                    color: _getOEEColor(oeeResult.performance),
                  ),
                ),
                Expanded(
                  child: _OEEMetric(
                    label: 'Quality',
                    value: oeeResult.quality,
                    color: _getOEEColor(oeeResult.quality),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatItem(
                  label: 'Good Parts',
                  value: '${oeeResult.goodParts}',
                  color: Colors.green,
                ),
                _StatItem(
                  label: 'Scrap',
                  value: '${oeeResult.scrapParts}',
                  color: Colors.red,
                ),
                _StatItem(
                  label: 'Downtime',
                  value: '${oeeResult.downtimeMinutes}m',
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OEEMetric extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _OEEMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${(value * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
