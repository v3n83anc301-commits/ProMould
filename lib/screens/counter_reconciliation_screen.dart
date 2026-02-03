// lib/screens/counter_reconciliation_screen.dart
// ProMould v9 - Counter Reconciliation UI

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../services/reconciliation_service.dart';
import '../services/rbac_service.dart';
import '../services/log_service.dart';
import '../models/reconciliation_model.dart';
import '../core/constants.dart';
import '../config/permissions.dart';

class CounterReconciliationScreen extends StatefulWidget {
  final String username;
  final int level;

  const CounterReconciliationScreen({
    super.key,
    required this.username,
    required this.level,
  });

  @override
  State<CounterReconciliationScreen> createState() =>
      _CounterReconciliationScreenState();
}

class _CounterReconciliationScreenState
    extends State<CounterReconciliationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CounterReconciliation> _reconciliations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReconciliations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReconciliations() async {
    setState(() => _isLoading = true);
    try {
      _reconciliations = ReconciliationService.getAllReconciliations();
    } catch (e) {
      LogService.error('Failed to load reconciliations', e);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('Counter Reconciliation'),
        backgroundColor: const Color(0xFF0F1419),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4CC9F0),
          tabs: const [
            Tab(icon: Icon(Icons.add_circle), text: 'New'),
            Tab(icon: Icon(Icons.pending), text: 'Pending'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _NewReconciliationTab(
                  username: widget.username,
                  onRefresh: _loadReconciliations,
                ),
                _PendingApprovalsTab(
                  reconciliations: _reconciliations
                      .where((r) => r.status == ReconciliationStatus.pending)
                      .toList(),
                  level: widget.level,
                  onRefresh: _loadReconciliations,
                ),
                _ReconciliationHistoryTab(
                  reconciliations: _reconciliations
                      .where((r) => r.status != ReconciliationStatus.pending)
                      .toList(),
                ),
              ],
            ),
    );
  }
}

// ============ NEW RECONCILIATION TAB ============

class _NewReconciliationTab extends StatefulWidget {
  final String username;
  final VoidCallback onRefresh;

  const _NewReconciliationTab({
    required this.username,
    required this.onRefresh,
  });

  @override
  State<_NewReconciliationTab> createState() => _NewReconciliationTabState();
}

class _NewReconciliationTabState extends State<_NewReconciliationTab> {
  final _formKey = GlobalKey<FormState>();
  final _physicalCounterController = TextEditingController();
  final _reasonController = TextEditingController();

  String? _selectedMachineId;
  String? _selectedJobId;
  int _systemCounter = 0;
  bool _isSubmitting = false;

  List<Map> _machines = [];
  List<Map> _jobs = [];

  @override
  void initState() {
    super.initState();
    _loadMachinesAndJobs();
  }

  @override
  void dispose() {
    _physicalCounterController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _loadMachinesAndJobs() {
    final machinesBox = Hive.box(HiveBoxes.machines);
    final jobsBox = Hive.box(HiveBoxes.jobs);

    setState(() {
      _machines = machinesBox.values.cast<Map>().toList();
      _jobs = jobsBox.values
          .cast<Map>()
          .where((j) => j['status'] == 'Running' || j['status'] == 'running')
          .toList();
    });
  }

  void _onMachineSelected(String? machineId) {
    setState(() {
      _selectedMachineId = machineId;
      _selectedJobId = null;
      _systemCounter = 0;
    });

    if (machineId != null) {
      // Find running job on this machine
      final machine = _machines.firstWhere(
        (m) => m['id'] == machineId,
        orElse: () => {},
      );
      final currentJobId = machine['currentJobId'] as String?;

      if (currentJobId != null) {
        final job = _jobs.firstWhere(
          (j) => j['id'] == currentJobId,
          orElse: () => {},
        );
        if (job.isNotEmpty) {
          setState(() {
            _selectedJobId = currentJobId;
            _systemCounter = (job['produced'] as int?) ?? 0;
          });
        }
      }
    }
  }

  int get _variance {
    final physical = int.tryParse(_physicalCounterController.text) ?? 0;
    return physical - _systemCounter;
  }

  double get _variancePercent {
    if (_systemCounter == 0) return 0;
    return (_variance / _systemCounter) * 100;
  }

  bool get _requiresApproval {
    return _variancePercent.abs() > SystemThresholds.counterVarianceThreshold;
  }

  Future<void> _submitReconciliation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMachineId == null || _selectedJobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a machine and job')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUser = RBACService.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      final physicalCounter = int.parse(_physicalCounterController.text);

      await ReconciliationService.createReconciliation(
        machineId: _selectedMachineId!,
        jobId: _selectedJobId!,
        systemCounter: _systemCounter,
        physicalCounter: physicalCounter,
        reason: _reasonController.text,
        reconciledById: currentUser.id,
        reconciledByName: currentUser.username,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_requiresApproval
                ? 'Reconciliation submitted for approval'
                : 'Reconciliation auto-approved'),
            backgroundColor: Colors.green,
          ),
        );
        _physicalCounterController.clear();
        _reasonController.clear();
        setState(() {
          _selectedMachineId = null;
          _selectedJobId = null;
          _systemCounter = 0;
        });
        widget.onRefresh();
      }
    } catch (e) {
      LogService.error('Failed to create reconciliation', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    }

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4CC9F0).withOpacity(0.2),
                    const Color(0xFF0F1419),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFF4CC9F0).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.sync, color: Color(0xFF4CC9F0), size: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Counter Reconciliation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Compare physical counter with system count',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Machine Selection
            const Text(
              'Select Machine',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedMachineId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select a machine',
              ),
              items: _machines.map((m) {
                return DropdownMenuItem<String>(
                  value: m['id'] as String,
                  child: Text(m['name'] as String? ?? 'Unknown'),
                );
              }).toList(),
              onChanged: _onMachineSelected,
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Job Info
            if (_selectedJobId != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.work, color: Color(0xFF4CC9F0)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Job: ${_jobs.firstWhere((j) => j['id'] == _selectedJobId, orElse: () => {})['jobNumber'] ?? 'N/A'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'System Counter: $_systemCounter',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Physical Counter Input
            const Text(
              'Physical Counter Reading',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _physicalCounterController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter physical counter value',
                prefixIcon: Icon(Icons.numbers),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (int.tryParse(v) == null) return 'Must be a number';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Variance Display
            if (_physicalCounterController.text.isNotEmpty) ...[
              _VarianceCard(
                systemCounter: _systemCounter,
                physicalCounter:
                    int.tryParse(_physicalCounterController.text) ?? 0,
                variance: _variance,
                variancePercent: _variancePercent,
                requiresApproval: _requiresApproval,
              ),
              const SizedBox(height: 16),
            ],

            // Reason
            const Text(
              'Reason for Variance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Explain the reason for the variance...',
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Reason is required' : null,
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitReconciliation,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_requiresApproval
                    ? 'Submit for Approval'
                    : 'Submit Reconciliation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _requiresApproval ? Colors.orange : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _VarianceCard extends StatelessWidget {
  final int systemCounter;
  final int physicalCounter;
  final int variance;
  final double variancePercent;
  final bool requiresApproval;

  const _VarianceCard({
    required this.systemCounter,
    required this.physicalCounter,
    required this.variance,
    required this.variancePercent,
    required this.requiresApproval,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = variance > 0;
    final color = requiresApproval
        ? Colors.red
        : (variance == 0 ? Colors.green : Colors.orange);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _CounterColumn('System', systemCounter, Colors.blue),
              Icon(
                isPositive ? Icons.arrow_forward : Icons.arrow_back,
                color: color,
              ),
              _CounterColumn('Physical', physicalCounter, Colors.teal),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                variance == 0
                    ? Icons.check_circle
                    : (requiresApproval ? Icons.warning : Icons.info),
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                'Variance: ${isPositive ? '+' : ''}$variance (${variancePercent.toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          if (requiresApproval) ...[
            const SizedBox(height: 8),
            Text(
              'Requires supervisor approval (>${SystemThresholds.counterVarianceThreshold}% variance)',
              style: TextStyle(color: color, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _CounterColumn extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _CounterColumn(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ============ PENDING APPROVALS TAB ============

class _PendingApprovalsTab extends StatelessWidget {
  final List<CounterReconciliation> reconciliations;
  final int level;
  final VoidCallback onRefresh;

  const _PendingApprovalsTab({
    required this.reconciliations,
    required this.level,
    required this.onRefresh,
  });

  bool get canApprove => level >= 4; // Manager level

  @override
  Widget build(BuildContext context) {
    if (reconciliations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            const Text(
              'No pending approvals',
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
        itemCount: reconciliations.length,
        itemBuilder: (context, index) {
          final rec = reconciliations[index];
          return _PendingApprovalCard(
            reconciliation: rec,
            canApprove: canApprove,
            onAction: onRefresh,
          );
        },
      ),
    );
  }
}

class _PendingApprovalCard extends StatelessWidget {
  final CounterReconciliation reconciliation;
  final bool canApprove;
  final VoidCallback onAction;

  const _PendingApprovalCard({
    required this.reconciliation,
    required this.canApprove,
    required this.onAction,
  });

  Future<void> _approve(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Reconciliation'),
        content: Text(
          'Approve variance of ${reconciliation.variance} parts '
          '(${reconciliation.variancePercent.toStringAsFixed(1)}%)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final currentUser = RBACService.currentUser;
        if (currentUser == null) throw Exception('No user logged in');

        await ReconciliationService.approveReconciliation(
          reconciliation.id,
          currentUser.id,
          currentUser.username,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reconciliation approved'),
              backgroundColor: Colors.green,
            ),
          );
          onAction();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to approve: $e')),
          );
        }
      }
    }
  }

  Future<void> _reject(BuildContext context) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Reconciliation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Reason...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.isNotEmpty) {
      try {
        final currentUser = RBACService.currentUser;
        if (currentUser == null) throw Exception('No user logged in');

        await ReconciliationService.rejectReconciliation(
          reconciliation.id,
          currentUser.id,
          currentUser.username,
          reasonController.text,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reconciliation rejected'),
              backgroundColor: Colors.orange,
            ),
          );
          onAction();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reject: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1F2E),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pending, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Submitted by ${reconciliation.reconciledByName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${reconciliation.variancePercent.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _InfoColumn('System', '${reconciliation.systemCounter}'),
                _InfoColumn('Physical', '${reconciliation.physicalCounter}'),
                _InfoColumn(
                  'Variance',
                  '${reconciliation.variance > 0 ? '+' : ''}${reconciliation.variance}',
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Reason: ${reconciliation.reason}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              DateFormat('MMM d, yyyy HH:mm').format(reconciliation.timestamp),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (canApprove) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reject(context),
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('Reject',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approve(context),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _InfoColumn(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ============ HISTORY TAB ============

class _ReconciliationHistoryTab extends StatelessWidget {
  final List<CounterReconciliation> reconciliations;

  const _ReconciliationHistoryTab({required this.reconciliations});

  @override
  Widget build(BuildContext context) {
    if (reconciliations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            const Text(
              'No reconciliation history',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reconciliations.length,
      itemBuilder: (context, index) {
        final rec = reconciliations[index];
        final isApproved = rec.status == ReconciliationStatus.approved;

        return Card(
          color: const Color(0xFF1A1F2E),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              isApproved ? Icons.check_circle : Icons.cancel,
              color: isApproved ? Colors.green : Colors.red,
            ),
            title: Text(
              'Variance: ${rec.variance > 0 ? '+' : ''}${rec.variance} (${rec.variancePercent.toStringAsFixed(1)}%)',
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('By: ${rec.reconciledByName}'),
                Text(
                  DateFormat('MMM d, yyyy HH:mm').format(rec.timestamp),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isApproved
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                rec.status.displayName,
                style: TextStyle(
                  color: isApproved ? Colors.green : Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
